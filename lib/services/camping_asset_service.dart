import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/camping_site.dart';

/// 從本地 asset 載入露營場(交通部觀光署全國露營場盤點資料)。
///
/// 資料檔:assets/data/camping.json
/// 縣市名在解析時已正規化(臺→台),可直接和 taiwanCities 比對。
class CampingAssetService {
  static const _assetPath = 'assets/data/camping.json';

  List<CampingSite>? _cache;

  /// 載入並解析全部露營場(結果快取,只解析一次)。
  Future<List<CampingSite>> loadAll() async {
    if (_cache != null) return _cache!;

    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw);
    final sites = <CampingSite>[];

    if (decoded is List) {
      for (var i = 0; i < decoded.length; i++) {
        final item = decoded[i];
        if (item is Map<String, dynamic>) {
          final site = CampingSite.fromJson(item, i);
          // 沒有名稱的資料無法顯示,略過。
          if (site.name.isNotEmpty) sites.add(site);
        }
      }
    }

    // 合法營區排前面,同狀態內依名稱排序。
    // 全國多數營區違反法規,把合法的放前面才有實用價值。
    sites.sort((a, b) {
      final l = a.legality.index.compareTo(b.legality.index);
      if (l != 0) return l;
      return a.name.compareTo(b.name);
    });

    _cache = sites;
    return sites;
  }

  /// 取得指定縣市的露營場。
  Future<List<CampingSite>> byCity(String city) async {
    final all = await loadAll();
    final target = city.replaceAll('臺', '台').trim();
    return all.where((s) => s.city == target).toList();
  }

  /// 有露營場資料的縣市清單(依數量排序)。
  Future<List<String>> citiesWithSites() async {
    final all = await loadAll();
    final counts = <String, int>{};
    for (final s in all) {
      if (s.city.isEmpty) continue;
      counts[s.city] = (counts[s.city] ?? 0) + 1;
    }
    final cities = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return cities;
  }
}