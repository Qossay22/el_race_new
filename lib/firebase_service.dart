import 'dart:convert';

import 'package:el_race/chat/models/models.dart';
import 'package:el_race/notifications/notification_controller.dart';
import 'package:el_race/core/app_globals.dart';
import 'package:el_race/core/services/attendance_status_sync_service.dart';
import 'package:el_race/core/services/notification_storage_service.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/chat/chat_screen.dart';
import 'package:el_race/utils/string_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FirebaseService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Track processed notification message IDs to avoid duplicate handling
  static final Set<String> _processedMessageIds = {};
  static String? _pendingChatTapPayload;
  static bool _isHandlingChatTap = false;
  static bool _isHomeReady = false;

  /// Public read-only accessor used by NotificationController.
  static bool get isHomeReady => _isHomeReady;

  /// Call this after splash/home is ready so queued chat-notification taps can
  /// be replayed with a valid app context.
  static void markHomeReady() {
    _isHomeReady = true;
    processPendingNotificationTap();
  }

  /// Call this when the app returns to splash and chat taps must wait again.
  static void markHomeNotReady() {
    _isHomeReady = false;
  }

  static Future<void> initialize() async {
    await _firebaseMessaging.setAutoInitEnabled(true);

    // Request notification permission with more detailed settings
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('🔔 Notification permission status: ${settings.authorizationStatus}');
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Notification permission granted');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print('⚠️ Provisional notification permission granted');
    } else {
      print(
          '❌ Notification permission declined: ${settings.authorizationStatus}');
    }

    // Initialize local notifications (for showing notifications in foreground)
    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInitSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: iosInitSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        print("🔔 [LOCAL NOTIFICATION TAP] Notification tapped!");
        print("   - Payload: $payload");
        print("   - Action ID: ${response.actionId}");
        print("   - Notification ID: ${response.id}");
        // General notifications are view-only. Chat notifications still open
        // their conversation.
        _handleNotificationTap(payload);
      },
    );

    // Create the high_importance_channel used by FCM foreground notifications.
    // Without this, Android 8+ silently drops or demotes notifications because
    // the channel referenced in AndroidManifest meta-data doesn't exist.
    final androidImpl =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          'high_importance_channel',
          'High Importance Notifications',
          description: 'Used for general push notifications',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );
    }

    // Ensure iOS presents incoming FCM notifications while app is in foreground.
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('📬 [FOREGROUND] Received message!');
      print('   - Title: ${message.notification?.title}');
      print('   - Body: ${message.notification?.body}');
      print('   - Data: ${message.data}');

      // On iOS, setForegroundNotificationPresentationOptions already shows
      // the notification natively — calling _showNotification here would
      // create a duplicate. Only show local notification on Android.
      if (defaultTargetPlatform == TargetPlatform.android) {
        _showNotification(message);
      }
      // Save notification to storage (await to ensure badge count
      // is persisted before the onCountChanged callback fires).
      await _saveNotificationToStorage(message);

      await _refreshAttendanceFromPushIfNeeded(
        message,
        source: 'foreground',
      );
    });

    // Handle background-tap messages (when app is resumed from notification)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      final messageId = message.messageId ?? message.data.toString();
      print('📲 [BACKGROUND TAP] App opened from notification!');
      print('   - Message ID: $messageId');
      print('   - Title: ${message.notification?.title}');
      print('   - Data: ${message.data}');

      // Check if already processed
      if (_processedMessageIds.contains(messageId)) {
        print('   - ⚠️ Message already processed, ignoring');
        return;
      }

      _processedMessageIds.add(messageId);
      print(
          '   - ✅ Processing message (${_processedMessageIds.length} total processed)');

      // Save notification to storage if not already saved
      await _saveNotificationToStorage(message);
      await _refreshAttendanceFromPushIfNeeded(
        message,
        source: 'background_tap',
      );
      _handleNotificationTap(_buildEnrichedPayload(message));
    });

    // Check for initial message (when app is opened from terminated state)
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) async {
      if (message != null) {
        final messageId = message.messageId ?? message.data.toString();
        print('📲 [TERMINATED TAP] App opened from notification!');
        print('   - Message ID: $messageId');
        print('   - Title: ${message.notification?.title}');
        print('   - Data: ${message.data}');

        // Check if already processed
        if (_processedMessageIds.contains(messageId)) {
          print('   - ⚠️ Message already processed, ignoring');
          return;
        }

        _processedMessageIds.add(messageId);
        print(
            '   - ✅ Processing message (${_processedMessageIds.length} total processed)');

        await _saveNotificationToStorage(message);
        await _refreshAttendanceFromPushIfNeeded(
          message,
          source: 'terminated_tap',
        );
        _handleNotificationTap(_buildEnrichedPayload(message));
      } else {
        print('ℹ️ [TERMINATED] No initial message found');
      }
    });

    // Get and print the FCM token (you can send this to your server)
    try {
      // For iOS, we need to wait for APNS token first
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        print('🍎 iOS detected - waiting for APNS token...');
        // Wait a bit for APNS token to be available
        await Future.delayed(const Duration(seconds: 2));

        final apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken != null && apnsToken.isNotEmpty) {
          print('🍎 APNS token: $apnsToken');
        } else {
          print('⚠️ APNS token unavailable during initialize');
        }
      }

      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        SharedPref().setPreferencesString(fcm_token, token);
        print('📱 FCM Token obtained: $token'); // full token for debugging
      } else {
        print('❌ FCM Token is null - this may indicate APNS token issue');
      }
    } catch (e) {
      print('❌ Error getting FCM token during initialization: $e');
    }

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      SharedPref().setPreferencesString(fcm_token, newToken.toString());
      print('🔁 FCM Token refreshed: $newToken'); // full token for debugging
    });
  }

  static Future<String?> ensureFCMToken() async {
    try {
      // Check if we already have a token in SharedPreferences
      String existingToken = SharedPref().getPreferenceString(fcm_token);
      if (existingToken.isNotEmpty) {
        print(
            '📱 Using existing FCM Token: ${existingToken.substring(0, 20)}...');
        return existingToken;
      }

      // For iOS, check APNS token first
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        print('🍎 Checking APNS token availability...');
        try {
          String? apnsToken = await _firebaseMessaging.getAPNSToken();
          if (apnsToken == null) {
            print('⚠️ APNS token not available yet, waiting...');
            print('💡 This usually means:');
            print('   1. Push Notifications capability not enabled in Xcode');
            print('   2. App not signed with proper provisioning profile');
            print('   3. Running on simulator (APNS not supported)');
            print('   4. Firebase APNS configuration missing');

            // Wait and retry a few times
            for (int i = 0; i < 5; i++) {
              await Future.delayed(const Duration(seconds: 1));
              apnsToken = await _firebaseMessaging.getAPNSToken();
              if (apnsToken != null) {
                print('✅ APNS token obtained after ${i + 1} attempts');
                break;
              }
            }
            if (apnsToken == null) {
              print('❌ APNS token still not available after 5 attempts');
              print('🔧 Please check the troubleshooting steps below');
              return null;
            }
          } else {
            print(
                '✅ APNS token is available: ${apnsToken.substring(0, 20)}...');
          }
        } catch (apnsError) {
          print('❌ Error checking APNS token: $apnsError');
        }
      }

      // Try to get a new FCM token
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        SharedPref().setPreferencesString(fcm_token, token);
        print('📱 FCM Token obtained and stored: ${token.substring(0, 20)}...');
      } else {
        print('❌ Failed to get FCM token - Firebase may not be initialized');
      }
      return token;
    } catch (e) {
      print('❌ Error getting FCM token: $e');
      print('❌ This may happen if Firebase is not properly initialized');
      return null;
    }
  }

  /// Test method to manually check FCM token generation
  static Future<void> testFCMToken() async {
    print('🧪 Testing FCM Token generation...');
    try {
      String? token = await ensureFCMToken();
      if (token != null) {
        print('✅ FCM Token test successful: ${token.substring(0, 20)}...');
      } else {
        print('❌ FCM Token test failed - no token generated');
        print('🔄 Trying alternative method...');
        await testFCMTokenAlternative();
      }
    } catch (e) {
      print('❌ FCM Token test error: $e');
    }
  }

  /// Alternative method to get FCM token without APNS dependency
  static Future<String?> testFCMTokenAlternative() async {
    print('🔄 Trying alternative FCM token retrieval...');
    try {
      // Try to get token directly without APNS check
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        print('✅ Alternative method successful: ${token.substring(0, 20)}...');
        SharedPref().setPreferencesString(fcm_token, token);
        return token;
      } else {
        print('❌ Alternative method also failed');
        return null;
      }
    } catch (e) {
      print('❌ Alternative method error: $e');
      return null;
    }
  }

  static Future<void> _showNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    final data = message.data;

    final title = (notification?.title ??
            data['title']?.toString() ??
            data['notification_title']?.toString() ??
            data['sender_name']?.toString() ??
            data['chat_title']?.toString() ??
            'Notification')
        .trim();

    final body = (notification?.body ??
            data['body']?.toString() ??
            data['message']?.toString() ??
            data['text']?.toString() ??
            '')
        .trim();

    if (title.isEmpty && body.isEmpty) {
      print('⚠️ Skipping local notification: empty title/body payload');
      return;
    }

    String category = 'notification';
    if (message.data.containsKey('category')) {
      category = message.data['category'].toString();
    } else if (message.data.containsKey('type')) {
      category = message.data['type'].toString();
    }

    final isMuted = await NotificationStorageService.shouldMuteNotification(
      category: category,
      data: message.data,
    );
    if (isMuted) {
      print(
          '🔇 Foreground notification suppressed by mute settings: category=$category');
      return;
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.high,
      priority: Priority.high,
      channelShowBadge: true,
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final notificationId = message.messageId?.hashCode ??
        '${title}_${body}_${DateTime.now().millisecondsSinceEpoch}'.hashCode;

    await _flutterLocalNotificationsPlugin.show(
      notificationId,
      title,
      body.isEmpty ? null : body,
      platformDetails,
      payload: _buildEnrichedPayload(message),
    );
  }

  static Future<void> _saveNotificationToStorage(RemoteMessage message) async {
    try {
      final notification = message.notification;
      if (notification != null) {
        // Determine category from message data
        String category = 'notification'; // default
        if (message.data.containsKey('category')) {
          category = message.data['category'].toString();
        } else if (message.data.containsKey('type')) {
          category = message.data['type'].toString();
        }

        await NotificationStorageService.saveNotification(
          title: notification.title ?? 'Notification',
          body: notification.body ?? '',
          imageUrl:
              notification.android?.imageUrl ?? notification.apple?.imageUrl,
          data: message.data,
          category: category,
        );
      }
    } catch (e) {
      print('❌ Error saving notification to storage: $e');
    }
  }

  static Future<void> _refreshAttendanceFromPushIfNeeded(
    RemoteMessage message, {
    required String source,
  }) async {
    if (!_isAttendancePush(message)) {
      return;
    }

    print(
      '🕒 Attendance push trigger detected from $source. Refreshing /api/attendance/today_status',
    );

    await AttendanceStatusSyncService.refreshFromServer(
      reason: 'push_$source',
    );
  }

  static bool _isAttendancePush(RemoteMessage message) {
    final data = message.data;

    final searchSpace = <String>[
      data['category']?.toString() ?? '',
      data['type']?.toString() ?? '',
      data['model']?.toString() ?? '',
      data['model_name']?.toString() ?? '',
      data['event']?.toString() ?? '',
      data['action']?.toString() ?? '',
      data['topic']?.toString() ?? '',
      message.notification?.title ?? '',
      message.notification?.body ?? '',
    ].join(' ').toLowerCase();

    final hasAttendanceKeyword = searchSpace.contains('hr.attendance') ||
        searchSpace.contains('attendance') ||
        searchSpace.contains('biotime') ||
        searchSpace.contains('check_in') ||
        searchSpace.contains('check_out') ||
        searchSpace.contains('check in') ||
        searchSpace.contains('check out') ||
        searchSpace.contains('checkout');

    if (hasAttendanceKeyword) {
      return true;
    }

    final refreshFlag = data['refresh_attendance'] ??
        data['attendance_refresh'] ??
        data['refresh_today_status'];

    if (refreshFlag == null) {
      return false;
    }

    final normalizedFlag = refreshFlag.toString().trim().toLowerCase();
    return normalizedFlag == '1' ||
        normalizedFlag == 'true' ||
        normalizedFlag == 'yes' ||
        normalizedFlag == 'y';
  }

  static void _handleNotificationTap(String? payload) {
    final payloadData = _parseNotificationPayload(payload);
    NotificationController.handleTap(payloadData);
  }

  static void processPendingNotificationTap({String? forcePayload}) {
    // Replay any non-chat tap queued by NotificationController
    NotificationController.processPending();

    final payload = forcePayload ?? _pendingChatTapPayload;
    if (payload == null || payload.isEmpty) return;

    _pendingChatTapPayload = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleNotificationTap(payload);
    });
  }

  static String _buildEnrichedPayload(RemoteMessage message) {
    final enriched = Map<String, dynamic>.from(message.data);
    final notification = message.notification;
    if (notification != null) {
      enriched.putIfAbsent('title', () => notification.title ?? '');
      enriched.putIfAbsent('body', () => notification.body ?? '');
    }

    return _encodePayload(enriched);
  }

  static String _encodePayload(Map<String, dynamic> data) {
    try {
      return jsonEncode(data);
    } catch (_) {
      return data.toString();
    }
  }

  static Map<String, dynamic> _parseNotificationPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) {
      return {};
    }

    final trimmed = payload.trim();
    if (trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          return decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          );
        }
      } catch (_) {
        // Fall back to parsing the Dart Map.toString() format used by older
        // notification payloads.
      }
    }

    final result = <String, dynamic>{};
    final content = trimmed
        .replaceFirst(RegExp(r'^\{'), '')
        .replaceFirst(RegExp(r'\}$'), '');

    for (final pair in content.split(RegExp(r',\s*'))) {
      final separatorIndex = pair.indexOf(':');
      if (separatorIndex <= 0) continue;

      final key = pair.substring(0, separatorIndex).trim();
      final value = pair.substring(separatorIndex + 1).trim();
      if (key.isNotEmpty) {
        result[key] = value;
      }
    }

    return result;
  }

  /// Back-channel called by [NotificationController] when a chat payload is
  /// detected. Re-encodes the decoded map so the existing chat handler
  /// signature is satisfied without modification.
  static void delegateChatTap(Map<String, dynamic> payloadData) {
    String? rawPayload;
    try {
      rawPayload = jsonEncode(payloadData);
    } catch (_) {
      rawPayload = payloadData.toString();
    }
    _handleChatNotificationTap(rawPayload, payloadData);
  }

  static void _handleChatNotificationTap(
    String? rawPayload,
    Map<String, dynamic> payloadData,
  ) {
    if (_isHandlingChatTap) {
      _pendingChatTapPayload = rawPayload;
      return;
    }

    final navigator = navKey.currentState;
    if (navigator == null || navKey.currentContext == null || !_isHomeReady) {
      _pendingChatTapPayload = rawPayload;
      print('   - Chat tap queued until navigation is ready.');
      return;
    }

    _isHandlingChatTap = true;
    try {
      final chatId =
          (payloadData['chat_id'] ?? payloadData['chatId'] ?? '').toString();
      if (chatId.trim().isEmpty) {
        print('   - Chat notification missing chat_id; no navigation.');
        return;
      }

      final chatTitle = (payloadData['chat_title'] ??
              payloadData['chatTitle'] ??
              payloadData['title'] ??
              'Chat')
          .toString();
      final chatType = _resolveChatType(payloadData);

      _navigateToChatScreen(navigator, chatId, chatTitle, chatType);
    } finally {
      _isHandlingChatTap = false;

      if (_pendingChatTapPayload != null &&
          _pendingChatTapPayload != rawPayload) {
        final nextPayload = _pendingChatTapPayload;
        _pendingChatTapPayload = null;
        processPendingNotificationTap(forcePayload: nextPayload);
      }
    }
  }

  static String _resolveChatType(Map<String, dynamic> payloadData) {
    for (final key in const [
      'chat_type',
      'chatType',
      'conversation_type',
      'type',
    ]) {
      final normalized =
          (payloadData[key] ?? '').toString().trim().toLowerCase();
      if (normalized == 'dm' ||
          normalized == 'role' ||
          normalized == 'group' ||
          normalized == 'support') {
        return normalized;
      }
    }

    return 'dm';
  }

  static void _navigateToChatScreen(
    NavigatorState navigator,
    String chatId,
    String chatTitle,
    String chatTypeStr,
  ) {
    try {
      final chatType = ChatType.fromString(chatTypeStr.toLowerCase().trim());

      String? peerUid;
      if (chatType == ChatType.dm && chatId.startsWith('dm_')) {
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        if (currentUid != null) {
          final allParts = chatId.substring(3);
          if (allParts.startsWith('${currentUid}_')) {
            peerUid = allParts.substring(currentUid.length + 1);
          } else if (allParts.endsWith('_$currentUid')) {
            peerUid =
                allParts.substring(0, allParts.length - currentUid.length - 1);
          }
        }
      }

      navigator.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            title: chatTitle.trim().isEmpty ? 'Chat' : chatTitle,
            chatType: chatType,
            peerUid: peerUid,
          ),
          settings: const RouteSettings(name: '/chat_from_notification'),
        ),
      );
      print('   - Chat notification opened chatId=$chatId');
    } catch (e) {
      print('   - Chat navigation failed: $e');
    }
  }
}
