import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

/// 認證結果。成功時 error 為 null。
class AuthResult {
  const AuthResult.success({this.requiresEmailConfirmation = false}) : error = null;
  const AuthResult.failure(this.error) : requiresEmailConfirmation = false;

  final String? error;
  final bool requiresEmailConfirmation;
  bool get isSuccess => error == null;
}

/// Email + 密碼認證。
///
/// 匿名身分升級:未登入的使用者一律先有匿名帳號(行程、照片都綁在上面),
/// 註冊時用 updateUser 把匿名帳號升級為正式帳號,user id 不變,
/// 因此既有資料會自動保留。
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  GoTrueClient get _auth => SupabaseConfig.client.auth;

  /// 目前使用者是否為匿名身分(尚未綁定 email)。
  bool get isAnonymous {
    final user = _auth.currentUser;
    if (user == null) return false;
    // Supabase 匿名使用者沒有 email。
    return user.email == null || user.email!.isEmpty;
  }

  /// 是否已用 email 登入(可發起/加入招募)。
  bool get isAuthenticated {
    final user = _auth.currentUser;
    return user != null && user.email != null && user.email!.isNotEmpty;
  }

  String? get email => _auth.currentUser?.email;

  /// 註冊。若目前是匿名身分則升級,保留既有資料。
  Future<AuthResult> signUp({
    required String email,
    required String password,
  }) async {
    try {
      if (isAnonymous) {
        // 匿名升級:綁定 email 與密碼,user id 不變。
        await _auth.signOut();
      }
      final response = await _auth.signUp(email: email, password: password);
      return AuthResult.success(
        requiresEmailConfirmation: response.session == null,
      );
    } on AuthException catch (e) {
      return AuthResult.failure(_translate(e));
    } catch (e) {
      return const AuthResult.failure('註冊失敗,請稍後再試。');
    }
  }

  /// 登入。
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithPassword(email: email, password: password);
      return const AuthResult.success();
    } on AuthException catch (e) {
      return AuthResult.failure(_translate(e));
    } catch (e) {
      return const AuthResult.failure('登入失敗,請稍後再試。');
    }
  }

  /// 寄送重設密碼信。
  Future<AuthResult> sendPasswordReset(String email) async {
    try {
      await _auth.resetPasswordForEmail(email);
      return const AuthResult.success();
    } on AuthException catch (e) {
      return AuthResult.failure(_translate(e));
    } catch (e) {
      return const AuthResult.failure('無法寄送重設信,請稍後再試。');
    }
  }

  /// 登出後回到匿名身分,讓唯讀功能仍可使用。
  Future<void> signOut() async {
    await _auth.signOut();
    await _auth.signInAnonymously();
  }

  /// Deletes the current account through a server-side Edge Function.
  /// The privileged Auth deletion operation must never be placed in the app.
  Future<AuthResult> deleteAccount() async {
    if (!isAuthenticated) {
      return const AuthResult.failure('請先登入帳號。');
    }

    try {
      await SupabaseConfig.client.functions.invoke('delete-account');
      await _auth.signOut();
      await _auth.signInAnonymously();
      return const AuthResult.success();
    } on FunctionException catch (e) {
      return AuthResult.failure(e.reasonPhrase ?? '註銷帳號失敗，請稍後再試。');
    } catch (_) {
      return const AuthResult.failure('註銷帳號失敗，請稍後再試。');
    }
  }

  /// 把 Supabase 的英文錯誤轉成可讀訊息。
  String _translate(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return 'Email 或密碼不正確。';
    }
    if (msg.contains('already registered') || msg.contains('already been registered')) {
      return '這個 Email 已經註冊過了,請直接登入。';
    }
    if (msg.contains('password should be at least')) {
      return '密碼長度不足,至少需要 6 個字元。';
    }
    if (msg.contains('unable to validate email') || msg.contains('invalid email')) {
      return 'Email 格式不正確。';
    }
    if (msg.contains('email not confirmed')) {
      return '請先到信箱點擊驗證連結。';
    }
    if (msg.contains('over_email_send_rate_limit') || msg.contains('rate limit')) {
      return '操作過於頻繁,請稍後再試。';
    }
    return e.message;
  }
}
