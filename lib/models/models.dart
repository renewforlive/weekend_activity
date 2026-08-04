import 'package:flutter/material.dart';

/// 活动分类(附带代表色与图标,供列表卡片使用)。
enum ActivityCategory {
  outdoor('戶外踏青', Icons.hiking, Color(0xFF3BB273)),
  sports('運動健身', Icons.sports_basketball, Color(0xFFFF9F45)),
  music('音樂展演', Icons.music_note, Color(0xFF7C6FF0)),
  market('市集文創', Icons.storefront, Color(0xFFE5896B)),
  food('美食聚會', Icons.restaurant, Color(0xFFEBA83A)),
  learning('講座學習', Icons.school, Color(0xFF4AA8D8));

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
  final String title;
  final String content;
  final int headcount; // 招募总人数
  final GenderPref genderPref;
  final int cost; // 预估每人花费
  final String author; // 发起人暱称
  final DateTime createdAt;
  final Activity? relatedActivity; // 可选:关联的活动
  final Set<String> joinedBy; // 已加入者暱称集合

  int get joinedCount => joinedBy.length;
  bool get isFull => joinedCount >= headcount;
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

/// 个人资料。
class UserProfile {
  UserProfile({
    required this.nickname,
    required this.bio,
    this.avatarColorValue = 0xFF3BB273,
    List<String>? photos,
  }) : photos = photos ?? <String>[];

  String nickname;
  String bio;
  int avatarColorValue; // 以颜色代替头像图片(无后端/无相册权限时的占位)
  final List<String> photos; // 照片占位(以 emoji / 文字代表)
}