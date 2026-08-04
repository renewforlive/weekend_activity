import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import '../widgets/recruitment_editor.dart';

/// 活動頁:選擇台灣縣市,列出近三個月內的活動。
class ActivitiesPage extends StatelessWidget {
  const ActivitiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final activities = state.activitiesForSelectedCity;
    return Scaffold(
      appBar: AppBar(
        title: const Text('探索活動'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.place, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: _CityDropdown(
                    value: state.selectedCity,
                    cities: state.cities,
                    onChanged: state.selectCity,
                  ),
                ),
                const SizedBox(width: 8),
                Text('近三個月', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
      body: activities.isEmpty
          ? const _EmptyHint(text: '這個縣市近三個月還沒有活動,\n換個縣市看看吧!')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: activities.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => ActivityCard(activity: activities[i]),
            ),
    );
  }
}

class _CityDropdown extends StatelessWidget {
  const _CityDropdown({required this.value, required this.cities, required this.onChanged});
  final String value;
  final List<String> cities;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          icon: const Icon(Icons.expand_more, color: AppColors.primary),
          items: [for (final c in cities) DropdownMenuItem(value: c, child: Text(c))],
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }
}

/// 活動卡片:分類色條 + 標題 + 日期地點 + 費用 + 操作(排入行程 / 發起招募)。
class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, required this.activity});
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheduled = state.isScheduled(activity);
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
                  decoration: BoxDecoration(color: activity.category.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: Icon(activity.category.icon, color: activity.category.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(activity.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(activity.category.label, style: TextStyle(fontSize: 12, color: activity.category.color, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                _CostTag(cost: activity.cost),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(icon: Icons.event, text: AppDate.monthDayWeek(activity.date)),
            const SizedBox(height: 4),
            _InfoRow(icon: Icons.place_outlined, text: '${activity.city} · ${activity.venue}'),
            const SizedBox(height: 10),
            Text(activity.description, style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: scheduled ? null : () {
                      state.addToSchedule(activity);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已排入行程,並幫你設定提醒 🔔')),
                      );
                    },
                    icon: Icon(scheduled ? Icons.check : Icons.add_task, size: 18),
                    label: Text(scheduled ? '已在行程' : '排入行程'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheduled ? AppColors.soft : AppColors.primary,
                      foregroundColor: scheduled ? AppColors.primaryDark : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showRecruitmentEditor(context, relatedActivity: activity),
                    icon: const Icon(Icons.campaign_outlined, size: 18),
                    label: const Text('發起招募'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: const BorderSide(color: AppColors.accent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CostTag extends StatelessWidget {
  const _CostTag({required this.cost});
  final int cost;
  @override
  Widget build(BuildContext context) {
    final free = cost == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: free ? AppColors.soft : AppColors.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        free ? '免費' : 'NT\$ $cost',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: free ? AppColors.primaryDark : AppColors.accent),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: AppColors.textSecondary))),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_busy, size: 56, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
        ],
      ),
    );
  }
}