import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat.dart';

/// Represents a chat entry in user's chat list.
/// Stored in Firestore at: userChats/{uid}/chats/{chatId}
/// This is an index collection for efficient chat list queries.
class UserChat {
  final String chatId;
  final ChatType type;
  final String? title;
  
  // DM-specific
  final String? peerUid;
  
  // Role chat-specific
  final int? roleId;
  final int? branchId;
  final int? companyId;
  
  // Support chat-specific
  final String? supportUserUid; // The external user who initiated the support chat
  final String? supportGroupTitle; // The group title (e.g. "HR") for display
  
  final DateTime updatedAt;
  final DateTime? lastReadAt;
  final bool pinned;
  final bool muted;
  final bool hasMessages;

  UserChat({
    required this.chatId,
    required this.type,
    this.title,
    this.peerUid,
    this.roleId,
    this.branchId,
    this.companyId,
    this.supportUserUid,
    this.supportGroupTitle,
    required this.updatedAt,
    this.lastReadAt,
    this.pinned = false,
    this.muted = false,
    this.hasMessages = false,
  });

  factory UserChat.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserChat(
      chatId: doc.id,
      type: ChatType.fromString(data['type'] ?? 'dm'),
      title: data['title'],
      peerUid: data['peer_uid'],
      roleId: data['role_id'],
      branchId: data['branch_id'],
      companyId: data['company_id'],
      supportUserUid: data['support_user_uid'],
      supportGroupTitle: data['support_group_title'],
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastReadAt: (data['last_read_at'] as Timestamp?)?.toDate(),
      pinned: data['pinned'] ?? false,
      muted: data['muted'] ?? false,
      hasMessages: data['has_messages'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore({bool isUpdate = false}) {
    final map = <String, dynamic>{
      'type': type.toJson(),
      'updated_at': FieldValue.serverTimestamp(),
      'pinned': pinned,
      'muted': muted,
    };

    if (hasMessages) map['has_messages'] = true;
    if (title != null) map['title'] = title;
    if (peerUid != null) map['peer_uid'] = peerUid;
    if (roleId != null) map['role_id'] = roleId;
    if (branchId != null) map['branch_id'] = branchId;
    if (companyId != null) map['company_id'] = companyId;
    if (supportUserUid != null) map['support_user_uid'] = supportUserUid;
    if (supportGroupTitle != null) map['support_group_title'] = supportGroupTitle;

    // Don't set lastReadAt on create; only on explicit read
    if (isUpdate && lastReadAt != null) {
      map['last_read_at'] = Timestamp.fromDate(lastReadAt!);
    }

    return map;
  }

  /// Check if there are unread messages based on chat's last message time
  bool hasUnread(DateTime? lastMessageTime) {
    if (lastMessageTime == null) return false;
    if (lastReadAt == null) return true;
    return lastMessageTime.isAfter(lastReadAt!);
  }

  UserChat copyWith({
    String? chatId,
    ChatType? type,
    String? title,
    String? peerUid,
    int? roleId,
    int? branchId,
    int? companyId,
    String? supportUserUid,
    String? supportGroupTitle,
    DateTime? updatedAt,
    DateTime? lastReadAt,
    bool? pinned,
    bool? muted,
    bool? hasMessages,
  }) {
    return UserChat(
      chatId: chatId ?? this.chatId,
      type: type ?? this.type,
      title: title ?? this.title,
      peerUid: peerUid ?? this.peerUid,
      roleId: roleId ?? this.roleId,
      branchId: branchId ?? this.branchId,
      companyId: companyId ?? this.companyId,
      supportUserUid: supportUserUid ?? this.supportUserUid,
      supportGroupTitle: supportGroupTitle ?? this.supportGroupTitle,
      updatedAt: updatedAt ?? this.updatedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      pinned: pinned ?? this.pinned,
      muted: muted ?? this.muted,
      hasMessages: hasMessages ?? this.hasMessages,
    );
  }

  @override
  String toString() => 'UserChat(chatId: $chatId, type: $type, title: $title)';
}
