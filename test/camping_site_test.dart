import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:weekend_activity/models/camping_site.dart';

void main() {
  group('CampingSite.fromJson', () {
    test('解析觀光署欄位', () {
      final s = CampingSite.fromJson({
        '露營場名稱': '測試露營區',
        '縣市別': '臺中市',
        '縣市代碼': '10008',
        '鄉/鎮/市/區': '和平區',
        '營業狀態': '營業中',
        '經度': '121.0',
        '緯度': '24.5',
        '地址': '臺中市和平區測試路1號',
        '電話': '0412345678',
        '手機': '',
        '網站': 'https://example.com',
        '符合相關法規露營場／違反相關法規露營場': '符合相關法規露營場',
        '違反相關法規': '',
        '是否有在原民區': '是',
        '露營場設置時間': '2020',
      }, 0);

      expect(s.name, '測試露營區');
      // 縣市須正規化為「台」,才能和 taiwanCities 比對。
      expect(s.city, '台中市');
      expect(s.district, '和平區');
      expect(s.location, '台中市和平區');
      expect(s.legality, CampingLegality.legal);
      expect(s.inIndigenousArea, isTrue);
      expect(s.contactNumber, '0412345678');
      expect(s.hasCoordinate, isTrue);
    });

    test('違規營場帶出違反的法規', () {
      final s = CampingSite.fromJson({
        '露營場名稱': '違規營區',
        '縣市別': '南投縣',
        '鄉/鎮/市/區': '仁愛鄉',
        '符合相關法規露營場／違反相關法規露營場': '違反相關法規露營場',
        '違反相關法規': '區域計畫法',
        '是否有在原民區': '否',
      }, 1);

      expect(s.legality, CampingLegality.illegal);
      expect(s.violation, '區域計畫法');
      expect(s.inIndigenousArea, isFalse);
    });

    test('缺漏欄位給安全預設值', () {
      final s = CampingSite.fromJson({'露營場名稱': '資料不全'}, 2);

      expect(s.legality, CampingLegality.unknown);
      expect(s.hasContact, isFalse);
      expect(s.hasCoordinate, isFalse);
      expect(s.violation, isEmpty);
    });

    test('手機作為備用聯絡號碼', () {
      final s = CampingSite.fromJson({
        '露營場名稱': '只有手機',
        '電話': '',
        '手機': '0912345678',
      }, 3);

      expect(s.contactNumber, '0912345678');
    });
  });

  test('camping.json 能被解析,且縣市名已正規化', () {
    final raw = File('assets/data/camping.json').readAsStringSync();
    final list = jsonDecode(raw) as List;
    final sites = list
        .whereType<Map<String, dynamic>>()
        .toList()
        .asMap()
        .entries
        .map((e) => CampingSite.fromJson(e.value, e.key))
        .where((s) => s.name.isNotEmpty)
        .toList();

    expect(sites.length, greaterThan(1500));
    // 解析後不應殘留「臺」,否則會對不上 taiwanCities。
    expect(sites.any((s) => s.city.contains('臺')), isFalse);
    // 資料裡合法營場是少數,確認兩種狀態都存在。
    expect(sites.any((s) => s.legality == CampingLegality.legal), isTrue);
    expect(sites.any((s) => s.legality == CampingLegality.illegal), isTrue);
  });
}