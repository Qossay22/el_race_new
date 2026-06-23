import 'dart:async';
import 'dart:convert';
import 'dart:math' show min, max;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/urll_utils.dart';
import '../models/models.dart';
import '../repositories/chat_repository.dart';
import '../repositories/user_repository.dart';
import 'chat_credential_storage.dart';
import 'chat_session_storage.dart';
import 'firebase_token_api_service.dart';
import 'presence_service.dart';
import 'chat_notification_service.dart';

/// Main service for Firebase chat authentication and setup.
///
/// This service handles the complete setup flow after backend login:
/// 1. Sign in to Firebase using custom token
/// 2. Create/update user profile in Firestore
/// 3. Ensure role chat membership
/// 4. Subscribe to FCM topics
/// 5. Setup presence
/// 6. Store FCM token
class FirebaseChatAuthService {
  static FirebaseChatAuthService? _instance;
  static FirebaseChatAuthService get instance =>
      _instance ??= FirebaseChatAuthService._();

  FirebaseChatAuthService._() {
    // Enable Firebase Auth persistence (automatic session storage)
    _auth.setPersistence(Persistence.LOCAL).catchError((error) {
      print('⚠️ FirebaseChatAuth: Could not set persistence: $error');
    });
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  ChatUserSession? _currentSession;
  String? _currentRoleChatId;
  bool _isSetupComplete = false;
  StreamSubscription<User?>? _idTokenSub;
  bool _isRefreshing = false;

  // Configuration
  static const bool groupByBranch = true; // Match with ChatRepository

  /// Get current user session
  ChatUserSession? get currentSession => _currentSession;

  /// Check if chat setup is complete
  bool get isSetupComplete => _isSetupComplete;

  /// Get current Firebase UID
  String? get currentUid => _auth.currentUser?.uid;

  /// Get current role chat ID
  String? get currentRoleChatId => _currentRoleChatId;

  /// Wait for Firebase Auth to fully hydrate persisted session.
  ///
  /// On app restart, Firebase Auth may not have the persisted user
  /// ready immediately. This waits for the first auth state emission.
  Future<User?> waitForAuthReady() async {
    try {
      print('⏳ FirebaseChatAuth: Waiting for Firebase Auth to hydrate...');
      final user = await _auth.authStateChanges().first.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print(
              '⚠️ FirebaseChatAuth: Auth hydration timeout, currentUser=${_auth.currentUser?.uid}');
          return _auth.currentUser;
        },
      );
      print('✅ FirebaseChatAuth: Auth ready, user=${user?.uid ?? "null"}');
      return user;
    } catch (e) {
      print('⚠️ FirebaseChatAuth: Error waiting for auth: $e');
      return _auth.currentUser;
    }
  }

  /// Refresh the Firebase custom token from the backend.
  ///
  /// Strategy:
  /// 1. Try the dedicated refresh endpoint (`/api/firebase/refresh_token`).
  /// 2. If that fails, try session cookies with `login/new`.
  /// 3. If all else fails, do a **silent re-login** with stored credentials.
  Future<String?> refreshFirebaseCustomToken(String backendToken) async {
    try {
      print(
          '🔄 FirebaseChatAuth: Requesting fresh Firebase token from backend...');

      // ── Attempt 1: Dedicated refresh endpoint via FirebaseTokenApiService ──
      final refreshResponse = await FirebaseTokenApiService.instance
          .refreshToken(backendToken: backendToken);

      if (refreshResponse != null && refreshResponse.isSuccess) {
        final token = refreshResponse.firebaseCustomToken;
        if (token != null) {
          print('✅ FirebaseChatAuth: Got token from refresh endpoint');
          // Persist the fresh token into loginResponse
          await _persistFreshToken(token);
          return token;
        }
      }

      // ── Attempt 2: Session cookies with login endpoint ──
      try {
        final appDocDir = await getApplicationDocumentsDirectory();
        final cookieJar = PersistCookieJar(
          ignoreExpires: true,
          storage: FileStorage('${appDocDir.path}/.cookies/'),
        );
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ))
          ..interceptors.add(CookieManager(cookieJar));

        final sessionUrl = '${UrlUtil.baseUrl}${UrlUtil.login}';
        print(
            '🔄 FirebaseChatAuth: Trying session-based refresh via $sessionUrl');

        final response = await dio.post(
          sessionUrl,
          data: jsonEncode({"jsonrpc": "2.0", "params": {}}),
          options: Options(headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $backendToken',
          }),
        );

        final token = _extractFirebaseToken(response.data);
        if (token != null) return token;
      } on DioException catch (e) {
        print(
            '⚠️ FirebaseChatAuth: Session-based refresh failed: ${e.response?.statusCode}');
      }

      // ── Attempt 3: Silent re-login with stored credentials ──
      try {
        final creds = await ChatCredentialStorage.instance.load();
        if (creds != null) {
          print('🔄 FirebaseChatAuth: Attempting silent re-login...');

          String fcmToken = '';
          try {
            final prefs = await SharedPreferences.getInstance();
            fcmToken = prefs.getString('fcm_token') ?? '';
          } catch (_) {}

          final appDocDir = await getApplicationDocumentsDirectory();
          final cookieJar = PersistCookieJar(
            ignoreExpires: true,
            storage: FileStorage('${appDocDir.path}/.cookies/'),
          );
          final dio = Dio(BaseOptions(
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
          ))
            ..interceptors.add(CookieManager(cookieJar));

          final loginUrl = '${UrlUtil.baseUrl}${UrlUtil.login}';
          final response = await dio.post(
            loginUrl,
            data: jsonEncode({
              "jsonrpc": "2.0",
              "params": {
                "db": "odoo.elrace.com",
                "login": creds.email,
                "password": creds.password,
                "device_id": creds.deviceId,
                "fcm_token": fcmToken,
              }
            }),
            options: Options(headers: {
              'Content-Type': 'application/json',
            }),
          );

          print(
              '🔄 FirebaseChatAuth: Silent re-login response status: ${response.statusCode}');

          final data = response.data;
          if (data is Map<String, dynamic>) {
            final result = data['result'];
            if (result is Map<String, dynamic> && result['success'] == true) {
              print('✅ FirebaseChatAuth: Silent re-login succeeded!');

              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('loginResponse', jsonEncode(data));
                print('✅ FirebaseChatAuth: Updated stored loginResponse');
              } catch (_) {}

              final token = _extractFirebaseToken(data);
              if (token != null) return token;
            } else {
              final msg = result?['message'] ?? 'unknown';
              print('⚠️ FirebaseChatAuth: Silent re-login failed: $msg');
            }
          }
        } else {
          print(
              '⚠️ FirebaseChatAuth: No stored credentials for silent re-login');
        }
      } catch (e) {
        print('⚠️ FirebaseChatAuth: Silent re-login error: $e');
      }

      print('⚠️ FirebaseChatAuth: All refresh attempts failed');
      return null;
    } catch (e) {
      print('⚠️ FirebaseChatAuth: Could not refresh Firebase token: $e');
      return null;
    }
  }

  /// Persist a fresh Firebase token into the stored loginResponse.
  Future<void> _persistFreshToken(String freshToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('loginResponse');
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;

      if (decoded['result']?['data'] is Map<String, dynamic>) {
        (decoded['result']['data']
            as Map<String, dynamic>)['firebase_custom_token'] = freshToken;
      }
      if (decoded['result'] is Map<String, dynamic>) {
        (decoded['result'] as Map<String, dynamic>)['firebase_custom_token'] =
            freshToken;
      }

      await prefs.setString('loginResponse', jsonEncode(decoded));
      print('✅ FirebaseChatAuth: Persisted fresh Firebase token');
    } catch (e) {
      print('⚠️ FirebaseChatAuth: Could not persist token: $e');
    }
  }

  /// Extract firebase_custom_token from any response shape.
  String? _extractFirebaseToken(dynamic data) {
    try {
      Map<String, dynamic>? payload;
      if (data is Map<String, dynamic>) {
        // jsonrpc envelope: { result: { data: { firebase_custom_token } } }
        final result = data['result'];
        if (result is Map<String, dynamic>) {
          final inner = result['data'];
          if (inner is Map<String, dynamic>) {
            payload = inner;
          } else {
            payload = result;
          }
        } else {
          payload = data;
        }
      } else if (data is String) {
        final parsed = jsonDecode(data);
        if (parsed is Map<String, dynamic>) {
          return _extractFirebaseToken(parsed);
        }
      }

      if (payload == null) return null;

      final token = payload['firebase_custom_token']?.toString();
      if (token != null &&
          token.isNotEmpty &&
          token != 'false' &&
          token != 'null') {
        print(
            '✅ FirebaseChatAuth: Got fresh Firebase token (${token.length} chars)');
        return token;
      }
    } catch (e) {
      print('⚠️ FirebaseChatAuth: Error extracting token: $e');
    }
    return null;
  }

  /// Main setup method - call this after backend login success.
  ///
  /// [session] - ChatUserSession created from backend login response
  ///
  /// Returns ChatSetupResult indicating success/failure and chat availability.
  Future<ChatSetupResult> setupAfterBackendLogin(
      ChatUserSession session) async {
    _currentSession = session;
    _isSetupComplete = false;

    // Check if chat is available (has Firebase custom token)
    if (!session.isChatAvailable) {
      print(
          '⚠️ FirebaseChatAuth: Chat not available - no Firebase custom token');
      return ChatSetupResult.disabled(
          'Firebase custom token not provided by backend');
    }

    try {
      // Check if already signed in with correct UID
      final currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.uid == session.firebaseUid) {
        print('✅ FirebaseChatAuth: Already signed in as ${currentUser.uid}');
        print('⏭️ FirebaseChatAuth: Skipping sign-in, proceeding to setup...');
      } else {
        // Step 1: Sign in to Firebase with custom token
        print('🔐 FirebaseChatAuth: Signing in with custom token...');

        // Clean and fix token format issues
        String token = _cleanFirebaseToken(session.firebaseCustomToken!);

        // Debug: Log token info (first/last chars only for security)
        print('🔐 FirebaseChatAuth: Token length: ${token.length}');
        print(
            '🔐 FirebaseChatAuth: Token preview: ${token.substring(0, min(20, token.length))}...${token.substring(max(0, token.length - 20))}');

        // Validate token format (should be JWT: xxx.yyy.zzz)
        if (!token.contains('.') || token.split('.').length != 3) {
          print('❌ FirebaseChatAuth: Invalid token format - not a valid JWT');
          return ChatSetupResult.failed(
            'Invalid Firebase token format from backend. Please contact support.',
          );
        }

        final userCredential = await _auth.signInWithCustomToken(token);

        final firebaseUid = userCredential.user?.uid;
        if (firebaseUid == null) {
          return ChatSetupResult.failed(
              'Firebase sign-in succeeded but no UID returned');
        }

        // Verify UID matches expected (log warning if mismatch)
        if (firebaseUid != session.firebaseUid) {
          print(
              '⚠️ FirebaseChatAuth: UID mismatch! Expected: ${session.firebaseUid}, Got: $firebaseUid');
          print(
              '⚠️ FirebaseChatAuth: Using actual UID from Firebase: $firebaseUid');
        }

        print('✅ FirebaseChatAuth: Signed in as $firebaseUid');
      }

      final firebaseUid = _auth.currentUser!.uid;

      // Step 2: Create/update user profile in Firestore
      print('📝 FirebaseChatAuth: Upserting user profile...');
      await UserRepository.instance.upsertUser(session);

      // Step 3: Ensure role chat membership
      print('👥 FirebaseChatAuth: Ensuring role chat membership...');
      _currentRoleChatId =
          await ChatRepository.instance.ensureRoleChatMembership(
        uid: firebaseUid,
        roleId: session.roleId,
        branchId: session.branchId,
        companyId: session.companyId,
        roleChatId: session.roleChatId,
        title: session.roleName, // Use role name as chat title
      );

      // Step 4: Subscribe to FCM topic for role group
      print('📲 FirebaseChatAuth: Subscribing to FCM topics...');
      final topicName = session.getRoleTopicName(groupByBranch: groupByBranch);
      await UserRepository.instance.subscribeToRoleTopic(topicName);

      // Step 5: Setup presence
      print('🟢 FirebaseChatAuth: Setting up presence...');
      await PresenceService.instance.initialize(firebaseUid);

      // Step 6: Store FCM token
      print('🔔 FirebaseChatAuth: Storing FCM token...');
      await UserRepository.instance.storeFcmToken(firebaseUid);

      // Step 7: Initialize chat notifications
      print('🔔 FirebaseChatAuth: Setting up chat notifications...');
      await ChatNotificationService.instance.initialize();
      await ChatNotificationService.instance.startListening();
      _wireChatNotificationTap();

      _isSetupComplete = true;
      print('✅ FirebaseChatAuth: Setup complete!');

      // Start proactive token refresh listener
      _startAutoTokenRefresh();

      // Bulk-hydrate missing email/phone/job for all users (fire-and-forget)
      UserRepository.instance.hydrateAllUsersFromDirectory().then((count) {
        if (count > 0) {
          print('✅ FirebaseChatAuth: Bulk hydrated $count user profiles');
        }
      }).catchError((e) {
        print('⚠️ FirebaseChatAuth: Bulk hydration error (non-fatal): $e');
      });

      // Cache session securely for fast restore on next app open
      await ChatSessionStorage.instance.saveSession(
        firebaseUid: firebaseUid,
        roleChatId: _currentRoleChatId!,
        sessionData: {
          'firebase_uid': session.firebaseUid,
          'odoo_user_id': session.odooUserId,
          'employee_id': session.employeeId,
          'employee_file_number': session.employeeFileNumber,
          'name': session.name,
          'email': session.email,
          'role_id': session.roleId,
          'branch_id': session.branchId,
          'company_id': session.companyId,
          'role_name': session.roleName,
          'avatar_url': session.avatarUrl,
        },
      );

      return ChatSetupResult.success(
        firebaseUid: firebaseUid,
        roleChatId: _currentRoleChatId!,
      );
    } on FirebaseAuthException catch (e) {
      print(
          '❌ FirebaseChatAuth: Firebase Auth error: ${e.code} - ${e.message}');
      return ChatSetupResult.failed('Firebase auth failed: ${e.message}');
    } catch (e) {
      print('❌ FirebaseChatAuth: Setup error: $e');
      return ChatSetupResult.failed('Chat setup failed: $e');
    }
  }

  /// Start listening to Firebase ID-token changes.
  ///
  /// When Firebase detects the ID-token is about to expire it emits an event.
  /// We use that as a trigger to proactively fetch a new custom token from the
  /// backend and re-sign-in, so chat never loses connectivity.
  void _startAutoTokenRefresh() {
    _idTokenSub?.cancel();
    _idTokenSub = _auth.idTokenChanges().listen((user) async {
      if (user == null || _isRefreshing || !_isSetupComplete) return;

      // Firebase ID tokens are valid for 1 hour. We refresh proactively
      // when we receive a token-change event (Firebase SDK triggers this
      // ~5 min before expiry when the app is in the foreground).
      try {
        _isRefreshing = true;
        print(
            '🔄 FirebaseChatAuth: ID token changed – refreshing custom token...');

        final backendToken = _currentSession?.backendJwt ?? '';
        if (backendToken.isEmpty) {
          print('⚠️ FirebaseChatAuth: No backend JWT for auto-refresh');
          return;
        }

        final freshToken = await FirebaseTokenApiService.instance
            .fetchFreshFirebaseToken(backendToken: backendToken);

        if (freshToken != null) {
          await _auth.signInWithCustomToken(_cleanFirebaseToken(freshToken));
          await _persistFreshToken(freshToken);
          print('✅ FirebaseChatAuth: Auto-refreshed Firebase token');
        }
      } catch (e) {
        print('⚠️ FirebaseChatAuth: Auto-refresh error (non-fatal): $e');
      } finally {
        _isRefreshing = false;
      }
    });
  }

  /// Lightweight restore from cached session.
  ///
  /// Skips Firestore writes (upsert user, role membership) and only sets up
  /// presence + notifications. Call this when Firebase Auth is still valid
  /// and we have a cached session from a previous successful setup.
  Future<ChatSetupResult> restoreFromCachedSession(
      CachedChatSession cached) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('⚠️ FirebaseChatAuth: No Firebase user for cached restore');
        return ChatSetupResult.failed(
            'Firebase user not signed in for cached restore');
      }

      if (currentUser.uid != cached.firebaseUid) {
        print(
            '⚠️ FirebaseChatAuth: UID mismatch in cache. Current: ${currentUser.uid}, Cached: ${cached.firebaseUid}');
        // Clear stale cache
        await ChatSessionStorage.instance.clearSession();
        return ChatSetupResult.failed('Cached session UID mismatch');
      }

      final firebaseUid = currentUser.uid;
      _currentRoleChatId = cached.roleChatId;

      print(
          '🔄 FirebaseChatAuth: Restoring from cached session for $firebaseUid...');

      // Only do lightweight setup: presence + notifications
      // Skip Firestore writes (upsert user, role membership) since
      // those were already done in a previous successful setup

      try {
        print('🟢 FirebaseChatAuth: Setting up presence...');
        await PresenceService.instance.initialize(firebaseUid);
      } catch (e) {
        print('⚠️ FirebaseChatAuth: Presence setup failed (non-fatal): $e');
      }

      try {
        print('🔔 FirebaseChatAuth: Setting up chat notifications...');
        await ChatNotificationService.instance.initialize();
        await ChatNotificationService.instance.startListening();
        _wireChatNotificationTap();
      } catch (e) {
        print('⚠️ FirebaseChatAuth: Notification setup failed (non-fatal): $e');
      }

      _isSetupComplete = true;
      print('✅ FirebaseChatAuth: Restored from cache successfully!');

      return ChatSetupResult.success(
        firebaseUid: firebaseUid,
        roleChatId: _currentRoleChatId!,
      );
    } catch (e) {
      print('❌ FirebaseChatAuth: Cache restore error: $e');
      // Clear bad cache
      await ChatSessionStorage.instance.clearSession();
      return ChatSetupResult.failed('Cache restore failed: $e');
    }
  }

  /// Re-authenticate with existing session (e.g., on app resume if token expired).
  ///
  /// Returns true if already authenticated with valid token,
  /// or if reauthentication succeeded. Returns false if token expired
  /// and needs fresh token from backend.

  /// Notification taps are routed by FirebaseService. This callback is kept
  /// for chat-module integrations that still observe tap events directly.
  void _wireChatNotificationTap() {
    ChatNotificationService.instance.onNotificationTap =
        (chatId, chatTitle, chatType) {
      print('🔔 FirebaseChatAuth: Chat notification tapped → $chatId');
    };
  }

  Future<bool> reauthenticate() async {
    // Check if user is already signed in with correct UID
    if (_auth.currentUser != null && _currentSession != null) {
      if (_auth.currentUser!.uid == _currentSession!.firebaseUid) {
        print(
            '✅ FirebaseChatAuth: User already authenticated as ${_auth.currentUser!.uid}');
        return true;
      } else {
        print(
            '⚠️ FirebaseChatAuth: UID mismatch. Current: ${_auth.currentUser!.uid}, Expected: ${_currentSession!.firebaseUid}');
      }
    }

    // Try to reauthenticate with stored token
    if (_currentSession == null || !_currentSession!.isChatAvailable) {
      print(
          '⚠️ FirebaseChatAuth: No session or token available for reauthentication');
      return false;
    }

    try {
      print(
          '🔄 FirebaseChatAuth: Attempting reauthentication with stored token...');
      final cleanToken =
          _cleanFirebaseToken(_currentSession!.firebaseCustomToken!);
      await _auth.signInWithCustomToken(cleanToken);
      print('✅ FirebaseChatAuth: Reauthentication successful');
      return true;
    } on FirebaseAuthException catch (e) {
      print(
          '❌ FirebaseChatAuth: Reauthentication failed - ${e.code}: ${e.message}');

      // Token expired or invalid - need fresh token from backend
      if (e.code == 'invalid-custom-token' ||
          e.code == 'custom-token-expired') {
        print(
            '⚠️ FirebaseChatAuth: Token expired. Need fresh token from backend.');
      }

      return false;
    } catch (e) {
      print('❌ FirebaseChatAuth: Reauthentication error: $e');
      return false;
    }
  }

  /// Sign out from Firebase and cleanup.
  Future<void> signOut() async {
    try {
      // Remove FCM token
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await UserRepository.instance.removeFcmToken(uid);

        // Unsubscribe from role topic
        if (_currentSession != null) {
          final topicName =
              _currentSession!.getRoleTopicName(groupByBranch: groupByBranch);
          await UserRepository.instance.unsubscribeFromRoleTopic(topicName);
        }
      }

      // Dispose notification service
      await ChatNotificationService.instance.dispose();

      // Dispose presence service
      await PresenceService.instance.dispose();

      // Cancel auto-refresh listener
      await _idTokenSub?.cancel();
      _idTokenSub = null;

      // Dispose token API service
      FirebaseTokenApiService.instance.dispose();

      // Clear cached session from secure storage
      await ChatSessionStorage.instance.clearSession();

      // Sign out from Firebase
      await _auth.signOut();

      _currentSession = null;
      _currentRoleChatId = null;
      _isSetupComplete = false;
      _isRefreshing = false;

      print('✅ FirebaseChatAuth: Signed out successfully');
    } catch (e) {
      print('❌ FirebaseChatAuth: Sign out error: $e');
    }
  }

  /// Request notification permissions (call during app initialization or login).
  Future<bool> requestNotificationPermissions() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;

      print(
          '🔔 FirebaseChatAuth: Notification permission: ${settings.authorizationStatus}');
      return granted;
    } catch (e) {
      print('❌ FirebaseChatAuth: Error requesting notification permission: $e');
      return false;
    }
  }

  /// Listen to auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Check if user is signed in to Firebase
  bool get isSignedIn => _auth.currentUser != null;

  /// Clean Firebase custom token by stripping surrounding whitespace only.
  ///
  /// IMPORTANT: Do NOT modify the JWT content (header/payload). The signature
  /// is computed over the exact original bytes. Changing even whitespace inside
  /// the decoded JSON header invalidates the signature.
  String _cleanFirebaseToken(String rawToken) {
    try {
      print('🧹 Cleaning token...');

      // Only trim leading/trailing whitespace and newlines
      String token = rawToken.trim();

      print(
          '🔍 Original length: ${rawToken.length}, Cleaned length: ${token.length}');

      // Validate it has 3 JWT parts
      final parts = token.split('.');
      if (parts.length != 3) {
        print(
            '⚠️ Token does not have 3 parts (has ${parts.length}), returning as-is');
        return token;
      }

      // Debug: decode header for logging only (do NOT modify)
      try {
        String headerPart = parts[0];
        String padded = headerPart;
        while (padded.length % 4 != 0) {
          padded += '=';
        }
        final decoded = base64Url.decode(padded);
        final headerJson = utf8.decode(decoded);
        print('🔍 Token header: $headerJson');
      } catch (e) {
        print('⚠️ Could not decode header for logging: $e');
      }

      print('✅ Token ready: ${token.length} chars');
      print(
          '🔐 FirebaseChatAuth: Token preview: ${token.substring(0, 20)}...${token.substring(token.length - 20)}');

      return token;
    } catch (e) {
      print('❌ Error cleaning token: $e');
      return rawToken.trim();
    }
  }
}

