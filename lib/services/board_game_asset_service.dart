import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/board_game_venue.dart';

/// 載入具官方頁面可供使用者確認的桌遊店資料。
class BoardGameAssetService {
  static const _assetPath = 'assets/data/board_game_venues.json';
  List<BoardGameVenue>? _cache;

  Future<List<BoardGameVenue>> loadAll() async {
    if (_cache != null) return _cache!;
    final decoded = jsonDecode(await rootBundle.loadString(_assetPath));
    final venues = <BoardGameVenue>[];
    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final venue = BoardGameVenue.fromJson(item);
          if (venue.id.isNotEmpty && venue.name.isNotEmpty) venues.add(venue);
        }
      }
    }
    venues.sort((a, b) => a.name.compareTo(b.name));
    return _cache = venues;
  }

  Future<List<BoardGameVenue>> byCity(String city) async {
    final target = city.replaceAll('臺', '台').trim();
    return (await loadAll()).where((venue) => venue.city == target).toList();
  }
}
