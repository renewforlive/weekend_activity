import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../l10n/app_strings.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import '../widgets/external_network_image.dart';
import 'travel_spot_detail_page.dart';
import 'activity_detail_page.dart';
import 'trails_list.dart';
import 'campings_list.dart';

/// 活動頁:選地區。全台縣市皆可切換景點(本地資料)/展覽(文化部)。
class ActivitiesPage extends StatelessWidget {
  const ActivitiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.activitiesTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Column(
            children: [
              Padding(
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
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _SectionTabs(
                  current: state.section,
                  onChanged: state.selectSection,
                ),
              ),
            ],
          ),
        ),
      ),
      body: IndexedStack(
        index: state.section.index,
        children: [
          const _AttractionsList(),
          _ExhibitionList(activities: state.activitiesForSelectedCity),
          const TrailsList(),
          const CampingsList(),
        ],
      ),
    );
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({required this.current, required this.onChanged});
  final ActivitySection current;
  final ValueChanged<ActivitySection> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _tab(AppStrings.sectionAttraction, ActivitySection.attraction),
        const SizedBox(width: 8),
        _tab(AppStrings.sectionExhibition, ActivitySection.exhibition),
        const SizedBox(width: 8),
        _tab(AppStrings.sectionTrail, ActivitySection.trail),
        const SizedBox(width: 8),
        _tab(AppStrings.sectionCamping, ActivitySection.camping),
      ],
    );
  }

  Widget _tab(String label, ActivitySection section) {
    final selected = current == section;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(section),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ===== 景點列表(全台,本地資料,前端分頁)=====
class _AttractionsList extends StatefulWidget {
  const _AttractionsList();

  @override
  State<_AttractionsList> createState() => _AttractionsListState();
}

class _AttractionsListState extends State<_AttractionsList> {
  final ScrollController _scroll = ScrollController();
  String? _lastCity;
  AttractionFilter? _lastFilter;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      context.read<AppState>().loadMoreTravelSpots();
    }
  }

  /// 換地區時把列表捲回最上方。
  void _resetScrollIfFiltersChanged(AppState state) {
    final changed = _lastCity != null &&
        (_lastCity != state.selectedCity || _lastFilter != state.spotFilter);
    if (changed && _scroll.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(0);
      });
    }
    _lastCity = state.selectedCity;
    _lastFilter = state.spotFilter;
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    _resetScrollIfFiltersChanged(state);
    if (state.isLoadingSpots) {
      return const Center(child: CircularProgressIndicator());
    }
    final spots = state.travelSpots;
    return Column(
      children: [
        _AttractionFilterBar(
          current: state.spotFilter,
          onChanged: state.selectSpotFilter,
        ),
        Expanded(
          child: state.spotsError != null && spots.isEmpty
              ? _ErrorRetry(
                  message: AppStrings.spotsError,
                  onRetry: state.loadCitySpots,
                )
              : spots.isEmpty
              ? _EmptyHint(text: AppStrings.spotsEmpty)
              : RefreshIndicator(
                  onRefresh: state.loadCitySpots,
                  child: GridView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          // 緊湊列表：剛好容納圖片、標題、兩行介紹與地點，
                          // 不讓 Grid 的固定高度在卡片底部留下大片空白。
                          childAspectRatio: .86,
                        ),
                    itemCount: spots.length + (state.hasMoreSpots ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == spots.length) return _footer(state);
                      return _SpotCard(spot: spots[i]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _footer(AppState state) {
    if (state.isLoadingMoreSpots) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          state.hasMoreSpots ? AppStrings.loadingMore : AppStrings.noMoreData,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ),
    );
  }
}

class _AttractionFilterBar extends StatelessWidget {
  const _AttractionFilterBar({required this.current, required this.onChanged});
  final AttractionFilter current;
  final ValueChanged<AttractionFilter> onChanged;

  static const _filters = <(AttractionFilter, String, IconData)>[
    (AttractionFilter.all, '全部', Icons.grid_view_rounded),
    (AttractionFilter.nature, '自然', Icons.terrain_outlined),
    (AttractionFilter.park, '公園', Icons.park_outlined),
    (AttractionFilter.culture, '人文', Icons.account_balance_outlined),
    (AttractionFilter.art, '藝文', Icons.palette_outlined),
    (AttractionFilter.religion, '宗教', Icons.temple_buddhist_outlined),
    (AttractionFilter.shopping, '購物', Icons.storefront_outlined),
    (AttractionFilter.outdoor, '戶外', Icons.directions_run_outlined),
    (AttractionFilter.recreation, '遊憩', Icons.attractions_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final filter = _filters[index];
          final selected = current == filter.$1;
          return SizedBox(
            width: 88,
            child: ChoiceChip(
              selected: selected,
              onSelected: (_) => onChanged(filter.$1),
              avatar: Icon(
                filter.$3,
                size: 16,
                color: selected ? Colors.white : AppColors.primaryDark,
              ),
              label: Text(filter.$2, maxLines: 1),
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppColors.primaryDark,
                fontWeight: FontWeight.w700,
              ),
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surface,
              side: BorderSide(
                color: selected ? AppColors.primary : AppColors.soft,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 緊湊景點卡片:縮圖、名稱、分類和地區,點擊進詳情頁。
class _SpotCard extends StatelessWidget {
  const _SpotCard({required this.spot});
  final TravelSpot spot;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TravelSpotDetailPage(spot: spot),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: spot.images.isNotEmpty
                  ? ExternalNetworkImage(
                      url: spot.images.first,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : Container(color: AppColors.soft),
                      errorBuilder: (_, _, _) => _imagePlaceholder(),
                    )
                  : _imagePlaceholder(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spot.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    if (spot.introduction.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        spot.introduction,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            spot.distric,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
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
    );
  }

  Widget _imagePlaceholder() => Container(
        color: AppColors.soft,
        alignment: Alignment.center,
        child: const Icon(Icons.landscape_outlined, color: AppColors.textSecondary),
      );
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 56, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('重試')),
        ],
      ),
    );
  }
}

// ===== 展覽列表(文化部)=====
class _ExhibitionList extends StatefulWidget {
  const _ExhibitionList({required this.activities});
  final List<Activity> activities;

  @override
  State<_ExhibitionList> createState() => _ExhibitionListState();
}

class _ExhibitionListState extends State<_ExhibitionList> {
  final ScrollController _scroll = ScrollController();
  String? _lastCity;

  /// 換地區時把列表捲回最上方。
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
    _resetScrollIfCityChanged(context.watch<AppState>().selectedCity);
    if (widget.activities.isEmpty) {
      return _EmptyHint(text: AppStrings.activitiesEmpty);
    }
    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: widget.activities.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) => ActivityCard(activity: widget.activities[i]),
    );
  }
}

class _CityDropdown extends StatelessWidget {
  const _CityDropdown({
    required this.value,
    required this.cities,
    required this.onChanged,
  });
  final String value;
  final List<String> cities;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          icon: const Icon(Icons.expand_more, color: AppColors.primary),
          items: [
            for (final c in cities) DropdownMenuItem(value: c, child: Text(c)),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
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
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ActivityDetailPage(activity: activity),
          ),
        ),
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
                      color: activity.category.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      activity.category.icon,
                      color: activity.category.color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppStrings.categoryLabel(activity.category),
                          style: TextStyle(
                            fontSize: 12,
                            color: activity.category.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _CostTag(cost: activity.cost),
                ],
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.event,
                text: AppDate.monthDayWeek(activity.date),
              ),
              const SizedBox(height: 4),
              _InfoRow(
                icon: Icons.place_outlined,
                text: '${activity.city} · ${activity.venue}',
              ),
              const SizedBox(height: 10),
              Text(
                activity.description,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
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
        AppStrings.costLabel(cost),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: free ? AppColors.primaryDark : AppColors.accent,
        ),
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
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
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
          const Icon(
            Icons.event_busy,
            size: 56,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}
