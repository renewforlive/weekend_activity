import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../services/attraction_asset_service.dart';
import '../models/hiking_trail.dart';
import '../models/camping_site.dart';
import '../services/auth_service.dart';
import '../services/trail_asset_service.dart';
import '../services/camping_asset_service.dart';
import '../services/culture_api_service.dart';
import '../services/notification_service.dart';
import '../services/profile_repository.dart';
import '../services/recruitment_repository.dart';
import '../services/schedule_repository.dart';
import '../services/supabase_config.dart';
import '../services/taipei_travel_service.dart';
import 'mock_data.dart';

/// 活動頁的類別:景點(全台,本地資料)/ 展覽(文化部 API)。
enum ActivitySection { attraction, exhibition, trail, camping }

/// 全 App 集中狀態:活動、行程、招募、預約、個人資料。
/// 無後端,資料存於記憶體(重啟即重置),提醒透過 NotificationService 排程。
class AppState extends ChangeNotifier {
  AppState() {
    _activities = buildMockActivities();
    loadActivities();
    loadCitySpots();
    loadRemoteData();
    _listenAuthChanges();
  }

  StreamSubscription<AuthState>? _authSub;

  /// 監聽登入狀態變化,讓帳號區塊等 UI 即時反映。
  void _listenAuthChanges() {
    _authSub = SupabaseConfig.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  final CultureApiService _cultureApi = CultureApiService();
  // 保留:台北線上景點 API(目前改用本地全台資料,暫不使用)。
  // ignore: unused_field
  final TaipeiTravelService _taipeiApi = TaipeiTravelService();
  final AttractionAssetService _attractionAsset = AttractionAssetService();
  final TrailAssetService _trailAsset = TrailAssetService();
  final CampingAssetService _campingAsset = CampingAssetService();
  final ProfileRepository _profileRepo = ProfileRepository();
  final RecruitmentRepository _recruitmentRepo = RecruitmentRepository();
  final ScheduleRepository _scheduleRepo = ScheduleRepository();

  /// 目前登入使用者的 id。
  String? get currentUserId => SupabaseConfig.userId;

  /// 是否已用 email 登入(可發起/加入招募)。
  ///
  /// 包一層 getter 而非讓 UI 直接讀 AuthService,是為了讓登入狀態
  /// 變化能透過 notifyListeners 觸發畫面更新。
  bool get isAuthenticated => AuthService.instance.isAuthenticated;

  /// 目前帳號的 email(訪客模式為 null)。
  String? get userEmail => AuthService.instance.email;

  /// Fetches the profile displayed to other members of a recruitment.
  Future<PublicProfile?> fetchPublicProfile(String userId) =>
      _profileRepo.fetchPublicProfile(userId);

  /// Recruitment memberships visible in the current activity feed.
  int participationCountFor(String userId) =>
      _recruitments.where((post) => post.isJoinedBy(userId)).length;

  bool _syncing = false;
  String? _syncError;
  bool get isSyncing => _syncing;
  String? get syncError => _syncError;

  /// 錯誤訊息顯示過後清除,避免重複彈出。
  void clearSyncError() {
    if (_syncError == null) return;
    _syncError = null;
    notifyListeners();
  }

  /// Clear all account-specific state before switching to a different user.
  /// This prevents the next account from briefly seeing the deleted account's data.
  void clearAccountData() {
    _profile = UserProfile(nickname: '我', bio: '');
    _participated = false;
    _schedule.clear();
    _recruitments.clear();
    _hostedCount = 0;
    _bookings.clear();
    _syncError = null;
    notifyListeners();
  }

  /// 從伺服器載入個人資料、招募、行程。
  ///
  /// 每個區塊獨立處理,單一失敗不影響其他資料載入。
  Future<void> loadRemoteData() async {
    if (!SupabaseConfig.isSignedIn) return;
    _syncing = true;
    _syncError = null;
    notifyListeners();

    final errors = <String>[];

    // 個人資料(後端尚無紀錄時會自動補建)
    try {
      final profile = await _profileRepo.fetchOrCreateProfile();
      if (profile != null) _profile = profile;
    } catch (e) {
      errors.add('個人資料');
      debugPrint('載入個人資料失敗: $e');
    }

    // 招募
    try {
      final posts = await _recruitmentRepo.fetchAll();
      _recruitments
        ..clear()
        ..addAll(posts);
      _hostedCount = _recruitments
          .where((r) => r.isHostedBy(currentUserId))
          .length;
    } catch (e) {
      errors.add('招募');
      debugPrint('載入招募失敗: $e');
    }

    // 行程
    try {
      final items = await _scheduleRepo.fetchAll();
      _schedule
        ..clear()
        ..addAll(items);
    } catch (e) {
      errors.add('行程');
      debugPrint('載入行程失敗: $e');
    }

    _rebuildBookings();

    if (errors.isNotEmpty) {
      _syncError = '無法載入${errors.join('、')},請檢查網路後下拉重新整理。';
    }
    _syncing = false;
    notifyListeners();
  }

  static const String taipeiCity = '台北市';

  // ===== 活動 =====
  late List<Activity> _activities;
  String _selectedCity = taipeiCity;
  bool _loadingActivities = false;
  bool _usingLiveData = false;
  String? _activitiesError;

  String get selectedCity => _selectedCity;
  List<String> get cities => taiwanCities;
  bool get isLoadingActivities => _loadingActivities;
  bool get usingLiveData => _usingLiveData;
  String? get activitiesError => _activitiesError;

  /// 目前是否為台北市。
  bool get isTaipei => _selectedCity == taipeiCity;

  // ===== 類別(景點/展覽)=====
  // 全台縣市都有景點類別,預設顯示景點。
  ActivitySection _section = ActivitySection.attraction;
  ActivitySection get section => _section;

  void selectSection(ActivitySection s) {
    _section = s;
    if (s == ActivitySection.attraction) loadCitySpots();
    if (s == ActivitySection.trail) loadCityTrails();
    if (s == ActivitySection.camping) loadCityCampings();
    notifyListeners();
  }

  void selectCity(String city) {
    _selectedCity = city;
    if (_section == ActivitySection.attraction) loadCitySpots();
    if (_section == ActivitySection.trail) loadCityTrails();
    if (_section == ActivitySection.camping) loadCityCampings();
    notifyListeners();
  }

  // ===== 景點(全台,本地 asset 資料,依縣市顯示)=====
  // 本地資料一次全載入並快取,依 selectedCity 過濾;分頁在前端做(避免一次渲染數百張卡)。
  List<TravelSpot> _citySpots = [];
  int _spotVisible = 0; // 目前顯示筆數(前端分頁)
  static const int _spotPageSize = 20;
  bool _loadingSpots = false;
  String? _spotsError;

  /// 目前縣市、已顯示的景點(前端分頁)。
  List<TravelSpot> get travelSpots =>
      List.unmodifiable(_citySpots.take(_spotVisible));
  bool get isLoadingSpots => _loadingSpots;
  bool get isLoadingMoreSpots => false;
  String? get spotsError => _spotsError;
  bool get hasMoreSpots => _spotVisible < _citySpots.length;

  /// 載入目前縣市的景點(從本地 asset)。
  Future<void> loadCitySpots() async {
    _loadingSpots = true;
    _spotsError = null;
    notifyListeners();
    try {
      _citySpots = await _attractionAsset.byCity(_selectedCity);
      _spotVisible = _citySpots.length < _spotPageSize
          ? _citySpots.length
          : _spotPageSize;
    } catch (e) {
      _spotsError = '無法載入景點資料,請稍後再試。';
      _citySpots = [];
      _spotVisible = 0;
    } finally {
      _loadingSpots = false;
      notifyListeners();
    }
  }

  /// 捲到底:多顯示一頁(前端分頁,不打網路)。
  Future<void> loadMoreTravelSpots() async {
    if (!hasMoreSpots) return;
    final next = _spotVisible + _spotPageSize;
    _spotVisible = next < _citySpots.length ? next : _citySpots.length;
    notifyListeners();
  }

  // ===== 登山步道(本地 asset 資料,依縣市顯示)=====
  // 只涵蓋 15 個縣市,沒有步道的縣市會顯示空狀態。
  List<HikingTrail> _cityTrails = [];
  bool _loadingTrails = false;
  String? _trailsError;

  /// 目前縣市的登山步道(依難度排序)。
  List<HikingTrail> get cityTrails => List.unmodifiable(_cityTrails);
  bool get isLoadingTrails => _loadingTrails;
  String? get trailsError => _trailsError;

  /// 載入目前縣市的登山步道。
  Future<void> loadCityTrails() async {
    _loadingTrails = true;
    _trailsError = null;
    notifyListeners();
    try {
      _cityTrails = await _trailAsset.byCity(_selectedCity);
    } catch (e) {
      _trailsError = '無法載入步道資料,請稍後再試';
      _cityTrails = [];
    } finally {
      _loadingTrails = false;
      notifyListeners();
    }
  }

  /// 把登山步道排入行程。步道沒有固定日期,由使用者指定。
  Future<void> addTrailToSchedule(
    HikingTrail trail,
    DateTime scheduledAt,
  ) async {
    await addToSchedule(Activity.fromTrail(trail, scheduledAt));
  }

  /// 把露營場排入行程。與步道一樣需要使用者指定日期。
  Future<void> addCampingToSchedule(
    CampingSite site,
    DateTime scheduledAt,
  ) async {
    await addToSchedule(Activity.fromCamping(site, scheduledAt));
  }

  // ===== 露營場(本地 asset 資料,依縣市顯示)=====
  List<CampingSite> _cityCampings = [];
  bool _loadingCampings = false;
  String? _campingsError;
  bool _legalCampingOnly = false;

  /// 目前縣市的露營場。開啟只看合法時會過濾掉違規營場。
  List<CampingSite> get cityCampings {
    if (!_legalCampingOnly) return List.unmodifiable(_cityCampings);
    return List.unmodifiable(
      _cityCampings.where((s) => s.legality == CampingLegality.legal),
    );
  }

  bool get isLoadingCampings => _loadingCampings;
  String? get campingsError => _campingsError;
  bool get legalCampingOnly => _legalCampingOnly;

  /// 目前縣市的合法營場數量,用於提示使用者篩選後還剩多少。
  int get legalCampingCount =>
      _cityCampings.where((s) => s.legality == CampingLegality.legal).length;

  /// 切換「只看合法營場」。
  void toggleLegalCampingOnly() {
    _legalCampingOnly = !_legalCampingOnly;
    notifyListeners();
  }

  /// 載入目前縣市的露營場。
  Future<void> loadCityCampings() async {
    _loadingCampings = true;
    _campingsError = null;
    notifyListeners();
    try {
      _cityCampings = await _campingAsset.byCity(_selectedCity);
    } catch (e) {
      _campingsError = '無法載入露營場資料,請稍後再試';
      _cityCampings = [];
    } finally {
      _loadingCampings = false;
      notifyListeners();
    }
  }

  /// 從文化部開放資料載入藝文活動(近三個月);失敗則保留假資料當後備。
  Future<void> loadActivities() async {
    _loadingActivities = true;
    _activitiesError = null;
    notifyListeners();
    try {
      final live = await _cultureApi.fetchActivities();
      if (live.isNotEmpty) {
        _activities = live;
        _usingLiveData = true;
        // 展覽即時資料載入後,若目前展覽縣市沒有活動且非台北,自動切到有活動的縣市。
        // (台北預設看景點,不因展覽空白而跳走)
        if (!isTaipei && activitiesForSelectedCity.isEmpty) {
          final firstWithData = cities.firstWhere(
            (c) => _activitiesInCity(c).isNotEmpty,
            orElse: () => _selectedCity,
          );
          _selectedCity = firstWithData;
        }
      }
    } catch (e) {
      _activitiesError = '無法載入即時活動資料,已顯示範例活動。';
    } finally {
      _loadingActivities = false;
      notifyListeners();
    }
  }

  List<Activity> _activitiesInCity(String city) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final limit = today.add(const Duration(days: 92));
    return _activities
        .where(
          (a) =>
              a.city == city &&
              !a.date.isBefore(today) &&
              !a.date.isAfter(limit),
        )
        .toList();
  }

