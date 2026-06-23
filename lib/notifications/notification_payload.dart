enum NotificationType { hr, rfq, pettyCash, invoice, chat, unknown }

class ParsedNotificationPayload {
  final NotificationType type;
  final String requestId;
  final String rawType;
  final Map<String, dynamic> raw;

  const ParsedNotificationPayload({
    required this.type,
    required this.requestId,
    required this.rawType,
    required this.raw,
  });

  bool get isNavigable => type != NotificationType.unknown;
  bool get isChatType => type == NotificationType.chat;
}
