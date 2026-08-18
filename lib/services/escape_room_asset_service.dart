import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/escape_room_venue.dart';

/// 載入已核實官方網址的密室逃脫據點。
class EscapeRoomAssetService {
  static const _assetPath = 'assets/data/escape_rooms.json';
  List<EscapeRoomVenue>? _cache;

  Future<List<EscapeRoomVenue>> loadAll() async {
    if (_cache != null) return _cache!;
    final decoded = jsonDecode(await rootBundle.loadString(_assetPath));
    final venues = <EscapeRoomVenue>[];
    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final venue = EscapeRoomVenue.fromJson(item);
          if (venue.id.isNotEmpty && venue.name.isNotEmpty) venues.add(venue);
        }
      }
    }
    venues.sort((a, b) => a.name.compareTo(b.name));
    return _cache = venues;
  }

  Future<List<EscapeRoomVenue>> byCity(String city) async {
    final target = city.replaceAll('臺', '台').trim();
    return (await loadAll()).where((venue) => venue.city == target).toList();
  }
}
