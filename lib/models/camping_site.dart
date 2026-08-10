import 'package:flutter/material.dart';

/// 露營場的法規狀態。
///
/// 全國 1807 筆裡有 1604 筆違反相關法規,這是選露營地時最該知道的事,
/// 所以獨立成 enum 以便在列表明顯標示。
enum CampingLegality {
  legal('合法露營場', Color(0xFF3BB273)),
  illegal('違反相關法規', Color(0xFFE5646E)),
  unknown('狀態不明', Color(0xFF6B7C74));

  const CampingLegality(this.label, this.color);

  final String label;
  final Color color;

  /// 從原始欄位判斷。只有明確標示符合法規才算合法。
  static CampingLegality fromText(String? text) {
    final t = text?.trim() ?? '';
    if (t.isEmpty) return CampingLegality.unknown;
    if (t.contains('符合')) return CampingLegality.legal;
    if (t.contains('違反')) return CampingLegality.illegal;
    return CampingLegality.unknown;
  }
}

/// 露營場(來自交通部觀光署全國露營場盤點資料)。
///
/// 與 HikingTrail、TravelSpot 一樣沒有固定日期,由使用者自己挑要哪天去。
class CampingSite {
  const CampingSite({
    required this.id,
    required this.name,
    required this.city,
    required this.district,
    required this.address,
    required this.status,
    required this.legality,
    required this.violation,
    required this.inIndigenousArea,
    required this.setupTime,
    required this.phone,
    required this.mobile,
    required this.url,
    required this.lat,
    required this.lng,
  });

  final String id;
  final String name;

  /// 縣市,已正規化為「台」。
  final String city;

  /// 鄉鎮市區。
  final String district;

  /// 完整地址。部分資料只有路名,沒有縣市前綴。
  final String address;

  /// 營業狀態。目前資料全部為「營業中」。
  final String status;

  final CampingLegality legality;

  /// 違反的法規名稱,例如「區域計畫法」。合法營區為空字串。
  final String violation;

  /// 是否位於原住民族地區。進入可能需留意相關規定。
  final bool inIndigenousArea;

  /// 露營場設置時間的說明文字。
  final String setupTime;

  final String phone;
  final String mobile;
  final String url;

  /// 座標。0 表示資料缺漏。
  final double lat;
  final double lng;

  /// 完整位置,用於顯示。
  String get location => district.isNotEmpty ? '$city$district' : city;

  /// 顯示用地址。資料缺縣市前綴時補上,方便使用者辨識。
  String get displayAddress {
    if (address.isEmpty) return location;
    if (address.startsWith(city) || address.contains(city)) return address;
    return '$location$address';
  }

  /// 可撥打的號碼,優先市話。空字串表示沒有聯絡電話。
  String get contactNumber => phone.isNotEmpty ? phone : mobile;

  bool get hasContact => contactNumber.isNotEmpty;

  /// 是否有座標可供定位。
  bool get hasCoordinate => lat != 0 && lng != 0;

  /// 從觀光署的原始欄位建立。缺漏一律給安全的預設值。
  factory CampingSite.fromJson(Map<String, dynamic> json, int index) {
    final city = _city(json['縣市別']);
    final district = _str(json['鄉/鎮/市/區']);

    return CampingSite(
      // 原始資料沒有唯一 id,用縣市+索引組出穩定的鍵。
      id: 'camp_${_str(json['縣市代碼'])}_$index',
      name: _str(json['露營場名稱']),
      city: city,
      district: district,
      address: _str(json['地址']),
      status: _str(json['營業狀態']),
      legality: CampingLegality.fromText(
        _str(json['符合相關法規露營場／違反相關法規露營場']),
      ),
      violation: _str(json['違反相關法規']),
      inIndigenousArea: _str(json['是否有在原民區']) == '是',
      setupTime: _str(json['露營場設置時間']),
      phone: _str(json['電話']),
      mobile: _str(json['手機']),
      url: _str(json['網站']),
      lat: _num(json['緯度']),
      lng: _num(json['經度']),
    );
  }

  /// 安全取字串。null 或 'null' 都轉成空字串。
  static String _str(dynamic v) {
    if (v == null) return '';
    final s = v.toString().trim();
    return s == 'null' ? '' : s;
  }

  /// 安全取數字。座標在原始資料裡是字串形式。
  static double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim()) ?? 0;
  }

  /// 縣市正規化。資料用「臺」而 App 的 taiwanCities 用「台」。
  static String _city(dynamic v) => _str(v).replaceAll('臺', '台');
}