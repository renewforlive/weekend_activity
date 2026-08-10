import 'package:flutter/material.dart';

/// 步道難度。對應林務局的 TR_DIF_CLASS(1~5)。
enum TrailDifficulty {
  easy(1, '步道健行', Color(0xFF3BB273)),
  moderate(2, '登山健行', Color(0xFF4AA8D8)),
  midMountain(3, '中級山', Color(0xFFEBA83A)),
  highMountain(4, '高山', Color(0xFFFF9F45)),
  expert(5, '高山嚮導', Color(0xFFE5646E));

  const TrailDifficulty(this.level, this.label, this.color);

  /// 1~5,數字越大越難。
  final int level;

  /// 顯示名稱。
  final String label;

  /// 由淺到深,難度越高顏色越警示。
  final Color color;

  /// 從林務局的代碼建立。無法辨識時給最保守的 easy。
  static TrailDifficulty fromCode(String? code) {
    return switch (code?.trim()) {
      '1' => TrailDifficulty.easy,
      '2' => TrailDifficulty.moderate,
      '3' => TrailDifficulty.midMountain,
      '4' => TrailDifficulty.highMountain,
      '5' => TrailDifficulty.expert,
      _ => TrailDifficulty.easy,
    };
  }
}

/// 登山步道(來自林務局全國步道資料)。
///
/// 與 TravelSpot 一樣沒有固定日期,由使用者自己挑要哪天去。
class HikingTrail {
  const HikingTrail({
    required this.id,
    required this.name,
    required this.city,
    required this.district,
    required this.difficulty,
    required this.lengthKm,
    required this.altHigh,
    required this.altLow,
    required this.duration,
    required this.bestSeason,
    required this.pavement,
    required this.guide,
    required this.system,
    required this.admin,
    required this.adminPhone,
    required this.needPermit,
    required this.url,
  });

  final String id;
  final String name;

  /// 縣市,已正規化為「台」。
  final String city;

  /// 鄉鎮市區。
  final String district;

  final TrailDifficulty difficulty;

  /// 步道長度(公里)。0 表示資料缺漏。
  final double lengthKm;

  /// 海拔高點與低點(公尺)。0 表示資料缺漏。
  final int altHigh;
  final int altLow;

  /// 建議時間,例如「半天」「一天」。
  final String duration;

  final String bestSeason;

  /// 路面狀況。
  final String pavement;

  /// 步道導覽介紹。
  final String guide;

  /// 所屬步道系統,例如「中央山脈脊樑國家步道系統」。
  final String system;

  final String admin;
  final String adminPhone;

  /// 是否需要入山證。
  final bool needPermit;

  final String url;

  /// 完整位置,用於顯示。
  String get location => district.isNotEmpty ? '$city$district' : city;

  /// 海拔範圍描述。資料缺漏時回傳空字串。
  String get altRange {
    if (altHigh <= 0 && altLow <= 0) return '';
    if (altLow <= 0 || altLow == altHigh) return '海拔 $altHigh m';
    return '海拔 $altLow ~ $altHigh m';
  }

  /// 長度描述。資料缺漏時回傳空字串。
  String get lengthText {
    if (lengthKm <= 0) return '';
    // 去掉無意義的小數點,例如 3.0 顯示為 3
    final t = lengthKm == lengthKm.roundToDouble()
        ? lengthKm.toStringAsFixed(0)
        : lengthKm.toStringAsFixed(1);
    return '$t 公里';
  }

  /// 從林務局的原始欄位建立。缺漏一律給安全的預設值。
  factory HikingTrail.fromJson(Map<String, dynamic> json) {
    final position = _str(json['TR_POSITION']);
    final (city, district) = _splitPosition(position);

    return HikingTrail(
      id: _str(json['TRAILID']),
      name: _str(json['TR_CNAME']),
      city: city,
      district: district,
      difficulty: TrailDifficulty.fromCode(_str(json['TR_DIF_CLASS'])),
      lengthKm: _num(json['TR_LENGTH_NUM']),
      altHigh: _num(json['TR_ALT']).round(),
      altLow: _num(json['TR_ALT_LOW']).round(),
      duration: _str(json['TR_TOUR']),
      bestSeason: _str(json['TR_BEST_SEASON']),
      pavement: _str(json['TR_PAVE']),
      guide: _str(json['GUIDE_CONTENT']),
      system: _str(json['TR_MAIN_SYS']),
      admin: _str(json['TR_ADMIN']),
      adminPhone: _str(json['TR_ADMIN_PHONE']),
      // 「無」以外都視為需要入山證。
      needPermit: _str(json['TR_permit']).isNotEmpty &&
          _str(json['TR_permit']) != '無',
      url: _str(json['URL']),
    );
  }

  /// 安全取字串。null 或 'null' 都轉成空字串。
  static String _str(dynamic v) {
    if (v == null) return '';
    final s = v.toString().trim();
    return s == 'null' ? '' : s;
  }

  /// 安全取數字。資料裡有些欄位是字串形式的數字。
  static double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim()) ?? 0;
  }

  /// 把「宜蘭縣南澳鄉」拆成縣市與鄉鎮。
  ///
  /// 縣市名一律為三字(如宜蘭縣、臺中市),但資料用「臺」而 App 用「台」,
  /// 這裡一併正規化以便和 taiwanCities 比對。
  static (String, String) _splitPosition(String position) {
    if (position.isEmpty) return ('', '');
    final normalized = position.replaceAll('臺', '台');
    if (normalized.length <= 3) return (normalized, '');
    return (normalized.substring(0, 3), normalized.substring(3));
  }
}