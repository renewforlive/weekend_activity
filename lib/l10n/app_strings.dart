import '../models/models.dart';

/// 支援的語言。之後要加語言,在這裡新增,並於各字串的 _pick 補上對應翻譯。
enum AppLang { zhTW, en }

/// 全 App 唯一的文字來源(集中管理,方便改字與多語言)。
///
/// 用法:`AppStrings.navActivities`。
/// 帶參數的字串用方法,例如 `AppStrings.costLabel(120)`。
/// 切換語言:設定 `AppStrings.lang`(建議透過 AppState.setLang 以觸發畫面更新)。
class AppStrings {
  AppStrings._();

  /// 目前語言。預設繁體中文。
  static AppLang lang = AppLang.zhTW;

  /// 依目前語言挑字串。新增語言時在此擴充。
  static String _pick(String zh, String en) {
    switch (lang) {
      case AppLang.zhTW:
        return zh;
      case AppLang.en:
        return en;
    }
  }

  // ===== App =====
  static String get appTitle => _pick('週末活動夥伴', 'Weekend Buddy');

  // ===== 底部導覽 =====
  static String get navActivities => _pick('活動', 'Activities');
  static String get navSchedule => _pick('行程', 'Schedule');
  static String get navRecruitment => _pick('招募', 'Recruit');
  static String get navBooked => _pick('已預約', 'Booked');
  static String get navProfile => _pick('個人', 'Profile');

  // ===== 共用 =====
  static String get free => _pick('免費', 'Free');
  static String get cancel => _pick('取消', 'Cancel');
  static String get save => _pick('儲存', 'Save');
  static String get add => _pick('新增', 'Add');
  static String costLabel(int cost) => cost == 0 ? free : _pick('NT\$ $cost', 'NT\$ $cost');

  // ===== 活動頁 =====
  static String get activitiesTitle => _pick('探索活動', 'Explore');
  static String get recentThreeMonths => _pick('近三個月', 'Next 3 months');
  static String get sectionAttraction => _pick('景點', 'Attractions');
  static String get sectionExhibition => _pick('展覽', 'Exhibitions');
  static String get spotsError => _pick('無法載入台北景點,請稍後再試。', 'Failed to load Taipei attractions. Try again later.');
  static String get spotsEmpty => _pick('目前沒有景點資料。', 'No attractions right now.');
  static String get loadingMore => _pick('載入更多…', 'Loading more…');
  static String get noMoreData => _pick('沒有更多了', 'No more');
  static String get open => _pick('開放中', 'Open');
  static String get closed => _pick('未開放', 'Closed');
  static String get viewDetail => _pick('查看詳情', 'View detail');
  static String get detailTitle => _pick('景點詳情', 'Attraction');
  static String get openWebsite => _pick('開啟官方網頁', 'Open website');
  static String get location => _pick('地點', 'Location');
  static String get introduction => _pick('介紹', 'Introduction');

  // ===== 排入行程對話框 =====
  static String get pickScheduleTime => _pick('選擇排入時間', 'Pick a time');
  static String get fixedTimeHint => _pick('此活動時間固定,不可更改', 'This event has a fixed time');
  static String get pickDate => _pick('選擇日期', 'Select date');
  static String get pickTime => _pick('選擇時間', 'Select time');
  static String get confirm => _pick('確定排入', 'Add');
  static String get selectDateFirst => _pick('請先選擇日期與時間', 'Please pick date and time');

  // ===== 週曆行程 =====
  static String get today => _pick('今天', 'Today');
  static String get jumpToDate => _pick('跳到某一天', 'Jump to date');
  static String get noScheduleOnDay => _pick('這天還沒有行程', 'Nothing scheduled');
  static String weekOf(String range) => _pick(range, range);
  static String get activitiesEmpty => _pick('這個縣市近三個月還沒有活動,\n換個縣市看看吧!', 'No activities here in the next 3 months.\nTry another city!');
  static String get scheduledAlready => _pick('已在行程', 'Scheduled');
  static String get addToSchedule => _pick('排入行程', 'Add to schedule');
  static String get scheduledSnack => _pick('已排入行程,並幫你設定提醒 🔔', 'Added to schedule with a reminder 🔔');
  static String get startRecruitment => _pick('發起招募', 'Start recruiting');

  // ===== 行程頁 =====
  static String get scheduleTitle => _pick('我的行程', 'My schedule');
  static String get scheduleEmpty => _pick('還沒有行程,\n到「活動」頁把想參加的排進來吧!', 'No plans yet.\nAdd activities from the Activities tab!');
  static String remindAtLabel(String time) => _pick('提醒時間:$time', 'Reminds at $time');
  static String get reminderOff => _pick('提醒已關閉', 'Reminder off');
  static String get adjustReminder => _pick('調整提醒時間', 'Adjust reminder');

  // ===== 已預約頁 =====
  static String get bookedTitle => _pick('已預約行程', 'Bookings');
  static String get bookedEmpty => _pick('還沒有預約,\n排入活動或加入招募後會出現在這裡!', 'No bookings yet.\nThey show up after you join or schedule something!');
  static String get bookingCount => _pick('預約數', 'Bookings');
  static String get estimatedCost => _pick('預估花費', 'Est. cost');
  static String get dateTBD => _pick('時間待定', 'Date TBD');

