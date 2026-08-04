import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';

/// 行程頁:管理已排入的活動,可設定/調整提醒時間與開關。
class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final items = state.schedule;
    return Scaffold(
      appBar: AppBar(title: const Text('我的行程')),
      body: items.isEmpty
          ? _empty()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _ScheduleCard(item: items[i]),
            ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_available, size: 56, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          const Text('還沒有行程,\n到「活動」頁把想參加的排進來吧!',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.item});
  final ScheduleItem item;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final a = item.activity;
    final dateStr = AppDate.monthDayWeekTime(a.date);
    final remindStr = AppDate.monthDayTime(item.remindAt);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: a.category.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: Icon(a.category.icon, color: a.category.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text('$dateStr · ${a.city}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => state.removeFromSchedule(item.id),
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.notifications_active_outlined, size: 20, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.reminderEnabled ? '提醒時間:$remindStr' : '提醒已關閉',
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  ),
                ),
                Switch(
                  value: item.reminderEnabled,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => state.updateReminder(item.id, enabled: v),
                ),
              ],
            ),
            if (item.reminderEnabled)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _pickRemind(context, state),
                  icon: const Icon(Icons.edit_calendar, size: 18, color: AppColors.primary),
                  label: const Text('調整提醒時間', style: TextStyle(color: AppColors.primary)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRemind(BuildContext context, AppState state) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: item.remindAt.isAfter(now) ? item.remindAt : now,
      firstDate: now,
      lastDate: item.activity.date,
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(item.remindAt),
    );
    if (time == null) return;
    final remind = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    state.updateReminder(item.id, remindAt: remind, enabled: true);
  }
}