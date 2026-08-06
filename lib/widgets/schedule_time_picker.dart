import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../l10n/app_strings.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';

/// 排入行程對話框。
/// - 景點(spot != null):自由選日期與時間。
/// - 展覽(activity != null):時間固定,不可更改,僅顯示並確認。
///
/// 排入成功回傳 true。
Future<bool> showScheduleTimePicker(
  BuildContext context, {
  TravelSpot? spot,
  Activity? activity,
}) async {
  assert(spot != null || activity != null, '需提供 spot 或 activity');
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ScheduleTimeSheet(spot: spot, activity: activity),
  );
  return result ?? false;
}

class _ScheduleTimeSheet extends StatefulWidget {
  const _ScheduleTimeSheet({this.spot, this.activity});
  final TravelSpot? spot;
  final Activity? activity;

  @override
  State<_ScheduleTimeSheet> createState() => _ScheduleTimeSheetState();
}

class _ScheduleTimeSheetState extends State<_ScheduleTimeSheet> {
  bool get _isSpot => widget.spot != null;
  bool get _fixed => widget.activity != null; // 展覽固定時間

  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    if (_fixed) _selected = widget.activity!.date;
  }

  String get _title => _isSpot ? widget.spot!.name : widget.activity!.title;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final base = _selected ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: base.isBefore(now) ? now : base,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return;
    final t = _selected;
    setState(() {
      _selected = DateTime(date.year, date.month, date.day, t?.hour ?? 9, t?.minute ?? 0);
    });
  }

  Future<void> _pickTime() async {
    final base = _selected ?? DateTime.now();
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return;
    setState(() {
      _selected = DateTime(base.year, base.month, base.day, time.hour, time.minute);
    });
  }

  void _confirm() {
    final state = context.read<AppState>();
    if (_isSpot) {
      if (_selected == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.selectDateFirst)),
        );
        return;
      }
      state.addSpotToSchedule(widget.spot!, _selected!);
    } else {
      state.addToSchedule(widget.activity!);
    }
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.scheduledSnack)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44, height: 4,
                decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(AppStrings.pickScheduleTime,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(_title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 18),
            if (_fixed) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    const Icon(Icons.lock_clock, color: AppColors.primaryDark),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppDate.monthDayWeekTime(_selected!),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text(AppStrings.fixedTimeHint,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _PickButton(
                      icon: Icons.event,
                      label: _selected == null ? AppStrings.pickDate : AppDate.monthDayWeek(_selected!),
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PickButton(
                      icon: Icons.schedule,
                      label: _selected == null
                          ? AppStrings.pickTime
                          : '${_selected!.hour.toString().padLeft(2, '0')}:${_selected!.minute.toString().padLeft(2, '0')}',
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _confirm,
                icon: const Icon(Icons.add_task),
                label: Text(AppStrings.confirm),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickButton extends StatelessWidget {
  const _PickButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryDark,
        side: const BorderSide(color: AppColors.primary),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}