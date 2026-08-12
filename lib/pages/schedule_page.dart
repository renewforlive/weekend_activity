import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../l10n/app_strings.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import 'activity_detail_page.dart';
import 'booked_recruitment_detail_page.dart';

/// 行程頁:週曆檢視。顯示一週日期,點日期看當天行程,
/// 可左右換週,並用日曆鈕跳到任一天。
class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  late DateTime _selectedDay;
  late DateTime _weekStart; // 當週週一

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _weekStart = _mondayOf(_selectedDay);
  }

  DateTime _mondayOf(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  void _shiftWeek(int weeks) {
    setState(() => _weekStart = _weekStart.add(Duration(days: 7 * weeks)));
  }

  void _selectDay(DateTime d) {
    setState(() {
      _selectedDay = DateTime(d.year, d.month, d.day);
      _weekStart = _mondayOf(_selectedDay);
    });
  }

  Future<void> _jumpToDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) _selectDay(picked);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final dayItems = state.scheduleOnDay(_selectedDay);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.scheduleTitle),
        actions: [
          IconButton(
            onPressed: _jumpToDate,
            icon: const Icon(Icons.calendar_month),
            tooltip: AppStrings.jumpToDate,
          ),
        ],
      ),
      body: Column(
        children: [
          _WeekBar(
            weekStart: _weekStart,
            selectedDay: _selectedDay,
            onPrev: () => _shiftWeek(-1),
            onNext: () => _shiftWeek(1),
            onSelectDay: _selectDay,
            hasScheduleOn: state.hasScheduleOnDay,
          ),
          const Divider(height: 1),
          Expanded(
            child: dayItems.isEmpty
                ? _empty()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: dayItems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) =>
                        _ScheduleCard(item: dayItems[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.event_available,
            size: 56,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            AppStrings.noScheduleOnDay,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// 一週日期列:週一到週日,顯示星期與日,標記有行程的日子。
class _WeekBar extends StatelessWidget {
  const _WeekBar({
    required this.weekStart,
    required this.selectedDay,
    required this.onPrev,
    required this.onNext,
    required this.onSelectDay,
    required this.hasScheduleOn,
  });
  final DateTime weekStart;
  final DateTime selectedDay;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelectDay;
  final bool Function(DateTime) hasScheduleOn;

  static const _weekNames = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final today = DateTime.now();
    final isToday = DateTime(today.year, today.month, today.day);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_left, color: AppColors.primary),
              ),
              Expanded(
                child: Text(
                  '${weekStart.month}/${weekStart.day} - ${weekEnd.month}/${weekEnd.day}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right, color: AppColors.primary),
              ),
            ],
          ),
          Row(
            children: [
              for (int i = 0; i < 7; i++)
                Expanded(
                  child: _DayCell(
                    day: weekStart.add(Duration(days: i)),
                    weekName: _weekNames[i],
                    selected: _sameDay(
                      weekStart.add(Duration(days: i)),
                      selectedDay,
                    ),
                    isToday: _sameDay(
                      weekStart.add(Duration(days: i)),
                      isToday,
                    ),
                    hasSchedule: hasScheduleOn(
                      weekStart.add(Duration(days: i)),
                    ),
                    onTap: () => onSelectDay(weekStart.add(Duration(days: i))),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.weekName,
    required this.selected,
    required this.isToday,
    required this.hasSchedule,
    required this.onTap,
  });
  final DateTime day;
  final String weekName;
  final bool selected;
  final bool isToday;
  final bool hasSchedule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Column(
          children: [
            Text(
              weekName,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: isToday && !selected
                    ? Border.all(color: AppColors.primary, width: 1.5)
                    : null,
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: hasSchedule ? AppColors.accent : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
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
    final isRecruitment = a.id.startsWith('recruitment_');
    final dateStr = AppDate.monthDayWeekTime(a.date);
    final remindStr = AppDate.monthDayTime(item.remindAt);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final page = isRecruitment
              ? BookedRecruitmentDetailPage(
                  recruitmentId: a.id.substring('recruitment_'.length),
                )
              : ActivityDetailPage(activity: a);
          Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => page));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: a.category.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(a.category.icon, color: a.category.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (isRecruitment)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                '招募活動',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          '$dateStr · ${a.city}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isRecruitment)
                    IconButton(
                      onPressed: () => state.removeFromSchedule(item.id),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.danger,
                      ),
                    ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(
                    Icons.notifications_active_outlined,
                    size: 20,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.reminderEnabled
                          ? AppStrings.remindAtLabel(remindStr)
                          : AppStrings.reminderOff,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
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
                    icon: const Icon(
                      Icons.edit_calendar,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      AppStrings.adjustReminder,
                      style: const TextStyle(color: AppColors.primary),
                    ),
                  ),
                ),
            ],
          ),
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
    final remind = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    state.updateReminder(item.id, remindAt: remind, enabled: true);
  }
}
