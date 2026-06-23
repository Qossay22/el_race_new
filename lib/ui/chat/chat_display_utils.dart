/// Shared display helpers for chat names and titles in lists and headers.
String limitChatDisplayName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return trimmed;
  final parts = trimmed.split(RegExp(r'\s+'));
  return parts.take(2).join(' ');
}
