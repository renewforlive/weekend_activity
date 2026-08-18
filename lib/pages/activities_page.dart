import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../l10n/app_strings.dart';
import '../models/models.dart';
import '../models/camping_site.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import '../widgets/external_network_image.dart';
import 'travel_spot_detail_page.dart';
import 'activity_detail_page.dart';
import 'trails_list.dart';
import 'campings_list.dart';
import 'camping_detail_page.dart';
import 'trail_detail_page.dart';
import 'escape_rooms_list.dart';

/// 活動頁:選地區。全台縣市皆可切換景點(本地資料)/展覽(文化部)。
class ActivitiesPage extends StatelessWidget {
  const ActivitiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('週末推薦'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ActivityExplorePage(),
              ),
            ),
            icon: const Icon(Icons.explore_outlined, size: 18),
            label: const Text('自己探索'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: const _WeekendRecommendationHome(),
    );
  }
}

/// 所有原始資料與分類篩選集中在此頁，從推薦首頁按「自己探索」才進入。
class ActivityExplorePage extends StatelessWidget {
  const ActivityExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('自己探索'),
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
          const EscapeRoomsList(),
        ],
      ),
    );
  }
}

/// 活動首頁：先提供少量、可直接點進去的週末提案，減少選擇疲勞。
class _WeekendRecommendationHome extends StatefulWidget {
  const _WeekendRecommendationHome();

  @override
  State<_WeekendRecommendationHome> createState() =>
      _WeekendRecommendationHomeState();
}

class _WeekendRecommendationHomeState
    extends State<_WeekendRecommendationHome> {
  String? _loadedCity;

  void _loadSupplementaryRecommendations(AppState state) {
    if (_loadedCity == state.selectedCity) return;
    _loadedCity = state.selectedCity;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final latest = context.read<AppState>();
      latest.loadCityTrails();
      latest.loadCityCampings();
    });
  }

  T? _weeklyPick<T>(List<T> items, int salt) {
    if (items.isEmpty) return null;
    final now = DateTime.now();
    final week = now.difference(DateTime(now.year, 1, 1)).inDays ~/ 7;
    final seed = (context.read<AppState>().selectedCity.hashCode ^ week ^ salt) &
        0x7fffffff;
    return items[seed % items.length];
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    _loadSupplementaryRecommendations(state);
    if (state.isLoadingSpots) {
      return const Center(child: CircularProgressIndicator());
    }

    final spot = _weeklyPick(
      state.recommendedTravelSpots(AttractionFilter.all),
      11,
    );
    final exhibition = _weeklyPick(state.activitiesForSelectedCity, 23);
    final trail = _weeklyPick(state.cityTrails, 37);
    final legalCampings = state.cityCampings
        .where((site) => site.legality == CampingLegality.legal)
        .toList();
    final camping = _weeklyPick(legalCampings, 41);

    return RefreshIndicator(
      onRefresh: state.loadCitySpots,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Row(
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
          const SizedBox(height: 22),
          Text(
            '${state.selectedCity}這個週末，直接去這裡吧',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            '四種不同玩法各挑一個，減少選擇，只留下值得出發的地方。',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          if (spot != null)
            _RecommendationSpotCard(
              eyebrow: '景點推薦',
              hint: '${state.selectedCity}的週末走走',
              spot: spot,
              accent: const Color(0xFF3BB273),
              fallbackAsset:
                  'assets/images/weekend_recommendations/attraction_fallback.png',
            ),
          if (spot != null) const SizedBox(height: 16),
          _WeekendActionCard(
            eyebrow: '展覽推薦',
            title: exhibition?.title ?? '近期展覽整理中',
            subtitle: exhibition == null
                ? '換個縣市看看近期藝文活動'
                : '${AppDate.monthDayWeek(exhibition.date)} · ${exhibition.venue}',
            icon: Icons.palette_outlined,
            colors: const [Color(0xFF7567C7), Color(0xFF9B91DD)],
            backgroundAsset:
                'assets/images/weekend_recommendations/exhibition_fallback.png',
            onTap: () {
              if (exhibition != null) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ActivityDetailPage(activity: exhibition),
                  ),
                );
              } else {
                state.selectSection(ActivitySection.exhibition);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ActivityExplorePage(),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 16),
          _WeekendActionCard(
            eyebrow: '登山推薦',
            title: trail?.name ?? '找一條適合出發的步道',
            subtitle: trail == null
                ? '${state.selectedCity}暫無步道資料，看看附近縣市'
                : [trail.location, trail.lengthText, trail.duration]
                    .where((text) => text.isNotEmpty)
                    .join(' · '),
            icon: Icons.terrain_outlined,
            colors: const [Color(0xFF2F8D9B), Color(0xFF64B6C4)],
            backgroundAsset:
                'assets/images/weekend_recommendations/trail_fallback.png',
            onTap: () {
              if (trail != null) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TrailDetailPage(trail: trail),
                  ),
                );
              } else {
                state.selectSection(ActivitySection.trail);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ActivityExplorePage(),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 16),
          _WeekendActionCard(
            eyebrow: '露營推薦',
            title: camping?.name ?? '找一處合法露營場',
            subtitle: camping == null
                ? '優先只推薦符合相關法規的營場'
                : camping.displayAddress,
            icon: Icons.cabin_outlined,
            colors: const [Color(0xFFE88C4E), Color(0xFFF2B176)],
            backgroundAsset:
                'assets/images/weekend_recommendations/camping_fallback.png',
            onTap: () {
              if (camping != null) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CampingDetailPage(site: camping),
                  ),
                );
              } else {
                state.selectSection(ActivitySection.camping);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ActivityExplorePage(),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ActivityExplorePage(),
              ),
            ),
            icon: const Icon(Icons.explore_outlined),
            label: const Text('都不喜歡？自己探索更多活動'),
          ),
        ],
      ),
    );
  }
}

