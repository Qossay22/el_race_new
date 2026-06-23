import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Securely stores login credentials for silent re-login.
///
/// Used exclusively by the chat module to obtain a fresh
/// `firebase_custom_token` when the stored one has expired.
/// Credentials are encrypted via Keychain (iOS) / EncryptedSharedPrefs (Android).
class ChatCredentialStorage {
  static ChatCredentialStorage? _instance;
  static ChatCredentialStorage get instance =>
      _instance ??= ChatCredentialStorage._();

  ChatCredentialStorage._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _keyEmail = 'chat_cred_email';
  static const _keyPassword = 'chat_cred_password';
  static const _keyDeviceId = 'chat_cred_device_id';

  /// Save credentials after a successful login.
  Future<void> save({
    required String email,
    required String password,
    required String deviceId,
  }) async {
    try {
      await Future.wait([
        _storage.write(key: _keyEmail, value: email),
        _storage.write(key: _keyPassword, value: password),
        _storage.write(key: _keyDeviceId, value: deviceId),
      ]);
      print('✅ ChatCredentialStorage: Credentials saved securely');
    } catch (e) {
      print('⚠️ ChatCredentialStorage: Error saving credentials: $e');
    }
  }

  /// Load stored credentials. Returns null if any field is missing.
  Future<StoredCredentials?> load() async {
    try {
      final results = await Future.wait([
        _storage.read(key: _keyEmail),
        _storage.read(key: _keyPassword),
        _storage.read(key: _keyDeviceId),
      ]);

      final email = results[0];
      final password = results[1];
      final deviceId = results[2];

      if (email == null || password == null) {
        return null;
      }

      return StoredCredentials(
        email: email,
        password: password,
        deviceId: deviceId ?? '',
      );
    } catch (e) {
      print('⚠️ ChatCredentialStorage: Error loading credentials: $e');
      return null;
    }
  }

  /// Check if credentials are stored.
  Future<bool> hasCredentials() async {
    try {
      final email = await _storage.read(key: _keyEmail);
      return email != null && email.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Clear stored credentials (call on logout).
  Future<void> clear() async {
    try {
      await Future.wait([
        _storage.delete(key: _keyEmail),
        _storage.delete(key: _keyPassword),
        _storage.delete(key: _keyDeviceId),
      ]);
      print('✅ ChatCredentialStorage: Credentials cleared');
    } catch (e) {
      print('⚠️ ChatCredentialStorage: Error clearing credentials: $e');
    }
  }
}

class StoredCredentials {
  final String email;
  final String password;
  final String deviceId;

  const StoredCredentials({
    required this.email,
    required this.password,
    required this.deviceId,
  });
}
