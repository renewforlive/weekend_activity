import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../data/mock_data.dart';
import '../l10n/app_strings.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';

/// 彈出「發起招募」表單:標題、內容、人數、性別、花費、集合資訊。
///
/// 傳入 [editing] 時為修改模式(只有發起者會走到這裡)。
Future<void> showRecruitmentEditor(
  BuildContext context, {
  Activity? relatedActivity,
  RecruitmentPost? editing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RecruitmentEditorSheet(
      relatedActivity: relatedActivity,
      editing: editing,
    ),
  );
}

class _RecruitmentEditorSheet extends StatefulWidget {
  const _RecruitmentEditorSheet({this.relatedActivity, this.editing});
  final Activity? relatedActivity;
  final RecruitmentPost? editing;

  @override
  State<_RecruitmentEditorSheet> createState() =>
      _RecruitmentEditorSheetState();
}

class _RecruitmentEditorSheetState extends State<_RecruitmentEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _content;
  late final TextEditingController _headcount;
  late final TextEditingController _cost;
  late final TextEditingController _activityPlace;
  late final TextEditingController _meetingPoint;
  late final TextEditingController _contact;
  GenderPref _gender = GenderPref.any;
  DateTime? _meetingTime;
  DateTime? _activityDate;
  String _city = taiwanCities.first;
  bool _saving = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final post = widget.editing;
    final a = widget.relatedActivity;

    if (post != null) {
      // 修改模式:帶入現有內容。
      _title = TextEditingController(text: post.title);
      _content = TextEditingController(text: post.content);
      _headcount = TextEditingController(text: post.headcount.toString());
      _cost = TextEditingController(text: post.cost.toString());
      _activityPlace = TextEditingController(text: post.activityPlace);
      _meetingPoint = TextEditingController(text: post.meetingPoint);
      _contact = TextEditingController(text: post.contactInfo);
      _gender = post.genderPref;
      _meetingTime = post.meetingTime;
      _activityDate = post.activityDate;
      _city = post.city.isEmpty ? taiwanCities.first : post.city;
    } else {
      _title = TextEditingController(
        text: a == null ? '' : AppStrings.togetherGo(a.title),
      );
      _content = TextEditingController(
        text: a == null
            ? ''
            : AppStrings.recruitmentContentPrefill(a.city, a.venue),
      );
      _headcount = TextEditingController(text: '4');
      _cost = TextEditingController(text: a?.cost.toString() ?? '0');
      _activityPlace = TextEditingController(text: a?.venue ?? '');
      _meetingPoint = TextEditingController();
      _contact = TextEditingController();
      _activityDate = a?.date;
      _city = a?.city ?? taiwanCities.first;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _headcount.dispose();
    _cost.dispose();
    _activityPlace.dispose();
    _meetingPoint.dispose();
    _contact.dispose();
    super.dispose();
  }

  /// 選集合時間。與活動的出行時間分開,通常早於出行時間。
  Future<void> _pickActivityDate() async {
    final now = DateTime.now();
    final initial = _activityDate ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    setState(() {
      _activityDate = DateTime(date.year, date.month, date.day);
    });
  }

  Future<void> _pickMeetingTime() async {
    final base = _meetingTime ?? _activityDate ?? DateTime.now();

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return;

    setState(() {
      _meetingTime = DateTime(
        base.year,
        base.month,
        base.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_activityDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請選擇活動日期')));
      return;
    }
    if (_meetingTime == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請選擇集合時間')));
      return;
    }
    setState(() => _saving = true);

    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final post = widget.editing;
    if (post != null) {
      final ok = await state.updateRecruitment(
        recruitmentId: post.id,
        title: _title.text.trim(),
        content: _content.text.trim(),
        headcount: int.parse(_headcount.text),
        genderPref: _gender,
        cost: int.tryParse(_cost.text) ?? 0,
        city: _city,
        activityPlace: _activityPlace.text.trim(),
        activityDate: _activityDate!,
        meetingPoint: _meetingPoint.text.trim(),
        meetingTime: _meetingTime,
        contactInfo: _contact.text.trim(),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      if (!ok) return; // 錯誤訊息由 AppState 的 syncError 統一顯示
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.recruitmentUpdated)),
      );
      return;
    }

    await state.createRecruitment(
      title: _title.text.trim(),
      content: _content.text.trim(),
      headcount: int.parse(_headcount.text),
      genderPref: _gender,
      cost: int.tryParse(_cost.text) ?? 0,
      relatedActivity: widget.relatedActivity,
      city: _city,
      activityPlace: _activityPlace.text.trim(),
      activityDate: _activityDate!,
      meetingPoint: _meetingPoint.text.trim(),
      meetingTime: _meetingTime,
      contactInfo: _contact.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(AppStrings.publishedSnack)));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing
                                ? AppStrings.editRecruitment
                                : AppStrings.startRecruitment,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppStrings.recruitmentEditorSubtitle,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 22),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.soft),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label(AppStrings.fieldTitle),
                        TextFormField(
                          controller: _title,
                          decoration: InputDecoration(
                            hintText: AppStrings.titleHint,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? AppStrings.titleRequired
                              : null,
                        ),
                        const SizedBox(height: 14),
                        _Label(AppStrings.fieldContent),
                        TextFormField(
                          controller: _content,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: AppStrings.contentHint,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? AppStrings.contentRequired
                              : null,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          '活動資訊',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _Label('活動縣市 *'),
                        DropdownButtonFormField<String>(
                          initialValue: _city,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.location_city_outlined),
                          ),
                          items: [
                            for (final city in taiwanCities)
                              DropdownMenuItem(value: city, child: Text(city)),
                          ],
                          onChanged: (city) {
                            if (city != null) setState(() => _city = city);
                          },
                        ),
                        const SizedBox(height: 14),
                        _Label('活動地點 *'),
                        TextFormField(
                          controller: _activityPlace,
                          decoration: const InputDecoration(
                            hintText: '例如：台北流行音樂中心、阿里山森林步道',
                            prefixIcon: Icon(Icons.place_outlined),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? '請填寫活動地點'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        _Label('活動日期 *'),
                        InkWell(
                          onTap: _pickActivityDate,
                          borderRadius: BorderRadius.circular(12),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.calendar_month_outlined),
                            ),
                            child: Text(
                              _activityDate == null
                                  ? '請選擇活動日期'
                                  : AppDate.monthDayWeek(_activityDate!),
                              style: TextStyle(
                                color: _activityDate == null
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _Label(AppStrings.headcountField),
                                  TextFormField(
                                    controller: _headcount,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: InputDecoration(
                                      suffixText: AppStrings.peopleUnit,
                                    ),
                                    validator: (v) {
                                      final n = int.tryParse(v ?? '');
                                      if (n == null || n < 1) {
                                        return AppStrings.atLeastOnePerson;
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _Label(AppStrings.costPerPerson),
                                  TextFormField(
                                    controller: _cost,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: const InputDecoration(
                                      prefixText: 'NT\$ ',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _Label(AppStrings.genderLimit),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final g in GenderPref.values)
                              ChoiceChip(
                                label: Text(AppStrings.genderLabel(g)),
                                selected: _gender == g,
                                onSelected: (_) => setState(() => _gender = g),
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(
                                  color: _gender == g
                                      ? Colors.white
                                      : AppColors.primaryDark,
                                  fontWeight: FontWeight.w600,
                                ),
                                backgroundColor: AppColors.soft,
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // 集合資訊:只有已核准的成員與發起者看得到,可留空之後再補。
                        Row(
                          children: [
                            const Icon(
                              Icons.lock_outline,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              AppStrings.meetingInfoTitle,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppStrings.meetingInfoOptional,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _Label('${AppStrings.meetingPointField} *'),
                        TextFormField(
                          controller: _meetingPoint,
                          decoration: InputDecoration(
                            hintText: AppStrings.meetingPointHint,
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? '請填寫集合地點'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        _Label('${AppStrings.meetingTimeField} *'),
                        InkWell(
                          onTap: _pickMeetingTime,
                          borderRadius: BorderRadius.circular(12),
                          child: InputDecorator(
                            decoration: const InputDecoration(),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _meetingTime == null
                                      ? AppStrings.meetingTimeHint
                                      : TimeOfDay.fromDateTime(
                                          _meetingTime!,
                                        ).format(context),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _meetingTime == null
                                        ? AppColors.textSecondary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                const Spacer(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _Label(AppStrings.contactField),
                        TextFormField(
                          controller: _contact,
                          decoration: InputDecoration(
                            hintText: AppStrings.contactHint,
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _submit,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.campaign),
                            label: Text(
                              _isEditing
                                  ? AppStrings.saveRecruitment
                                  : AppStrings.publishRecruitment,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
