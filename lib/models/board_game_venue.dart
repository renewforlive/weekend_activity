/// 桌遊店家據點。
///
/// 場次、費用與可玩的遊戲容易異動，App 僅提供店家基本資料及官方連結。
class BoardGameVenue {
  const BoardGameVenue({
    required this.id,
    required this.name,
    required this.city,
    required this.district,
    required this.address,
    required this.summary,
    required this.officialUrl,
    required this.verifiedAt,
  });

  final String id;
  final String name;
  final String city;
  final String district;
  final String address;
  final String summary;
  final String officialUrl;
  final String verifiedAt;

  String get location => district.isEmpty ? city : '$city$district';

  factory BoardGameVenue.fromJson(Map<String, dynamic> json) {
    String value(String key) => (json[key] ?? '').toString().trim();
    return BoardGameVenue(
      id: value('id'),
      name: value('name'),
      city: value('city').replaceAll('臺', '台'),
      district: value('district'),
      address: value('address'),
      summary: value('summary'),
      officialUrl: value('officialUrl'),
      verifiedAt: value('verifiedAt'),
    );
  }
}
