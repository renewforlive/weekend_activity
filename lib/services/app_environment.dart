enum AppEnvironment { development, production }

/// Build-time environment selection. The development build deliberately has no
/// production fallback, so it cannot accidentally write test data to prod.
class AppEnvironmentConfig {
  AppEnvironmentConfig._();

  static const String _raw = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'prod',
  );

  static AppEnvironment get current =>
      _raw == 'dev' ? AppEnvironment.development : AppEnvironment.production;

  static bool get isDevelopment => current == AppEnvironment.development;

  static String get appName => isDevelopment ? '周末遊 測試版' : '周末遊';
}
