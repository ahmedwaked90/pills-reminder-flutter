import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the Sanctum bearer token in the platform keystore / keychain.
class SecureTokenStorage {
  static const _key = 'pills_reminder.sanctum_token';
  final FlutterSecureStorage _storage;

  SecureTokenStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );

  Future<String?> read() => _storage.read(key: _key);

  Future<void> write(String token) => _storage.write(key: _key, value: token);

  Future<void> clear() => _storage.delete(key: _key);
}
