import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/models.dart';

/// 從本地 asset(交通部觀光署全台景點資料)載入景點。
///
/// 資料檔:assets/data/attractions.json(TDX AttractionList 格式)。
/// 依縣市分組,城市名稱正規化(臺→台)以對應 app 既有的城市清單。
class AttractionAssetService {
  static const _assetPath = 'assets/data/attractions.json';

  List<TravelSpot>? _cache;

  /// 城市名稱正規化:臺北市 → 台北市。
  static String normalizeCity(String city) => city.replaceAll('臺', '台').trim();

  /// 載入並解析全部景點(結果快取,只解析一次)。
  Future<List<TravelSpot>> loadAll() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw);
    final spots = <TravelSpot>[];
    if (decoded is Map<String, dynamic>) {
      final list = decoded['Attractions'];
      if (list is List) {
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final spot = _parse(item);
            if (spot != null) spots.add(spot);
          }
        }
      }
    }
    _cache = spots;
    return spots;
  }

  /// 取得指定縣市的景點(城市名稱會先正規化比對)。
  Future<List<TravelSpot>> byCity(String city) async {
    final all = await loadAll();
    final target = normalizeCity(city);
    return all.where((s) => normalizeCity(s.distric) == target).toList();
  }

  /// 依縣市分組:{ 城市: [景點...] }。
  Future<Map<String, List<TravelSpot>>> groupedByCity() async {
    final all = await loadAll();
    final map = <String, List<TravelSpot>>{};
    for (final s in all) {
      final city = normalizeCity(s.distric);
      map.putIfAbsent(city, () => []).add(s);
    }
    return map;
  }

  TravelSpot? _parse(Map<String, dynamic> json) {
    final name = (json['AttractionName'] as String?)?.trim() ?? '';
    if (name.isEmpty) return null;

    // 圖片:Images[].URL
    final images = <String>[];
    final rawImages = json['Images'];
    if (rawImages is List) {
      for (final img in rawImages) {
        if (img is Map && img['URL'] is String) {
          final u = (img['URL'] as String).trim();
          if (u.isNotEmpty) images.add(u);
        }
      }
    }

    // 地址:PostalAddress { City, Town, StreetAddress }
    final addr = json['PostalAddress'];
    String city = '';
    String fullAddress = '';
    if (addr is Map) {
      city = (addr['City'] as String?)?.trim() ?? '';
      final town = (addr['Town'] as String?)?.trim() ?? '';
      final street = (addr['StreetAddress'] as String?)?.trim() ?? '';
      fullAddress = '$town$street';
    }

    // ID:AttractionID 是字串,取數字雜湊當作 int id(model 需要 int)。
    final rawId = (json['AttractionID'] as String?)?.trim() ?? name;
    final id = rawId.hashCode & 0x7fffffff;

    // 服務狀態:ServiceStatus == 1 視為開放。
    final status = json['ServiceStatus'];
    final openStatus = (status is int ? status : int.tryParse('$status') ?? 0) == 1 ? 1 : 0;

    return TravelSpot(
      id: id,
      name: name,
      introduction: (json['Description'] as String?)?.trim() ?? '',
      openStatus: openStatus,
      distric: city,
      address: fullAddress,
      images: images,
      url: (json['WebsiteURL'] as String?)?.trim() ?? '',
      attractionClasses: (json['AttractionClasses'] as List?)
              ?.map((value) => value is int
                  ? value
                  : int.tryParse('$value'))
              .whereType<int>()
              .toList() ??
          const <int>[],
    );
  }
}
