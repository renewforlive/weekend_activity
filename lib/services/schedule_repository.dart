import '../models/models.dart';
import 'supabase_config.dart';

/// 行程的遠端存取(私人資料,RLS 限制只有本人可讀寫)。
class ScheduleRepository {
  static const _table = 'schedules';

  /// 讀取目前使用者的所有行程。
  Future<List<ScheduleItem>> fetchAll() async {
    final uid = SupabaseConfig.userId;
    if (uid == null) return [];

    final rows = await SupabaseConfig.client
        .from(_table)
        .select()
        .eq('user_id', uid)
        .order('activity_date');

    final items = <ScheduleItem>[];
    for (final row in rows as List) {
      if (row is! Map) continue;
      final activity = Activity(
        id: (row['activity_ref'] as String?) ?? '',
        title: (row['title'] as String?) ?? '',
        city: (row['city'] as String?) ?? '',
        venue: (row['venue'] as String?) ?? '',
        date: DateTime.tryParse('${row['activity_date']}')?.toLocal() ?? DateTime.now(),
        category: _categoryFrom(row['category'] as String?),
        description: (row['description'] as String?) ?? '',
        cost: (row['cost'] as num?)?.toInt() ?? 0,
      );
      items.add(ScheduleItem(
        id: row['id'] as String,
        activity: activity,
        remindAt: DateTime.tryParse('${row['remind_at']}')?.toLocal() ?? DateTime.now(),
        reminderEnabled: (row['reminder_enabled'] as bool?) ?? true,
      ));
    }
    return items;
  }

  static ActivityCategory _categoryFrom(String? raw) {
    for (final c in ActivityCategory.values) {
      if (c.name == raw) return c;
    }
    return ActivityCategory.outdoor;
  }

  /// 新增行程。回傳新建立的項目(含資料庫 id);已存在則回傳 null。
  Future<ScheduleItem?> add(Activity activity, DateTime remindAt) async {
    final uid = SupabaseConfig.userId;
    if (uid == null) return null;

    try {
      final inserted = await SupabaseConfig.client
          .from(_table)
          .insert({
            'user_id': uid,
            'activity_ref': activity.id,
            'title': activity.title,
            'city': activity.city,
            'venue': activity.venue,
            'activity_date': activity.date.toUtc().toIso8601String(),
            'category': activity.category.name,
            'description': activity.description,
            'cost': activity.cost,
            'remind_at': remindAt.toUtc().toIso8601String(),
            'reminder_enabled': true,
          })
          .select()
          .single();

      return ScheduleItem(
        id: inserted['id'] as String,
        activity: activity,
        remindAt: remindAt,
      );
    } catch (_) {
      // unique (user_id, activity_ref) 衝突 = 已排入過。
      return null;
    }
  }

  /// 移除行程。
  Future<void> remove(String scheduleId) async {
    await SupabaseConfig.client.from(_table).delete().eq('id', scheduleId);
  }

  /// 更新提醒時間與開關。
  Future<void> updateReminder(
    String scheduleId, {
    DateTime? remindAt,
    bool? enabled,
  }) async {
    final payload = <String, dynamic>{};
    if (remindAt != null) payload['remind_at'] = remindAt.toUtc().toIso8601String();
    if (enabled != null) payload['reminder_enabled'] = enabled;
    if (payload.isEmpty) return;

    await SupabaseConfig.client.from(_table).update(payload).eq('id', scheduleId);
  }
}