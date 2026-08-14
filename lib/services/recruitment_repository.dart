import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../models/models.dart';
import 'supabase_config.dart';

/// 加入招募的結果。
enum JoinResult { ok, full, notFound, notAuthenticated, error }

/// 審核成員或更新招募的結果。
enum HostActionResult {
  ok,
  forbidden,
  notFound,
  notAuthenticated,

  /// 更新招募時,新名額小於目前已佔用的人數。
  headcountTooLow,
  invalidStatus,
  error,
}

/// 招募討論版的遠端存取。
class RecruitmentRepository {
  static const _recruitments = 'recruitments';

  /// 讀取所有招募貼文(含發起人與成員暱稱)。
  ///
  /// 注意:recruitments.author_id 的外鍵指向 auth.users,不是 profiles,
  /// 所以無法用 PostgREST 的 embed 直接帶出暱稱,改為分批查詢後在本地組裝。
  Future<List<RecruitmentPost>> fetchAll() async {
    // Moves elapsed posts to their terminal state before the feed is loaded.
    await SupabaseConfig.client.rpc('archive_expired_recruitments');
    final rows = await SupabaseConfig.client
        .from(_recruitments)
        .select('*, recruitment_members(user_id, status, guest_count)')
        .order('created_at', ascending: false);

    final list = rows as List;
    if (list.isEmpty) return [];

    // 收集發起人與所有成員的 id,一次查回暱稱。
    // 發起者要看到是誰申請,所以連成員一起查。
    final userIds = <String>{};
    for (final row in list) {
      if (row is! Map) continue;
      if (row['author_id'] is String) {
        userIds.add(row['author_id'] as String);
      }
      final members = row['recruitment_members'];
      if (members is List) {
        for (final m in members) {
          if (m is Map && m['user_id'] is String) {
            userIds.add(m['user_id'] as String);
          }
        }
      }
    }

    final nicknames = await _fetchNicknames(userIds);

    final posts = <RecruitmentPost>[];
    for (final row in list) {
      if (row is! Map) continue;
      posts.add(_parsePost(row, nicknames));
    }
    return posts;
  }

  /// 批次查詢暱稱。查不到不影響貼文顯示。
  Future<Map<String, String>> _fetchNicknames(Set<String> ids) async {
    if (ids.isEmpty) return {};
    final nicknames = <String, String>{};
    try {
      final rows = await SupabaseConfig.client
          .from('profiles')
          .select('id, nickname')
          .inFilter('id', ids.toList());
      for (final p in rows as List) {
        if (p is Map && p['id'] is String) {
          nicknames[p['id'] as String] = (p['nickname'] as String?) ?? '匿名';
        }
      }
    } catch (_) {
      // 查不到暱稱不影響貼文顯示。
    }
    return nicknames;
  }

