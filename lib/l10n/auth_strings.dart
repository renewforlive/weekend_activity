import 'app_strings.dart';

/// 認證相關文案(登入、註冊、忘記密碼)。
///
/// 獨立於 AppStrings,方便單獨維護;語言切換沿用 AppStrings.lang。
class AuthStrings {
  AuthStrings._();

  static String _pick(String zh, String en) =>
      AppStrings.lang == AppLang.zhTW ? zh : en;

  // 頁面標題
  static String get signInTitle => _pick('登入', 'Sign in');
  static String get signUpTitle => _pick('註冊', 'Sign up');
  static String get forgotTitle => _pick('忘記密碼', 'Reset password');

  // 欄位
  static String get emailLabel => _pick('Email', 'Email');
  static String get passwordLabel => _pick('密碼', 'Password');
  static String get confirmPasswordLabel => _pick('確認密碼', 'Confirm password');

  // 按鈕
  static String get signInAction => _pick('登入', 'Sign in');
  static String get signUpAction => _pick('建立帳號', 'Create account');
  static String get sendResetAction => _pick('寄送重設信', 'Send reset link');
  static String get signOutAction => _pick('登出', 'Sign out');
  static String get securitySection => _pick('安全性', 'Security');
  static String get biometricLock => _pick('生物辨識解鎖', 'Biometric unlock');
  static String get biometricLockHint => _pick(
    '開啟 App 或回到前景時需先完成臉部／指紋辨識。',
    'Require Face ID, fingerprint, or other biometrics when opening the app.',
  );
  static String get biometricNotAvailable => _pick(
    '此裝置尚未設定可用的生物辨識。',
    'No biometric authentication is available on this device.',
  );
  static String get rememberAccount => _pick('記住帳號', 'Remember account');
  static String get biometricSignIn =>
      _pick('使用臉部／生物辨識登入', 'Sign in with biometrics');
  static String get biometricUnavailable => _pick(
    '此裝置無法使用生物辨識登入，請使用密碼登入。',
    'Biometric sign-in is unavailable. Please use your password.',
  );
  static String get emailConfirmationSent => _pick(
    '驗證信已寄出，請完成 Email 驗證後再登入。',
    'Confirmation email sent. Verify your email before signing in.',
  );
  static String get deleteAccountAction => _pick('註銷帳號', 'Delete account');
  static String get deleteAccountConfirm => _pick(
    '註銷後將永久刪除帳號、個人資料、頭像、照片、行程與你建立的招募，且無法復原。確定要繼續嗎？',
    'This permanently deletes your account, profile, avatar, photos, schedules, and groups you created. This cannot be undone.',
  );
  static String get deleteAccountSuccess =>
      _pick('帳號已註銷。', 'Your account has been deleted.');
  static String get deleteAccountFailed => _pick(
    '註銷帳號失敗，請稍後再試。',
    'Could not delete your account. Please try again.',
  );

  // 導引文字
  static String get noAccountYet => _pick('還沒有帳號?', "Don't have an account?");
  static String get haveAccount => _pick('已經有帳號了?', 'Already have an account?');
  static String get forgotPasswordLink => _pick('忘記密碼?', 'Forgot password?');
  static String get backToSignIn => _pick('回到登入', 'Back to sign in');

  // 說明
  static String get signInHint =>
      _pick('登入後才能發起或加入招募', 'Sign in to host or join a group');
  static String get signUpHint =>
      _pick('目前排好的行程與照片會一起保留', 'Your saved plans and photos will be kept');
  static String get forgotHint => _pick(
    '輸入註冊時使用的 Email,我們會寄送重設密碼的連結',
    "Enter your email and we'll send a reset link",
  );

  // 驗證訊息
  static String get emailRequired => _pick('請輸入 Email', 'Email is required');
  static String get emailInvalid =>
      _pick('Email 格式不正確', 'Invalid email format');
  static String get passwordRequired => _pick('請輸入密碼', 'Password is required');
  static String get passwordTooShort =>
      _pick('密碼至少需要 6 個字元', 'Password must be at least 6 characters');
  static String get passwordMismatch =>
      _pick('兩次輸入的密碼不一致', 'Passwords do not match');

  // 結果訊息
  static String get signUpSuccess => _pick('註冊成功', 'Signed up successfully');
  static String get resetSent =>
      _pick('重設密碼的信件已寄出,請查看信箱', 'Reset link sent, please check your inbox');

  // 需要登入的提示
  static String get needSignInForRecruitment =>
      _pick('發起或加入招募需要先登入', 'Sign in to host or join a group');
  static String get signInNow => _pick('前往登入', 'Sign in');
  static String get maybeLater => _pick('稍後再說', 'Maybe later');

  // 個人頁的帳號區塊
  static String get accountSection => _pick('帳號', 'Account');
  static String get guestMode => _pick('訪客模式', 'Guest');
  static String get guestHint =>
      _pick('登入後可發起與加入招募', 'Sign in to host or join groups');
  static String get signOutConfirm => _pick(
    '登出後將回到訪客模式,已排的行程會保留在這個裝置上。',
    'You will return to guest mode. Saved plans stay on this device.',
  );
}
