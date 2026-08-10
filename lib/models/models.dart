import 'package:flutter/material.dart';

import 'hiking_trail.dart';
import 'camping_site.dart';

/// 活动分类(附带代表色与图标,供列表卡片使用)。
enum ActivityCategory {
  outdoor('戶外踏青', Icons.hiking, Color(0xFF3BB273)),
  sports('運動健身', Icons.sports_basketball, Color(0xFFFF9F45)),
  music('音樂展演', Icons.music_note, Color(0xFF7C6FF0)),
  market('市集文創', Icons.storefront, Color(0xFFE5896B)),
  food('美食聚會', Icons.restaurant, Color(0xFFEBA83A)),
  learning('講座學習', Icons.school, Color(0xFF4AA8D8)),
  travel('旅遊景點', Icons.travel_explore, Color(0xFF2AA9A0)),
  hiking('登山步道', Icons.terrain, Color(0xFF5B8C5A)),
  camping('露營場', Icons.cabin, Color(0xFF8B6F47));

  const ActivityCategory(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

/// 招募性别限制。
enum GenderPref {
  any('不限'),
  male('限男生'),
  female('限女生'),
  balanced('男女各半');

  const GenderPref(this.label);
  final String label;
}

/// 一场活动(近三个月内、指定县市)。
class Activity {
  const Activity({
    required this.id,
    required this.title,
    required this.city,
    required this.venue,
    required this.date,
    required this.category,
    required this.description,
    required this.cost,
  });

  final String id;
  final String title;
  final String city;
  final String venue;
  final DateTime date;
  final ActivityCategory category;
  final String description;
  final int cost; // 参加费用(元),0 表示免费

  /// 由台北景點建立一場活動(景點無固定日期,需帶入使用者選定的日期)。
  factory Activity.fromSpot(TravelSpot spot, DateTime date) {
    return Activity(
      id: 'spot_${spot.id}',
      title: spot.name,
      city: '台北市',
      venue: spot.address.isNotEmpty ? spot.address : spot.distric,
      date: date,
      category: ActivityCategory.travel,
      description: spot.introduction,
      cost: 0,
    );
  }

  /// 是否為景點(無固定時間,可自由選排入時間)。
  bool get isSpot => category == ActivityCategory.travel;

  /// 由登山步道建立活動。步道沒有固定日期,需帶使用者選定的日期。
  factory Activity.fromTrail(HikingTrail trail, DateTime date) {
    return Activity(
      id: 'trail_${trail.id}',
      title: trail.name,
      city: trail.city,
      venue: trail.location,
      date: date,
      category: ActivityCategory.hiking,
      description: trail.guide,
      cost: 0,
    );
  }

  /// 是否為登山步道(無固定時間,由使用者選擇時間)。
  bool get isTrail => category == ActivityCategory.hiking;

  /// 由露營場建立活動。營場沒有固定日期,需帶使用者選定的日期。
  factory Activity.fromCamping(CampingSite site, DateTime date) {
    return Activity(
      id: 'camping_${site.id}',
      title: site.name,
      city: site.city,
      venue: site.displayAddress,
      date: date,
      category: ActivityCategory.camping,
      // 法規狀態是選營場的關鍵資訊,帶進行程以便日後回顧。
      description: site.violation.isEmpty
          ? site.legality.label
          : '${site.legality.label}（${site.violation}）',
      cost: 0,
    );
  }

  /// 是否為露營場(無固定時間,由使用者選擇時間)。
  bool get isCamping => category == ActivityCategory.camping;
}

/// 行程项目:某个活动被排入行程,可设定提醒。
class ScheduleItem {
  ScheduleItem({
    required this.id,
    required this.activity,
    required this.remindAt,
    this.reminderEnabled = true,
  });

  final String id;
  final Activity activity;
  DateTime remindAt;
  bool reminderEnabled;
}

/// 招募贴文(讨论版):标题、内容、人数、性别、花费。
class RecruitmentPost {
  RecruitmentPost({
    required this.id,
    required this.authorId,
    required this.title,
    required this.content,
    required this.headcount,
    required this.genderPref,
    required this.cost,
    required this.author,
    required this.createdAt,
    this.relatedActivity,
    Set<String>? joinedBy,
  }) : joinedBy = joinedBy ?? <String>{};

  final String id;
  final String authorId; // 發起人 user id
  final String title;
  final String content;
  final int headcount; // 招募總人數
  final GenderPref genderPref;
  final int cost; // 預估每人花費
  final String author; // 發起人暱稱(顯示用)
  final DateTime createdAt;
  final Activity? relatedActivity; // 可選:關聯的活動
  final Set<String> joinedBy; // 已加入者的 user id 集合

  int get joinedCount => joinedBy.length;
  bool get isFull => joinedCount >= headcount;

  /// 指定使用者是否已加入。
  bool isJoinedBy(String? userId) => userId != null && joinedBy.contains(userId);

  /// 是否為指定使用者發起。
  bool isHostedBy(String? userId) => userId != null && authorId == userId;
}

/// 预约来源:自己发起的招募 或 加入他人的招募。
enum BookingSource { hosted('我發起的招募'), joined('我加入的招募'), activity('我排入的活動');

  const BookingSource(this.label);
  final String label;
}

/// 已预约的行程项(由加入/发起招募,或排入活动产生)。
class Booking {
  Booking({
    required this.id,
    required this.title,
    required this.date,
    required this.source,
    this.city,
    this.cost = 0,
  });

  final String id;
  final String title;
  final DateTime? date;
  final BookingSource source;
  final String? city;
  final int cost;
}

/// 照片來源類型。
enum PhotoKind {
  /// emoji 佔位(用文字顯示)。
  emoji,

  /// 裝置本機檔案(用 Image.file 顯示,上傳前的暫時狀態)。
  file,

  /// 遠端網址(用 Image.network 顯示,已上傳到 Storage)。
  remote,
}

/// 個人照片。可以是 emoji 佔位、本機檔案,或已上傳的遠端圖片。
class ProfilePhoto {
  const ProfilePhoto.emoji(this.value, {this.id})
      : kind = PhotoKind.emoji,
        storagePath = null;

  const ProfilePhoto.file(this.value)
      : kind = PhotoKind.file,
        id = null,
        storagePath = null;

  const ProfilePhoto.remote(this.value, {this.id, this.storagePath})
      : kind = PhotoKind.remote;

  /// emoji 字元、本機路徑,或遠端網址。
  final String value;

  final PhotoKind kind;

  /// 資料庫紀錄 id(遠端照片才有)。
  final String? id;

  /// Storage 內的路徑(遠端照片才有,刪除時需要)。
  final String? storagePath;

  bool get isEmoji => kind == PhotoKind.emoji;
  bool get isFile => kind == PhotoKind.file;
  bool get isRemote => kind == PhotoKind.remote;

  /// 是否為圖片(非 emoji)。
  bool get isImage => !isEmoji;
}

/// 个人资料。
class UserProfile {
  UserProfile({
    required this.nickname,
    required this.bio,
    this.avatarColorValue = 0xFF3BB273,
    this.avatarUrl,
    this.avatarPath,
    List<ProfilePhoto>? photos,
  }) : photos = photos ?? <ProfilePhoto>[];

  String nickname;
  String bio;
  int avatarColorValue; // 未設頭像時,以色塊 + 暱稱首字代替
  String? avatarUrl; // 頭像公開網址(有值就顯示圖片)
  String? avatarPath; // 頭像在 Storage 的路徑(更換/刪除時需要)
  final List<ProfilePhoto> photos; // 照片:emoji 佔位或實際圖片檔

  /// 是否已設定頭像圖片。
  bool get hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;
}

/// 台北旅遊景點(來自 travel.taipei 開放 API)。與展覽類活動分開。
class TravelSpot {
  const TravelSpot({
    required this.id,
    required this.name,
    required this.introduction,
    required this.openStatus,
    required this.distric,
    required this.address,
    required this.images,
    required this.url,
  });

  final int id;
  final String name; // 標題
  final String introduction; // 內容介紹
  final int openStatus; // 1=開放 0=未開放
  final String distric; // 行政區
  final String address; // 地址
  final List<String> images; // 圖片網址(大圖輪播用)
  final String url; // 詳情網址(WebView 開啟)

  bool get isOpen => openStatus == 1;

  factory TravelSpot.fromJson(Map<String, dynamic> json) {
    final rawImages = json['images'];
    final imgs = <String>[];
    if (rawImages is List) {
      for (final item in rawImages) {
        if (item is Map && item['src'] is String) {
          imgs.add(item['src'] as String);
        }
      }
    }
    return TravelSpot(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      name: (json['name'] as String?)?.trim() ?? '',
      introduction: (json['introduction'] as String?)?.trim() ?? '',
      openStatus: json['open_status'] is int ? json['open_status'] as int : int.tryParse('${json['open_status']}') ?? 0,
      distric: (json['distric'] as String?)?.trim() ?? '',
      address: (json['address'] as String?)?.trim() ?? '',
      images: imgs,
      url: (json['url'] as String?)?.trim() ?? '',
    );
  }
}