/// 密室逃脫店家據點。
///
/// 每筆資料代表可前往的一個實體場館，而不是單一遊戲主題；官方網站
/// 由使用者自行查看最新場次與票價，避免把容易變動的資訊寫死在 App。
class EscapeRoomVenue {
  const EscapeRoomVenue({
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

  factory EscapeRoomVenue.fromJson(Map<String, dynamic> json) {
    String value(String key) => (json[key] ?? '').toString().trim();
    return EscapeRoomVenue(
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
