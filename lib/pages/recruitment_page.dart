import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../data/mock_data.dart';
import '../l10n/app_strings.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import '../widgets/recruitment_editor.dart';
import '../widgets/require_sign_in.dart';

/// 招募討論版:瀏覽揪團貼文、申請加入、發起與管理招募。
///
/// 三種身分看到的內容不同:
/// * 發起者:修改鈕 + 審核名單(同意/拒絕),看得到集合資訊,沒有加入/退出鈕。
/// * 已申請者:依審核狀態顯示「等待同意」或「已加入」,核准後才看得到集合資訊。
/// * 未加入者:申請鈕(可帶人),看不到集合資訊。
class RecruitmentPage extends StatefulWidget {
  const RecruitmentPage({super.key});

  @override
  State<RecruitmentPage> createState() => _RecruitmentPageState();
}

enum _DateFilter { all, week, month }

class _RecruitmentPageState extends State<RecruitmentPage> {
  String _city = '全部縣市';
  _DateFilter _dateFilter = _DateFilter.all;
  DateTimeRange? _customDateRange;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final posts = state.recruitments
        // 招募討論版只用來媒合。成團後改由「已預約」承接。
        .where((post) => post.isRecruiting && _matchesFilters(post, state))
        .toList();
    final mine = posts
        .where((post) => post.isHostedBy(state.currentUserId))
        .toList();
    final others = posts
        .where((post) => !post.isHostedBy(state.currentUserId))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.recruitmentTitle),
        actions: [
          IconButton(
            tooltip: AppStrings.startRecruitment,
            onPressed: () => _startRecruitment(context),
            icon: const Icon(Icons.add_circle_outline),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: state.loadRemoteData,
        child: posts.isEmpty && state.recruitments.isEmpty
            ? Stack(
                children: [
                  ListView(), // 讓下拉手勢在空清單也有效
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _FilterBar(
                        city: _city,
                        dateFilter: _dateFilter,
                        onCityChanged: (city) => setState(() => _city = city),
                        onDateChanged: _selectDateFilter,
                        dateRange: _customDateRange,
                        onPickDateRange: _pickDateRange,
                        onClearDateRange: () =>
                            setState(() => _customDateRange = null),
                      ),
                    ),
                  ),
                  _empty(),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _FilterBar(
                    city: _city,
                    dateFilter: _dateFilter,
                    onCityChanged: (city) => setState(() => _city = city),
                    onDateChanged: _selectDateFilter,
                    dateRange: _customDateRange,
                    onPickDateRange: _pickDateRange,
                    onClearDateRange: () =>
                        setState(() => _customDateRange = null),
                  ),
                  const SizedBox(height: 18),
                  if (posts.isEmpty) ...[const SizedBox(height: 72), _empty()],
                  if (mine.isNotEmpty) ...[
                    const _SectionTitle('我發起的招募'),
                    const SizedBox(height: 10),
                    _RecruitmentGrid(posts: mine),
                  ],
                  if (others.isNotEmpty) ...[
                    const _SectionTitle('其他人發起的招募'),
                    const SizedBox(height: 10),
                    _RecruitmentGrid(posts: others),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.forum_outlined,
            size: 56,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            AppStrings.recruitmentEmpty,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  bool _matchesFilters(RecruitmentPost post, AppState state) {
    if (_city != '全部縣市' && post.city != _city) return false;
    // 發起人始終可管理自己的貼文；其他招募則依帳號性別過濾。
    if (!post.isHostedBy(state.currentUserId)) {
      final profileGender = state.profile.gender;
      if (profileGender == ProfileGender.male &&
          post.genderPref == GenderPref.female) {
        return false;
      }
      if (profileGender == ProfileGender.female &&
          post.genderPref == GenderPref.male) {
        return false;
      }
    }
    final date = post.activityDate;
    if (date == null) {
      return _dateFilter == _DateFilter.all && _customDateRange == null;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final range = _customDateRange;
    if (range != null) {
      final start = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      final end = DateTime(range.end.year, range.end.month, range.end.day);
      return !target.isBefore(start) && !target.isAfter(end);
    }
    if (_dateFilter == _DateFilter.all) return true;
    switch (_dateFilter) {
      case _DateFilter.week:
        return !target.isBefore(today) &&
            target.isBefore(today.add(const Duration(days: 7)));
      case _DateFilter.month:
        return target.year == today.year && target.month == today.month;
      case _DateFilter.all:
        return true;
    }
  }

  void _selectDateFilter(_DateFilter filter) {
    setState(() {
      _dateFilter = filter;
      _customDateRange = null;
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    if (kIsWeb) {
      // The standard range picker becomes a two-month full-screen sheet at
      // the web app's compact width, which overflows its phone-like frame.
      // Use two compact pickers instead while preserving range selection.
      final start = await showDatePicker(
        context: context,
        initialDate: _customDateRange?.start ?? now,
        firstDate: DateTime(2020),
        lastDate: DateTime(now.year + 2, 12, 31),
        helpText: '選擇開始日期',
        confirmText: '下一步',
      );
      if (start == null || !mounted) return;
      final end = await showDatePicker(
        context: context,
        initialDate: _customDateRange?.end.isBefore(start) ?? true
            ? start
            : _customDateRange!.end,
        firstDate: start,
        lastDate: DateTime(now.year + 2, 12, 31),
        helpText: '選擇結束日期',
        confirmText: '套用篩選',
      );
      if (end == null || !mounted) return;
      setState(() {
        _customDateRange = DateTimeRange(start: start, end: end);
        _dateFilter = _DateFilter.all;
      });
      return;
    }
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _customDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: '選擇活動日期區間',
      saveText: '套用篩選',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customDateRange = picked;
      _dateFilter = _DateFilter.all;
    });
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary,
    ),
  );
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.city,
    required this.dateFilter,
    required this.onCityChanged,
    required this.onDateChanged,
    required this.dateRange,
    required this.onPickDateRange,
    required this.onClearDateRange,
  });
  final String city;
  final _DateFilter dateFilter;
  final ValueChanged<String> onCityChanged;
  final ValueChanged<_DateFilter> onDateChanged;
  final DateTimeRange? dateRange;
  final VoidCallback onPickDateRange;
  final VoidCallback onClearDateRange;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      DropdownButtonFormField<String>(
        initialValue: city,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: '活動縣市',
          prefixIcon: Icon(Icons.location_city_outlined),
        ),
        items: [
          const DropdownMenuItem(value: '全部縣市', child: Text('全部縣市')),
          for (final item in taiwanCities)
            DropdownMenuItem(value: item, child: Text(item)),
        ],
        onChanged: (value) {
          if (value != null) onCityChanged(value);
        },
      ),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final filter in _DateFilter.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _DateFilterChip(
                  label: _dateFilterLabel(filter),
                  selected: dateRange == null && dateFilter == filter,
                  onTap: () => onDateChanged(filter),
                ),
              ),
            _CustomDateRangeChip(
              label: dateRange == null
                  ? _rangeLabel(null)
                  : _rangeLabel(dateRange),
              selected: dateRange != null,
              onTap: onPickDateRange,
              onClear: dateRange == null ? null : onClearDateRange,
            ),
          ],
        ),
      ),
    ],
  );

  static String _dateFilterLabel(_DateFilter filter) => switch (filter) {
    _DateFilter.all => '全部日期',
    _DateFilter.week => '本週',
    _DateFilter.month => '本月',
  };

  static String _rangeLabel(DateTimeRange? range) {
    if (range == null) return '自訂區間';
    String format(DateTime value) => '${value.month}/${value.day}';
    return '${format(range.start)} - ${format(range.end)}';
  }
}

