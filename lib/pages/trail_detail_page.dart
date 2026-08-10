import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/app_state.dart';
import '../l10n/app_strings.dart';
import '../models/hiking_trail.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';

/// 步道詳情。步道沒有固定日期,由使用者挑要哪天去,再排入行程。
class TrailDetailPage extends StatelessWidget {
  const TrailDetailPage({super.key, required this.trail});

  final HikingTrail trail;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(trail.name, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _DifficultyHeader(trail: trail),
          const SizedBox(height: 16),

          // 步道數據。資料缺漏的欄位直接不顯示,避免出現空白列。
          _InfoCard(
            rows: [
              if (trail.lengthText.isNotEmpty)
                (Icons.straighten, AppStrings.trailLength, trail.lengthText),
              if (trail.altRange.isNotEmpty)
                (Icons.height, AppStrings.trailAltitude, trail.altRange),
              if (trail.duration.isNotEmpty)
                (Icons.schedule, AppStrings.trailDuration, trail.duration),
              if (trail.bestSeason.isNotEmpty)
                (Icons.wb_sunny_outlined, AppStrings.trailBestSeason, trail.bestSeason),
              if (trail.pavement.isNotEmpty)
                (Icons.landscape_outlined, AppStrings.trailPavement, trail.pavement),
              if (trail.system.isNotEmpty)
                (Icons.map_outlined, AppStrings.trailSystem, trail.system),
              if (trail.admin.isNotEmpty)
                (Icons.business_outlined, AppStrings.trailAdmin, trail.admin),
            ],
          ),

          // 入山證關係到能不能進去,需要時特別標示。
          if (trail.needPermit) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppStrings.trailNeedPermit,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (trail.guide.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              AppStrings.trailGuide,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              trail.guide,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6),
            ),
          ],

          if (trail.url.isNotEmpty) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _TrailWebViewPage(title: trail.name, url: trail.url),
                ),
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(AppStrings.trailOfficialSite),
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _pickDateAndSchedule(context),
              icon: const Icon(Icons.event_available),
              label: Text(AppStrings.pickHikingDate),
            ),
          ),
        ],
      ),
    );
  }

  /// 選日期與時間後排入行程。登山多半清早出發,預設 07:00。
  Future<void> _pickDateAndSchedule(BuildContext context) async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return;
    if (!context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 7, minute: 0),
    );
    if (time == null) return;

    final at = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    await state.addTrailToSchedule(trail, at);

    messenger.showSnackBar(
      SnackBar(
        content: Text('${trail.name}  ${AppDate.monthDayWeekTime(at)}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// 難度標頭。用顏色與星級把難度視覺化,讓使用者一眼判斷適不適合。
class _DifficultyHeader extends StatelessWidget {
  const _DifficultyHeader({required this.trail});

  final HikingTrail trail;

  @override
  Widget build(BuildContext context) {
    final d = trail.difficulty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: d.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: d.color,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.terrain, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.label,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: d.color),
                ),
                const SizedBox(height: 2),
                Text(
                  trail.location,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Icon(
                  i <= d.level ? Icons.star : Icons.star_border,
                  size: 14,
                  color: d.color,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 資料列卡片。只顯示有值的欄位。
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});

  final List<(IconData, String, String)> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (final (icon, label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 18, color: AppColors.primary),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 72,
                    child: Text(
                      label,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 官方步道頁面。與景點詳情頁用同一套 WebView 做法。
class _TrailWebViewPage extends StatefulWidget {
  const _TrailWebViewPage({required this.title, required this.url});
  final String title;
  final String url;

  @override
  State<_TrailWebViewPage> createState() => _TrailWebViewPageState();
}

class _TrailWebViewPageState extends State<_TrailWebViewPage> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title, overflow: TextOverflow.ellipsis)),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}