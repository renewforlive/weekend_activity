import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/culture_api_service.dart';
import '../services/notification_service.dart';
import 'mock_data.dart';

/// 全 App 集中狀態:活動、行程、招募、預約、個人資料。
/// 無後端,資料存於記憶體(重啟即重置),提醒透過 NotificationService 排程。
class AppState extends ChangeNotifier {
  AppState() {
    _activities = buildMockActivities();
    _seedRecruitments();
    loadActivities();
  }

  final CultureApiService _cultureApi = CultureApiService();

  // ===== 活動 =====
  late List<Activity> _activities;
  String _selectedCity = '台北市';
  bool _loadingActivities = false;
  bool _usingLiveData = false;
  String? _activitiesError;

  String get selectedCity => _selectedCity;
  List<String> get cities => taiwanCities;
  bool get isLoadingActivities => _loadingActivities;
  bool get usingLiveData => _usingLiveData;
  String? get activitiesError => _activitiesError;

  void selectCity(String city) {
    _selectedCity = city;
    notifyListeners();
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
        // 若目前選的縣市在即時資料中沒有活動,自動切到有活動的第一個縣市。
        if (activitiesForSelectedCity.isEmpty) {
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
        .where((a) => a.city == city && !a.date.isBefore(today) && !a.date.isAfter(limit))
        .toList();
  }

  /// 指定縣市、近三個月內的活動(依日期升序)。
  List<Activity> get activitiesForSelectedCity {
    final list = _activitiesInCity(_selectedCity)..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  // ===== 行程 =====
  final List<ScheduleItem> _schedule = [];
  List<ScheduleItem> get schedule => List.unmodifiable(_schedule..sort((a, b) => a.activity.date.compareTo(b.activity.date)));

  bool isScheduled(Activity activity) => _schedule.any((s) => s.activity.id == activity.id);

  /// 排入行程:预设提醒时间为活动前一天早上 9 点(若已过则改活动前一小时)。
  void addToSchedule(Activity activity) {
    if (isScheduled(activity)) return;
    final defaultRemind = _defaultRemindFor(activity.date);
    final item = ScheduleItem(
      id: 'sch_${activity.id}',
      activity: activity,
      remindAt: defaultRemind,
    );
    _schedule.add(item);
    _syncReminder(item);
    // 同步产生一笔预约(来源:排入活动)。
    _addBooking(Booking(
      id: 'book_${activity.id}',
      title: activity.title,
      date: activity.date,
      source: BookingSource.activity,
      city: activity.city,
      cost: activity.cost,
    ));
    notifyListeners();
  }

  void removeFromSchedule(String scheduleId) {
    final idx = _schedule.indexWhere((s) => s.id == scheduleId);
    if (idx < 0) return;
    final item = _schedule[idx];
    NotificationService.instance.cancel(item.id.hashCode);
    _schedule.removeAt(idx);
    _removeBooking('book_${item.activity.id}');
    notifyListeners();
  }

  void updateReminder(String scheduleId, {DateTime? remindAt, bool? enabled}) {
    final item = _schedule.firstWhere((s) => s.id == scheduleId);
    if (remindAt != null) item.remindAt = remindAt;
    if (enabled != null) item.reminderEnabled = enabled;
    _syncReminder(item);
    notifyListeners();
  }

  DateTime _defaultRemindFor(DateTime activityDate) {
    final dayBefore = DateTime(activityDate.year, activityDate.month, activityDate.day - 1, 9);
    if (dayBefore.isAfter(DateTime.now())) return dayBefore;
    final hourBefore = activityDate.subtract(const Duration(hours: 1));
    return hourBefore.isAfter(DateTime.now()) ? hourBefore : DateTime.now().add(const Duration(minutes: 1));
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
  List<RecruitmentPost> get recruitments => List.unmodifiable(_recruitments..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  int _hostedCount = 0;
  int get hostedRecruitmentCount => _hostedCount;

  void _seedRecruitments() {
    final now = DateTime.now();
    _recruitments.addAll([
      RecruitmentPost(
        id: 'rec_seed_1',
        title: '找伴一起去陽明山健行',
        content: '預計早上出發,輕鬆路線,歡迎新手!結束後可以一起吃午餐。',
        headcount: 6,
        genderPref: GenderPref.any,
        cost: 0,
        author: '小綠',
        createdAt: now.subtract(const Duration(hours: 5)),
        joinedBy: {'阿哲', '妞妞'},
        // 範例資料
      ),
      RecruitmentPost(
        id: 'rec_seed_2',
        title: '週末羽球揪團',
        content: '雙打輪替,程度不拘,球場已訂好,費用現場均分。',
        headcount: 4,
        genderPref: GenderPref.balanced,
        cost: 180,
        author: '球咖阿明',
        createdAt: now.subtract(const Duration(days: 1)),
        joinedBy: {'Ken'},
      ),
    ]);
  }

  /// 发起招募(讨论版发文):同时算一次「开启招募次数」,并产生一笔预约。
  void createRecruitment({
    required String title,
    required String content,
    required int headcount,
    required GenderPref genderPref,
    required int cost,
    Activity? relatedActivity,
  }) {
    final me = _profile.nickname;
    final post = RecruitmentPost(
      id: 'rec_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      content: content,
      headcount: headcount,
      genderPref: genderPref,
      cost: cost,
      author: me,
      createdAt: DateTime.now(),
      relatedActivity: relatedActivity,
      joinedBy: {me},
    );
    _recruitments.add(post);
    _hostedCount += 1;
    _addBooking(Booking(
      id: 'book_${post.id}',
      title: post.title,
      date: relatedActivity?.date,
      source: BookingSource.hosted,
      city: relatedActivity?.city,
      cost: cost,
    ));
    notifyListeners();
  }

  bool hasJoined(RecruitmentPost post) => post.joinedBy.contains(_profile.nickname);

  /// 加入/退出招募。加入时产生预约,退出时移除。
  void toggleJoin(RecruitmentPost post) {
    final me = _profile.nickname;
    if (post.joinedBy.contains(me)) {
      post.joinedBy.remove(me);
      _removeBooking('book_join_${post.id}');
    } else {
      if (post.isFull) return;
      post.joinedBy.add(me);
      _participated = true;
      _addBooking(Booking(
        id: 'book_join_${post.id}',
        title: post.title,
        date: post.relatedActivity?.date,
        source: BookingSource.joined,
        city: post.relatedActivity?.city,
        cost: post.cost,
      ));
    }
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

  void _addBooking(Booking b) {
    if (_bookings.any((x) => x.id == b.id)) return;
    _bookings.add(b);
  }

  void _removeBooking(String id) {
    _bookings.removeWhere((x) => x.id == id);
  }

  // ===== 个人资料 =====
  final UserProfile _profile = UserProfile(
    nickname: '我',
    bio: '熱愛週末走跳、認識新朋友!',
    avatarColorValue: 0xFF3BB273,
    photos: ['🌿', '🏞️', '☕'],
  );
  bool _participated = false;

  UserProfile get profile => _profile;
  bool get hasParticipated => _participated || _schedule.isNotEmpty;

  void updateProfile({String? nickname, String? bio, int? avatarColorValue}) {
    if (nickname != null && nickname.trim().isNotEmpty) _profile.nickname = nickname.trim();
    if (bio != null) _profile.bio = bio.trim();
    if (avatarColorValue != null) _profile.avatarColorValue = avatarColorValue;
    notifyListeners();
  }

  void addPhoto(String emoji) {
    _profile.photos.add(emoji);
    notifyListeners();
  }

  void removePhoto(int index) {
    if (index >= 0 && index < _profile.photos.length) {
      _profile.photos.removeAt(index);
      notifyListeners();
    }
  }
}