/// Avoid ChoiceChip's Safari CanvasKit text-width issue, which can render only
/// the first Chinese character inside a selectable chip.
class _DateFilterChip extends StatelessWidget {
  const _DateFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.primaryDark;
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: .18)
          : AppColors.soft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Icons.check, size: 16, color: color),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.visible,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomDateRangeChip extends StatelessWidget {
  const _CustomDateRangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.primaryDark;
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: .18)
          : AppColors.soft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.date_range_outlined, size: 18, color: color),
              const SizedBox(width: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.visible,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
              if (onClear != null) ...[
                const SizedBox(width: 5),
                InkResponse(
                  onTap: onClear,
                  radius: 16,
                  child: Icon(Icons.close, size: 18, color: color),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 發起招募。未登入時先引導登入,登入成功才開啟編輯表單。
Future<void> _startRecruitment(BuildContext context) async {
  if (!await requireSignIn(context)) return;
  if (!context.mounted) return;
  showRecruitmentEditor(context);
}

/// Feed cards intentionally expose only the decision-critical details. The
/// complete post, member list and actions are available from the detail page.
class _RecruitmentGrid extends StatelessWidget {
  const _RecruitmentGrid({required this.posts});
  final List<RecruitmentPost> posts;

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: .74,
    ),
    itemCount: posts.length,
    itemBuilder: (context, index) =>
        _RecruitmentPreviewCard(post: posts[index]),
  );
}

class _RecruitmentPreviewCard extends StatelessWidget {
  const _RecruitmentPreviewCard({required this.post});
  final RecruitmentPost post;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RecruitmentDetailPage(post: post),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: post.coverUrl == null
                ? const ColoredBox(
                    color: AppColors.soft,
                    child: Center(
                      child: Icon(
                        Icons.groups_2_outlined,
                        size: 34,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  )
                : Image.network(
                    post.coverUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: AppColors.soft,
                      child: Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  _PreviewInfo(
                    icon: Icons.group_outlined,
                    text: AppStrings.headcountLabel(
                      post.joinedCount,
                      post.headcount,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _PreviewInfo(
                    icon: Icons.place_outlined,
                    text: post.activityPlace.isNotEmpty
                        ? '${post.city}・${post.activityPlace}'
                        : post.city,
                  ),
                  const SizedBox(height: 5),
                  _PreviewInfo(
                    icon: Icons.calendar_today_outlined,
                    text: post.activityDate == null
                        ? '日期待確認'
                        : AppDate.monthDayWeek(post.activityDate!),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PreviewInfo extends StatelessWidget {
  const _PreviewInfo({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 14, color: AppColors.textSecondary),
      const SizedBox(width: 5),
      Expanded(
        child: Text(
          text.isEmpty ? '地點待確認' : text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ),
    ],
  );
}

/// Full recruitment details and participation controls.
class RecruitmentDetailPage extends StatelessWidget {
  const RecruitmentDetailPage({super.key, required this.post});
  final RecruitmentPost post;

  @override
  Widget build(BuildContext context) {
    final posts = context.watch<AppState>().recruitments;
    final matching = posts.where((item) => item.id == post.id);
    final current = matching.isEmpty ? post : matching.first;
    return Scaffold(
      appBar: AppBar(title: const Text('招募詳情')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: _PostCard(post: current),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});
  final RecruitmentPost post;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final uid = state.currentUserId;
    final hosted = post.isHostedBy(uid);
    final membership = post.memberOf(uid);
    final canSeeMeeting = post.canSeeMeetingInfo(uid);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.coverUrl != null)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                post.coverUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: AppColors.soft,
                  child: Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(post: post, hosted: hosted),
                const SizedBox(height: 12),
                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  post.content,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Tag(
                      icon: Icons.group,
                      text: AppStrings.headcountLabel(
                        post.joinedCount,
                        post.headcount,
                      ),
                    ),
                    _Tag(
                      icon: Icons.wc,
                      text: AppStrings.genderLabel(post.genderPref),
                    ),
                    _Tag(
                      icon: Icons.payments,
                      text: AppStrings.costLabel(post.cost),
                    ),
                    if (post.city.isNotEmpty)
                      _Tag(icon: Icons.location_city_outlined, text: post.city),
                    if (post.activityPlace.isNotEmpty)
                      _Tag(
                        icon: Icons.place_outlined,
                        text: post.activityPlace,
                      ),
                    if (post.activityDate != null)
                      _Tag(
                        icon: Icons.calendar_today_outlined,
                        text: AppDate.monthDayWeek(post.activityDate!),
                      ),
                  ],
                ),

                // 集合資訊:只有發起者與已核准成員看得到。
                if (canSeeMeeting && post.hasMeetingInfo) ...[
                  const SizedBox(height: 12),
                  _MeetingInfo(post: post),
                ],

                const SizedBox(height: 14),

                // 底部依身分切換。
                if (hosted)
                  _HostControls(post: post)
                else
                  _JoinControls(post: post, membership: membership),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 貼文標頭:發起者頭像、暱稱、發起標記、時間。
class _Header extends StatelessWidget {
  const _Header({required this.post, required this.hosted});
  final RecruitmentPost post;
  final bool hosted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.soft,
          child: Text(
            post.author.characters.first,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    post.author,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (hosted) ...[
                    const SizedBox(width: 6),
                    _Badge(
                      text: AppStrings.hostedByMe,
                      color: AppColors.accent,
                    ),
                  ],
                ],
              ),
              Text(
                _ago(post.createdAt),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _ago(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return AppStrings.justNow;
    if (diff.inMinutes < 60) return AppStrings.minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return AppStrings.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return AppStrings.daysAgo(diff.inDays);
    return AppDate.monthDay(t);
  }
}

/// 集合資訊區塊:地點、時間、聯絡方式。只顯示有填的欄位。
class _MeetingInfo extends StatelessWidget {
  const _MeetingInfo({required this.post});
  final RecruitmentPost post;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lock_open,
                size: 15,
                color: AppColors.primaryDark,
              ),
              const SizedBox(width: 6),
              Text(
                AppStrings.meetingInfoTitle,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (post.meetingPoint.isNotEmpty)
            _row(
              Icons.place_outlined,
              AppStrings.meetingPointField,
              post.meetingPoint,
            ),
          if (post.meetingTime != null)
            _row(
              Icons.schedule,
              AppStrings.meetingTimeField,
              AppDate.monthDayWeekTime(post.meetingTime!),
            ),
          if (post.contactInfo.isNotEmpty)
            _row(
              Icons.contact_phone_outlined,
              AppStrings.contactField,
              post.contactInfo,
            ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 發起者的控制項:修改鈕 + 待審核提示 + 成員名單。
class _HostControls extends StatelessWidget {
  const _HostControls({required this.post});
  final RecruitmentPost post;

  @override
  Widget build(BuildContext context) {
    final pending = post.pendingMembers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => showRecruitmentEditor(context, editing: post),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(AppStrings.editRecruitment),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                ),
              ),
            ),
            if (pending.isNotEmpty) ...[
              const SizedBox(width: 10),
              _Badge(
                text: AppStrings.pendingCount(pending.length),
                color: AppColors.accent,
              ),
            ],
          ],
        ),
        if (post.isRecruiting) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _confirmStatus(
                    context,
                    title: '確定成團',
                    message: '確定後將關閉新的加入申請，成員無法退出，且僅能修改聯繫方式。',
                    action: () =>
                        context.read<AppState>().confirmRecruitment(post),
                    color: AppColors.primary,
                  ),
                  icon: const Icon(Icons.groups_2_outlined, size: 18),
                  label: const Text('確定成團'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmStatus(
                    context,
                    title: '放棄招募',
                    message: '此招募將結束並移至歷史紀錄，已加入的成員會收到通知。',
                    action: () =>
                        context.read<AppState>().abandonRecruitment(post),
                    color: AppColors.danger,
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('放棄招募'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
        ] else if (post.isConfirmed) ...[
          const SizedBox(height: 10),
          const _StatusBanner(
            icon: Icons.verified_outlined,
            text: '已成團，活動結束後將自動歸檔。',
            color: AppColors.primary,
          ),
        ],
        const SizedBox(height: 8),
        _MemberList(post: post),
      ],
    );
  }

  Future<void> _confirmStatus(
    BuildContext context, {
    required String title,
    required String message,
    required Future<bool> Function() action,
    required Color color,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppStrings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: color),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(title),
          ),
        ],
      ),
    );
    if (confirmed == true) await action();
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.icon,
    required this.text,
    required this.color,
  });
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

