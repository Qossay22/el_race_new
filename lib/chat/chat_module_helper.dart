import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/models.dart';
import 'services/services.dart';
import 'services/chat_credential_storage.dart';
import 'services/chat_session_storage.dart';

/// Chat module initialization helper.
/// 
/// Use this class to initialize the chat module after backend login
/// or to restore chat session on app restart.
class ChatModuleHelper {
  static final ChatModuleHelper _instance = ChatModuleHelper._();
  static ChatModuleHelper get instance => _instance;
  
  ChatModuleHelper._();

  bool _isInitialized = false;
  ChatSetupResult? _lastResult;
  ChatUserSession? _currentSession;

  /// Notifies listeners when chat becomes enabled/disabled.
  /// BottomNavBar listens to this to start the unread badge subscription.
  final ValueNotifier<bool> chatEnabledNotifier = ValueNotifier<bool>(false);

  /// Check if chat module is initialized
  bool get isInitialized => _isInitialized;
  
  /// Check if chat is enabled and ready to use
  bool get isChatEnabled => _lastResult?.chatEnabled ?? false;
  
  /// Get current role chat ID
  String? get roleChatId => _lastResult?.roleChatId;
  
  /// Get current Firebase UID
  String? get currentUid => _lastResult?.firebaseUid;
  
  /// Get current session
  ChatUserSession? get currentSession => _currentSession;

  /// Initialize chat from login response.
  /// 
  /// Call this immediately after successful backend login.
  /// 
  /// ```dart
  /// // In your login handler:
  /// if (loginResponse.result?.success == true) {
  ///   await ChatModuleHelper.instance.initializeFromLoginResponse(
  ///     loginResponse.toJson(),
  ///   );
  /// }
  /// ```
  Future<ChatSetupResult> initializeFromLoginResponse(
    Map<String, dynamic> loginResponseJson,
  ) async {
    try {
      print('🔷 ChatModuleHelper: Initializing from login response...');
      
      final session = ChatUserSession.fromLoginResponse(loginResponseJson);
      _currentSession = session;
      
      // Log session info (without sensitive data)
      print('🔷 ChatModuleHelper: Session created:');
      print('   - Firebase UID: ${session.firebaseUid}');
      print('   - Odoo User ID: ${session.odooUserId}');
      print('   - Employee ID: ${session.employeeId}');
      print('   - Role ID: ${session.roleId}');
      print('   - Branch ID: ${session.branchId}');
      print('   - Company ID: ${session.companyId}');
      print('   - Chat Available: ${session.isChatAvailable}');
      print('   - Has Firebase Token: ${session.firebaseCustomToken != null}');
      
      if (!session.isChatAvailable) {
        print('⚠️ ChatModuleHelper: Chat not available - no Firebase custom token');
        _lastResult = ChatSetupResult.disabled(
          'Firebase custom token not provided by backend. '
          'Backend needs to add firebase_custom_token field to login response.',
        );
        return _lastResult!;
      }

      // Setup Firebase chat
      _lastResult = await FirebaseChatAuthService.instance
          .setupAfterBackendLogin(session);

      if (_lastResult!.success && _lastResult!.chatEnabled) {
        _isInitialized = true;
        chatEnabledNotifier.value = true;
        
        // Initialize lifecycle observer for presence
        ChatLifecycleObserver.instance.initialize();
        
        // Request notification permissions (non-blocking)
        FirebaseChatAuthService.instance.requestNotificationPermissions();
        
        print('✅ ChatModuleHelper: Chat initialized successfully');
        print('   - Role Chat ID: ${_lastResult!.roleChatId}');
      } else {
        print('⚠️ ChatModuleHelper: Chat setup completed but not enabled');
        print('   - Error: ${_lastResult!.error}');
      }

      return _lastResult!;
    } catch (e, stack) {
      print('❌ ChatModuleHelper: Error initializing chat: $e');
      print(stack);
      _lastResult = ChatSetupResult.failed(e.toString());
      return _lastResult!;
    }
  }