  // ===== 招募頁 =====
  static String get recruitmentTitle => _pick('招募討論版', 'Recruitment board');
  static String get recruitmentEmpty => _pick('還沒有招募貼文,\n點右下角發起第一則揪團吧!', 'No posts yet.\nTap the button to start the first one!');
  static String headcountLabel(int joined, int total) => _pick('$joined/$total 人', '$joined/$total ppl');
  static String get hostedByMe => _pick('我發起', 'Mine');
  static String get joinedTapToLeave => _pick('已加入(點擊退出)', 'Joined (tap to leave)');
  static String get full => _pick('人數已滿', 'Full');
  static String get join => _pick('我要加入', 'Join');
  static String get justNow => _pick('剛剛', 'just now');
  static String minutesAgo(int n) => _pick('$n 分鐘前', '${n}m ago');
  static String hoursAgo(int n) => _pick('$n 小時前', '${n}h ago');
  static String daysAgo(int n) => _pick('$n 天前', '${n}d ago');

  // ===== 個人頁 =====
  static String get profileTitle => _pick('個人頁', 'Profile');
  static String get participatedLabel => _pick('是否參與過活動', 'Joined an activity?');
  static String get participated => _pick('已參與', 'Yes');
  static String get notParticipated => _pick('尚未參與', 'Not yet');
  static String get hostedCountLabel => _pick('開啟招募次數', 'Recruits started');
  static String timesLabel(int n) => _pick('$n 次', '$n');
  static String get myPhotos => _pick('我的照片', 'My photos');
  static String get avatarColor => _pick('頭像顏色', 'Avatar color');
  static String get editProfile => _pick('編輯個人資料', 'Edit profile');
  static String get nickname => _pick('暱稱', 'Nickname');
  static String get bio => _pick('自我介紹', 'Bio');
  static String get pickPhoto => _pick('新增照片', 'Add photo');
  static String get noPhotos => _pick('還沒有照片,點右上角新增', 'No photos yet, tap add above');
  static String get setAvatar => _pick('設定頭像', 'Set avatar');
  static String get removeAvatar => _pick('移除頭像', 'Remove avatar');
  static String get takePhoto => _pick('拍照', 'Take photo');
  static String get chooseFromGallery => _pick('從相簿選擇', 'Choose from gallery');
  static String get useEmoji => _pick('用圖示代表', 'Use an icon');
  static String get photoFailed => _pick('無法取得照片,請確認權限設定', 'Could not get photo, check permissions');
  static String get longPressToRemove => _pick('長按照片可刪除', 'Long press a photo to remove');

  // ===== 發起招募表單 =====
  static String get recruitmentEditorSubtitle => _pick('填寫標題與內容,揪對活動有興趣的人一起!', 'Fill in the details and gather people!');
  static String get fieldTitle => _pick('標題', 'Title');
  static String get titleHint => _pick('例如:週末陽明山健行揪團', 'e.g. Weekend hiking group');
  static String get titleRequired => _pick('請輸入標題', 'Title required');
  static String get fieldContent => _pick('內容', 'Content');
  static String get contentHint => _pick('說明集合時間、路線、注意事項…', 'Meeting time, route, notes…');
  static String get contentRequired => _pick('請輸入內容', 'Content required');
  static String get headcountField => _pick('招募人數', 'Headcount');
  static String get peopleUnit => _pick('人', 'ppl');
  static String get atLeastOnePerson => _pick('至少 1 人', 'At least 1');
  static String get costPerPerson => _pick('每人花費', 'Cost / person');
  static String get genderLimit => _pick('性別限制', 'Gender');
  static String get publishRecruitment => _pick('發布招募', 'Publish');
  static String get publishedSnack => _pick('招募已發布!到招募版看看吧 📣', 'Published! Check the board 📣');
  static String togetherGo(String title) => _pick('一起去「$title」', 'Join me at "$title"');
  static String recruitmentContentPrefill(String city, String venue) => _pick('$city · $venue,有興趣的一起來!', '$city · $venue, join if interested!');

  // ===== enum:活動分類 =====
  static String categoryLabel(ActivityCategory c) {
    switch (c) {
      case ActivityCategory.outdoor:
        return _pick('戶外踏青', 'Outdoor');
      case ActivityCategory.sports:
        return _pick('運動健身', 'Sports');
      case ActivityCategory.music:
        return _pick('音樂展演', 'Music');
      case ActivityCategory.market:
        return _pick('市集文創', 'Market');
      case ActivityCategory.food:
        return _pick('美食聚會', 'Food');
      case ActivityCategory.learning:
        return _pick('講座學習', 'Learning');
      case ActivityCategory.travel:
        return _pick('旅遊景點', 'Attraction');
    }
  }

  // ===== enum:性別限制 =====
  static String genderLabel(GenderPref g) {
    switch (g) {
      case GenderPref.any:
        return _pick('不限', 'Any');
      case GenderPref.male:
        return _pick('限男生', 'Male only');
      case GenderPref.female:
        return _pick('限女生', 'Female only');
      case GenderPref.balanced:
        return _pick('男女各半', 'Balanced');
    }
  }

  // ===== enum:預約來源 =====
  static String bookingSourceLabel(BookingSource s) {
    switch (s) {
      case BookingSource.hosted:
        return _pick('我發起的招募', 'Hosted');
      case BookingSource.joined:
        return _pick('我加入的招募', 'Joined');
      case BookingSource.activity:
        return _pick('我排入的活動', 'Scheduled');
    }
  }
}
