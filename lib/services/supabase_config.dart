import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase 連線設定與初始化。
///
/// publishable key 可以放在客戶端(設計如此),安全性依賴資料庫的 RLS 政策。
/// 切勿把 service_role key 放進 App。
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://jhyvszprtsdbjoytejne.supabase.co';
  static const String publishableKey =
      'sb_publishable_qZOlYKcEW_dU4SWklQykHg_Be0T1L6x';

  /// Storage bucket:個人照片。
  static const String photoBucket = 'profile-photos';

  static SupabaseClient get client => Supabase.instance.client;

  /// 目前登入使用者的 id(未登入時為 null)。
  static String? get userId => client.auth.currentUser?.id;

  /// 是否已登入。
  static bool get isSignedIn => client.auth.currentUser != null;

  /// 初始化 Supabase。需在 runApp 之前呼叫。
  static Future<void> init() async {
    await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
    );
  }

  /// 確保有身分可用:未登入時以匿名帳號登入。
  /// 之後要加 email 登入時,這裡可改為導向登入頁。
  static Future<void> ensureSignedIn() async {
    if (isSignedIn) return;
    await client.auth.signInAnonymously();
  }
}