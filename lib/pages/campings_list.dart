import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../l10n/app_strings.dart';
import '../models/camping_site.dart';
import '../theme/app_theme.dart';
import 'camping_detail_page.dart';

/// 露營場列表。全國多數營場違反相關法規,
/// 因此提供「只看合法營場」的篩選,並在卡片明顯標示狀態。
class CampingsList extends StatefulWidget {
  const CampingsList({super.key});

  @override
  State<CampingsList> createState() => _CampingsListState();
}

class _CampingsListState extends State<CampingsList> {
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

    if (state.isLoadingCampings) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.campingsError != null && state.cityCampings.isEmpty) {
      return _Centered(
        icon: Icons.cloud_off,
        message: AppStrings.campingError,
        action: TextButton(
          onPressed: state.loadCityCampings,
          child: Text(AppStrings.retry),
        ),
      );
    }

    final sites = state.cityCampings;

    return Column(
      children: [
        _LegalFilterBar(
          enabled: state.legalCampingOnly,
          legalCount: state.legalCampingCount,
          onToggle: state.toggleLegalCampingOnly,
        ),
        Expanded(
          child: sites.isEmpty
              ? _Centered(
                  icon: Icons.cabin_outlined,
                  message: AppStrings.campingEmpty,
                )
              : ListView.separated(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: sites.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _CampingCard(site: sites[i]),
                ),
        ),
      ],
    );
  }
}

/// 只看合法營場的切換列。順便顯示合法數量,讓使用者知道篩選後剩多少。
class _LegalFilterBar extends StatelessWidget {
  const _LegalFilterBar({
    required this.enabled,
    required this.legalCount,
    required this.onToggle,
  });

  final bool enabled;
  final int legalCount;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Icon(
            Icons.verified_outlined,
            size: 18,
            color: enabled ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${AppStrings.campingLegalOnly}（$legalCount）',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: enabled ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
          Switch(
            value: enabled,
            onChanged: (_) => onToggle(),
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

/// 露營場卡片。左側色條表示法規狀態,違規營場一眼可辨。
class _CampingCard extends StatelessWidget {
  const _CampingCard({required this.site});

  final CampingSite site;

  @override
  Widget build(BuildContext context) {
    final legality = site.legality;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CampingDetailPage(site: site)),
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
                  color: legality.color,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        site.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              site.displayAddress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _Chip(label: legality.label, color: legality.color),
                          if (site.violation.isNotEmpty)
                            _Chip(
                              label: site.violation,
                              color: AppColors.textSecondary,
                            ),
                          if (site.inIndigenousArea)
                            _Chip(
                              label: AppStrings.campingIndigenous,
                              color: AppColors.accent,
                            ),
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
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
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
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}