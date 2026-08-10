import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../l10n/app_strings.dart';
import '../models/hiking_trail.dart';
import '../theme/app_theme.dart';
import 'trail_detail_page.dart';

/// 登山步道列表。資料只涵蓋部分縣市,沒有步道的縣市顯示空狀態。
class TrailsList extends StatefulWidget {
  const TrailsList({super.key});

  @override
  State<TrailsList> createState() => _TrailsListState();
}

class _TrailsListState extends State<TrailsList> {
  final ScrollController _scroll = ScrollController();
  String? _lastCity;

  /// 換地區時把列表捲回最上方。
  /// 切換分頁走 IndexedStack 不會經過這裡,所以位置得以保留。
  void _resetScrollIfCityChanged(String city) {
    if (_lastCity != null && _lastCity != city && _scroll.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(0);
      });
    }
    _lastCity = city;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    _resetScrollIfCityChanged(state.selectedCity);

    if (state.isLoadingTrails) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.trailsError != null && state.cityTrails.isEmpty) {
      return _Centered(
        icon: Icons.cloud_off,
        message: AppStrings.trailsError,
        action: TextButton(
          onPressed: state.loadCityTrails,
          child: Text(AppStrings.retry),
        ),
      );
    }

    final trails = state.cityTrails;
    if (trails.isEmpty) {
      return _Centered(
        icon: Icons.terrain_outlined,
        message: AppStrings.trailsEmpty,
      );
    }

    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: trails.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _TrailCard(trail: trails[i]),
    );
  }
}

/// 步道卡片。難度用左側色條與標籤表示,長度與時間是選步道最常看的兩個數字。
class _TrailCard extends StatelessWidget {
  const _TrailCard({required this.trail});

  final HikingTrail trail;

  @override
  Widget build(BuildContext context) {
    final d = trail.difficulty;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TrailDetailPage(trail: trail)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        // IntrinsicHeight 讓左側色條能撐滿卡片高度。
        // ListView 裡的高度約束是無限的,直接用 stretch 會導致 layout 失敗。
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: d.color,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              trail.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (trail.needPermit)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(Icons.badge_outlined, size: 16, color: AppColors.danger),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              trail.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _Chip(label: d.label, color: d.color),
                          if (trail.lengthText.isNotEmpty)
                            _Chip(label: trail.lengthText, color: AppColors.textSecondary),
                          if (trail.duration.isNotEmpty)
                            _Chip(label: trail.duration, color: AppColors.textSecondary),
                        ],
                      ),
                    ],
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

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 44, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
            ),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}