import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/hiking_trail.dart';

/// 從本地 asset 載入登山步道(林務局全國步道資料)。
///
/// 資料檔:assets/data/trails.json
/// 縣市名在解析時已正規化(臺→台),可直接和 taiwanCities 比對。
class TrailAssetService {
  static const _assetPath = 'assets/data/trails.json';

  List<HikingTrail>? _cache;

  /// 載入並解析全部步道(結果快取,只解析一次)。
  Future<List<HikingTrail>> loadAll() async {
    if (_cache != null) return _cache!;

    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw);
    final trails = <HikingTrail>[];

    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final trail = HikingTrail.fromJson(item);
          // 沒有名稱的資料無法顯示,略過。
          if (trail.name.isNotEmpty) trails.add(trail);
        }
      }
    }

    // 依難度再依長度排序,讓輕鬆的步道排前面。
    trails.sort((a, b) {
      final d = a.difficulty.level.compareTo(b.difficulty.level);
      if (d != 0) return d;
      return a.lengthKm.compareTo(b.lengthKm);
    });

    _cache = trails;
    return trails;
  }

  /// 取得指定縣市的步道。
  Future<List<HikingTrail>> byCity(String city) async {
    final all = await loadAll();
    final target = city.replaceAll('臺', '台').trim();
    return all.where((t) => t.city == target).toList();
  }

  /// 有步道資料的縣市清單(依步道數量排序)。
  ///
  /// 資料只涵蓋部分縣市,UI 可用這份清單避免讓使用者選到空的縣市。
  Future<List<String>> citiesWithTrails() async {
    final all = await loadAll();
    final counts = <String, int>{};
    for (final t in all) {
      if (t.city.isEmpty) continue;
      counts[t.city] = (counts[t.city] ?? 0) + 1;
    }
    final cities = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return cities;
  }
}