  /// Restore chat session from stored login data.
  /// 
  /// Call this on app startup if user is already logged in.
  /// 
  /// ```dart
  /// // In main.dart or splash screen:
  /// if (SharedPref.isUserAuthenticated()) {
  ///   await ChatModuleHelper.instance.restoreFromStoredSession();
  /// }
  /// ```
  Future<ChatSetupResult?> restoreFromStoredSession() async {
    try {
      print('🔷 ChatModuleHelper: Attempting to restore from stored session...');
      
      // IMPORTANT: Wait for Firebase Auth to hydrate persisted session
      // On app restart, currentUser may be null until auth state resolves
      final authUser = await FirebaseChatAuthService.instance.waitForAuthReady();
      final isAlreadySignedIn = authUser != null;
      
      if (isAlreadySignedIn) {
        print('✅ ChatModuleHelper: Firebase Auth ready, user=${authUser.uid}');
        
        // If we have cached result and it's enabled, return it
        if (_isInitialized && _lastResult != null && _lastResult!.chatEnabled) {
          print('✅ ChatModuleHelper: Returning cached chat session');
          return _lastResult;
        }

        // Try to restore from secure storage cache (fast path - no Firestore writes)
        final cachedSession = await ChatSessionStorage.instance.loadSession();
        if (cachedSession != null && cachedSession.isFresh) {
          print('🔄 ChatModuleHelper: Restoring from secure storage cache...');
          
          final result = await FirebaseChatAuthService.instance
              .restoreFromCachedSession(cachedSession);

          if (result.success && result.chatEnabled) {
            _isInitialized = true;
            chatEnabledNotifier.value = true;
            _lastResult = result;
            
            // Restore session model from cached data
            _currentSession = ChatUserSession(
              backendJwt: '',
              odooUserId: cachedSession.sessionData['odoo_user_id'] ?? 0,
              employeeId: cachedSession.sessionData['employee_id'],
              employeeFileNumber:
                  cachedSession.sessionData['employee_file_number'],
              name: cachedSession.sessionData['name'] ?? '',
              email: cachedSession.sessionData['email'],
              roleId: cachedSession.sessionData['role_id'] ?? 0,
              roleName: cachedSession.sessionData['role_name'],
              branchId: cachedSession.sessionData['branch_id'],
              companyId: cachedSession.sessionData['company_id'] ?? 0,
              firebaseUid: cachedSession.firebaseUid,
              avatarUrl: cachedSession.sessionData['avatar_url'],
            );
            
            // Initialize lifecycle observer for presence
            ChatLifecycleObserver.instance.initialize();
            
            print('✅ ChatModuleHelper: Restored from secure cache successfully');
            print('   - Role Chat ID: ${result.roleChatId}');
            return result;
          } else {
            print('⚠️ ChatModuleHelper: Cached restore failed, trying full setup...');
          }
        }
      } else {
        print('⚠️ ChatModuleHelper: Firebase Auth has no persisted user');
      }
      
      // Fall back to full setup from SharedPreferences login response
      final prefs = await SharedPreferences.getInstance();
      final loginJson = prefs.getString('loginResponse');
      
      if (loginJson == null || loginJson.isEmpty) {
        print('ℹ️ ChatModuleHelper: No stored login response found');
        return null;
      }

      print('✅ ChatModuleHelper: Found stored login response (${loginJson.length} chars)');
      final decoded = jsonDecode(loginJson) as Map<String, dynamic>;
      
      // Debug: Check if firebase fields exist in stored data
      final data = decoded['result']?['data'] ?? decoded['data'];
      print('🔍 Stored data contains:');
      print('   - firebase_uid: ${data?['firebase_uid'] ?? "NOT FOUND"}'  );
      print('   - firebase_custom_token: ${data?['firebase_custom_token'] != null ? "EXISTS (${data['firebase_custom_token'].toString().length} chars)" : "NOT FOUND ❌"}');
      print('   - odoo_user_id: ${data?['odoo_user_id'] ?? "NOT FOUND"}');
      print('   - employee_id: ${data?['employee_id'] ?? "NOT FOUND"}');
      
      // If already initialized and signed in, just try to complete setup
      if (_isInitialized && isAlreadySignedIn) {
        print('🔷 ChatModuleHelper: Already initialized and signed in, verifying setup...');
        if (_lastResult != null && _lastResult!.chatEnabled) {
          print('✅ ChatModuleHelper: Setup already complete');
          return _lastResult;
        }
      }
      
      // ── Step A: Try to get a FRESH token from backend before using the stale one ──
      final backendToken = decoded['result']?['token']?.toString();
      if (backendToken != null && backendToken.isNotEmpty) {
        print('🔄 ChatModuleHelper: Requesting fresh Firebase token FIRST...');
        final freshToken = await FirebaseChatAuthService.instance
            .refreshFirebaseCustomToken(backendToken);

        if (freshToken != null) {
          // Inject fresh token into the decoded response
          if (decoded['result']?['data'] != null) {
            (decoded['result']['data']
                as Map<String, dynamic>)['firebase_custom_token'] = freshToken;
          }
          // Persist updated token
          try {
            await prefs.setString('loginResponse', jsonEncode(decoded));
            print('✅ ChatModuleHelper: Updated stored login response with fresh token');
          } catch (_) {}
        }
      }

      // ── Step B: Initialize with (hopefully fresh) token ──
      final result = await initializeFromLoginResponse(decoded);

      // ── Step C: If still failed due to token issue, try one more time ──
      if (result.error != null && _isTokenError(result.error!)) {
        print('🔄 ChatModuleHelper: Token error detected, attempting backend refresh...');

        if (backendToken != null && backendToken.isNotEmpty) {
          final freshToken = await FirebaseChatAuthService.instance
              .refreshFirebaseCustomToken(backendToken);

          if (freshToken != null) {
            if (decoded['result']?['data'] != null) {
              (decoded['result']['data']
                  as Map<String, dynamic>)['firebase_custom_token'] = freshToken;
            }
            try {
              await prefs.setString('loginResponse', jsonEncode(decoded));
            } catch (_) {}

            print('🔄 ChatModuleHelper: Retrying with fresh Firebase token...');
            final retryResult = await initializeFromLoginResponse(decoded);
            if (retryResult.success && retryResult.chatEnabled) {
              print('✅ ChatModuleHelper: Chat restored with refreshed token!');
              return retryResult;
            }
            print('⚠️ ChatModuleHelper: Retry also failed: ${retryResult.error}');
          }
        }

        print('⚠️ ChatModuleHelper: Token expired and could not refresh.');
        return ChatSetupResult.failed(
          'Chat session expired. Please logout and login again to restore chat.',
        );
      }

      return result;
    } catch (e) {
      print('❌ ChatModuleHelper: Error restoring session: $e');
      
      // Provide user-friendly error message
      if (_isTokenError(e.toString()) || e.toString().contains('auth/')) {
        return ChatSetupResult.failed(
          'Chat session expired. Please logout and login again.',
        );
      }

      return ChatSetupResult.failed('Unable to restore chat: $e');
    }
  }

