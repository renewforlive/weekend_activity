/// 不依賴 intl locale 的日期格式化(避免未初始化 locale 資料時 format 拋例外,
/// 這是先前活動頁白畫面的主因)。統一以繁體中文星期顯示。
class AppDate {
  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// 例:8/4（二）
  static String monthDayWeek(DateTime d) {
    final w = _weekdays[(d.weekday - 1) % 7];
    return '${d.month}/${d.day}（$w）';
  }

  /// 例:8/4（二）09:00
  static String monthDayWeekTime(DateTime d) {
    return '${monthDayWeek(d)} ${_two(d.hour)}:${_two(d.minute)}';
  }

  /// 例:8/4 09:00
  static String monthDayTime(DateTime d) {
    return '${d.month}/${d.day} ${_two(d.hour)}:${_two(d.minute)}';
  }

  /// 例:8/4
  static String monthDay(DateTime d) => '${d.month}/${d.day}';
}