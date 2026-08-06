import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

/// 台北旅遊景點 API(travel.taipei 開放資料)。
///
/// 注意:此 API 由 Cloudflare 保護,必須帶完整瀏覽器 User-Agent 才能取得 JSON,
/// 否則會回傳 challenge 頁面。
class TaipeiTravelService {
  static const _base = 'https://www.travel.taipei/open-api/zh-tw/Attractions/All';

  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36',
    'Accept': 'application/json',
    'Accept-Language': 'zh-TW',
  };

  /// 取得指定頁的景點(每頁 30 筆)。回傳景點清單與總筆數。
  Future<TravelSpotPage> fetchAttractions({int page = 1}) async {
    final uri = Uri.parse('$_base?page=$page');
    final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('景點 API 回應錯誤:${resp.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw Exception('景點 API 回應格式不符');
    }
    final total = decoded['total'] is int ? decoded['total'] as int : 0;
    final data = decoded['data'];
    final spots = <TravelSpot>[];
    if (data is List) {
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          spots.add(TravelSpot.fromJson(item));
        }
      }
    }
    return TravelSpotPage(spots: spots, total: total);
  }
}

/// 一頁景點結果。
class TravelSpotPage {
  const TravelSpotPage({required this.spots, required this.total});
  final List<TravelSpot> spots;
  final int total;
}