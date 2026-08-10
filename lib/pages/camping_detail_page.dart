import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/app_state.dart';
import '../l10n/app_strings.dart';
import '../models/camping_site.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';

/// 露營場詳情。營場沒有固定日期,由使用者挑要哪天去,再排入行程。
class CampingDetailPage extends StatelessWidget {
  const CampingDetailPage({super.key, required this.site});

  final CampingSite site;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(site.name, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _LegalityHeader(site: site),
          const SizedBox(height: 16),

          // 營場資料。缺漏的欄位直接不顯示,避免出現空白列。
          _InfoCard(
            rows: [
              (Icons.place_outlined, AppStrings.campingAddress, site.displayAddress),
              if (site.status.isNotEmpty)
                (Icons.storefront_outlined, AppStrings.campingStatus, site.status),
              if (site.hasContact)
                (Icons.call_outlined, AppStrings.campingPhone, site.contactNumber),
              if (site.setupTime.isNotEmpty)
                (Icons.event_outlined, AppStrings.campingSetupTime, site.setupTime),
            ],
          ),

          // 法規狀態關係到營場能不能安心使用,違規時明確警示。
          const SizedBox(height: 12),
          _LegalityNote(site: site),

          if (site.inIndigenousArea) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppStrings.campingIndigenous,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (site.url.isNotEmpty) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _CampingWebViewPage(title: site.name, url: site.url),
                ),
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(AppStrings.campingOfficialSite),
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

  /// 選日期與時間後排入行程。露營多半下午進場,預設 14:00。
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
      initialTime: const TimeOfDay(hour: 14, minute: 0),
    );
    if (time == null) return;

    final at = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    await state.addCampingToSchedule(site, at);

    messenger.showSnackBar(
      SnackBar(
        content: Text('${site.name}  ${AppDate.monthDayWeekTime(at)}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// 法規狀態標頭。用顏色把狀態視覺化,讓使用者一眼判斷。
class _LegalityHeader extends StatelessWidget {
  const _LegalityHeader({required this.site});

  final CampingSite site;

  @override
  Widget build(BuildContext context) {
    final l = site.legality;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: l.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: l.color,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.cabin, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: l.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  site.location,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
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

/// 法規說明。違規營場列出違反的法規名稱。
class _LegalityNote extends StatelessWidget {
  const _LegalityNote({required this.site});

  final CampingSite site;

  @override
  Widget build(BuildContext context) {
    final legal = site.legality == CampingLegality.legal;
    final color = legal ? AppColors.primary : AppColors.danger;
    final note = legal ? AppStrings.campingLegalNote : AppStrings.campingIllegalNote;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                legal ? Icons.verified_outlined : Icons.warning_amber_rounded,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  note,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          if (site.violation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Text(
                '${AppStrings.campingViolation}：${site.violation}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],
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
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
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

/// 營場官方頁面。與步道詳情頁用同一套 WebView 做法。
class _CampingWebViewPage extends StatefulWidget {
  const _CampingWebViewPage({required this.title, required this.url});
  final String title;
  final String url;

  @override
  State<_CampingWebViewPage> createState() => _CampingWebViewPageState();
}

class _CampingWebViewPageState extends State<_CampingWebViewPage> {
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