  /// Check if an error message relates to an invalid / expired custom token.
  static bool _isTokenError(String error) {
    final lower = error.toLowerCase();
    return lower.contains('custom-token') ||
        lower.contains('custom token') ||
        lower.contains('invalid-custom-token') ||
        lower.contains('token format') ||
        lower.contains('token expired') ||
        lower.contains('token-expired');
  }

  /// Cleanup on logout.
  /// 
  /// Call this when user logs out.
  /// 
  /// ```dart
  /// // In your logout handler:
  /// await ChatModuleHelper.instance.cleanup();
  /// ```
  Future<void> cleanup() async {
    try {
      print('🔷 ChatModuleHelper: Cleaning up...');
      
      // Dispose lifecycle observer
      ChatLifecycleObserver.instance.dispose();
      
      // Sign out from Firebase and cleanup (also clears secure cache)
      await FirebaseChatAuthService.instance.signOut();

      // Clear stored credentials
      await ChatCredentialStorage.instance.clear();
      
      _isInitialized = false;
      chatEnabledNotifier.value = false;
      _lastResult = null;
      _currentSession = null;
      
      print('✅ ChatModuleHelper: Cleanup complete');
    } catch (e) {
      print('❌ ChatModuleHelper: Error during cleanup: $e');
    }
  }

  /// Check if chat should be shown based on current state.
  bool shouldShowChat() {
    return _isInitialized && isChatEnabled;
  }

  /// Get status message for UI display.
  String getStatusMessage() {
    if (!_isInitialized) {
      return 'Chat not initialized';
    }
    if (!isChatEnabled) {
      final error = _lastResult?.error ?? 'Chat not available';

      // Provide user-friendly messages
      if (_isTokenError(error)) {
        return 'Chat session expired. Please logout and login again.';
      }
      if (error.contains('expired') || error.contains('login again')) {
        return 'Chat session expired. Please logout and login again.';
      }
      if (error.contains('custom token not provided')) {
        return 'Chat not configured on server. Contact IT support.';
      }

      return error;
    }
    return 'Chat ready';
  }
}
