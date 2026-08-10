import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:weekend_activity/models/hiking_trail.dart';

void main() {
  group('HikingTrail.fromJson', () {
    test('解析林務局欄位', () {
      final t = HikingTrail.fromJson({
        'TRAILID': '123',
        'TR_CNAME': '測試步道',
        'TR_POSITION': '臺中市和平區',
        'TR_DIF_CLASS': '3',
        'TR_LENGTH_NUM': '5.5',
        'TR_ALT': '2200',
        'TR_ALT_LOW': '1800',
        'TR_TOUR': '一天',
        'TR_permit': '甲種入山證',
      });

      // 臺 要正規化成 台,否則和 taiwanCities 比對不到
      expect(t.city, '台中市');
      expect(t.district, '和平區');
      expect(t.difficulty, TrailDifficulty.midMountain);
      expect(t.lengthKm, 5.5);
      expect(t.altRange, '海拔 1800 ~ 2200 m');
      expect(t.needPermit, isTrue);
    });

    test('缺漏欄位給安全預設值', () {
      final t = HikingTrail.fromJson({'TR_CNAME': '無資料步道'});

      expect(t.difficulty, TrailDifficulty.easy);
      expect(t.lengthKm, 0);
      expect(t.lengthText, isEmpty);
      expect(t.altRange, isEmpty);
      expect(t.needPermit, isFalse);
    });

    test("TR_permit 為「無」時不需入山證", () {
      final t = HikingTrail.fromJson({'TR_CNAME': 'x', 'TR_permit': '無'});
      expect(t.needPermit, isFalse);
    });

    test('長度整數不顯示小數點', () {
      final t = HikingTrail.fromJson({'TR_CNAME': 'x', 'TR_LENGTH_NUM': '3.0'});
      expect(t.lengthText, '3 公里');
    });
  });

  test('trails.json 能被解析,且縣市名已正規化', () async {
    final raw = await File('assets/data/trails.json').readAsString();
    final list = jsonDecode(raw) as List;
    expect(list, isNotEmpty);

    final trails = list
        .map((e) => HikingTrail.fromJson(e as Map<String, dynamic>))
        .toList();

    // 每筆都要有名稱與縣市,否則列表會出現空白項
    for (final t in trails) {
      expect(t.name, isNotEmpty, reason: 'trail ${t.id} 沒有名稱');
      expect(t.city, isNotEmpty, reason: '${t.name} 沒有縣市');
      expect(t.city.contains('臺'), isFalse, reason: '${t.name} 的縣市未正規化');
    }
  });
}