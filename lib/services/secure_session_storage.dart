import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps Supabase's access and refresh tokens in the platform encrypted store
/// (Android Keystore / iOS Keychain) instead of ordinary app preferences.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage();

  static const _key = 'supabase_auth_session';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async =>
      (await accessToken())?.isNotEmpty ?? false;

  @override
  Future<String?> accessToken() => _storage.read(key: _key);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _key);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _key, value: persistSessionString);
}