/// 成員名單(發起者視角):待審核可同意/拒絕,已加入者分區顯示。
class _MemberList extends StatelessWidget {
  const _MemberList({required this.post});
  final RecruitmentPost post;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final pending = post.pendingMembers;
    final approved = post.approvedMembers;

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Text(
        AppStrings.memberListTitle,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      children: [
        if (pending.isEmpty && approved.isEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              AppStrings.noMembersYet,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        if (pending.isNotEmpty) ...[
          _sectionLabel(AppStrings.pendingSection),
          for (final m in pending)
            _MemberRow(
              member: m,
              isHostRow: m.userId == post.authorId,
              onApprove: () => state.approveMember(post, m.userId),
              onReject: () => state.rejectMember(post, m.userId),
            ),
        ],
        if (approved.isNotEmpty) ...[
          _sectionLabel(AppStrings.approvedSection),
          for (final m in approved)
            _MemberRow(member: m, isHostRow: m.userId == post.authorId),
        ],
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// 單一成員列。待審核者(且非發起者本人)顯示同意/拒絕鈕。
class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isHostRow,
    this.onApprove,
    this.onReject,
  });

  final RecruitmentMember member;
  final bool isHostRow;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final showActions = member.isPending && onApprove != null && !isHostRow;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.soft,
            child: Text(
              member.nickname.characters.first,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    member.nickname,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isHostRow) ...[
                  const SizedBox(width: 6),
                  _Badge(text: AppStrings.hostLabel, color: AppColors.primary),
                ],
                if (member.guestCount > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    AppStrings.withGuests(member.guestCount),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (showActions) ...[
            IconButton(
              onPressed: onReject,
              icon: const Icon(Icons.close, size: 20, color: AppColors.danger),
              tooltip: AppStrings.rejectAction,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: onApprove,
              icon: const Icon(Icons.check, size: 20, color: AppColors.primary),
              tooltip: AppStrings.approveAction,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}

/// 非發起者的控制項:依成員狀態切換申請 / 待審核 / 退出。
class _JoinControls extends StatelessWidget {
  const _JoinControls({required this.post, required this.membership});
  final RecruitmentPost post;
  final RecruitmentMember? membership;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final m = membership;

    // 已核准:顯示已加入 + 退出。
    if (m != null && m.isApproved) {
      return Row(
        children: [
          const Icon(Icons.check_circle, size: 20, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            AppStrings.approvedJoined,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
          if (m.guestCount > 0) ...[
            const SizedBox(width: 6),
            Text(
              AppStrings.withGuests(m.guestCount),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const Spacer(),
          if (post.isConfirmed)
            const Text(
              '已成團，無法退出',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            )
          else
            TextButton(
              onPressed: () => _confirmLeave(context, state),
              child: Text(
                AppStrings.leaveGroup,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
        ],
      );
    }

    // 待審核:顯示等待中 + 取消申請。
    if (m != null && m.isPending) {
      return Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            AppStrings.pendingReview,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => state.leaveRecruitment(post),
            child: Text(
              AppStrings.cancelRequest,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      );
    }

    // 未加入:申請鈕(滿了就停用)。
    if (post.isConfirmed) {
      return const _StatusBanner(
        icon: Icons.lock_outline,
        text: '此揪團已成團，不再開放加入。',
        color: AppColors.primaryDark,
      );
    }
    final full = post.isFull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 讓未加入者知道有集合資訊,但要通過審核才看得到。
        if (post.hasMeetingInfo) ...[
          Row(
            children: [
              const Icon(
                Icons.lock_outline,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  AppStrings.meetingInfoLocked,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: full ? null : () => _requestJoin(context, state),
            icon: Icon(full ? Icons.block : Icons.group_add),
            label: Text(full ? AppStrings.full : AppStrings.join),
          ),
        ),
      ],
    );
  }

  /// 申請加入:未登入先引導,再問要不要帶人。
  Future<void> _requestJoin(BuildContext context, AppState state) async {
    if (!await requireSignIn(context)) return;
    if (!context.mounted) return;

    final guestCount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BringPeopleSheet(remaining: post.remainingSlots),
    );
    if (guestCount == null) return; // 使用者取消
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final ok = await state.requestJoin(post, guestCount: guestCount);
    if (ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.requestSentSnack)),
      );
    }
  }

  Future<void> _confirmLeave(BuildContext context, AppState state) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(AppStrings.leaveGroup),
        content: Text(post.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.leaveGroup),
          ),
        ],
      ),
    );
    if (confirmed == true) await state.leaveRecruitment(post);
  }
}