  /// 指定縣市、近三個月內的活動(依日期升序)。
  List<Activity> get activitiesForSelectedCity {
    final list = _activitiesInCity(_selectedCity)
      ..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  // ===== 行程 =====
  final List<ScheduleItem> _schedule = [];
  List<ScheduleItem> get schedule => List.unmodifiable(
    _schedule..sort((a, b) => a.activity.date.compareTo(b.activity.date)),
  );

  bool isScheduled(Activity activity) =>
      _schedule.any((s) => s.activity.id == activity.id);

  /// 排入行程。可帶入使用者選定的排入時間 scheduledAt(景點無固定時間時使用);
  /// 展覽等有固定時間者傳 null,沿用 activity.date。
  Future<void> addToSchedule(Activity activity, {DateTime? scheduledAt}) async {
    if (isScheduled(activity)) return;
    // 景點依使用者選的時間建立;其餘沿用原本 activity。
    final effective = scheduledAt != null
        ? Activity(
            id: activity.id,
            title: activity.title,
            city: activity.city,
            venue: activity.venue,
            date: scheduledAt,
            category: activity.category,
            description: activity.description,
            cost: activity.cost,
          )
        : activity;
    final defaultRemind = _defaultRemindFor(effective.date);

    final item = await _scheduleRepo.add(effective, defaultRemind);
    if (item == null) {
      _syncError = '無法排入行程,請稍後再試。';
      notifyListeners();
      return;
    }
    _schedule.add(item);
    _syncReminder(item);
    _rebuildBookings();
    notifyListeners();
  }

  /// 排入景點:一律需要使用者選定日期時間。
  Future<void> addSpotToSchedule(TravelSpot spot, DateTime scheduledAt) async {
    final activity = Activity.fromSpot(spot, scheduledAt);
    await addToSchedule(activity, scheduledAt: scheduledAt);
  }

  /// 取得某一天(不含時間)的行程,依時間升序。
  List<ScheduleItem> scheduleOnDay(DateTime day) {
    final target = DateTime(day.year, day.month, day.day);
    final list = _schedule.where((s) {
      final d = s.activity.date;
      return DateTime(d.year, d.month, d.day) == target;
    }).toList()..sort((a, b) => a.activity.date.compareTo(b.activity.date));
    return list;
  }

  /// 某一天是否有行程(週曆上做標記用)。
  bool hasScheduleOnDay(DateTime day) => scheduleOnDay(day).isNotEmpty;

  Future<void> removeFromSchedule(String scheduleId) async {
    final idx = _schedule.indexWhere((s) => s.id == scheduleId);
    if (idx < 0) return;
    final item = _schedule[idx];
    NotificationService.instance.cancel(item.id.hashCode);
    _schedule.removeAt(idx);
    _rebuildBookings();
    notifyListeners();
    await _scheduleRepo.remove(scheduleId);
  }

  Future<void> updateReminder(
    String scheduleId, {
    DateTime? remindAt,
    bool? enabled,
  }) async {
    final item = _schedule.firstWhere((s) => s.id == scheduleId);
    if (remindAt != null) item.remindAt = remindAt;
    if (enabled != null) item.reminderEnabled = enabled;
    _syncReminder(item);
    notifyListeners();
    await _scheduleRepo.updateReminder(
      scheduleId,
      remindAt: remindAt,
      enabled: enabled,
    );
  }

  DateTime _defaultRemindFor(DateTime activityDate) {
    final dayBefore = DateTime(
      activityDate.year,
      activityDate.month,
      activityDate.day - 1,
      9,
    );
    if (dayBefore.isAfter(DateTime.now())) return dayBefore;
    final hourBefore = activityDate.subtract(const Duration(hours: 1));
    return hourBefore.isAfter(DateTime.now())
        ? hourBefore
        : DateTime.now().add(const Duration(minutes: 1));
  }

  void _syncReminder(ScheduleItem item) {
    final notifId = item.id.hashCode;
    NotificationService.instance.cancel(notifId);
    if (item.reminderEnabled) {
      NotificationService.instance.scheduleReminder(
        id: notifId,
        title: '活動提醒:${item.activity.title}',
        body: '${item.activity.city} · ${item.activity.venue}',
        remindAt: item.remindAt,
      );
    }
  }

  // ===== 招募(讨论版)=====
  final List<RecruitmentPost> _recruitments = [];
  List<RecruitmentPost> get recruitments => List.unmodifiable(
    _recruitments..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );

  int _hostedCount = 0;
  int get hostedRecruitmentCount => _hostedCount;

  /// 發起招募。建立後重新從伺服器取得清單,保持單一資料來源。
  Future<void> createRecruitment({
    required String title,
    required String content,
    required int headcount,
    required GenderPref genderPref,
    required int cost,
    Activity? relatedActivity,
    String meetingPoint = '',
    DateTime? meetingTime,
    String contactInfo = '',
  }) async {
    try {
      await _recruitmentRepo.create(
        title: title,
        content: content,
        headcount: headcount,
        genderPref: genderPref,
        cost: cost,
        relatedActivity: relatedActivity,
        meetingPoint: meetingPoint,
        meetingTime: meetingTime,
        contactInfo: contactInfo,
      );
      await loadRemoteData();
    } catch (e) {
      _syncError = '無法發布招募,請稍後再試。';
      notifyListeners();
    }
  }

  /// 發起者修改招募內容。只有發起者能改,伺服器會再驗一次。
  Future<bool> updateRecruitment({
    required String recruitmentId,
    required String title,
    required String content,
    required int headcount,
    required GenderPref genderPref,
    required int cost,
    String meetingPoint = '',
    DateTime? meetingTime,
    String contactInfo = '',
  }) async {
    final result = await _recruitmentRepo.update(
      recruitmentId: recruitmentId,
      title: title,
      content: content,
      headcount: headcount,
      genderPref: genderPref,
      cost: cost,
      meetingPoint: meetingPoint,
      meetingTime: meetingTime,
      contactInfo: contactInfo,
    );

    switch (result) {
      case HostActionResult.ok:
        await loadRemoteData();
        return true;
      case HostActionResult.headcountTooLow:
        _syncError = '人數不能少於已加入的人數,請先調整成員。';
      case HostActionResult.forbidden:
        _syncError = '只有發起者可以修改這則招募。';
      default:
        _syncError = '無法修改招募,請稍後再試。';
    }
    notifyListeners();
    return false;
  }

  /// 目前使用者是否已申請這則招募(含待審核)。
  bool hasJoined(RecruitmentPost post) => post.isJoinedBy(currentUserId);

  /// 目前使用者在這則招募的成員紀錄。未申請則為 null。
  RecruitmentMember? myMembership(RecruitmentPost post) =>
      post.memberOf(currentUserId);

  /// 目前使用者是否為這則招募的發起者。
  bool isHost(RecruitmentPost post) => post.isHostedBy(currentUserId);

  /// 目前使用者能否看到集合資訊(發起者或已核准成員)。
  bool canSeeMeetingInfo(RecruitmentPost post) =>
      post.canSeeMeetingInfo(currentUserId);

  /// 申請加入招募。[guestCount] 為本人以外要帶的人數。
  ///
  /// 名額在申請時就鎖住(待審核也佔位),檢查由伺服器以交易保證。
  Future<bool> requestJoin(RecruitmentPost post, {int guestCount = 0}) async {
    final uid = currentUserId;
    if (uid == null) return false;

    final result = await _recruitmentRepo.join(post.id, guestCount: guestCount);
    switch (result) {
      case JoinResult.ok:
        _participated = true;
        // 重新同步以取得伺服器產生的成員狀態。
        await loadRemoteData();
        return true;
      case JoinResult.full:
        _syncError = '名額已滿,請看看其他揪團。';
        await loadRemoteData();
        return false;
      default:
        _syncError = '無法加入,請稍後再試。';
        notifyListeners();
        return false;
    }
  }

  /// 退出招募(自行取消申請)。
  Future<void> leaveRecruitment(RecruitmentPost post) async {
    final uid = currentUserId;
    if (uid == null) return;
    await _recruitmentRepo.leave(post.id);
    await loadRemoteData();
  }

  /// 發起者同意申請者加入。
  Future<void> approveMember(RecruitmentPost post, String userId) async {
    await _setMemberStatus(post, userId, MemberStatus.approved);
  }

  /// 發起者拒絕申請者。拒絕後會釋出名額。
  Future<void> rejectMember(RecruitmentPost post, String userId) async {
    await _setMemberStatus(post, userId, MemberStatus.rejected);
  }

  Future<void> _setMemberStatus(
    RecruitmentPost post,
    String userId,
    MemberStatus status,
  ) async {
    final result = await _recruitmentRepo.setMemberStatus(
      recruitmentId: post.id,
      userId: userId,
      status: status,
    );
    if (result == HostActionResult.ok) {
      await loadRemoteData();
      return;
    }
    _syncError = result == HostActionResult.forbidden
        ? '只有發起者可以審核成員。'
        : '無法更新審核狀態,請稍後再試。';
    notifyListeners();
  }

  // ===== 预约 =====
  final List<Booking> _bookings = [];
  List<Booking> get bookings {
    final list = List<Booking>.from(_bookings);
    list.sort((a, b) {
      final da = a.date, db = b.date;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return list;
  }

  /// 從行程與招募重新推導預約清單(單一資料來源,避免兩邊不同步)。
  void _rebuildBookings() {
    final uid = currentUserId;
    _bookings.clear();

    // 我排入的活動
    for (final s in _schedule) {
      _bookings.add(
        Booking(
          id: 'book_sch_${s.id}',
          title: s.activity.title,
          date: s.activity.date,
          source: BookingSource.activity,
          city: s.activity.city,
          cost: s.activity.cost,
        ),
      );
    }

    if (uid == null) return;

    // 我發起 / 我加入的招募
    for (final r in _recruitments) {
      final hosted = r.isHostedBy(uid);
      final joined = r.isJoinedBy(uid);
      if (!hosted && !joined) continue;
      _bookings.add(
        Booking(
          id: 'book_rec_${r.id}',
          title: r.title,
          date: r.relatedActivity?.date,
          source: hosted ? BookingSource.hosted : BookingSource.joined,
          city: r.relatedActivity?.city,
          cost: r.cost,
          recruitmentId: r.id,
        ),
      );
    }
  }

  // ===== 个人资料 =====
  UserProfile _profile = UserProfile(
    nickname: '我',
    bio: '熱愛週末走跳、認識新朋友!',
    avatarColorValue: 0xFF3BB273,
  );
  bool _participated = false;
  bool _avatarUploading = false;

  UserProfile get profile => _profile;

  /// 頭像是否正在上傳(UI 顯示進度用)。
  bool get isAvatarUploading => _avatarUploading;
  bool get hasParticipated => _participated || _schedule.isNotEmpty;

  Future<void> updateProfile({
    String? nickname,
    String? bio,
    int? avatarColorValue,
  }) async {
    if (nickname != null && nickname.trim().isNotEmpty) {
      _profile.nickname = nickname.trim();
    }
    if (bio != null) {
      _profile.bio = bio.trim();
    }
    final validAvatarColor =
        avatarColorValue != null &&
            UserProfile.isValidAvatarColor(avatarColorValue)
        ? avatarColorValue
        : null;
    if (validAvatarColor != null) {
      _profile.avatarColorValue = validAvatarColor;
    }
    notifyListeners();
    await _profileRepo.updateProfile(
      nickname: nickname,
      bio: bio,
      avatarColorValue: validAvatarColor,
    );
  }

  /// 上傳頭像。上傳中先以本機檔案顯示,完成後換成遠端網址。
  Future<void> uploadAvatar(String path) async {
    if (path.trim().isEmpty) return;

    final oldPath = _profile.avatarPath;
    final oldUrl = _profile.avatarUrl;

    // 樂觀更新:先用本機路徑讓畫面立即有反應。
    _profile.avatarUrl = path;
    _profile.avatarPath = null;
    _avatarUploading = true;
    notifyListeners();

    try {
      final result = await _profileRepo.uploadAvatar(path, oldPath: oldPath);
      if (result != null) {
        _profile.avatarUrl = result.url;
        _profile.avatarPath = result.path;
      } else {
        _profile.avatarUrl = oldUrl;
        _profile.avatarPath = oldPath;
        _syncError = '頭像上傳失敗,請稍後再試。';
      }
    } catch (e) {
      _profile.avatarUrl = oldUrl;
      _profile.avatarPath = oldPath;
      _syncError = '頭像上傳失敗,請稍後再試。';
      debugPrint('頭像上傳失敗: $e');
    } finally {
      _avatarUploading = false;
      notifyListeners();
    }
  }

  /// 移除頭像,回到色塊 + 暱稱首字。
  Future<void> removeAvatar() async {
    final oldPath = _profile.avatarPath;
    _profile.avatarUrl = null;
    _profile.avatarPath = null;
    notifyListeners();
    await _profileRepo.removeAvatar(oldPath);
  }

  /// 新增 emoji 佔位照片。
  Future<void> addPhoto(String emoji) async {
    final photo = await _profileRepo.addEmojiPhoto(emoji);
    if (photo == null) {
      _syncError = '無法新增照片,請稍後再試。';
      notifyListeners();
      return;
    }
    _profile.photos.add(photo);
    notifyListeners();
  }

  /// 上傳實際照片(來自相機或相簿)。上傳中先以本機檔案顯示。
  Future<void> addPhotoFile(String path) async {
    if (path.trim().isEmpty) return;

    // 樂觀更新:先放本機檔案讓畫面立即有反應。
    final placeholder = ProfilePhoto.file(path);
    _profile.photos.add(placeholder);
    notifyListeners();

    try {
      final uploaded = await _profileRepo.uploadPhoto(path);
      final idx = _profile.photos.indexOf(placeholder);
      if (uploaded != null) {
        if (idx >= 0) {
          _profile.photos[idx] = uploaded;
        } else {
          _profile.photos.add(uploaded);
        }
      } else if (idx >= 0) {
        _profile.photos.removeAt(idx);
        _syncError = '照片上傳失敗,請稍後再試。';
      }
    } catch (e) {
      _profile.photos.remove(placeholder);
      _syncError = '照片上傳失敗,請稍後再試。';
    }
    notifyListeners();
  }

  Future<void> removePhoto(int index) async {
    if (index < 0 || index >= _profile.photos.length) return;
    final photo = _profile.photos.removeAt(index);
    notifyListeners();
    await _profileRepo.deletePhoto(photo);
  }
}
