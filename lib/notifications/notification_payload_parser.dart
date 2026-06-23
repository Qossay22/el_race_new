import 'package:el_race/notifications/notification_payload.dart';

class NotificationPayloadParser {
  const NotificationPayloadParser._();

  static ParsedNotificationPayload parse(Map<String, dynamic> rawData) {
    final rawType = _extractRawType(rawData);
    final category = rawType.toLowerCase();
    final requestId = _extractRequestId(rawData);
    final type = _resolveType(category, rawData);

    return ParsedNotificationPayload(
      type: type,
      requestId: requestId,
      rawType: rawType,
      raw: rawData,
    );
  }

  static String _extractRawType(Map<String, dynamic> data) {
    return (data['category'] ?? data['type'] ?? data['model'] ?? '')
        .toString()
        .trim();
  }

  static String _extractRequestId(Map<String, dynamic> data) {
    return (data['request_id'] ??
            data['requestId'] ??
            data['record_id'] ??
            data['id'] ??
            '')
        .toString()
        .trim();
  }

  static NotificationType _resolveType(
    String category,
    Map<String, dynamic> data,
  ) {
    if (category == 'chat_message' ||
        category == 'chat' ||
        data.containsKey('chat_id') ||
        data.containsKey('chatId')) {
      return NotificationType.chat;
    }

    if (category == 'hr' ||
        category == 'hr_approval' ||
        category == 'human_resources' ||
        category == 'hr.leave' ||
        category == 'leave') {
      return NotificationType.hr;
    }

    if (category == 'rfq' || category == 'request_for_quotation') {
      return NotificationType.rfq;
    }

    if (category == 'petty_cash' || category == 'pettycash') {
      return NotificationType.pettyCash;
    }

    if (category == 'invoice' || category == 'invoices') {
      return NotificationType.invoice;
    }

    // employee.requests: sub-type determines the actual screen
    if (category == 'employee.requests') {
      final subType =
          (data['type'] ?? data['model'] ?? '').toString().trim().toUpperCase();
      if (subType == 'HR') return NotificationType.hr;
      if (subType == 'RFQ') return NotificationType.rfq;
      if (subType == 'INVOICE') return NotificationType.invoice;
      if (subType.contains('PETTY')) return NotificationType.pettyCash;
    }

    // module / category / type based fallback: "New Employee Request Approval" must open the
    // HR detail screen directly, regardless of what category the server sent.
    if (data['module'] == 'employee_request' ||
        data['category'] == 'approval' ||
        (data['type'] ?? '').toString().contains('employee_request')) {
      return NotificationType.hr;
    }

    return NotificationType.unknown;
  }
}
