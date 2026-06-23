import 'package:el_race/core/app_globals.dart';
import 'package:el_race/firebase_service.dart';
import 'package:el_race/notifications/notification_payload.dart';
import 'package:el_race/notifications/notification_payload_parser.dart';
import 'package:el_race/notifications/notification_router.dart';
import 'package:flutter/widgets.dart';

/// Single entry point for all notification tap events.
/// Owns the re-entrancy guard and home-readiness queue.
class NotificationController {
  const NotificationController._();

  static bool _isBusy = false;
  static Map<String, dynamic>? _pendingRawData;

  /// Called from [FirebaseService] (system tray / background) and from
  /// the notification list screen (in-app tap).
  ///
  /// Returns [true] if the tap was consumed (navigated or queued for replay).
  /// Returns [false] if the notification is view-only (unknown type) — the
  /// caller should show its own fallback UI.
  static bool handleTap(Map<String, dynamic> rawData) {
    return _handle(rawData);
  }

  /// Replays any tap that arrived before the home screen was ready.
  /// Called by [FirebaseService.processPendingNotificationTap] on home-ready.
  static void processPending() {
    final pending = _pendingRawData;
    if (pending == null) return;
    _pendingRawData = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _handle(pending));
  }

  static bool _handle(Map<String, dynamic> rawData) {
    // Guard 1: re-entrancy — queue and report consumed
    if (_isBusy) {
      _pendingRawData = rawData;
      return true;
    }

    // Guard 2: home not ready — queue and report consumed
    final navigator = navKey.currentState;
    if (navigator == null ||
        navKey.currentContext == null ||
        !FirebaseService.isHomeReady) {
      _pendingRawData = rawData;
      debugPrint('[NotificationController] tap queued — home not ready');
      return true;
    }

    final payload = NotificationPayloadParser.parse(rawData);

    // Chat: back-delegate to FirebaseService (preserves existing chat flow)
    if (payload.isChatType) {
      FirebaseService.delegateChatTap(rawData);
      return true;
    }

    // View-only: caller decides what to show
    if (payload.type == NotificationType.unknown) {
      return false;
    }

    _isBusy = true;
    try {
      final navigated = NotificationRouter.route(payload, navigator);
      return navigated;
    } finally {
      _isBusy = false;
      final next = _pendingRawData;
      if (next != null && next != rawData) {
        _pendingRawData = null;
        processPending();
      }
    }
  }
}