// ============== Push Notification Trigger Notes ==============
//
// The client-side FCM token storage and topic subscription is implemented above.
// Actual push notification sending should be done via Cloud Functions.
//
// Example Cloud Function (Node.js) for sending DM notifications:
//
// ```javascript
// exports.onNewMessage = functions.firestore
//   .document('chats/{chatId}/messages/{messageId}')
//   .onCreate(async (snap, context) => {
//     const message = snap.data();
//     const chatId = context.params.chatId;
//
//     // Get chat document
//     const chatDoc = await admin.firestore().collection('chats').doc(chatId).get();
//     const chat = chatDoc.data();
//
//     if (chat.type === 'dm') {
//       // For DM: Send to other user's device tokens
//       const otherUid = chat.dm_pair.find(uid => uid !== message.sender_id);
//       const tokensSnapshot = await admin.firestore()
//         .collection('users').doc(otherUid).collection('fcm_tokens').get();
//
//       const tokens = tokensSnapshot.docs.map(doc => doc.id);
//       if (tokens.length === 0) return;
//
//       const payload = {
//         notification: {
//           title: senderName,
//           body: message.text || 'Sent a media',
//         },
//         data: {
//           chatId: chatId,
//           type: 'dm',
//         },
//       };
//
//       await admin.messaging().sendToDevice(tokens, payload);
//     } else if (chat.type === 'role') {
//       // For role chat: Send to topic
//       const topic = `role_${chat.role_id}`;
//       const payload = {
//         notification: {
//           title: chat.title,
//           body: `${senderName}: ${message.text || 'Sent a media'}`,
//         },
//         data: {
//           chatId: chatId,
//           type: 'role',
//         },
//       };
//
//       await admin.messaging().sendToTopic(topic, payload);
//     }
//   });
// ```
