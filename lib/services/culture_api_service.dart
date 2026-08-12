// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

/// 文化部「全國藝文活動資訊」開放資料(data.gov.tw dataset 6012)。
/// 回傳 JSON 陣列,每筆含 title / category / showInfo[] / startDate / endDate 等。
class CultureApiService {
  static const _endpoint =
      'https://cloud.culture.tw/frontsite/trans/SearchShowAction.do?method=doFindTypeJ&category=all';

  /// 抓取藝文活動並轉成 App 的 [Activity] 清單。
  /// 失敗時丟出例外,由呼叫端決定後備行為。
  Future<List<Activity>> fetchActivities() async {
    final res = await http
        .get(Uri.parse(_endpoint))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('文化部 API 回應狀態碼 ${res.statusCode}');
    }
    // 回應為 UTF-8 JSON 陣列。
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is! List) {
      throw Exception('文化部 API 回應格式非預期');
    }

    final result = <Activity>[];
    var seq = 0;
    for (final raw in decoded) {
      if (raw is! Map<String, dynamic>) continue;
      final activity = _parseOne(raw, seq);
      if (activity != null) {
        result.add(activity);
        seq++;
      }
    }
    return result;
  }

  Activity? _parseOne(Map<String, dynamic> json, int seq) {
    final title = (json['title'] ?? '').toString().trim();
    if (title.isEmpty) return null;

    final showInfoList = json['showInfo'];
    final firstShow =
        (showInfoList is List &&
            showInfoList.isNotEmpty &&
            showInfoList.first is Map)
        ? showInfoList.first as Map
        : const {};

    // 地點字串:如「臺中市40453 臺中市北區館前路一號」→ 解析出縣市與場館。
    final locationRaw = (firstShow['location'] ?? '').toString().trim();
    final locationName = (firstShow['locationName'] ?? '').toString().trim();
    final city = _parseCity(locationRaw);
    if (city == null) return null; // 無法歸類縣市者略過

    // 活動日期:優先用 showInfo.time,退回 startDate。
    final dateStr = (firstShow['time'] ?? json['startDate'] ?? '').toString();
    final date = _parseDate(dateStr);
    if (date == null) return null;

    final uid = (json['UID'] ?? '').toString();
    final id = uid.isEmpty ? 'culture_$seq' : 'culture_${uid}_$seq';

    return Activity(
      id: id,
      title: title,
      city: city,
      venue: locationName.isNotEmpty
          ? locationName
          : _venueFromLocation(locationRaw),
      date: date,
      category: _mapCategory((json['category'] ?? '').toString()),
      description: _cleanHtml((json['descriptionFilterHtml'] ?? '').toString()),
      cost: _parseCost((firstShow['price'] ?? '').toString()),
      detailsUrl: _firstUrl(json['webSales'], json['sourceWebPromote']),
    );
  }

  String _firstUrl(dynamic sales, dynamic promote) {
    for (final value in [sales, promote]) {
      final url = (value ?? '').toString().trim();
      if (url.startsWith('https://') || url.startsWith('http://')) return url;
    }
    return '';
  }

  /// 台灣縣市對照:location 常以「臺北市…」「台北市…」開頭,統一成本 App 用字。
  static const Map<String, String> _cityAliases = {
    '臺北市': '台北市',
    '台北市': '台北市',
    '新北市': '新北市',
    '基隆市': '基隆市',
    '桃園市': '桃園市',
    '桃園縣': '桃園市',
    '新竹市': '新竹市',
    '新竹縣': '新竹縣',
    '苗栗縣': '苗栗縣',
    '臺中市': '台中市',
    '台中市': '台中市',
    '彰化縣': '彰化縣',
    '南投縣': '南投縣',
    '雲林縣': '雲林縣',
    '嘉義市': '嘉義市',
    '嘉義縣': '嘉義縣',
    '臺南市': '台南市',
    '台南市': '台南市',
    '高雄市': '高雄市',
    '屏東縣': '屏東縣',
    '宜蘭縣': '宜蘭縣',
    '花蓮縣': '花蓮縣',
    '臺東縣': '台東縣',
    '台東縣': '台東縣',
    '澎湖縣': '澎湖縣',
    '金門縣': '金門縣',
    '連江縣': '連江縣',
  };

  String? _parseCity(String location) {
    if (location.isEmpty) return null;
    for (final entry in _cityAliases.entries) {
      if (location.contains(entry.key)) return entry.value;
    }
    return null;
  }

  String _venueFromLocation(String location) {
    if (location.isEmpty) return '地點詳見官網';
    // 去掉開頭的「縣市 + 郵遞區號」,取後段地址。
    final cleaned = location.replaceAll(RegExp(r'^\S*?\d{3,5}\s*'), '').trim();
    return cleaned.isEmpty ? location : cleaned;
  }

  DateTime? _parseDate(String raw) {
    if (raw.isEmpty) return null;
    // 格式如 2026/08/04 09:00:00 或 2026/08/04。
    final m = RegExp(r'(\d{4})/(\d{1,2})/(\d{1,2})').firstMatch(raw);
    if (m == null) return null;
    final y = int.tryParse(m.group(1)!);
    final mo = int.tryParse(m.group(2)!);
    final d = int.tryParse(m.group(3)!);
    if (y == null || mo == null || d == null) return null;
    // 時間(可選)。
    final t = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(raw);
    final hh = t != null ? int.tryParse(t.group(1)!) ?? 9 : 9;
    final mm = t != null ? int.tryParse(t.group(2)!) ?? 0 : 0;
    return DateTime(y, mo, d, hh, mm);
  }

  /// 文化部 category 代碼 → App 分類(近似對應)。
  ActivityCategory _mapCategory(String code) {
    switch (code) {
      case '1': // 音樂
      case '2': // 戲劇
      case '3': // 舞蹈
        return ActivityCategory.music;
      case '4': // 親子
      case '5': // 展覽
      case '6': // 講座
        return ActivityCategory.learning;
      case '11': // 綜藝
      case '19': // 電影
        return ActivityCategory.market;
      default:
        return ActivityCategory.market;
    }
  }

  int _parseCost(String price) {
    if (price.isEmpty) return 0;
    if (price.contains('免費') || price.contains('免票') || price.contains('自由'))
      return 0;
    // 抓第一組數字當代表票價。
    final m = RegExp(r'(\d{2,6})').firstMatch(price.replaceAll(',', ''));
    if (m == null) return 0;
    return int.tryParse(m.group(1)!) ?? 0;
  }

  String _cleanHtml(String html) {
    if (html.isEmpty) return '詳情請見主辦單位公告。';
    final text = html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\r\n]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.isEmpty) return '詳情請見主辦單位公告。';
    return text.length > 120 ? '${text.substring(0, 120)}…' : text;
  }
}