/// 帶人參加的選擇面板。帶的人也佔名額,所以上限是剩餘名額 - 1。
class _BringPeopleSheet extends StatefulWidget {
  const _BringPeopleSheet({required this.remaining});

  /// 目前剩餘名額(含本人)。
  final int remaining;

  @override
  State<_BringPeopleSheet> createState() => _BringPeopleSheetState();
}

class _BringPeopleSheetState extends State<_BringPeopleSheet> {
  final _guests = TextEditingController(text: '1');
  bool _bringing = false;
  String? _error;

  /// 本人以外還能帶幾人。
  int get _maxGuests => widget.remaining - 1;

  @override
  void dispose() {
    _guests.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_bringing) {
      Navigator.pop(context, 0);
      return;
    }
    final n = int.tryParse(_guests.text) ?? 0;
    if (n < 1 || n > _maxGuests) {
      setState(() => _error = AppStrings.guestCountTooMany);
      return;
    }
    Navigator.pop(context, n);
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
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.soft,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.bringPeopleTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.remainingSlots(widget.remaining),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Text(AppStrings.joinAlone),
                    selected: !_bringing,
                    onSelected: (_) => setState(() {
                      _bringing = false;
                      _error = null;
                    }),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: !_bringing ? Colors.white : AppColors.primaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: AppColors.soft,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    label: Text(AppStrings.bringGuests),
                    selected: _bringing,
                    // 沒有多餘名額時無法帶人。
                    onSelected: _maxGuests < 1
                        ? null
                        : (_) => setState(() => _bringing = true),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: _bringing ? Colors.white : AppColors.primaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: AppColors.soft,
                    disabledColor: AppColors.soft,
                  ),
                ),
              ],
            ),
            if (_bringing) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _guests,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                decoration: InputDecoration(
                  labelText: AppStrings.guestCountField,
                  suffixText: AppStrings.peopleUnit,
                  errorText: _error,
                ),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _confirm,
                icon: const Icon(Icons.send),
                label: Text(AppStrings.sendRequest),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.soft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryDark),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 小標籤:發起標記、待審核筆數、發起者標示。
class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
