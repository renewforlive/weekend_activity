import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Stores only the biometric-lock preference. Supabase persists the session
/// tokens itself; this service never stores a password or copies auth tokens.
class BiometricLockService {
  BiometricLockService._();

  static final BiometricLockService instance = BiometricLockService._();
  static const _enabledKey = 'biometric_lock_enabled';
  static const _emailKey = 'remembered_email';
  static const _passwordKey = 'biometric_login_password';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> get isEnabled async =>
      (await _storage.read(key: _enabledKey)) == 'true';

  Future<bool> canAuthenticate() async {
    return await _localAuth.canCheckBiometrics &&
        await _localAuth.isDeviceSupported();
  }

  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await _storage.write(key: _enabledKey, value: 'true');
    } else {
      await _storage.delete(key: _enabledKey);
      await _storage.delete(key: _passwordKey);
    }
  }

  Future<String?> rememberedEmail() => _storage.read(key: _emailKey);

  Future<void> setRememberedEmail(String? email) async {
    if (email == null || email.isEmpty) {
      await _storage.delete(key: _emailKey);
    } else {
      await _storage.write(key: _emailKey, value: email);
    }
  }

  Future<bool> get hasSavedCredentials async {
    final email = await rememberedEmail();
    final password = await _storage.read(key: _passwordKey);
    return email != null &&
        email.isNotEmpty &&
        password != null &&
        password.isNotEmpty;
  }

  Future<void> saveCredentials({
    required String email,
    required String password,
  }) async {
    await setRememberedEmail(email);
    await _storage.write(key: _passwordKey, value: password);
    await setEnabled(true);
  }

  Future<void> clearCredentials() async {
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _passwordKey);
    await _storage.delete(key: _enabledKey);
  }

  Future<bool> authenticate() async {
    if (!await canAuthenticate()) return false;
    return _localAuth.authenticate(
      localizedReason: '請使用生物辨識解鎖您的帳號',
      options: const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
      ),
    );
  }

  Future<({String email, String password})?>
  authenticateAndReadCredentials() async {
    if (!await authenticate()) return null;
    final email = await rememberedEmail();
    final password = await _storage.read(key: _passwordKey);
    if (email == null ||
        email.isEmpty ||
        password == null ||
        password.isEmpty) {
      return null;
    }
    return (email: email, password: password);
  }
}
