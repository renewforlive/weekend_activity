import '../models/models.dart';

/// 台灣縣市清單(供活動頁篩選,用字與文化部 API 解析結果一致)。
const List<String> taiwanCities = [
  '台北市', '新北市', '基隆市', '桃園市', '新竹市', '新竹縣',
  '苗栗縣', '台中市', '彰化縣', '南投縣', '雲林縣', '嘉義市',
  '嘉義縣', '台南市', '高雄市', '屏東縣', '宜蘭縣', '花蓮縣',
  '台東縣', '澎湖縣', '金門縣', '連江縣',
];

/// 依當前日期動態產生「近三個月內」的活動假資料(API 失敗時的離線後備),
/// 保證不論何時執行,活動日期都落在今天起算的三個月內。
List<Activity> buildMockActivities() {
  final now = DateTime.now();
  DateTime day(int offset) => DateTime(now.year, now.month, now.day).add(Duration(days: offset));

  final seeds = <_Seed>[
    _Seed('陽明山秋季健行團', '台北市', '陽明山國家公園', 6, ActivityCategory.outdoor, '沿著二子坪步道漫步,適合新手的輕鬆路線,終點有咖啡休息站。', 0),
    _Seed('河濱黃昏路跑', '新北市', '大稻埕河濱公園', 9, ActivityCategory.sports, '5 公里團練,配速輕鬆,跑後一起吃晚餐。', 100),
    _Seed('週末草地音樂節', '台中市', '文心森林公園', 14, ActivityCategory.music, '獨立樂團接力演出,帶上野餐墊享受午後陽光。', 350),
    _Seed('文青手作市集', '台南市', '藍晒圖文創園區', 18, ActivityCategory.market, '手作飾品、皮件與咖啡攤位,現場有街頭表演。', 0),
    _Seed('海線自行車小旅行', '新竹縣', '新豐海岸線', 22, ActivityCategory.outdoor, '沿海騎乘約 20 公里,欣賞紅樹林與夕陽。', 250),
    _Seed('無菜單料理共食會', '高雄市', '鹽埕老屋餐桌', 27, ActivityCategory.food, '六人小桌共享在地食材料理,認識新朋友。', 780),
    _Seed('城市攝影講座', '台北市', '松菸文創園區', 33, ActivityCategory.learning, '從構圖到後製,攝影師分享街拍心法。', 300),
    _Seed('登山入門體驗', '宜蘭縣', '聖母山莊步道', 40, ActivityCategory.outdoor, '通往抹茶山的經典路線,含嚮導與保險。', 500),
    _Seed('沙灘排球同樂', '屏東縣', '墾丁大灣', 46, ActivityCategory.sports, '分組對抗賽,不分程度都能玩,備有飲水。', 150),
    _Seed('爵士之夜', '台中市', '中山堂前廣場', 52, ActivityCategory.music, '露天爵士演出,可自備摺疊椅。', 200),
    _Seed('小農蔬果市集', '花蓮縣', '鐵道文化園區', 58, ActivityCategory.market, '在地小農直送,現場有食農教育體驗。', 0),
    _Seed('日式甜點品嚐會', '台北市', '大安巷弄甜點店', 64, ActivityCategory.food, '五款季節限定甜點搭配茶飲,名額有限。', 450),
    _Seed('溪谷溯溪體驗', '南投縣', '五分車溪谷', 71, ActivityCategory.outdoor, '專業教練帶隊,提供裝備,體驗清涼溪流。', 900),
    _Seed('羽球週末團', '桃園市', '巨蛋運動中心', 77, ActivityCategory.sports, '雙打輪替,場地與球拍可租借。', 180),
    _Seed('理財入門工作坊', '新竹市', '公道五路共享空間', 84, ActivityCategory.learning, '零基礎理財觀念,現場互動練習。', 350),
  ];

  return [
    for (var i = 0; i < seeds.length; i++)
      Activity(
        id: 'act_$i',
        title: seeds[i].title,
        city: seeds[i].city,
        venue: seeds[i].venue,
        date: day(seeds[i].dayOffset),
        category: seeds[i].category,
        description: seeds[i].description,
        cost: seeds[i].cost,
      ),
  ];
}

class _Seed {
  const _Seed(this.title, this.city, this.venue, this.dayOffset, this.category, this.description, this.cost);
  final String title;
  final String city;
  final String venue;
  final int dayOffset;
  final ActivityCategory category;
  final String description;
  final int cost;
}