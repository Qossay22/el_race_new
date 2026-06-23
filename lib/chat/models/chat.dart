import 'package:cloud_firestore/cloud_firestore.dart';

/// Chat types supported
enum ChatType {
  dm,
  role,
  group,
  support; // Helpdesk-style: user ↔ department group (anonymous replies)

  static ChatType fromString(String value) {
    switch (value) {
      case 'dm':
        return ChatType.dm;
      case 'role':
        return ChatType.role;
      case 'group':
        return ChatType.group;
      case 'support':
        return ChatType.support;
      default:
        return ChatType.dm;
    }
  }

  String toJson() => name;
}

/// Last message preview info stored in chat document
class LastMessage {
  final String text;
  final String type;
  final String senderId;
  final DateTime createdAt;

  LastMessage({
    required this.text,
    required this.type,
    required this.senderId,
    required this.createdAt,
  });

  factory LastMessage.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return LastMessage(
        text: '',
        type: 'text',
        senderId: '',
        createdAt: DateTime.now(),
      );
    }
    return LastMessage(
      text: data['text'] ?? '',
      type: data['type'] ?? 'text',
      senderId: data['sender_id'] ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'type': type,
      'sender_id': senderId,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }
}

/// Represents a chat (DM or group).
/// Stored in Firestore at: chats/{chatId}
class Chat {
  final String id;
  final ChatType type;
  final DateTime createdAt;
  final DateTime updatedAt;
  final LastMessage? lastMessage;

  // DM-specific fields
  final List<String>? dmPair; // [uidA, uidB] sorted alphabetically

  // Role/Group-specific fields
  final int? roleId;
  final int? branchId;
  final int? companyId;
  final String? title;
  final String? photoUrl;

  // Support chat-specific fields
  final String?
      supportUserUid; // The external user who initiated the support chat

  Chat({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
    this.dmPair,
    this.roleId,
    this.branchId,
    this.companyId,
    this.title,
    this.photoUrl,
    this.supportUserUid,
  });

  /// Generate DM chat ID from two user UIDs.
  /// Format: dm_{min(uidA, uidB)}_{max(uidA, uidB)}
  static String generateDmChatId(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return 'dm_${sorted[0]}_${sorted[1]}';
  }

  /// Generate role chat ID.
  /// Format depends on groupByBranch flag:
  /// - false: role_{roleId}
  /// - true: role_{roleId}_branch_{branchId} (falls back to role_{roleId} if no branch)
  static String generateRoleChatId({
    required int roleId,
    int? branchId,
    bool groupByBranch = false,
  }) {
    if (groupByBranch && branchId != null) {
      return 'role_${roleId}_branch_$branchId';
    }
    return 'role_$roleId';
  }

  /// Get sorted DM pair from two UIDs
  static List<String> getSortedDmPair(String uidA, String uidB) {
    return [uidA, uidB]..sort();
  }

  /// Generate support chat ID.
  /// Format: support_{roleId}_{userUid}
  /// One unique chat per (department, external user) pair.
  static String generateSupportChatId({
    required int roleId,
    required String userUid,
  }) {
    return 'support_${roleId}_$userUid';
  }

  factory Chat.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Chat(
      id: doc.id,
      type: ChatType.fromString(data['type'] ?? 'dm'),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessage: data['last_message'] != null
          ? LastMessage.fromMap(data['last_message'] as Map<String, dynamic>)
          : null,
      dmPair:
          data['dm_pair'] != null ? List<String>.from(data['dm_pair']) : null,
      roleId: data['role_id'],
      branchId: data['branch_id'],
      companyId: data['company_id'],
      title: data['title'],
      photoUrl: data['photo_url'],
      supportUserUid: data['support_user_uid'],
    );
  }

  Map<String, dynamic> toFirestore({bool isUpdate = false}) {
    final map = <String, dynamic>{
      'type': type.toJson(),
      'updated_at': FieldValue.serverTimestamp(),
    };

    if (!isUpdate) {
      map['created_at'] = FieldValue.serverTimestamp();
    }

    if (lastMessage != null) {
      map['last_message'] = lastMessage!.toMap();
    }

    if (type == ChatType.dm && dmPair != null) {
      map['dm_pair'] = dmPair;
    }

    if (type == ChatType.role || type == ChatType.group) {
      if (roleId != null) map['role_id'] = roleId;
      if (branchId != null) map['branch_id'] = branchId;
      if (companyId != null) map['company_id'] = companyId;
      if (title != null) map['title'] = title;
      if (photoUrl != null) map['photo_url'] = photoUrl;
    }

    if (type == ChatType.support) {
      if (roleId != null) map['role_id'] = roleId;
      if (branchId != null) map['branch_id'] = branchId;
      if (companyId != null) map['company_id'] = companyId;
      if (title != null) map['title'] = title;
      if (photoUrl != null) map['photo_url'] = photoUrl;
      if (supportUserUid != null) map['support_user_uid'] = supportUserUid;
    }

    return map;
  }

  Chat copyWith({
    String? id,
    ChatType? type,
    DateTime? createdAt,
    DateTime? updatedAt,
    LastMessage? lastMessage,
    List<String>? dmPair,
    int? roleId,
    int? branchId,
    int? companyId,
    String? title,
    String? photoUrl,
    String? supportUserUid,
  }) {
    return Chat(
      id: id ?? this.id,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessage: lastMessage ?? this.lastMessage,
      dmPair: dmPair ?? this.dmPair,
      roleId: roleId ?? this.roleId,
      branchId: branchId ?? this.branchId,
      companyId: companyId ?? this.companyId,
      title: title ?? this.title,
      photoUrl: photoUrl ?? this.photoUrl,
      supportUserUid: supportUserUid ?? this.supportUserUid,
    );
  }

  @override
  String toString() => 'Chat(id: $id, type: $type, title: $title)';
}
