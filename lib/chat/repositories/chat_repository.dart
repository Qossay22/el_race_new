import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../services/presence_service.dart';
import 'user_repository.dart';

/// Repository for chat-related Firestore and Storage operations.
///
/// Handles:
/// - DM creation and management
/// - Role chat setup
/// - Message sending (text, image, file, audio)
/// - Message streaming with pagination
/// - Read receipts
/// - User chat list management
class ChatRepository {
  static ChatRepository? _instance;
  static ChatRepository get instance => _instance ??= ChatRepository._();

  ChatRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  // Configuration
  static const bool groupByBranch = true; // Group role chats by branch/city
  static const int defaultPageSize = 25;

  // Collection references
  CollectionReference<Map<String, dynamic>> get _chatsCollection =>
      _firestore.collection('chats');

  CollectionReference<Map<String, dynamic>> _userChatsCollection(String uid) =>
      _firestore.collection('userChats').doc(uid).collection('chats');

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  // ============== DM Chat Creation ==============

  /// Create or get an existing DM chat between two users.
  /// Returns the chat ID.
  Future<String> createOrGetDmChat({
    required String otherUid,
    required String otherName,
    required String currentUserName,
    int? otherRoleId,
    int? otherBranchId,
    int? otherCompanyId,
    int? currentUserRoleId,
    int? currentUserBranchId,
    int? currentUserCompanyId,
  }) async {
    final currentUid = _currentUid;
    if (currentUid == null) {
      throw Exception('Not authenticated');
    }

    final chatId = Chat.generateDmChatId(currentUid, otherUid);
    final dmPair = Chat.getSortedDmPair(currentUid, otherUid);

    try {
      final batch = _firestore.batch();

      // Create/update chat document
      final chatRef = _chatsCollection.doc(chatId);
      batch.set(
          chatRef,
          {
            'type': 'dm',
            'dm_pair': dmPair,
            'member_ids': FieldValue.arrayUnion(dmPair),
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      // Create member documents for both users
      final currentMemberRef = chatRef.collection('members').doc(currentUid);
      batch.set(
          currentMemberRef,
          {
            'joined_at': FieldValue.serverTimestamp(),
            'role_id_snapshot': currentUserRoleId,
            'branch_id_snapshot': currentUserBranchId,
            'company_id_snapshot': currentUserCompanyId,
            'muted': false,
          },
          SetOptions(merge: true));

      final otherMemberRef = chatRef.collection('members').doc(otherUid);
      batch.set(
          otherMemberRef,
          {
            'joined_at': FieldValue.serverTimestamp(),
            'role_id_snapshot': otherRoleId,
            'branch_id_snapshot': otherBranchId,
            'company_id_snapshot': otherCompanyId,
            'muted': false,
          },
          SetOptions(merge: true));

      // NOTE: userChats entries are NOT created here.
      // They will be created when the first message is sent
      // (via _ensureDmChatExists / sendText / _sendMedia).
      // This prevents empty chats from appearing in the chat list.

      await batch.commit();
      print('✅ ChatRepository: Created/updated DM chat $chatId');

      return chatId;
    } catch (e) {
      print('❌ ChatRepository: Error creating DM chat: $e');
      rethrow;
    }
  }

  /// Finds an existing DM with the same person (uid or employee identity).
  Future<ExistingDmMatch?> findExistingDmForUser(ChatUser candidate) async {
    final currentUid = _currentUid;
    if (currentUid == null) return null;

    final canonical =
        await UserRepository.instance.resolveCanonicalChatUser(candidate);

    try {
      final snapshot = await _userChatsCollection(currentUid)
          .where('type', isEqualTo: 'dm')
          .get();

      final peerUids = snapshot.docs
          .map((doc) => UserChat.fromFirestore(doc).peerUid)
          .whereType<String>()
          .toSet()
          .toList();
      final peers = await UserRepository.instance.getUsersByIds(peerUids);
      final peersByUid = {for (final peer in peers) peer.uid: peer};

      for (final doc in snapshot.docs) {
        final userChat = UserChat.fromFirestore(doc);
        final peerUid = userChat.peerUid;
        if (peerUid == null) continue;

        final isDirectUidMatch =
            peerUid == candidate.uid || peerUid == canonical.uid;
        final peer = peersByUid[peerUid];
        final isIdentityMatch = peer != null &&
            (UserRepository.isSameChatPerson(peer, candidate) ||
                UserRepository.isSameChatPerson(peer, canonical));

        if (!isDirectUidMatch && !isIdentityMatch) continue;

        return ExistingDmMatch(
          chatId: userChat.chatId,
          peerUid: peerUid,
          title: userChat.title ?? peer?.name ?? canonical.name,
        );
      }
    } catch (e) {
      print('❌ ChatRepository: Error finding existing DM: $e');
    }

    return null;
  }

  // ============== Role Chat Setup ==============

  /// Ensure role chat exists and current user is a member.
  /// Called during chat setup after login.
  Future<String> ensureRoleChatMembership({
    required String uid,
    required int roleId,
    int? branchId,
    int? companyId,
    String? roleChatId, // Backend-provided chat ID
    String? title, // Optional title for the group
  }) async {
    // Determine chat ID
    final chatId = roleChatId ??
        Chat.generateRoleChatId(
          roleId: roleId,
          branchId: branchId,
          groupByBranch: groupByBranch,
        );

    // Generate default title - use provided title (role name) or fallback to role ID
    final groupTitle = title ??
        'مجموعة $roleId${groupByBranch && branchId != null ? ' - فرع $branchId' : ''}';

    try {
      final batch = _firestore.batch();

      // Create/update role chat document
      final chatRef = _chatsCollection.doc(chatId);
      batch.set(
          chatRef,
          {
            'type': 'role',
            'role_id': roleId,
            'branch_id': branchId,
            'company_id': companyId,
            'title': groupTitle,
            'member_ids': FieldValue.arrayUnion([uid]),
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      // Add current user as member
      final memberRef = chatRef.collection('members').doc(uid);
      batch.set(
          memberRef,
          {
            'joined_at': FieldValue.serverTimestamp(),
            'role_id_snapshot': roleId,
            'branch_id_snapshot': branchId,
            'company_id_snapshot': companyId,
            'muted': false,
          },
          SetOptions(merge: true));

      // Create userChats entry for current user
      final userChatRef = _userChatsCollection(uid).doc(chatId);
      batch.set(
          userChatRef,
          {
            'type': 'role',
            'role_id': roleId,
            'branch_id': branchId,
            'company_id': companyId,
            'title': groupTitle,
            'updated_at': FieldValue.serverTimestamp(),
            'pinned': false,
            'muted': false,
          },
          SetOptions(merge: true));

      await batch.commit();
      print(
          '✅ ChatRepository: Ensured role chat membership for $uid in $chatId');

      // Cleanup: remove old non-branch role chat if we switched to groupByBranch
      if (groupByBranch && branchId != null) {
        final oldChatId = 'role_$roleId';
        if (oldChatId != chatId) {
          try {
            final oldUserChatDoc =
                await _userChatsCollection(uid).doc(oldChatId).get();
            if (oldUserChatDoc.exists) {
              await _userChatsCollection(uid).doc(oldChatId).delete();
              // Also remove user from old chat members
              await _chatsCollection
                  .doc(oldChatId)
                  .collection('members')
                  .doc(uid)
                  .delete();
              await _chatsCollection.doc(oldChatId).update({
                'member_ids': FieldValue.arrayRemove([uid]),
              });
              print(
                  '🧹 ChatRepository: Cleaned up old role chat $oldChatId for $uid');
            }
          } catch (e) {
            print(
                '⚠️ ChatRepository: Could not cleanup old role chat: $e');
          }
        }
      }

      return chatId;
    } catch (e) {
      print('❌ ChatRepository: Error ensuring role chat membership: $e');
      rethrow;
    }
  }

  // ============== Chat List ==============

  // ============== Support Chat (Helpdesk) ==============

  /// Create or get a support chat between a user and a department group.
  /// The user sees it as a DM with the group name.
  /// Group members see it as individual conversations per user (ticket-style).
  /// Group members can reply anonymously (user sees group name, not individual).
  Future<String> createOrGetSupportChat({
    required String userUid,
    required String userName,
    required int targetRoleId,
    required String groupTitle, // e.g. "HR"
    String? sourceRoleChatId,
    String? supportGroupKey,
    int? userRoleId,
    int? userBranchId,
    int? userCompanyId,
  }) async {
    final normalizedGroupKey = _normalizeSupportGroupKey(supportGroupKey);
    final chatId = (normalizedGroupKey != null)
        ? 'support_${normalizedGroupKey}_$userUid'
        : Chat.generateSupportChatId(
            roleId: targetRoleId,
            userUid: userUid,
          );

    try {
      final batch = _firestore.batch();

      // Create/update support chat document
      final chatRef = _chatsCollection.doc(chatId);
      batch.set(
          chatRef,
          {
            'type': 'support',
            'role_id': targetRoleId,
            'support_user_uid': userUid,
            'title': groupTitle,
            'member_ids': FieldValue.arrayUnion([userUid]),
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      // Add the external user as member
      final userMemberRef = chatRef.collection('members').doc(userUid);
      batch.set(
          userMemberRef,
          {
            'joined_at': FieldValue.serverTimestamp(),
            'role_id_snapshot': userRoleId,
            'branch_id_snapshot': userBranchId,
            'company_id_snapshot': userCompanyId,
            'muted': false,
            'is_support_user': true, // Mark as the external user
          },
          SetOptions(merge: true));

      // Create userChats entry for the external user (sees group name)
      final userChatRef = _userChatsCollection(userUid).doc(chatId);
      batch.set(
          userChatRef,
          {
            'type': 'support',
            'role_id': targetRoleId,
            'title': groupTitle, // User sees "HR Group"
            'support_user_uid': userUid,
            'support_group_title': groupTitle,
            'updated_at': FieldValue.serverTimestamp(),
            'pinned': false,
            'muted': false,
          },
          SetOptions(merge: true));

      await batch.commit();

      // Now add all role group members to this support chat
      await _addRoleMembersToSupportChat(
        chatId: chatId,
        targetRoleId: targetRoleId,
        userName: userName,
        userUid: userUid,
        groupTitle: groupTitle,
        sourceRoleChatId: sourceRoleChatId,
      );

      print('✅ ChatRepository: Created/updated support chat $chatId');
      return chatId;
    } catch (e) {
      print('❌ ChatRepository: Error creating support chat: $e');
      rethrow;
    }
  }

  /// Add all members of a role group to a support chat.
  /// Each group member sees the chat titled with the user's name (ticket-style).
  Future<void> _addRoleMembersToSupportChat({
    required String chatId,
    required int targetRoleId,
    required String userName,
    required String userUid,
    required String groupTitle,
    String? sourceRoleChatId,
  }) async {
    try {
      // Find the role chat to get its members
      final roleChatId =
          sourceRoleChatId ?? Chat.generateRoleChatId(roleId: targetRoleId);
      final membersSnapshot =
          await _chatsCollection.doc(roleChatId).collection('members').get();

      if (membersSnapshot.docs.isEmpty) {
        print('⚠️ ChatRepository: No members found in role chat $roleChatId');
        return;
      }

      final batch = _firestore.batch();
      final memberUids = <String>[];

      for (final memberDoc in membersSnapshot.docs) {
        final memberUid = memberDoc.id;
        if (memberUid == userUid)
          continue; // Skip the external user (already added)

        memberUids.add(memberUid);
        final memberData = memberDoc.data();

        // Add as member of support chat
        final memberRef =
            _chatsCollection.doc(chatId).collection('members').doc(memberUid);
        batch.set(
            memberRef,
            {
              'joined_at': FieldValue.serverTimestamp(),
              'role_id_snapshot': memberData['role_id_snapshot'],
              'branch_id_snapshot': memberData['branch_id_snapshot'],
              'company_id_snapshot': memberData['company_id_snapshot'],
              'muted': false,
              'is_support_user': false, // Mark as group member
            },
            SetOptions(merge: true));

        // Create userChats entry for group member (sees user's name)
        final memberChatRef = _userChatsCollection(memberUid).doc(chatId);
        batch.set(
            memberChatRef,
            {
              'type': 'support',
              'role_id': targetRoleId,
              'title': userName, // Group member sees "محمد أحمد"
              'peer_uid': userUid, // To identify the external user
              'support_user_uid': userUid,
              'support_group_title': groupTitle,
              'updated_at': FieldValue.serverTimestamp(),
              'pinned': false,
              'muted': false,
            },
            SetOptions(merge: true));
      }

      // Update chat member_ids array
      if (memberUids.isNotEmpty) {
        batch.update(_chatsCollection.doc(chatId), {
          'member_ids': FieldValue.arrayUnion(memberUids),
        });
      }

      await batch.commit();
      print(
          '✅ ChatRepository: Added ${memberUids.length} role members to support chat $chatId');
    } catch (e) {
      print('❌ ChatRepository: Error adding role members to support chat: $e');
    }
  }

  /// Get all available role groups for support chat.
  /// Returns role chats that the current user is NOT a member of.
  Future<List<Chat>> getAvailableSupportGroups() async {
    final currentUid = _currentUid;
    if (currentUid == null) return [];

    try {
      // Get all role chats
      final roleChatSnapshot =
          await _chatsCollection.where('type', isEqualTo: 'role').get();

      final availableGroups = <Chat>[];

      for (final doc in roleChatSnapshot.docs) {
        // Check if current user is NOT a member of this role chat
        final memberDoc =
            await doc.reference.collection('members').doc(currentUid).get();

        if (!memberDoc.exists) {
          availableGroups.add(Chat.fromFirestore(doc));
        }
      }

      return deduplicateDepartmentGroups(availableGroups);
    } catch (e) {
      print('❌ ChatRepository: Error getting available support groups: $e');
      return [];
    }
  }

  /// Get ALL role groups (for support tab — show every department).
  /// Duplicate department names (e.g. two "Project Managers") are collapsed.
  Future<List<Chat>> getAllRoleGroups() async {
    try {
      final roleChatsSnapshot =
          await _chatsCollection.where('type', isEqualTo: 'role').get();

      final roleChats = roleChatsSnapshot.docs
          .map(Chat.fromFirestore)
          .where((chat) => chat.roleId != null)
          .toList();

      if (roleChats.isNotEmpty) {
        return deduplicateDepartmentGroups(roleChats);
      }

      // Fallback for legacy data when role chat docs are not available yet.
      final usersSnapshot = await _firestore.collection('users').get();
      final Map<int, String> roleMap = {};
      for (final doc in usersSnapshot.docs) {
        final data = doc.data();
        final roleId = data['role_id'];
        if (roleId == null || roleId == 0) continue;
        if (roleMap.containsKey(roleId)) continue;
        final roleName = data['role_name']?.toString();
        roleMap[roleId as int] = roleName ?? 'Department $roleId';
      }

      return deduplicateDepartmentGroups(
        roleMap.entries
            .map((e) => Chat(
                  id: Chat.generateRoleChatId(roleId: e.key),
                  type: ChatType.role,
                  roleId: e.key,
                  title: e.value,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ))
            .toList(),
      );
    } catch (e) {
      print('❌ ChatRepository: Error getting all role groups: $e');
      return [];
    }
  }

  String? _normalizeNullableString(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();
    if (lower == 'null' || lower == 'false' || lower == 'n/a') return null;
    return trimmed;
  }

  /// Display title for a chat list row (prefers live chat doc / catalog).
  String resolveUserChatDisplayTitle(
    UserChat userChat, {
    Chat? chatDoc,
    Iterable<Chat> roleCatalog = const [],
  }) {
    if (userChat.type == ChatType.support) {
      return _normalizeNullableString(userChat.supportGroupTitle) ??
          _normalizeNullableString(chatDoc?.title) ??
          _normalizeNullableString(userChat.title) ??
          'Support';
    }

    if (userChat.type == ChatType.role || userChat.type == ChatType.group) {
      final fromDoc = _normalizeNullableString(chatDoc?.title);
      if (fromDoc != null) return fromDoc;

      final roleId = userChat.roleId;
      if (roleId != null) {
        for (final group in roleCatalog) {
          if (group.roleId == roleId) {
            final catalogTitle = _normalizeNullableString(group.title);
            if (catalogTitle != null) return catalogTitle;
          }
        }
      }

      final fromIndex = _normalizeNullableString(userChat.title);
      if (fromIndex != null) return fromIndex;
      if (roleId != null) return 'Department $roleId';
      return 'Department';
    }

    return _normalizeNullableString(userChat.title) ?? 'Chat';
  }

  String? _normalizeSupportGroupKey(String? rawKey) {
    if (rawKey == null) return null;
    final trimmed = rawKey.trim();
    if (trimmed.isEmpty) return null;
    final normalized = trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return normalized.isEmpty ? null : normalized;
  }

  /// Normalized key for deduplicating department/role groups by visible name.
  String _departmentGroupTitleKey({String? title, int? roleId, String? chatId}) {
    final normalized =
        (title ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isNotEmpty) return normalized;
    if (roleId != null) return 'role_$roleId';
    return chatId ?? '';
  }

  /// Prefer canonical `role_{id}` docs over legacy branch duplicates.
  int _departmentGroupPreferenceRank(Chat chat) {
    if (RegExp(r'^role_\d+$').hasMatch(chat.id)) return 0;
    if (!chat.id.contains('_branch_')) return 1;
    return 2;
  }

  /// Remove duplicate department groups (e.g. two "Project Managers").
  List<Chat> deduplicateDepartmentGroups(List<Chat> groups) {
    if (groups.length <= 1) return groups;

    final sorted = List<Chat>.from(groups)
      ..sort((a, b) {
        final rankCompare = _departmentGroupPreferenceRank(a)
            .compareTo(_departmentGroupPreferenceRank(b));
        if (rankCompare != 0) return rankCompare;
        return b.updatedAt.compareTo(a.updatedAt);
      });

    final uniqueByTitle = <String, Chat>{};
    final seenRoleIds = <int>{};

    for (final chat in sorted) {
      final roleId = chat.roleId;
      if (roleId != null && seenRoleIds.contains(roleId)) {
        continue;
      }

      final titleKey = _departmentGroupTitleKey(
        title: chat.title,
        roleId: roleId,
        chatId: chat.id,
      );
      if (titleKey.isEmpty || uniqueByTitle.containsKey(titleKey)) {
        continue;
      }

      uniqueByTitle[titleKey] = chat;
      if (roleId != null) {
        seenRoleIds.add(roleId);
      }
    }

    final result = uniqueByTitle.values.toList()
      ..sort((a, b) => (a.title ?? '').compareTo(b.title ?? ''));
    return result;
  }

  int _departmentUserChatPreferenceRank(UserChat chat) {
    if (RegExp(r'^role_\d+$').hasMatch(chat.chatId)) return 0;
    if (!chat.chatId.contains('_branch_')) return 1;
    return 2;
  }

  /// Same as [deduplicateDepartmentGroups] for entries in the user's chat list.
  List<UserChat> deduplicateDepartmentUserChats(List<UserChat> chats) {
    if (chats.length <= 1) return chats;

    final sorted = List<UserChat>.from(chats)
      ..sort((a, b) {
        final rankCompare = _departmentUserChatPreferenceRank(a)
            .compareTo(_departmentUserChatPreferenceRank(b));
        if (rankCompare != 0) return rankCompare;
        return b.updatedAt.compareTo(a.updatedAt);
      });

    final uniqueByTitle = <String, UserChat>{};
    final seenRoleIds = <int>{};

    for (final chat in sorted) {
      final roleId = chat.roleId;
      if (roleId != null && seenRoleIds.contains(roleId)) {
        continue;
      }

      final titleKey = _departmentGroupTitleKey(
        title: chat.title,
        roleId: roleId,
        chatId: chat.chatId,
      );
      if (titleKey.isEmpty || uniqueByTitle.containsKey(titleKey)) {
        continue;
      }

      uniqueByTitle[titleKey] = chat;
      if (roleId != null) {
        seenRoleIds.add(roleId);
      }
    }

    final result = uniqueByTitle.values.toList()
      ..sort((a, b) => (a.title ?? '').compareTo(b.title ?? ''));
    return result;
  }

  /// Check if the current user is the support user (external) in a support chat.
  Future<bool> isSupportUser(String chatId) async {
    final currentUid = _currentUid;
    if (currentUid == null) return false;

    try {
      final chatDoc = await _chatsCollection.doc(chatId).get();
      if (!chatDoc.exists) return false;
      final data = chatDoc.data() as Map<String, dynamic>? ?? {};
      return data['support_user_uid'] == currentUid;
    } catch (e) {
      return false;
    }
  }

  /// Get role member UIDs for a support chat (for updating all member userChats on new message)
  Future<List<String>> _getSupportChatMemberUids(String chatId) async {
    try {
      final snapshot =
          await _chatsCollection.doc(chatId).collection('members').get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      return [];
    }
  }

  /// Infer chat type from the canonical chat ID prefix.
  ChatType inferChatTypeFromChatId(String chatId) {
    if (chatId.startsWith('dm_')) return ChatType.dm;
    if (chatId.startsWith('support_')) return ChatType.support;
    if (chatId.startsWith('role_')) return ChatType.role;
    return ChatType.group;
  }

  int? roleIdFromChatId(String chatId) {
    final match = RegExp(r'^role_(\d+)').firstMatch(chatId);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  /// Rows that look like DMs but are mis-indexed department/support chats.
  bool isGhostListEntry(UserChat userChat) {
    if (userChat.chatId.startsWith('role_') ||
        userChat.chatId.startsWith('support_')) {
      return userChat.type == ChatType.dm;
    }
    if (userChat.chatId.startsWith('dm_') &&
        (userChat.peerUid == null || userChat.peerUid!.trim().isEmpty)) {
      return true;
    }
    if (userChat.type == ChatType.dm &&
        (userChat.peerUid == null || userChat.peerUid!.trim().isEmpty)) {
      return !userChat.chatId.startsWith('dm_');
    }
    return false;
  }

  /// Fix type/peer/role locally from chatId (no network).
  UserChat normalizeUserChatIndex(String uid, UserChat userChat) {
    var resolvedType = inferChatTypeFromChatId(userChat.chatId);
    if (userChat.chatId.startsWith('dm_')) {
      resolvedType = ChatType.dm;
    }

    String? resolvedPeerUid = userChat.peerUid;
    if (resolvedType == ChatType.dm &&
        (resolvedPeerUid == null || resolvedPeerUid.trim().isEmpty)) {
      final dmPair = _parseDmPair(userChat.chatId, uid);
      if (dmPair != null) {
        resolvedPeerUid =
            dmPair.firstWhere((id) => id != uid, orElse: () => '');
        if (resolvedPeerUid.isEmpty) resolvedPeerUid = null;
      }
    }

    final resolvedRoleId =
        userChat.roleId ?? roleIdFromChatId(userChat.chatId);

    return userChat.copyWith(
      type: resolvedType,
      peerUid: resolvedPeerUid,
      roleId: resolvedRoleId,
    );
  }

  /// Whether a chat should appear in the main conversation list.
  bool shouldShowInConversationList(UserChat userChat, {String? uid}) {
    final chat =
        uid != null ? normalizeUserChatIndex(uid, userChat) : userChat;

    if (isGhostListEntry(chat)) return false;
    if (!chat.hasMessages) return false;

    // DMs are shown by peer identity; department rows need a real title.
    if (chat.type == ChatType.dm) {
      return chat.peerUid != null && chat.peerUid!.trim().isNotEmpty;
    }
    if (chat.type == ChatType.role || chat.type == ChatType.group) {
      return _normalizeNullableString(chat.title) != null;
    }
    return true;
  }

  /// One-shot cleanup of broken userChats rows (run when opening chat list).
  Future<void> repairUserChatIndex(String uid) async {
    print('🔧 ChatRepository: repairUserChatIndex start ($uid)');
    try {
      final snapshot = await _userChatsCollection(uid).get();
      var deleted = 0;
      var patched = 0;

      for (final doc in snapshot.docs) {
        final raw = UserChat.fromFirestore(doc);
        final normalized = normalizeUserChatIndex(uid, raw);

        Map<String, dynamic>? chatData;
        try {
          final chatDoc = await _chatsCollection.doc(normalized.chatId).get();
          chatData = chatDoc.data();
        } catch (e) {
          print(
              '⚠️ ChatRepository: repair read failed for ${normalized.chatId}: $e');
        }

        final hasLastMessage =
            chatData != null && chatData['last_message'] != null;

        bool hasSubcollectionMessage = false;
        if (!hasLastMessage) {
          try {
            final msgSnap = await _chatsCollection
                .doc(normalized.chatId)
                .collection('messages')
                .limit(1)
                .get();
            hasSubcollectionMessage = msgSnap.docs.isNotEmpty;
          } catch (_) {}
        }

        final hasRealActivity = hasLastMessage || hasSubcollectionMessage;

        final shouldDelete = !hasRealActivity &&
            (normalized.chatId.startsWith('role_') ||
                normalized.chatId.startsWith('support_') ||
                isGhostListEntry(normalized) ||
                normalized.chatId.startsWith('dm_'));

        if (shouldDelete) {
          try {
            await doc.reference.delete();
            deleted++;
            print(
                '🧹 ChatRepository: repair deleted empty index ${normalized.chatId}');
          } catch (e) {
            print(
                '⚠️ ChatRepository: repair delete failed ${normalized.chatId}: $e');
          }
          continue;
        }

        final patch = <String, dynamic>{};
        if (raw.type != normalized.type) {
          patch['type'] = normalized.type.toJson();
        }
        if (normalized.peerUid != null && normalized.peerUid != raw.peerUid) {
          patch['peer_uid'] = normalized.peerUid;
        }
        if (normalized.roleId != null && normalized.roleId != raw.roleId) {
          patch['role_id'] = normalized.roleId;
        }
        final chatTitle =
            _normalizeNullableString(chatData?['title']?.toString());
        if (_normalizeNullableString(raw.title) == null && chatTitle != null) {
          patch['title'] = chatTitle;
        }
        if (raw.hasMessages != hasRealActivity) {
          patch['has_messages'] = hasRealActivity;
        }

        if (patch.isNotEmpty) {
          await doc.reference.set(patch, SetOptions(merge: true));
          patched++;
        }
      }

      await _pruneDuplicateDepartmentIndexEntries(uid, snapshot.docs
          .map((d) => normalizeUserChatIndex(uid, UserChat.fromFirestore(d)))
          .toList());

      print(
          '✅ ChatRepository: repairUserChatIndex done (deleted=$deleted, patched=$patched)');
    } catch (e) {
      print('❌ ChatRepository: repairUserChatIndex failed: $e');
    }
  }

  /// Get user's chat list stream.
  Stream<List<UserChat>> subscribeToUserChats(String uid) {
    return _userChatsCollection(uid)
        .orderBy('updated_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) =>
              normalizeUserChatIndex(uid, UserChat.fromFirestore(doc)))
          .toList();
    });
  }

  Future<UserChat> _reconcileUserChatIndexEntry(
    String uid,
    UserChat userChat,
  ) async {
    try {
      final chatDoc = await _chatsCollection.doc(userChat.chatId).get();
      final data = chatDoc.data();

      var resolvedType = inferChatTypeFromChatId(userChat.chatId);
      if (data != null) {
        resolvedType = ChatType.fromString(
          data['type']?.toString() ?? resolvedType.toJson(),
        );
      } else if (userChat.type != ChatType.dm || userChat.peerUid != null) {
        resolvedType = userChat.type;
      }

      final hasActivity = data != null && data['last_message'] != null;
      final chatTitle = _normalizeNullableString(data?['title']?.toString());
      final indexTitle = _normalizeNullableString(userChat.title);

      String? resolvedPeerUid = userChat.peerUid;
      if (resolvedType == ChatType.dm &&
          (resolvedPeerUid == null || resolvedPeerUid.isEmpty)) {
        final dmPair = _parseDmPair(userChat.chatId, uid);
        if (dmPair != null) {
          resolvedPeerUid =
              dmPair.firstWhere((id) => id != uid, orElse: () => '');
          if (resolvedPeerUid.isEmpty) resolvedPeerUid = null;
        }
      }

      int? resolvedRoleId = userChat.roleId ?? roleIdFromChatId(userChat.chatId);
      if (resolvedRoleId == null && data?['role_id'] != null) {
        resolvedRoleId = data!['role_id'] as int?;
      }

      final patch = <String, dynamic>{};
      if (userChat.type != resolvedType) {
        patch['type'] = resolvedType.toJson();
      }
      if (indexTitle == null && chatTitle != null) {
        patch['title'] = chatTitle;
      }
      if (resolvedPeerUid != null && resolvedPeerUid != userChat.peerUid) {
        patch['peer_uid'] = resolvedPeerUid;
      }
      if (resolvedRoleId != null && resolvedRoleId != userChat.roleId) {
        patch['role_id'] = resolvedRoleId;
      }
      if (userChat.hasMessages != hasActivity) {
        patch['has_messages'] = hasActivity;
      }

      if (patch.isNotEmpty) {
        await _userChatsCollection(uid)
            .doc(userChat.chatId)
            .set(patch, SetOptions(merge: true));
      }

      return userChat.copyWith(
        type: resolvedType,
        title: chatTitle ?? indexTitle ?? userChat.title,
        peerUid: resolvedPeerUid,
        roleId: resolvedRoleId,
        hasMessages: hasActivity,
      );
    } catch (_) {
      return userChat;
    }
  }

  /// Delete duplicate empty department rows from userChats (legacy data).
  Future<Set<String>> _pruneDuplicateDepartmentIndexEntries(
    String uid,
    List<UserChat> chats,
  ) async {
    final deletedIds = <String>{};

    for (final entry in chats) {
      if (!isGhostListEntry(entry) || entry.hasMessages) continue;
      try {
        await _userChatsCollection(uid).doc(entry.chatId).delete();
        deletedIds.add(entry.chatId);
        print(
            '🧹 ChatRepository: Removed ghost list index ${entry.chatId}');
      } catch (e) {
        print('⚠️ ChatRepository: Failed removing ghost ${entry.chatId}: $e');
      }
    }

    final roleEntries = chats
        .where((c) => !deletedIds.contains(c.chatId))
        .where((c) =>
            c.chatId.startsWith('role_') ||
            c.type == ChatType.role ||
            c.type == ChatType.group)
        .toList();

    final buckets = <int, List<UserChat>>{};
    for (final entry in roleEntries) {
      final roleId = entry.roleId ?? roleIdFromChatId(entry.chatId);
      if (roleId == null) continue;
      buckets.putIfAbsent(roleId, () => []).add(entry);
    }

    for (final entries in buckets.values) {
      if (entries.length <= 1) continue;

      final sorted = List<UserChat>.from(entries)
        ..sort((a, b) {
          if (a.hasMessages != b.hasMessages) {
            return a.hasMessages ? -1 : 1;
          }
          final rank = _departmentUserChatPreferenceRank(a)
              .compareTo(_departmentUserChatPreferenceRank(b));
          if (rank != 0) return rank;
          return b.updatedAt.compareTo(a.updatedAt);
        });

      for (var i = 1; i < sorted.length; i++) {
        final duplicate = sorted[i];
        if (duplicate.hasMessages) continue;
        try {
          await _userChatsCollection(uid).doc(duplicate.chatId).delete();
          deletedIds.add(duplicate.chatId);
          print(
              '🧹 ChatRepository: Removed duplicate empty department index ${duplicate.chatId}');
        } catch (e) {
          print('⚠️ ChatRepository: Failed pruning ${duplicate.chatId}: $e');
        }
      }
    }
    return deletedIds;
  }

  Map<String, dynamic> _senderUserChatPatch({
    required String chatId,
    required String currentUid,
    String? dmOtherUid,
  }) {
    final type = inferChatTypeFromChatId(chatId);
    final patch = <String, dynamic>{
      'type': type.toJson(),
      'updated_at': FieldValue.serverTimestamp(),
      'has_messages': true,
    };

    if (type == ChatType.dm && dmOtherUid != null && dmOtherUid.isNotEmpty) {
      patch['peer_uid'] = dmOtherUid;
    }
    final roleId = roleIdFromChatId(chatId);
    if (roleId != null) {
      patch['role_id'] = roleId;
    }
    return patch;
  }

  /// Get a specific chat
  Future<Chat?> getChat(String chatId) async {
    try {
      final doc = await _chatsCollection.doc(chatId).get();
      if (!doc.exists) return null;
      return Chat.fromFirestore(doc);
    } catch (e) {
      print('❌ ChatRepository: Error getting chat: $e');
      return null;
    }
  }

  /// Get user's chat entry (for checking mute status, etc.)
  Future<UserChat?> getUserChat(String chatId) async {
    final uid = _currentUid;
    if (uid == null) return null;

    try {
      final doc = await _userChatsCollection(uid).doc(chatId).get();
      if (!doc.exists) return null;
      return UserChat.fromFirestore(doc);
    } catch (e) {
      print('❌ ChatRepository: Error getting user chat: $e');
      return null;
    }
  }

  /// Subscribe to a specific chat
  Stream<Chat?> subscribeToChat(String chatId) {
    return _chatsCollection.doc(chatId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Chat.fromFirestore(doc);
    });
  }

  // ============== Messages ==============

  /// Subscribe to messages in a chat with pagination
  Stream<List<Message>> subscribeToMessages(
    String chatId, {
    int pageSize = defaultPageSize,
    DocumentSnapshot? startAfter,
  }) {
    Query<Map<String, dynamic>> query = _chatsCollection
        .doc(chatId)
        .collection('messages')
        .orderBy('created_at', descending: true)
        .limit(pageSize);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query.snapshots().map((snapshot) {
      final now = DateTime.now();
      return snapshot.docs
          .map((doc) => Message.fromFirestore(doc))
          .where((msg) {
        // Filter out expired unsigned signable docs
        if (msg.type == MessageType.signableDoc &&
            msg.signStatus != SignStatus.signed &&
            msg.expiresAt != null &&
            now.isAfter(msg.expiresAt!)) {
          return false;
        }
        return true;
      }).toList();
    });
  }

  /// Load more messages (for pagination)
  Future<List<Message>> loadMoreMessages(
    String chatId, {
    required DocumentSnapshot startAfter,
    int pageSize = defaultPageSize,
  }) async {
    try {
      final snapshot = await _chatsCollection
          .doc(chatId)
          .collection('messages')
          .orderBy('created_at', descending: true)
          .startAfterDocument(startAfter)
          .limit(pageSize)
          .get();

      return snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList();
    } catch (e) {
      print('❌ ChatRepository: Error loading more messages: $e');
      return [];
    }
  }

  /// Get a single message by ID from a chat.
  Future<Message?> getMessageById(String chatId, String messageId) async {
    try {
      final doc = await _chatsCollection
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .get();

      if (!doc.exists) return null;

      final message = Message.fromFirestore(doc);
      final now = DateTime.now();

      // Keep behavior consistent with subscribeToMessages filter.
      if (message.type == MessageType.signableDoc &&
          message.signStatus != SignStatus.signed &&
          message.expiresAt != null &&
          now.isAfter(message.expiresAt!)) {
        return null;
      }

      return message;
    } catch (e) {
      print('❌ ChatRepository: Error getting message by ID: $e');
      return null;
    }
  }

  /// Get a window of messages around a timestamp.
  /// Useful when direct document get is blocked or unavailable.
  Future<List<Message>> getMessagesAroundCreatedAt(
    String chatId,
    DateTime anchor, {
    int windowSize = 400,
  }) async {
    try {
      final anchorTs = Timestamp.fromDate(anchor);
      final halfWindow = (windowSize / 2).round();

      final olderOrEqualFuture = _chatsCollection
          .doc(chatId)
          .collection('messages')
          .where('created_at', isLessThanOrEqualTo: anchorTs)
          .orderBy('created_at', descending: true)
          .limit(halfWindow)
          .get();

      final newerFuture = _chatsCollection
          .doc(chatId)
          .collection('messages')
          .where('created_at', isGreaterThan: anchorTs)
          .orderBy('created_at', descending: false)
          .limit(halfWindow)
          .get();

      final results = await Future.wait([olderOrEqualFuture, newerFuture]);
      final olderOrEqual = results[0].docs;
      final newer = results[1].docs;

      final Map<String, Message> byId = {};
      final now = DateTime.now();

      for (final doc in [...olderOrEqual, ...newer]) {
        final msg = Message.fromFirestore(doc);
        if (msg.type == MessageType.signableDoc &&
            msg.signStatus != SignStatus.signed &&
            msg.expiresAt != null &&
            now.isAfter(msg.expiresAt!)) {
          continue;
        }
        byId[msg.id] = msg;
      }

      final merged = byId.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return merged;
    } catch (e) {
      print('❌ ChatRepository: Error getting messages around created_at: $e');
      return [];
    }
  }

  /// Find a message for starred navigation by scanning paginated message history.
  /// Tries exact ID first, then metadata matching as a fallback.
  Future<Message?> findMessageForStarredNavigation(
    String chatId, {
    String? messageId,
    DateTime? createdAt,
    String? senderId,
    String? type,
    String? text,
    String? fileName,
    int pageSize = 300,
    int maxPages = 80,
  }) async {
    try {
      print('🔎 STAR_JUMP[repo]: find start '
          'chatId=$chatId messageId=$messageId createdAt=$createdAt '
          'senderId=$senderId type=$type fileName=$fileName '
          'textLen=${text?.length ?? 0} pageSize=$pageSize maxPages=$maxPages');

      final normalizedMessageId = messageId?.trim();
      final expectedSender = senderId?.trim();
      final expectedTypeRaw = type?.trim();
      final expectedText = text?.trim();
      final expectedFileName = fileName?.trim();

      MessageType? expectedType;
      if (expectedTypeRaw != null && expectedTypeRaw.isNotEmpty) {
        expectedType = MessageType.fromString(expectedTypeRaw);
      }

      if (normalizedMessageId != null &&
          normalizedMessageId.isNotEmpty &&
          !normalizedMessageId.startsWith('pending_')) {
        final exact = await getMessageById(chatId, normalizedMessageId);
        if (exact != null) {
          print('✅ STAR_JUMP[repo]: exact id match found id=${exact.id}');
          return exact;
        }
        print(
            '⚠️ STAR_JUMP[repo]: exact id not found for id=$normalizedMessageId');
      }

      // For legacy starred entries where message_id may be missing/invalid,
      // anchor around created_at first for a deterministic nearby lookup.
      if (createdAt != null) {
        final around = await getMessagesAroundCreatedAt(
          chatId,
          createdAt,
          windowSize: 1200,
        );

        final aroundMatches = around.where((msg) {
          return _matchesStarredDescriptor(
            msg,
            expectedSender: expectedSender,
            expectedType: expectedType,
            expectedText: expectedText,
            expectedFileName: expectedFileName,
          );
        }).toList();

        if (aroundMatches.isNotEmpty) {
          aroundMatches.sort((a, b) {
            final da = a.createdAt.difference(createdAt).inMilliseconds.abs();
            final db = b.createdAt.difference(createdAt).inMilliseconds.abs();
            return da.compareTo(db);
          });
          print('✅ STAR_JUMP[repo]: around(created_at) matched '
              'count=${aroundMatches.length} selected=${aroundMatches.first.id}');
          return aroundMatches.first;
        }
        print('⚠️ STAR_JUMP[repo]: around(created_at) returned 0 matches');
      }

      QueryDocumentSnapshot<Map<String, dynamic>>? lastDoc;
      final now = DateTime.now();
      final candidates = <Message>[];

      for (int page = 0; page < maxPages; page++) {
        Query<Map<String, dynamic>> query = _chatsCollection
            .doc(chatId)
            .collection('messages')
            .orderBy('created_at', descending: true)
            .limit(pageSize);

        if (lastDoc != null) {
          query = query.startAfterDocument(lastDoc);
        }

        final snapshot = await query.get();
        if (snapshot.docs.isEmpty) break;

        if (page == 0 || page % 10 == 0) {
          print('🔎 STAR_JUMP[repo]: scanning page=${page + 1} '
              'docs=${snapshot.docs.length} candidates=${candidates.length}');
        }

        for (final doc in snapshot.docs) {
          final msg = Message.fromFirestore(doc);

          if (msg.type == MessageType.signableDoc &&
              msg.signStatus != SignStatus.signed &&
              msg.expiresAt != null &&
              now.isAfter(msg.expiresAt!)) {
            continue;
          }

          if (normalizedMessageId != null &&
              normalizedMessageId.isNotEmpty &&
              msg.id == normalizedMessageId) {
            return msg;
          }

          if (_matchesStarredDescriptor(
            msg,
            expectedSender: expectedSender,
            expectedType: expectedType,
            expectedText: expectedText,
            expectedFileName: expectedFileName,
          )) {
            candidates.add(msg);
          }
        }

        lastDoc = snapshot.docs.last;
        if (snapshot.docs.length < pageSize) break;
      }

      if (candidates.isEmpty) {
        // Last-resort resolver: jump to the closest message by time so starred
        // navigation always lands near the intended message instead of opening
        // chat without any jump.
        if (createdAt != null) {
          final around = await getMessagesAroundCreatedAt(
            chatId,
            createdAt,
            windowSize: 1200,
          );
          if (around.isNotEmpty) {
            around.sort((a, b) {
              final da = a.createdAt.difference(createdAt).inMilliseconds.abs();
              final db = b.createdAt.difference(createdAt).inMilliseconds.abs();
              return da.compareTo(db);
            });
            print('✅ STAR_JUMP[repo]: fallback nearest-by-time selected '
                'id=${around.first.id} totalNearby=${around.length}');
            return around.first;
          }
          print(
              '❌ STAR_JUMP[repo]: fallback nearest-by-time found no nearby messages');
        }
        print('❌ STAR_JUMP[repo]: no candidates found');
        return null;
      }
      if (createdAt == null) {
        print('✅ STAR_JUMP[repo]: candidates found without anchor date '
            'count=${candidates.length} selected=${candidates.first.id}');
        return candidates.first;
      }

      candidates.sort((a, b) {
        final da = a.createdAt.difference(createdAt).inMilliseconds.abs();
        final db = b.createdAt.difference(createdAt).inMilliseconds.abs();
        return da.compareTo(db);
      });
      print('✅ STAR_JUMP[repo]: candidates sorted by anchor date '
          'count=${candidates.length} selected=${candidates.first.id}');
      return candidates.first;
    } catch (e) {
      print('❌ ChatRepository: Error finding starred target message: $e');
      print(
          '❌ STAR_JUMP[repo]: find crashed chatId=$chatId messageId=$messageId');
      return null;
    }
  }

  bool _matchesStarredDescriptor(
    Message message, {
    String? expectedSender,
    MessageType? expectedType,
    String? expectedText,
    String? expectedFileName,
  }) {
    if (expectedSender != null &&
        expectedSender.isNotEmpty &&
        message.senderId != expectedSender) {
      final hasOtherHints = (expectedText != null && expectedText.isNotEmpty) ||
          (expectedFileName != null && expectedFileName.isNotEmpty);
      if (!hasOtherHints) {
        return false;
      }
    }

    if (expectedType != null && message.type != expectedType) {
      return false;
    }

    if (expectedType == MessageType.text &&
        expectedText != null &&
        expectedText.isNotEmpty) {
      final normalizedMessageText = _normalizeText(message.text);
      final normalizedExpectedText = _normalizeText(expectedText);

      // Text content can differ slightly after serialization/normalization.
      // Keep strict/partial checks first, then allow created_at proximity
      // (done by caller) instead of rejecting the candidate outright.
      if (normalizedMessageText.isNotEmpty &&
          normalizedExpectedText.isNotEmpty) {
        if (normalizedMessageText != normalizedExpectedText &&
            !normalizedMessageText.contains(normalizedExpectedText) &&
            !normalizedExpectedText.contains(normalizedMessageText)) {
          // Do not return false here.
        }
      }
    }

    if ((expectedType == MessageType.file ||
            expectedType == MessageType.signableDoc) &&
        expectedFileName != null &&
        expectedFileName.isNotEmpty) {
      if ((message.fileName ?? '').trim() != expectedFileName) {
        return false;
      }
    }

    return true;
  }

  String _normalizeText(String? value) {
    if (value == null) return '';
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Send a text message
  Future<Message> sendText(String chatId, String text,
      {ReplyTo? replyTo}) async {
    final currentUid = _currentUid;
    if (currentUid == null) {
      throw Exception('Not authenticated');
    }

    final clientMsgId = _uuid.v4();
    final messageRef =
        _chatsCollection.doc(chatId).collection('messages').doc();

    final message = Message(
      id: messageRef.id,
      senderId: currentUid,
      type: MessageType.text,
      text: text,
      createdAt: DateTime.now(),
      clientMsgId: clientMsgId,
      replyTo: replyTo,
      status: MessageStatus.sending,
    );

    try {
      // For DM chats: ensure chat document + both userChats entries exist
      String? _dmOtherUid;
      List<String>? _dmPair;
      if (chatId.startsWith('dm_')) {
        _dmPair = _parseDmPair(chatId, currentUid);
        if (_dmPair != null) {
          _dmOtherUid =
              _dmPair.firstWhere((u) => u != currentUid, orElse: () => '');
        }
        await _ensureDmChatExists(chatId);
      }

      final batch = _firestore.batch();

      // Add message
      batch.set(messageRef, message.toFirestore());

      // Update chat last_message and updated_at
      final chatRef = _chatsCollection.doc(chatId);
      final chatUpdate = <String, dynamic>{
        'last_message': {
          'text': text,
          'type': 'text',
          'sender_id': currentUid,
          'created_at': FieldValue.serverTimestamp(),
        },
        'updated_at': FieldValue.serverTimestamp(),
      };
      // Always include member_ids + dm_pair for DM chats so the doc is valid
      // even if _ensureDmChatExists partially failed
      if (_dmPair != null) {
        chatUpdate['type'] = 'dm';
        chatUpdate['dm_pair'] = _dmPair;
        chatUpdate['member_ids'] = FieldValue.arrayUnion(_dmPair);
      }
      batch.set(chatRef, chatUpdate, SetOptions(merge: true));

      // Update sender's userChats entry
      batch.set(
        _userChatsCollection(currentUid).doc(chatId),
        _senderUserChatPatch(
          chatId: chatId,
          currentUid: currentUid,
          dmOtherUid: _dmOtherUid,
        ),
        SetOptions(merge: true),
      );

      await batch.commit();

      // For DM chats, also update the other user's userChats timestamp
      if (chatId.startsWith('dm_')) {
        _updateDmPeerTimestamp(chatId, currentUid);
      }

      // For support chats, update all members' userChats timestamps
      if (chatId.startsWith('support_')) {
        _updateSupportChatMemberTimestamps(chatId, currentUid);
      }

      // Clear typing status
      await PresenceService.instance.setTyping(chatId, false);

      return message.copyWith(status: MessageStatus.sent);
    } catch (e) {
      print('❌ ChatRepository: Error sending text message: $e');
      rethrow;
    }
  }

  /// Ensure DM chat doc, member entries, and both users' userChats entries exist.
  /// Uses set(merge) everywhere so it's idempotent and works whether docs
  /// exist or not. Individual writes so a failure on one doesn't block others.
  Future<void> _ensureDmChatExists(String chatId) async {
    final currentUid = _currentUid;
    if (currentUid == null) return;

    final dmPair = _parseDmPair(chatId, currentUid);
    if (dmPair == null) {
      print('⚠️ _ensureDmChatExists: Cannot parse UIDs from $chatId');
      return;
    }

    final otherUid =
        dmPair.firstWhere((u) => u != currentUid, orElse: () => '');
    if (otherUid.isEmpty) return;

    print(
        '🔍 _ensureDmChatExists: chatId=$chatId, currentUid=$currentUid, otherUid=$otherUid');

    // Check if chat doc already exists — if yes, skip creation steps.
    // Permission error on read is treated as "probably doesn't exist".
    bool chatExists = false;
    try {
      final chatDoc = await _chatsCollection.doc(chatId).get();
      chatExists = chatDoc.exists;
    } catch (_) {
      // Permission denied or other error — proceed to create
    }

    if (chatExists) {
      print('✅ _ensureDmChatExists: Chat $chatId already exists');
      // Still ensure the current user's userChats entry exists
      try {
        final peerUser = await UserRepository.instance.getUser(otherUid);
        await _userChatsCollection(currentUid).doc(chatId).set({
          'type': 'dm',
          'peer_uid': otherUid,
          'title': peerUser?.name ?? 'User',
          'updated_at': FieldValue.serverTimestamp(),
          'pinned': false,
          'muted': false,
        }, SetOptions(merge: true));
      } catch (e) {
        print('⚠️ _ensureDmChatExists: Error ensuring own userChats: $e');
      }
      return;
    }

    // Fetch user info for titles
    final peerUser = await UserRepository.instance.getUser(otherUid);
    final currentUser = await UserRepository.instance.getUser(currentUid);
    final peerName = peerUser?.name ?? 'User';
    final currentName = currentUser?.name ?? 'User';

    // Step 1: Create/update chat document with member_ids
    print('📝 _ensureDmChatExists: Step 1 — creating chat doc');
    try {
      await _chatsCollection.doc(chatId).set({
        'type': 'dm',
        'dm_pair': dmPair,
        'member_ids': FieldValue.arrayUnion(dmPair),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('✅ Step 1 succeeded');
    } catch (e) {
      print('⚠️ Step 1 failed: $e');
      // Don't return — the sendText batch will also try to create the doc
    }

    // Step 2: Create member entries for both users
    for (final uid in dmPair) {
      final user = uid == currentUid ? currentUser : peerUser;
      try {
        await _chatsCollection.doc(chatId).collection('members').doc(uid).set({
          'joined_at': FieldValue.serverTimestamp(),
          'role_id_snapshot': user?.roleId,
          'branch_id_snapshot': user?.branchId,
          'company_id_snapshot': user?.companyId,
          'muted': false,
        }, SetOptions(merge: true));
      } catch (e) {
        print('⚠️ _ensureDmChatExists: Member doc $uid: $e');
      }
    }

    // Step 3: Create userChats entries for both users
    try {
      await _userChatsCollection(currentUid).doc(chatId).set({
        'type': 'dm',
        'peer_uid': otherUid,
        'title': peerName,
        'updated_at': FieldValue.serverTimestamp(),
        'pinned': false,
        'muted': false,
      }, SetOptions(merge: true));
    } catch (e) {
      print('⚠️ _ensureDmChatExists: Own userChats: $e');
    }

    try {
      await _userChatsCollection(otherUid).doc(chatId).set({
        'type': 'dm',
        'peer_uid': currentUid,
        'title': currentName,
        'updated_at': FieldValue.serverTimestamp(),
        'pinned': false,
        'muted': false,
      }, SetOptions(merge: true));
    } catch (e) {
      print('⚠️ _ensureDmChatExists: Peer userChats: $e');
    }

    print('✅ _ensureDmChatExists: Chat $chatId setup complete');
  }

  /// Helper: parse DM pair from chat ID.
  /// Returns [uidA, uidB] sorted, or null if parsing fails.
  List<String>? _parseDmPair(String chatId, String currentUid) {
    final withoutPrefix = chatId.replaceFirst('dm_', '');
    String otherUid;
    if (withoutPrefix.startsWith('${currentUid}_')) {
      otherUid = withoutPrefix.substring(currentUid.length + 1);
    } else if (withoutPrefix.endsWith('_$currentUid')) {
      otherUid = withoutPrefix.substring(
          0, withoutPrefix.length - currentUid.length - 1);
    } else {
      return null;
    }
    return Chat.getSortedDmPair(currentUid, otherUid);
  }

  /// Update the other user's userChats entry for a DM.
  /// Creates a FULL entry (not just updated_at) so the chat appears
  /// properly in the other user's chat list with title and peer info.
  void _updateDmPeerTimestamp(String chatId, String currentUid) async {
    try {
      final dmPair = _parseDmPair(chatId, currentUid);
      if (dmPair == null) return;
      final otherUid =
          dmPair.firstWhere((uid) => uid != currentUid, orElse: () => '');
      if (otherUid.isEmpty) return;

      // Get current user's name so the other user sees it as the chat title
      final currentUser = await UserRepository.instance.getUser(currentUid);
      final currentName = currentUser?.name ?? 'User';

      await _userChatsCollection(otherUid).doc(chatId).set({
        'type': 'dm',
        'peer_uid': currentUid,
        'title': currentName,
        'updated_at': FieldValue.serverTimestamp(),
        'has_messages': true,
        'pinned': false,
        'muted': false,
      }, SetOptions(merge: true));
      print('✅ _updateDmPeerTimestamp: Updated peer $otherUid userChats entry');
    } catch (e) {
      print('⚠️ ChatRepository: Error updating DM peer timestamp: $e');
    }
  }

  /// Update all support chat members' userChats timestamps (fire-and-forget)
  Future<void> _updateSupportChatMemberTimestamps(
      String chatId, String excludeUid) async {
    try {
      final memberUids = await _getSupportChatMemberUids(chatId);
      final batch = _firestore.batch();
      for (final uid in memberUids) {
        if (uid == excludeUid) continue; // Already updated in the main batch
        batch.update(_userChatsCollection(uid).doc(chatId), {
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      print(
          '⚠️ ChatRepository: Error updating support chat member timestamps: $e');
    }
  }

  /// Send an image message
  Future<Message> sendImage(
    String chatId,
    File imageFile, {
    String? caption,
    ReplyTo? replyTo,
  }) async {
    return _sendMedia(
      chatId: chatId,
      file: imageFile,
      type: MessageType.image,
      caption: caption,
      replyTo: replyTo,
    );
  }

  /// Send a file message
  Future<Message> sendFile(
    String chatId,
    File file, {
    String? caption,
    String? mimeType,
    ReplyTo? replyTo,
  }) async {
    return _sendMedia(
      chatId: chatId,
      file: file,
      type: MessageType.file,
      caption: caption,
      mimeType: mimeType,
      replyTo: replyTo,
    );
  }

  /// Send a voice message
  Future<Message> sendVoice(
    String chatId,
    File audioFile, {
    required int durationMs,
    ReplyTo? replyTo,
  }) async {
    return _sendMedia(
      chatId: chatId,
      file: audioFile,
      type: MessageType.audio,
      durationMs: durationMs,
      mimeType: 'audio/m4a',
      replyTo: replyTo,
    );
  }

  /// Send a signable document (PDF) with sign zones
  Future<Message> sendSignableDocument(
    String chatId,
    File pdfFile, {
    required List<SignZone> signZones,
    String? caption,
    int expiresInDays = 2,
    int? pageCount,
  }) async {
    final currentUid = _currentUid;
    if (currentUid == null) throw Exception('Not authenticated');

    if (chatId.startsWith('dm_')) {
      await _ensureDmChatExists(chatId);
    }

    if (!await pdfFile.exists()) {
      throw Exception('File does not exist: ${pdfFile.path}');
    }

    final clientMsgId = _uuid.v4();
    final messageRef =
        _chatsCollection.doc(chatId).collection('messages').doc();
    final fileName = p.basename(pdfFile.path);
    final fileSize = await pdfFile.length();
    final storagePath = 'chat_media/$chatId/${messageRef.id}/$fileName';

    try {
      // Upload PDF
      final ref = _storage.ref(storagePath);
      final metadata = SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {'uploadedBy': currentUid, 'chatId': chatId},
      );
      final fileBytes = await pdfFile.readAsBytes();
      await ref.putData(fileBytes, metadata);
      final mediaUrl = await ref.getDownloadURL();

      // Create message with 24-hour expiry for unsigned docs
      final message = Message(
        id: messageRef.id,
        senderId: currentUid,
        type: MessageType.signableDoc,
        text: caption,
        mediaUrl: mediaUrl,
        mediaPath: storagePath,
        fileName: fileName,
        fileSize: fileSize,
        mimeType: 'application/pdf',
        createdAt: DateTime.now(),
        clientMsgId: clientMsgId,
        status: MessageStatus.sent,
        signZones: signZones,
        signStatus: SignStatus.pending,
        signExpiresInDays: expiresInDays,
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        pageCount: pageCount,
      );

      final batch = _firestore.batch();
      batch.set(messageRef, message.toFirestore());

      // Update chat last_message
      final chatUpdate = <String, dynamic>{
        'last_message': {
          'text': '📝 ${fileName}',
          'type': 'signable_doc',
          'sender_id': currentUid,
          'created_at': FieldValue.serverTimestamp(),
        },
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (chatId.startsWith('dm_')) {
        final dmPair = _parseDmPair(chatId, currentUid);
        if (dmPair != null) {
          chatUpdate['type'] = 'dm';
          chatUpdate['dm_pair'] = dmPair;
          chatUpdate['member_ids'] = FieldValue.arrayUnion(dmPair);
        }
      }
      batch.set(
          _chatsCollection.doc(chatId), chatUpdate, SetOptions(merge: true));

      // Update sender's userChats
      String? dmOtherUid;
      if (chatId.startsWith('dm_')) {
        final dmPair = _parseDmPair(chatId, currentUid);
        if (dmPair != null) {
          dmOtherUid =
              dmPair.firstWhere((u) => u != currentUid, orElse: () => '');
        }
      }
      batch.set(
        _userChatsCollection(currentUid).doc(chatId),
        _senderUserChatPatch(
          chatId: chatId,
          currentUid: currentUid,
          dmOtherUid: dmOtherUid,
        ),
        SetOptions(merge: true),
      );

      await batch.commit();

      if (chatId.startsWith('dm_')) {
        _updateDmPeerTimestamp(chatId, currentUid);
      }
      if (chatId.startsWith('support_')) {
        _updateSupportChatMemberTimestamps(chatId, currentUid);
      }

      return message;
    } catch (e) {
      print('❌ ChatRepository: Error sending signable document: $e');
      rethrow;
    }
  }

  /// Sign a document — uploads signed PDF and updates message
  Future<void> signDocument(
    String chatId,
    String messageId,
    Uint8List signedPdfBytes,
    String originalFileName,
  ) async {
    final currentUid = _currentUid;
    if (currentUid == null) throw Exception('Not authenticated');

    try {
      // Upload signed PDF
      final signedFileName = 'signed_$originalFileName';
      final storagePath = 'chat_media/$chatId/$messageId/$signedFileName';
      final ref = _storage.ref(storagePath);
      final metadata = SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {'signedBy': currentUid, 'chatId': chatId},
      );
      await ref.putData(signedPdfBytes, metadata);
      final signedUrl = await ref.getDownloadURL();

      // Update message document
      await _chatsCollection
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'sign_status': 'signed',
        'signed_pdf_url': signedUrl,
        'signed_at': FieldValue.serverTimestamp(),
        'signed_by': currentUid,
      });

      print('✅ Document signed successfully: $messageId');
    } catch (e) {
      print('❌ ChatRepository: Error signing document: $e');
      rethrow;
    }
  }

  /// Internal method to send media messages
  Future<Message> _sendMedia({
    required String chatId,
    required File file,
    required MessageType type,
    String? caption,
    String? mimeType,
    int? durationMs,
    ReplyTo? replyTo,
  }) async {
    final currentUid = _currentUid;
    if (currentUid == null) {
      throw Exception('Not authenticated');
    }

    // For DM chats: ensure chat document exists before uploading/writing
    if (chatId.startsWith('dm_')) {
      await _ensureDmChatExists(chatId);
    }

    // Verify file exists before attempting upload
    if (!await file.exists()) {
      throw Exception('File does not exist: ${file.path}');
    }

    final clientMsgId = _uuid.v4();
    final messageRef =
        _chatsCollection.doc(chatId).collection('messages').doc();

    final fileName = p.basename(file.path);
    final fileSize = await file.length();
    final storagePath = 'chat_media/$chatId/${messageRef.id}/$fileName';

    try {
      // 1. Upload file to Storage
      print('📤 ChatRepository: Uploading to path: $storagePath');
      print('📤 ChatRepository: Storage bucket: ${_storage.bucket}');
      print('📤 ChatRepository: Current user UID: $currentUid');
      print(
          '📤 ChatRepository: File exists: ${await file.exists()}, size: $fileSize');

      // Check Firebase Auth state
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null) {
        throw Exception(
            'Firebase Auth: No user signed in. Cannot upload to Storage.');
      }
      print(
          '📤 ChatRepository: Auth user email: ${authUser.email}, isAnonymous: ${authUser.isAnonymous}');

      final ref = _storage.ref(storagePath);
      final metadata = SettableMetadata(
        contentType: mimeType ?? _getMimeType(fileName),
        customMetadata: {
          'uploadedBy': currentUid,
          'chatId': chatId,
        },
      );

      // Read file bytes and use putData for better compatibility
      final fileBytes = await file.readAsBytes();
      print(
          '📤 ChatRepository: Read ${fileBytes.length} bytes, starting upload...');

      final uploadTask = ref.putData(fileBytes, metadata);

      // Listen to upload progress for debugging
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress =
            (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print(
            '📤 ChatRepository: Upload progress: ${progress.toStringAsFixed(1)}%');
      }, onError: (e) {
        print('❌ ChatRepository: Upload stream error: $e');
      });

      // Wait for upload
      final snapshot = await uploadTask;
      print('📤 ChatRepository: Upload complete, state: ${snapshot.state}');

      // Get download URL
      final mediaUrl = await ref.getDownloadURL();
      print(
          '📤 ChatRepository: Download URL obtained: ${mediaUrl.substring(0, 50)}...');

      // 2. Create message document
      final message = Message(
        id: messageRef.id,
        senderId: currentUid,
        type: type,
        text: caption,
        mediaUrl: mediaUrl,
        mediaPath: storagePath,
        fileName: fileName,
        fileSize: fileSize,
        mimeType: mimeType ?? _getMimeType(fileName),
        durationMs: durationMs,
        createdAt: DateTime.now(),
        clientMsgId: clientMsgId,
        replyTo: replyTo,
        status: MessageStatus.sent,
      );

      final batch = _firestore.batch();

      // Add message
      batch.set(messageRef, message.toFirestore());

      // Update chat last_message
      final previewText = message.getPreviewText();
      final chatUpdate = <String, dynamic>{
        'last_message': {
          'text': previewText,
          'type': type.toJson(),
          'sender_id': currentUid,
          'created_at': FieldValue.serverTimestamp(),
        },
        'updated_at': FieldValue.serverTimestamp(),
      };
      // Always include member_ids for DM chats
      if (chatId.startsWith('dm_')) {
        final dmPair = _parseDmPair(chatId, currentUid);
        if (dmPair != null) {
          chatUpdate['type'] = 'dm';
          chatUpdate['dm_pair'] = dmPair;
          chatUpdate['member_ids'] = FieldValue.arrayUnion(dmPair);
        }
      }
      batch.set(
          _chatsCollection.doc(chatId), chatUpdate, SetOptions(merge: true));

      // Update sender's userChats
      String? dmOtherUid;
      if (chatId.startsWith('dm_')) {
        final dmPair = _parseDmPair(chatId, currentUid);
        if (dmPair != null) {
          dmOtherUid =
              dmPair.firstWhere((u) => u != currentUid, orElse: () => '');
        }
      }
      batch.set(
        _userChatsCollection(currentUid).doc(chatId),
        _senderUserChatPatch(
          chatId: chatId,
          currentUid: currentUid,
          dmOtherUid: dmOtherUid,
        ),
        SetOptions(merge: true),
      );

      await batch.commit();

      // For DM chats, also update the other user's userChats timestamp
      if (chatId.startsWith('dm_')) {
        _updateDmPeerTimestamp(chatId, currentUid);
      }

      // For support chats, update all members' userChats timestamps
      if (chatId.startsWith('support_')) {
        _updateSupportChatMemberTimestamps(chatId, currentUid);
      }

      return message;
    } on FirebaseException catch (e) {
      print('❌ ChatRepository: Firebase error sending media:');
      print('   Code: ${e.code}');
      print('   Message: ${e.message}');
      print('   Plugin: ${e.plugin}');
      print('   Storage bucket: ${_storage.bucket}');
      print('   Path attempted: $storagePath');
      rethrow;
    } catch (e) {
      print('❌ ChatRepository: Error sending media: $e');
      rethrow;
    }
  }

  /// Get MIME type from file extension
  String _getMimeType(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.mp3':
        return 'audio/mpeg';
      case '.m4a':
        return 'audio/m4a';
      case '.aac':
        return 'audio/aac';
      case '.wav':
        return 'audio/wav';
      case '.pdf':
        return 'application/pdf';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.xls':
        return 'application/vnd.ms-excel';
      case '.xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
    }
  }

  // ============== Read Receipts ==============

  /// Mark a chat as read (update last_read_at in userChats)
  Future<void> markChatRead(String chatId) async {
    final currentUid = _currentUid;
    if (currentUid == null) return;

    try {
      // Use update() so we don't accidentally create a userChats doc
      // for a chat where no messages have been sent yet.
      await _userChatsCollection(currentUid).doc(chatId).update({
        'last_read_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Ignore "not-found" — the doc doesn't exist yet (no messages sent)
      if (e is FirebaseException && e.code == 'not-found') return;
      print('❌ ChatRepository: Error marking chat as read: $e');
    }
  }

  /// Subscribe to total unread message count across all chats
  Stream<int> subscribeToTotalUnreadCount() {
    final currentUid = _currentUid;
    if (currentUid == null) {
      // print('⚠️ subscribeToTotalUnreadCount: No current UID');
      return Stream.value(0);
    }

    // print('🔔 subscribeToTotalUnreadCount: Subscribing for uid=$currentUid');
    return subscribeToUserChats(currentUid).asyncMap((chats) async {
      // print('🔔 subscribeToTotalUnreadCount: Got ${chats.length} chats');
      int total = 0;
      for (final chat in chats) {
        if (chat.muted) continue;
        final lastReadAt = chat.lastReadAt;
        try {
          Query query =
              _chatsCollection.doc(chat.chatId).collection('messages');

          // Only add created_at filter if user has read the chat before
          if (lastReadAt != null) {
            query = query.where('created_at',
                isGreaterThan: Timestamp.fromDate(lastReadAt));
          }

          // Limit to avoid fetching too many docs when lastReadAt is null
          query = query.limit(100);

          // Fetch the docs and count those NOT from current user
          final snapshot = await query.get();
          final count = snapshot.docs.where((d) {
            final data = d.data() as Map<String, dynamic>?;
            return data?['sender_id'] != currentUid;
          }).length;

          // if (count > 0) {
          //   print(
          //       '🔔 Chat ${chat.chatId}: $count unread (lastReadAt=$lastReadAt)');
          // }
          total += count;
        } catch (e) {
          // print('⚠️ subscribeToTotalUnreadCount: Error for ${chat.chatId}: $e');
        }
      }
      // print('🔔 subscribeToTotalUnreadCount: Total unread = $total');
      return total;
    });
  }

  /// Get unread count for a chat based on last_read_at
  Stream<int> subscribeToUnreadCount(String chatId) {
    final currentUid = _currentUid;
    if (currentUid == null) {
      print('⚠️ subscribeToUnreadCount($chatId): No current UID');
      return Stream.value(0);
    }

    return _userChatsCollection(currentUid)
        .doc(chatId)
        .snapshots()
        .asyncMap((userChatDoc) async {
      if (!userChatDoc.exists) {
        print(
            '⚠️ subscribeToUnreadCount($chatId): userChats doc does NOT exist');
        return 0;
      }

      final data = userChatDoc.data();
      final lastReadAt = (data?['last_read_at'] as Timestamp?)?.toDate();

      try {
        Query query = _chatsCollection.doc(chatId).collection('messages');

        // Only add created_at filter if user has read the chat before
        if (lastReadAt != null) {
          query = query.where('created_at',
              isGreaterThan: Timestamp.fromDate(lastReadAt));
        }

        // Limit to avoid fetching too many docs when lastReadAt is null
        query = query.limit(100);

        // Fetch and filter out current user's messages in-memory
        final snapshot = await query.get();
        final count = snapshot.docs.where((d) {
          final data = d.data() as Map<String, dynamic>?;
          return data?['sender_id'] != currentUid;
        }).length;

        if (count > 0)
          print(
              '🔵 subscribeToUnreadCount($chatId): $count unread (lastReadAt=$lastReadAt)');
        return count;
      } catch (e) {
        print('⚠️ subscribeToUnreadCount($chatId): Error: $e');
        return 0;
      }
    });
  }

  // ============== Chat Members ==============

  /// Get members of a chat
  Future<List<ChatMember>> getChatMembers(String chatId) async {
    try {
      final snapshot =
          await _chatsCollection.doc(chatId).collection('members').get();

      return snapshot.docs.map((doc) => ChatMember.fromFirestore(doc)).toList();
    } catch (e) {
      print('❌ ChatRepository: Error getting chat members: $e');
      return [];
    }
  }

  /// Toggle mute for a chat
  Future<void> toggleMute(String chatId, bool muted) async {
    final currentUid = _currentUid;
    if (currentUid == null) return;

    try {
      final batch = _firestore.batch();

      // Update in members subcollection
      batch.update(
        _chatsCollection.doc(chatId).collection('members').doc(currentUid),
        {'muted': muted},
      );

      // Update in userChats
      batch.update(
        _userChatsCollection(currentUid).doc(chatId),
        {'muted': muted},
      );

      await batch.commit();
    } catch (e) {
      print('❌ ChatRepository: Error toggling mute: $e');
    }
  }

  /// Toggle pin for a chat
  Future<void> togglePin(String chatId, bool pinned) async {
    final currentUid = _currentUid;
    if (currentUid == null) return;

    try {
      await _userChatsCollection(currentUid).doc(chatId).update({
        'pinned': pinned,
      });
    } catch (e) {
      print('❌ ChatRepository: Error toggling pin: $e');
    }
  }

  // ============== Starred Messages ==============

  /// Star a message (stored per-user in userChats/{uid}/starred_messages/{messageId})
  Future<void> starMessage(String chatId, Message message) async {
    final currentUid = _currentUid;
    if (currentUid == null) return;

    try {
      await _firestore
          .collection('userChats')
          .doc(currentUid)
          .collection('starred_messages')
          .doc(message.id)
          .set({
        'chat_id': chatId,
        'message_id': message.id,
        'sender_id': message.senderId,
        'type': message.type.toJson(),
        'text': message.text,
        'media_url': message.mediaUrl,
        'file_name': message.fileName,
        'file_size': message.fileSize,
        'mime_type': message.mimeType,
        'duration_ms': message.durationMs,
        'created_at': Timestamp.fromDate(message.createdAt),
        'starred_at': FieldValue.serverTimestamp(),
      });
      print('⭐ ChatRepository: Starred message ${message.id}');
    } catch (e) {
      print('❌ ChatRepository: Error starring message: $e');
    }
  }

  /// Unstar a message
  Future<void> unstarMessage(String messageId) async {
    final currentUid = _currentUid;
    if (currentUid == null) return;

    try {
      await _firestore
          .collection('userChats')
          .doc(currentUid)
          .collection('starred_messages')
          .doc(messageId)
          .delete();
      print('⭐ ChatRepository: Unstarred message $messageId');
    } catch (e) {
      print('❌ ChatRepository: Error unstarring message: $e');
    }
  }

  /// Check if a message is starred
  Future<bool> isMessageStarred(String messageId) async {
    final currentUid = _currentUid;
    if (currentUid == null) return false;

    try {
      final doc = await _firestore
          .collection('userChats')
          .doc(currentUid)
          .collection('starred_messages')
          .doc(messageId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Subscribe to starred message IDs (returns Set of message IDs for quick lookup)
  Stream<Set<String>> subscribeToStarredMessageIds() {
    final currentUid = _currentUid;
    if (currentUid == null) return Stream.value({});

    return _firestore
        .collection('userChats')
        .doc(currentUid)
        .collection('starred_messages')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.id).toSet();
    });
  }

  /// Get all starred messages stream
  Stream<List<Map<String, dynamic>>> subscribeToStarredMessages() {
    final currentUid = _currentUid;
    if (currentUid == null) return Stream.value([]);

    return _firestore
        .collection('userChats')
        .doc(currentUid)
        .collection('starred_messages')
        .orderBy('starred_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }
}

class ExistingDmMatch {
  final String chatId;
  final String peerUid;
  final String title;

  const ExistingDmMatch({
    required this.chatId,
    required this.peerUid,
    required this.title,
  });
}