  RecruitmentPost _parsePost(Map row, Map<String, String> nicknames) {
    final authorId = (row['author_id'] as String?) ?? '';
    final author = nicknames[authorId] ?? '匿名';

    // 成員名單(含審核狀態與帶人數)
    final members = <RecruitmentMember>[];
    final rawMembers = row['recruitment_members'];
    if (rawMembers is List) {
      for (final m in rawMembers) {
        if (m is! Map || m['user_id'] is! String) continue;
        final uid = m['user_id'] as String;
        members.add(
          RecruitmentMember(
            userId: uid,
            nickname: nicknames[uid] ?? '匿名',
            status: MemberStatus.fromText(m['status'] as String?),
            guestCount: (m['guest_count'] as num?)?.toInt() ?? 0,
          ),
        );
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

    final meetingRaw = row['meeting_time'] as String?;

    return RecruitmentPost(
      id: row['id'] as String,
      authorId: authorId,
      title: (row['title'] as String?) ?? '',
      content: (row['content'] as String?) ?? '',
      headcount: (row['headcount'] as num?)?.toInt() ?? 1,
      genderPref: _genderFrom(row['gender_pref'] as String?),
      cost: (row['cost'] as num?)?.toInt() ?? 0,
      author: author,
      createdAt:
          DateTime.tryParse('${row['created_at']}')?.toLocal() ??
          DateTime.now(),
      relatedActivity: related,
      city: (row['activity_city'] as String?) ?? '',
      activityPlace: (row['activity_venue'] as String?) ?? '',
      activityDate: actDate == null
          ? null
          : DateTime.tryParse(actDate)?.toLocal(),
      meetingPoint: (row['meeting_point'] as String?) ?? '',
      meetingTime: meetingRaw == null
          ? null
          : DateTime.tryParse(meetingRaw)?.toLocal(),
      contactInfo: (row['contact_info'] as String?) ?? '',
      coverPath: (row['cover_path'] as String?)?.trim(),
      coverUrl: _coverUrl(row['cover_path'] as String?),
      status: RecruitmentStatus.fromText(row['status'] as String?),
      members: members,
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

  static String? _coverUrl(String? path) {
    final value = path?.trim();
    if (value == null || value.isEmpty) return null;
    return SupabaseConfig.client.storage
        .from(SupabaseConfig.photoBucket)
        .getPublicUrl(value);
  }

  /// Uploads a 16:9 recruitment cover under the signed-in user's folder.
  Future<String> uploadCover({
    required Uint8List bytes,
    required String filePath,
  }) async {
    final uid = SupabaseConfig.userId;
    if (uid == null) throw StateError('尚未登入，無法上傳招募封面');
    final ext = p.extension(filePath).isEmpty ? '.jpg' : p.extension(filePath);
    final storagePath =
        '$uid/recruitment-covers/${DateTime.now().millisecondsSinceEpoch}$ext';
    await SupabaseConfig.client.storage
        .from(SupabaseConfig.photoBucket)
        .uploadBinary(storagePath, bytes);
    return storagePath;
  }

  Future<void> removeCover(String? storagePath) async {
    if (storagePath == null || storagePath.isEmpty) return;
    try {
      await SupabaseConfig.client.storage
          .from(SupabaseConfig.photoBucket)
          .remove([storagePath]);
    } catch (_) {
      // A stale cover does not prevent the recruitment from being updated.
    }
  }

  Future<void> updateCover(String recruitmentId, String coverPath) async {
    await SupabaseConfig.client
        .from(_recruitments)
        .update({'cover_path': coverPath})
        .eq('id', recruitmentId);
  }

  /// 發起招募。建立後自動把自己加入成員(狀態為已核准)。
  ///
  /// 成功回傳新貼文 id;失敗丟出例外由呼叫端處理。
  Future<String> create({
    required String title,
    required String content,
    required int headcount,
    required GenderPref genderPref,
    required int cost,
    Activity? relatedActivity,
    required String city,
    required String activityPlace,
    required DateTime activityDate,
    String meetingPoint = '',
    DateTime? meetingTime,
    String contactInfo = '',
    String? coverPath,
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
          'activity_city': relatedActivity?.city ?? city,
          'activity_venue': relatedActivity?.venue ?? activityPlace,
          'activity_date': _dateOnly(relatedActivity?.date ?? activityDate),
          'meeting_point': meetingPoint.isEmpty ? null : meetingPoint,
          'meeting_time': meetingTime?.toUtc().toIso8601String(),
          'contact_info': contactInfo.isEmpty ? null : contactInfo,
          'cover_path': coverPath,
        })
        .select()
        .single();

    final newId = inserted['id'] as String;
    // 發起人自動加入(走 function,會直接給 approved 狀態)。
    // 加入失敗不影響貼文本身,呼叫端重新 fetch 即可看到正確狀態。
    await join(newId);
    return newId;
  }

  /// 發起者更新招募內容(含集合資訊)。
  Future<HostActionResult> update({
    required String recruitmentId,
    required String title,
    required String content,
    required int headcount,
    required GenderPref genderPref,
    required int cost,
    required String city,
    required String activityPlace,
    required DateTime activityDate,
    String meetingPoint = '',
    DateTime? meetingTime,
    String contactInfo = '',
  }) async {
    try {
      final result = await SupabaseConfig.client.rpc(
        'update_recruitment',
        params: {
          'p_recruitment_id': recruitmentId,
          'p_title': title,
          'p_content': content,
          'p_headcount': headcount,
          'p_gender_pref': _genderTo(genderPref),
          'p_cost': cost,
          'p_activity_city': city,
          'p_activity_venue': activityPlace,
          'p_activity_date': _dateOnly(activityDate),
          'p_meeting_point': meetingPoint.isEmpty ? null : meetingPoint,
          'p_meeting_time': meetingTime?.toUtc().toIso8601String(),
          'p_contact_info': contactInfo.isEmpty ? null : contactInfo,
        },
      );
      return _hostResultFrom(result);
    } catch (_) {
      return HostActionResult.error;
    }
  }

  /// 申請加入招募。名額檢查(含帶的人)由資料庫 function 以交易保證。
  ///
  /// [guestCount] 為本人以外額外帶的人數。
  Future<JoinResult> join(String recruitmentId, {int guestCount = 0}) async {
    try {
      final result = await SupabaseConfig.client.rpc(
        'join_recruitment',
        params: {
          'p_recruitment_id': recruitmentId,
          'p_guest_count': guestCount,
        },
      );
      switch (result) {
        case 'ok':
          await _sendRecruitmentNotification(
            type: 'join_request',
            recruitmentId: recruitmentId,
          );
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

  /// 發起者同意或拒絕某位申請者。
  Future<HostActionResult> setMemberStatus({
    required String recruitmentId,
    required String userId,
    required MemberStatus status,
  }) async {
    try {
      final result = await SupabaseConfig.client.rpc(
        'set_member_status',
        params: {
          'p_recruitment_id': recruitmentId,
          'p_user_id': userId,
          'p_status': status.name,
        },
      );
      if (result == 'ok') {
        await _sendRecruitmentNotification(
          type: 'member_status',
          recruitmentId: recruitmentId,
          memberId: userId,
          status: status.name,
        );
      }
      return _hostResultFrom(result);
    } catch (_) {
      return HostActionResult.error;
    }
  }

  Future<HostActionResult> setRecruitmentStatus({
    required String recruitmentId,
    required RecruitmentStatus status,
  }) async {
    try {
      final result = await SupabaseConfig.client.rpc(
        'set_recruitment_status',
        params: {'p_recruitment_id': recruitmentId, 'p_status': status.name},
      );
      if (result == 'ok') {
        await _sendRecruitmentNotification(
          type: 'recruitment_status',
          recruitmentId: recruitmentId,
          status: status.name,
        );
      }
      return _hostResultFrom(result);
    } catch (_) {
      return HostActionResult.error;
    }
  }

  Future<void> _sendRecruitmentNotification({
    required String type,
    required String recruitmentId,
    String? memberId,
    String? status,
  }) async {
    try {
      final payload = <String, dynamic>{
        'type': type,
        'recruitmentId': recruitmentId,
      };
      if (memberId != null) payload['memberId'] = memberId;
      if (status != null) payload['status'] = status;
      await SupabaseConfig.client.functions.invoke(
        'recruitment-notifications',
        body: payload,
      );
    } catch (_) {
      // The action already succeeded; a transient push failure must not undo it.
    }
  }

  static HostActionResult _hostResultFrom(dynamic raw) {
    switch (raw) {
      case 'ok':
        return HostActionResult.ok;
      case 'forbidden':
        return HostActionResult.forbidden;
      case 'not_found':
        return HostActionResult.notFound;
      case 'not_authenticated':
        return HostActionResult.notAuthenticated;
      case 'headcount_too_low':
        return HostActionResult.headcountTooLow;
      case 'invalid_status':
        return HostActionResult.invalidStatus;
      default:
        return HostActionResult.error;
    }
  }

  /// Activity dates are calendar dates; only the optional meeting time carries
  /// a time of day. Store the date at UTC midnight to keep it stable in SQL.
  static String _dateOnly(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day).toIso8601String();

  /// 退出招募。
  Future<HostActionResult> leave(String recruitmentId) async {
    try {
      final result = await SupabaseConfig.client.rpc(
        'leave_recruitment',
        params: {'p_recruitment_id': recruitmentId},
      );
      return _hostResultFrom(result);
    } catch (_) {
      return HostActionResult.error;
    }
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
