import '../models/models.dart';
import 'supabase_config.dart';

/// 加入招募的結果。
enum JoinResult {
  ok,
  full,
  notFound,
  notAuthenticated,
  error,
}

/// 招募討論版的遠端存取。
class RecruitmentRepository {
  static const _recruitments = 'recruitments';
  static const _members = 'recruitment_members';

  /// 讀取所有招募貼文(含發起人暱稱與參加者)。
  ///
  /// 注意:recruitments.author_id 的外鍵指向 auth.users,不是 profiles,
  /// 所以無法用 PostgREST 的 embed 直接帶出暱稱,改為分批查詢後在本地組裝。
  Future<List<RecruitmentPost>> fetchAll() async {
    final rows = await SupabaseConfig.client
        .from(_recruitments)
        .select('*, recruitment_members(user_id)')
        .order('created_at', ascending: false);

    final list = rows as List;
    if (list.isEmpty) return [];

    // 收集所有發起人 id,一次查回暱稱。
    final authorIds = <String>{};
    for (final row in list) {
      if (row is Map && row['author_id'] is String) {
        authorIds.add(row['author_id'] as String);
      }
    }

    final nicknames = <String, String>{};
    if (authorIds.isNotEmpty) {
      try {
        final profileRows = await SupabaseConfig.client
            .from('profiles')
            .select('id, nickname')
            .inFilter('id', authorIds.toList());
        for (final p in profileRows as List) {
          if (p is Map && p['id'] is String) {
            nicknames[p['id'] as String] = (p['nickname'] as String?) ?? '匿名';
          }
        }
      } catch (_) {
        // 查不到暱稱不影響貼文顯示。
      }
    }

    final posts = <RecruitmentPost>[];
    for (final row in list) {
      if (row is! Map) continue;
      posts.add(_parsePost(row, nicknames));
    }
    return posts;
  }

  RecruitmentPost _parsePost(Map row, Map<String, String> nicknames) {
    final authorId = (row['author_id'] as String?) ?? '';
    final author = nicknames[authorId] ?? '匿名';

    // 參加者 user_id 集合
    final joinedBy = <String>{};
    final members = row['recruitment_members'];
    if (members is List) {
      for (final m in members) {
        if (m is Map && m['user_id'] is String) {
          joinedBy.add(m['user_id'] as String);
        }
      }
    }

    // 關聯活動(以攤平欄位存的快照)
    Activity? related;
    final actTitle = row['activity_title'] as String?;
    final actDate = row['activity_date'] as String?;
    if (actTitle != null && actTitle.isNotEmpty && actDate != null) {
      final parsed = DateTime.tryParse(actDate);
      if (parsed != null) {
        related = Activity(
          id: 'rel_${row['id']}',
          title: actTitle,
          city: (row['activity_city'] as String?) ?? '',
          venue: '',
          date: parsed.toLocal(),
          category: ActivityCategory.outdoor,
          description: '',
          cost: 0,
        );
      }
    }

    return RecruitmentPost(
      id: row['id'] as String,
      authorId: authorId,
      title: (row['title'] as String?) ?? '',
      content: (row['content'] as String?) ?? '',
      headcount: (row['headcount'] as num?)?.toInt() ?? 1,
      genderPref: _genderFrom(row['gender_pref'] as String?),
      cost: (row['cost'] as num?)?.toInt() ?? 0,
      author: author,
      createdAt: DateTime.tryParse('${row['created_at']}')?.toLocal() ?? DateTime.now(),
      relatedActivity: related,
      joinedBy: joinedBy,
    );
  }

  static GenderPref _genderFrom(String? raw) {
    switch (raw) {
      case 'male':
        return GenderPref.male;
      case 'female':
        return GenderPref.female;
      case 'balanced':
        return GenderPref.balanced;
      default:
        return GenderPref.any;
    }
  }

  static String _genderTo(GenderPref g) => g.name;

  /// 發起招募。建立後自動把自己加入成員。
  ///
  /// 成功回傳新貼文 id;失敗丟出例外由呼叫端處理。
  Future<String> create({
    required String title,
    required String content,
    required int headcount,
    required GenderPref genderPref,
    required int cost,
    Activity? relatedActivity,
  }) async {
    final uid = SupabaseConfig.userId;
    if (uid == null) {
      throw StateError('尚未登入,無法發起招募');
    }

    final inserted = await SupabaseConfig.client
        .from(_recruitments)
        .insert({
          'author_id': uid,
          'title': title,
          'content': content,
          'headcount': headcount,
          'gender_pref': _genderTo(genderPref),
          'cost': cost,
          'activity_title': relatedActivity?.title,
          'activity_city': relatedActivity?.city,
          'activity_date': relatedActivity?.date.toUtc().toIso8601String(),
        })
        .select()
        .single();

    final newId = inserted['id'] as String;
    // 發起人自動加入(走 function 以符合名額檢查邏輯)。
    // 加入失敗不影響貼文本身,呼叫端重新 fetch 即可看到正確狀態。
    await join(newId);
    return newId;
  }

  /// 加入招募。名額檢查由資料庫 function 以交易保證。
  Future<JoinResult> join(String recruitmentId) async {
    try {
      final result = await SupabaseConfig.client.rpc(
        'join_recruitment',
        params: {'p_recruitment_id': recruitmentId},
      );
      switch (result) {
        case 'ok':
          return JoinResult.ok;
        case 'full':
          return JoinResult.full;
        case 'not_found':
          return JoinResult.notFound;
        case 'not_authenticated':
          return JoinResult.notAuthenticated;
        default:
          return JoinResult.error;
      }
    } catch (_) {
      return JoinResult.error;
    }
  }

  /// 退出招募。
  Future<void> leave(String recruitmentId) async {
    final uid = SupabaseConfig.userId;
    if (uid == null) return;
    await SupabaseConfig.client
        .from(_members)
        .delete()
        .eq('recruitment_id', recruitmentId)
        .eq('user_id', uid);
  }

  /// 我發起的招募數量。
  Future<int> hostedCount() async {
    final uid = SupabaseConfig.userId;
    if (uid == null) return 0;
    final rows = await SupabaseConfig.client
        .from(_recruitments)
        .select('id')
        .eq('author_id', uid);
    return (rows as List).length;
  }
}