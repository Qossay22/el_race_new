import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure persistent storage for chat session data.
///
/// Uses flutter_secure_storage to cache the chat session state
/// so the app doesn't need to re-authenticate with Firestore
/// on every app restart.
class ChatSessionStorage {
  static ChatSessionStorage? _instance;
  static ChatSessionStorage get instance =>
      _instance ??= ChatSessionStorage._();

  ChatSessionStorage._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Storage keys
  static const _keyFirebaseUid = 'chat_firebase_uid';
  static const _keyRoleChatId = 'chat_role_chat_id';
  static const _keySessionData = 'chat_session_data';
  static const _keySetupTimestamp = 'chat_setup_timestamp';
  static const _keyIsSetupComplete = 'chat_setup_complete';

  /// Save successful chat setup result to secure storage.
  Future<void> saveSession({
    required String firebaseUid,
    required String roleChatId,
    required Map<String, dynamic> sessionData,
  }) async {
    try {
      await Future.wait([
        _storage.write(key: _keyFirebaseUid, value: firebaseUid),
        _storage.write(key: _keyRoleChatId, value: roleChatId),
        _storage.write(
            key: _keySessionData, value: jsonEncode(sessionData)),
        _storage.write(
            key: _keySetupTimestamp,
            value: DateTime.now().toIso8601String()),
        _storage.write(key: _keyIsSetupComplete, value: 'true'),
      ]);
      print('✅ ChatSessionStorage: Session saved securely');
    } catch (e) {
      print('❌ ChatSessionStorage: Error saving session: $e');
    }
  }

  /// Load cached chat session from secure storage.
  /// Returns null if no cached session exists.
  Future<CachedChatSession?> loadSession() async {
    try {
      final isComplete = await _storage.read(key: _keyIsSetupComplete);
      if (isComplete != 'true') {
        print('ℹ️ ChatSessionStorage: No cached session found');
        return null;
      }

      final results = await Future.wait([
        _storage.read(key: _keyFirebaseUid),
        _storage.read(key: _keyRoleChatId),
        _storage.read(key: _keySessionData),
        _storage.read(key: _keySetupTimestamp),
      ]);

      final firebaseUid = results[0];
      final roleChatId = results[1];
      final sessionDataJson = results[2];
      final timestampStr = results[3];

      if (firebaseUid == null || roleChatId == null || sessionDataJson == null) {
        print('⚠️ ChatSessionStorage: Incomplete cached session');
        return null;
      }

      final sessionData =
          jsonDecode(sessionDataJson) as Map<String, dynamic>;
      final timestamp = timestampStr != null
          ? DateTime.tryParse(timestampStr)
          : null;

      print('✅ ChatSessionStorage: Loaded cached session');
      print('   - Firebase UID: $firebaseUid');
      print('   - Role Chat ID: $roleChatId');
      print('   - Cached at: $timestamp');

      return CachedChatSession(
        firebaseUid: firebaseUid,
        roleChatId: roleChatId,
        sessionData: sessionData,
        timestamp: timestamp,
      );
    } catch (e) {
      print('❌ ChatSessionStorage: Error loading session: $e');
      return null;
    }
  }

  /// Check if a cached session exists.
  Future<bool> hasCachedSession() async {
    try {
      final isComplete = await _storage.read(key: _keyIsSetupComplete);
      return isComplete == 'true';
    } catch (e) {
      return false;
    }
  }

  /// Clear cached session (call on logout).
  Future<void> clearSession() async {
    try {
      await Future.wait([
        _storage.delete(key: _keyFirebaseUid),
        _storage.delete(key: _keyRoleChatId),
        _storage.delete(key: _keySessionData),
        _storage.delete(key: _keySetupTimestamp),
        _storage.delete(key: _keyIsSetupComplete),
      ]);
      print('✅ ChatSessionStorage: Session cleared');
    } catch (e) {
      print('❌ ChatSessionStorage: Error clearing session: $e');
    }
  }
}

/// Represents a cached chat session loaded from secure storage.
class CachedChatSession {
  final String firebaseUid;
  final String roleChatId;
  final Map<String, dynamic> sessionData;
  final DateTime? timestamp;

  CachedChatSession({
    required this.firebaseUid,
    required this.roleChatId,
    required this.sessionData,
    this.timestamp,
  });

  /// Check if the cached session is still reasonably fresh (within 30 days).
  bool get isFresh {
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp!).inDays < 30;
  }
}
