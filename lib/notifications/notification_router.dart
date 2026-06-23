import 'package:el_race/notifications/notification_payload.dart';
import 'package:el_race/ui/presentation/Email%20Approval/screens/hr_details_screen.dart';
import 'package:el_race/ui/presentation/Email%20Approval/screens/invoice_details_screen.dart';
import 'package:el_race/ui/presentation/Email%20Approval/screens/pettycash_details_screen.dart';
import 'package:el_race/ui/presentation/Email%20Approval/screens/rfq_details_screen.dart';
import 'package:flutter/material.dart';

class NotificationRouter {
  const NotificationRouter._();

  /// Routes a parsed notification payload to the correct screen.
  /// Returns true if navigation was performed, false if no route exists.
  static bool route(
    ParsedNotificationPayload payload,
    NavigatorState navigator,
  ) {
    switch (payload.type) {
      case NotificationType.hr:
        return _push(
          navigator,
          HrDetailsScreen(requestId: payload.requestId, type: payload.rawType),
          '/hr_details_from_notification',
        );
      case NotificationType.rfq:
        return _push(
          navigator,
          RfqDetailsScreen(requestId: payload.requestId, type: payload.rawType),
          '/rfq_details_from_notification',
        );
      case NotificationType.pettyCash:
        return _push(
          navigator,
          PettyCashDetailsScreen(
            requestId: payload.requestId,
            type: payload.rawType,
          ),
          '/pettycash_details_from_notification',
        );
      case NotificationType.invoice:
        return _push(
          navigator,
          InvoiceDetailsScreen(
            requestId: payload.requestId,
            type: payload.rawType,
          ),
          '/invoice_details_from_notification',
        );
      case NotificationType.chat:
      case NotificationType.unknown:
        return false;
    }
  }

  static bool _push(
    NavigatorState navigator,
    Widget screen,
    String routeName,
  ) {
    try {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => screen,
          settings: RouteSettings(name: routeName),
        ),
      );
      return true;
    } catch (e) {
      debugPrint('[NotificationRouter] navigation failed: $e');
      return false;
    }
  }
}
