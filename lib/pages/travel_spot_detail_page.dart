import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/app_state.dart';
import '../l10n/app_strings.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/official_website.dart';
import '../widgets/external_network_image.dart';
import '../widgets/recruitment_editor.dart';
import '../widgets/schedule_time_picker.dart';

/// 景點詳情頁:大圖每 4 秒輪換、名稱、開放狀態、地區地址、介紹,
/// 並可用內嵌 WebView 開啟官方網頁(以 spot.url 帶入)。
class TravelSpotDetailPage extends StatefulWidget {
  const TravelSpotDetailPage({super.key, required this.spot});
  final TravelSpot spot;

  @override
  State<TravelSpotDetailPage> createState() => _TravelSpotDetailPageState();
}

class _TravelSpotDetailPageState extends State<TravelSpotDetailPage> {
  final PageController _pageController = PageController();
  Timer? _timer;
  int _current = 0;

  List<String> get _images => widget.spot.images;

  @override
  void initState() {
    super.initState();
    if (_images.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) => _next());
    }
  }

  void _next() {
    if (!mounted || _images.length <= 1) return;
    final next = (_current + 1) % _images.length;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spot = widget.spot;
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.detailTitle)),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildCarousel(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        spot.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    _OpenBadge(isOpen: spot.isOpen),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.place,
                  value: [
                    spot.distric,
                    spot.address,
                  ].where((s) => s.isNotEmpty).join(' · '),
                ),
                const SizedBox(height: 20),
                if (spot.introduction.isNotEmpty) ...[
                  Text(
                    AppStrings.introduction,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    spot.introduction,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.7,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                _SpotActions(spot: spot),
                if (spot.url.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,

                    child: OutlinedButton.icon(
                      onPressed: () => openOfficialWebsite(
                        context,
                        url: spot.url,
                        nativePageBuilder: (_) =>
                            _SpotWebViewPage(title: spot.name, url: spot.url),
                      ),
                      icon: const Icon(Icons.public),
                      label: Text(AppStrings.openWebsite),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryDark,
                        side: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarousel() {
    if (_images.isEmpty) {
      return Container(
        height: 240,
        color: AppColors.soft,
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_not_supported_outlined,
          size: 48,
          color: AppColors.textSecondary,
        ),
      );
    }
    return SizedBox(
      height: 240,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _images.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, i) => ExternalNetworkImage(
              url: _images[i],
              fit: BoxFit.cover,
              width: double.infinity,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: AppColors.soft,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(),
                );
              },
              errorBuilder: (context, _, _) => Container(
                color: AppColors.soft,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.broken_image_outlined,
                  size: 48,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          if (_images.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < _images.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _current ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _current ? Colors.white : Colors.white54,
                        borderRadius: BorderRadius.circular(4),
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

/// 景點詳情頁的操作:排入行程(選時間)、發起招募。
class _SpotActions extends StatelessWidget {
  const _SpotActions({required this.spot});
  final TravelSpot spot;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheduled = state.isScheduled(
      Activity.fromSpot(spot, DateTime.now()),
    );
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: scheduled
                ? null
                : () => showScheduleTimePicker(context, spot: spot),
            icon: Icon(scheduled ? Icons.check : Icons.add_task, size: 18),
            label: Text(
              scheduled
                  ? AppStrings.scheduledAlready
                  : AppStrings.addToSchedule,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: scheduled ? AppColors.soft : AppColors.primary,
              foregroundColor: scheduled ? AppColors.primaryDark : Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => showRecruitmentEditor(
              context,
              relatedActivity: Activity.fromSpot(spot, DateTime.now()),
            ),
            icon: const Icon(Icons.campaign_outlined, size: 18),
            label: Text(AppStrings.startRecruitment),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accent),
            ),
          ),
        ),
      ],
    );
  }
}

class _OpenBadge extends StatelessWidget {
  const _OpenBadge({required this.isOpen});
  final bool isOpen;
  @override
  Widget build(BuildContext context) {
    final color = isOpen ? AppColors.primary : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOpen ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            isOpen ? AppStrings.open : AppStrings.closed,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.value});
  final IconData icon;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// 內嵌 WebView 開啟景點官方網頁。
class _SpotWebViewPage extends StatefulWidget {
  const _SpotWebViewPage({required this.title, required this.url});
  final String title;
  final String url;

  @override
  State<_SpotWebViewPage> createState() => _SpotWebViewPageState();
}

class _SpotWebViewPageState extends State<_SpotWebViewPage> {
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
      appBar: AppBar(
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
