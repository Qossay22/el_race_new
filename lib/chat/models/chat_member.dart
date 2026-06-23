import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a member of a chat.
/// Stored in Firestore at: chats/{chatId}/members/{uid}
class ChatMember {
  final String uid;
  final DateTime joinedAt;
  final int? roleIdSnapshot;
  final int? branchIdSnapshot;
  final int? companyIdSnapshot;
  final bool muted;

  ChatMember({
    required this.uid,
    required this.joinedAt,
    this.roleIdSnapshot,
    this.branchIdSnapshot,
    this.companyIdSnapshot,
    this.muted = false,
  });

  factory ChatMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ChatMember(
      uid: doc.id,
      joinedAt: (data['joined_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      roleIdSnapshot: data['role_id_snapshot'],
      branchIdSnapshot: data['branch_id_snapshot'],
      companyIdSnapshot: data['company_id_snapshot'],
      muted: data['muted'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore({bool isUpdate = false}) {
    final map = <String, dynamic>{
      'muted': muted,
    };

    if (!isUpdate) {
      map['joined_at'] = FieldValue.serverTimestamp();
      if (roleIdSnapshot != null) map['role_id_snapshot'] = roleIdSnapshot;
      if (branchIdSnapshot != null) map['branch_id_snapshot'] = branchIdSnapshot;
      if (companyIdSnapshot != null) map['company_id_snapshot'] = companyIdSnapshot;
    }

    return map;
  }

  ChatMember copyWith({
    String? uid,
    DateTime? joinedAt,
    int? roleIdSnapshot,
    int? branchIdSnapshot,
    int? companyIdSnapshot,
    bool? muted,
  }) {
    return ChatMember(
      uid: uid ?? this.uid,
      joinedAt: joinedAt ?? this.joinedAt,
      roleIdSnapshot: roleIdSnapshot ?? this.roleIdSnapshot,
      branchIdSnapshot: branchIdSnapshot ?? this.branchIdSnapshot,
      companyIdSnapshot: companyIdSnapshot ?? this.companyIdSnapshot,
      muted: muted ?? this.muted,
    );
  }

  @override
  String toString() => 'ChatMember(uid: $uid, muted: $muted)';
}