class _RecommendationSpotCard extends StatelessWidget {
  const _RecommendationSpotCard({
    required this.eyebrow,
    required this.hint,
    required this.spot,
    required this.accent,
    required this.fallbackAsset,
  });

  final String eyebrow;
  final String hint;
  final TravelSpot spot;
  final Color accent;
  final String fallbackAsset;

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
        child: SizedBox(
          height: 220,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (spot.images.isNotEmpty)
                ExternalNetworkImage(
                  url: spot.images.first,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _recommendationFallback(),
                )
              else
                _recommendationFallback(),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: .76)],
                  ),
                ),
              ),
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    eyebrow,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 15,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spot.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hint,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recommendationFallback() => Image.asset(fallbackAsset, fit: BoxFit.cover);
}

class _WeekendActionCard extends StatelessWidget {
  const _WeekendActionCard({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.backgroundAsset,
    required this.onTap,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final String backgroundAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        height: 132,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(backgroundAsset, fit: BoxFit.cover),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      colors.first.withValues(alpha: .88),
                      Colors.black.withValues(alpha: .28),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.white, size: 34),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            eyebrow,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _tab(AppStrings.sectionAttraction, ActivitySection.attraction),
          const SizedBox(width: 8),
          _tab(AppStrings.sectionExhibition, ActivitySection.exhibition),
          const SizedBox(width: 8),
          _tab(AppStrings.sectionTrail, ActivitySection.trail),
          const SizedBox(width: 8),
          _tab(AppStrings.sectionCamping, ActivitySection.camping),
          const SizedBox(width: 8),
          _tab(AppStrings.sectionEscapeRoom, ActivitySection.escapeRoom),
        ],
      ),
    );
  }

  Widget _tab(String label, ActivitySection section) {
    final selected = current == section;
    return SizedBox(
      width: 104,
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
                  child: CustomScrollView(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => _SpotCard(spot: spots[i]),
                            childCount: spots.length,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                // 緊湊列表：剛好容納圖片、標題、兩行介紹與地點。
                                childAspectRatio: .86,
                              ),
                        ),
                      ),
                      if (state.hasMoreSpots)
                        SliverToBoxAdapter(child: _footer(state)),
                    ],
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
          // ChoiceChip 在 selected 狀態會自動加入勾選圖示，會和我們的
          // 分類圖示搶空間；改為固定寬度的自訂標籤以確保文字不被覆蓋。
          return SizedBox(
            width: 88,
            child: Material(
              color: selected ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => onChanged(filter.$1),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.soft,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        filter.$3,
                        size: 16,
                        color: selected ? Colors.white : AppColors.primaryDark,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          filter.$2,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : AppColors.primaryDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
