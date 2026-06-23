import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:el_race/core/utils/shared_pref.dart';

import '../data/todo_list_model.dart';
import '../data/todo_model.dart';
import '../data/task_member_model.dart';

/// Firebase Service for Task Management
/// All CRUD operations are done through Firebase Firestore
/// Only members are fetched from backend API
class TodoFirebaseService {
  static TodoFirebaseService? _instance;
  static TodoFirebaseService get instance =>
      _instance ??= TodoFirebaseService._();

  TodoFirebaseService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user ID - fallback to firebase_uid from login data if Firebase Auth not signed in
  String? get _currentUid {
    final firebaseUid = FirebaseAuth.instance.currentUser?.uid;
    if (firebaseUid != null) return firebaseUid;
    // Fallback: use firebase_uid from backend login data
    return SharedPref.getLoginData().result?.data?.firebase_uid;
  }

  // Ensure Firebase Auth is signed in using the custom token from login data
  Future<void> _ensureSignedIn() async {
    if (FirebaseAuth.instance.currentUser != null) return;
    final loginData = SharedPref.getLoginData();
    final customToken = loginData.result?.data?.firebase_custom_token;
    if (customToken != null &&
        customToken.isNotEmpty &&
        customToken != 'false') {
      try {
        await FirebaseAuth.instance.signInWithCustomToken(customToken);
        print('✅ TodoFirebaseService: Signed in to Firebase with custom token');
      } catch (e) {
        print(
            '⚠️ TodoFirebaseService: Could not sign in with custom token: $e');
      }
    }
  }

  // Get current user name from SharedPref
  String get _currentUserName {
    final loginData = SharedPref.getLoginData();
    return loginData.result?.data?.name ?? 'Unknown';
  }

  /// Public accessor for current user name (used by notification services).
  String get currentUserNamePublic => _currentUserName;

  // Get current user photo URL from SharedPref
  String? get _currentUserPhoto {
    return SharedPref.preferences.getUserBase64Image();
  }

  // Collection references
  CollectionReference<Map<String, dynamic>> get _todosCollection =>
      _firestore.collection('todos');

  CollectionReference<Map<String, dynamic>> get _todoListsCollection =>
      _firestore.collection('todoLists');

  // User-specific todos path
  CollectionReference<Map<String, dynamic>> _userTodosCollection(String uid) =>
      _firestore.collection('users').doc(uid).collection('todos');

  CollectionReference<Map<String, dynamic>> _userTodoListsCollection(
          String uid) =>
      _firestore.collection('users').doc(uid).collection('todoLists');

  List<TodoModel> _sortTodosByCreatedDesc(Iterable<TodoModel> todos) {
    final sorted = todos.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  Future<List<TodoModel>> _getOwnTodos(String uid) async {
    final snapshot = await _userTodosCollection(uid).get();
    return _sortTodosByCreatedDesc(
      snapshot.docs.map((doc) => TodoModel.fromFirestore(doc)),
    );
  }

  Stream<List<TodoModel>> _streamOwnTodos(String uid) {
    return _userTodosCollection(uid).snapshots().map(
          (snapshot) => _sortTodosByCreatedDesc(
            snapshot.docs.map((doc) => TodoModel.fromFirestore(doc)),
          ),
        );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findTodoDocumentById(
    String todoId,
  ) async {
    final snapshot = await _firestore
        .collectionGroup('todos')
        .where(FieldPath.documentId, isEqualTo: todoId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first;
  }

  String _resolveOwnerUidForTodo(TodoModel todo, String currentUid) {
    final ownerUid = todo.ownerUid?.trim();
    if (ownerUid != null && ownerUid.isNotEmpty) {
      return ownerUid;
    }
    return currentUid;
  }

  List<String> get _currentUserIdentifiers {
    final data = SharedPref.getLoginData().result?.data;
    // Build numeric IDs
    final numericIds = <String?>[
      data?.odoo_user_id?.toString(),
      data?.uid?.toString(),
      data?.employee_id?.toString(),
      data?.emp_id?.toString(),
      data?.emp_profile_id?.toString(),
    ].whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e.toLowerCase() != 'false')
        .toSet();

    // Also add firebase_uid (e.g. "odoo_123") — most reliable cross-user identifier
    final firebaseUid = data?.firebase_uid?.trim();
    // And derive "odoo_{id}" format from every numeric odoo_user_id / uid
    final derived = <String>{};
    for (final id in [data?.odoo_user_id?.toString(), data?.uid?.toString()]) {
      final clean = id?.trim();
      if (clean != null && clean.isNotEmpty && clean.toLowerCase() != 'false') {
        derived.add('odoo_$clean');
      }
    }
    if (firebaseUid != null &&
        firebaseUid.isNotEmpty &&
        firebaseUid.toLowerCase() != 'false') {
      derived.add(firebaseUid);
    }

    print('🔍 [TaskAssign] _currentUserIdentifiers: ${[...numericIds, ...derived]}');
    return [...numericIds, ...derived];
  }

  List<String> get _currentUserNames {
    final data = SharedPref.getLoginData().result?.data;
    final values = <String?>[
      data?.name,
      data?.emp_name,
      data?.username,
      data?.partnerDisplayName,
    ];
    final cleaned = values
        .whereType<String>()
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty && e != 'false')
        .toSet()
        .toList();
    return cleaned;
  }

  /// Build all identifiers for a single TaskMember:
  /// odooId, userId (numeric), and "odoo_{userId}" (firebase_uid format).
  List<String> _memberAllIds(TaskMember m) {
    final ids = <String>{};
    final oId = m.odooId?.trim();
    if (oId != null && oId.isNotEmpty) ids.add(oId);
    final uId = m.userId?.trim();
    if (uId != null && uId.isNotEmpty) {
      ids.add(uId);
      ids.add('odoo_$uId'); // firebase_uid format → most reliable match
    }
    return ids.toList();
  }

  Map<String, dynamic> _withMembershipFields(TodoModel todo) {
    final data = todo.toFirestore();

    // Collect ALL identifiers for each assigned member
    final assignedIds = (todo.assignedMembers ?? const <TaskMember>[])
        .expand(_memberAllIds)
        .toSet()
        .toList();

    // Collect ALL identifiers for each follower
    final followerIds = (todo.followedUpBy ?? const <TaskMember>[])
        .expand(_memberAllIds)
        .toSet()
        .toList();

    final assignedNames = (todo.assignedMembers ?? const <TaskMember>[])
        .map((m) => m.name.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();

    data['owner_uid'] = todo.ownerUid;
    data['assigned_member_ids'] = assignedIds;
    data['follower_member_ids'] = followerIds;
    data['assigned_member_names'] = assignedNames;
    return data;
  }

  List<TodoModel> _mergeUniqueTodos(
    List<TodoModel> primary,
    List<TodoModel> secondary,
  ) {
    final map = <String, TodoModel>{};

    String keyFor(TodoModel t) {
      if (t.firebaseId != null && t.firebaseId!.isNotEmpty) {
        return t.firebaseId!;
      }
      return '${t.title}_${t.createdAt.millisecondsSinceEpoch}';
    }

    for (final t in [...primary, ...secondary]) {
      final key = keyFor(t);
      final existing = map[key];
      if (existing == null || t.updatedAt.isAfter(existing.updatedAt)) {
        map[key] = t;
      }
    }

    final merged = map.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  Future<List<TodoModel>> _getAssignedToCurrentUserFromAllCollections() async {
    final ids = _currentUserIdentifiers;
    final names = _currentUserNames;
    if (ids.isEmpty && names.isEmpty) return const [];

    try {
      final Map<String, TodoModel> seen = {};

      void addUnique(DocumentSnapshot<Map<String, dynamic>> doc) {
        if (!seen.containsKey(doc.id)) {
          seen[doc.id] = TodoModel.fromFirestore(doc);
        }
      }

      // ── Query by assigned_member_ids (covers both odooId + userId) ──
      if (ids.isNotEmpty) {
        // arrayContainsAny max 10 items per query
        final chunks = _chunkedList(ids, 10);
        for (final chunk in chunks) {
          final snap = await _firestore
              .collectionGroup('todos')
              .where('assigned_member_ids', arrayContainsAny: chunk)
              .get();
          for (final doc in snap.docs) addUnique(doc);
        }
      }

      // ── Query by assigned_member_names (name-based fallback) ──
      if (names.isNotEmpty) {
        final chunks = _chunkedList(names, 10);
        for (final chunk in chunks) {
          final snap = await _firestore
              .collectionGroup('todos')
              .where('assigned_member_names', arrayContainsAny: chunk)
              .get();
          for (final doc in snap.docs) addUnique(doc);
        }
      }

      return seen.values.toList();
    } catch (e) {
      print('❌ TodoFirebaseService: arrayContainsAny query failed ($e), falling back to full scan');
      // Fallback: full scan + client-side filter
      try {
        final snapshot = await _firestore.collectionGroup('todos').get();
        final all = snapshot.docs.map((doc) => TodoModel.fromFirestore(doc)).toList();
        return all.where(_isAssignedToCurrentUser).toList();
      } catch (e2) {
        print('❌ TodoFirebaseService: Error loading assigned tasks from all users: $e2');
        return const [];
      }
    }
  }

  /// Split a list into chunks of [size].
  List<List<T>> _chunkedList<T>(List<T> list, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      chunks.add(list.sublist(i, i + size > list.length ? list.length : i + size));
    }
    return chunks;
  }

  bool _isAssignedToCurrentUser(TodoModel todo) {
    final ids = _currentUserIdentifiers;
    final names = _currentUserNames;
    if (ids.isEmpty && names.isEmpty) return false;

    // Collect all stored IDs from assignedMembers (odooId + userId + firebase_uid format)
    final memberIds = (todo.assignedMembers ?? const <TaskMember>[])
        .expand(_memberAllIds)
        .toSet();

    print('🔍 [TaskAssign] Checking "${todo.title}" | storedIds=$memberIds | myIds=$ids | storedNames=${(todo.assignedMembers ?? []).map((m) => m.name).toSet()} | myNames=$names');

    if (memberIds.any(ids.contains)) {
      print('✅ [TaskAssign] ID match for "${todo.title}"');
      return true;
    }

    final memberNames = (todo.assignedMembers ?? const <TaskMember>[])
        .map((m) => m.name.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet();
    if (memberNames.any(names.contains)) {
      print('✅ [TaskAssign] Name match for "${todo.title}"');
      return true;
    }

    final assignedTo = todo.assignedTo?.trim();
    if (assignedTo != null &&
        assignedTo.isNotEmpty &&
        ids.contains(assignedTo)) {
      return true;
    }

    final assignedToName = todo.assignedToName?.trim().toLowerCase();
    if (assignedToName != null && assignedToName.isNotEmpty) {
      final splitNames = assignedToName
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
      if (splitNames.any(names.contains)) return true;
    }

    return false;
  }

  // ==================== TODO OPERATIONS ====================

  /// Resolve Firestore UID for an assigned member.
  /// Tries "odoo_{userId}" first; if userId is absent, queries Firestore
  /// `users` collection by `odoo_user_id` or `employee_id` matching odooId.
  Future<String?> _resolveFirebaseUid(TaskMember member) async {
    final uId = member.userId?.trim();
    if (uId != null && uId.isNotEmpty) {
      final userIntId = int.tryParse(uId);
      if (userIntId != null) {
        try {
          final byOdoo = await _firestore
              .collection('users')
              .where('odoo_user_id', isEqualTo: userIntId)
              .limit(1)
              .get();
          if (byOdoo.docs.isNotEmpty) {
            return byOdoo.docs.first.id;
          }

          final odooDoc =
              await _firestore.collection('users').doc('odoo_$userIntId').get();
          if (odooDoc.exists) {
            return odooDoc.id;
          }
        } catch (e) {
          print('⚠️ _resolveFirebaseUid: query error for userId=$uId: $e');
        }
      }

      return 'odoo_$uId';
    }

    // Fallback: query Firestore users by odoo_user_id / employee_id
    final oId = member.odooId?.trim();
    if (oId == null || oId.isEmpty) return null;

    final intId = int.tryParse(oId);
    if (intId != null) {
      try {
        final snap = await _firestore
            .collection('users')
            .where('odoo_user_id', isEqualTo: intId)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          return snap.docs.first.id; // document ID = firebase_uid
        }

        // 3️⃣ try employee_id
        final snap2 = await _firestore
            .collection('users')
            .where('employee_id', isEqualTo: intId)
            .limit(1)
            .get();
        if (snap2.docs.isNotEmpty) {
          return snap2.docs.first.id;
        }
      } catch (e) {
        print('⚠️ _resolveFirebaseUid: query error for odooId=$oId: $e');
      }
    }

    // 4️⃣ Try name-based lookup as last resort
    final name = member.name.trim();
    if (name.isNotEmpty) {
      try {
        final snap = await _firestore
            .collection('users')
            .where('name', isEqualTo: name)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          return snap.docs.first.id;
        }
      } catch (_) {}
    }

    return null;
  }

  Future<List<String>> _resolveRecipientFirebaseUids(
    TodoModel todo,
    String ownerUid,
  ) async {
    final recipients = <String>{ownerUid};

    for (final member in [
      ...(todo.assignedMembers ?? const <TaskMember>[]),
      ...(todo.followedUpBy ?? const <TaskMember>[]),
    ]) {
      final memberUid = await _resolveFirebaseUid(member);
      if (memberUid != null && memberUid.isNotEmpty) {
        recipients.add(memberUid);
      }
    }

    return recipients.toList(growable: false);
  }

  Future<void> _syncTodoFieldToAssignees(
    String todoId,
    TodoModel todo,
    String ownerUid,
    Map<String, dynamic> update,
  ) async {
    for (final member in todo.assignedMembers ?? const <TaskMember>[]) {
      final memberUid = await _resolveFirebaseUid(member);
      if (memberUid == null || memberUid.isEmpty || memberUid == ownerUid) {
        continue;
      }
      try {
        await _userTodosCollection(memberUid).doc(todoId).update(update);
      } catch (e) {
        print('⚠️ TodoFirebaseService: Could not sync field to $memberUid: $e');
      }
    }
  }

  /// Backfill recipient_firebase_uids for older tasks so comment pushes work.
  Future<void> ensureRecipientFirebaseUids(TodoModel todo) async {
    if (todo.firebaseId == null || todo.firebaseId!.isEmpty) return;

    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) return;

    final ownerUid = (todo.ownerUid != null && todo.ownerUid!.isNotEmpty)
        ? todo.ownerUid!
        : uid;

    try {
      final doc =
          await _userTodosCollection(ownerUid).doc(todo.firebaseId!).get();
      if (!doc.exists) return;

      final existing = doc.data()?['recipient_firebase_uids'];
      if (existing is List && existing.isNotEmpty) return;

      final recipients = await _resolveRecipientFirebaseUids(todo, ownerUid);
      final update = {'recipient_firebase_uids': recipients};
      await _userTodosCollection(ownerUid).doc(todo.firebaseId!).update(update);
      await _syncTodoFieldToAssignees(
        todo.firebaseId!,
        todo,
        ownerUid,
        update,
      );
    } catch (e) {
      print('⚠️ TodoFirebaseService: ensureRecipientFirebaseUids failed: $e');
    }
  }

  /// Upload task attachments to Firebase Storage and persist download URLs.
  Future<List<String>> uploadTaskAttachments({
    required String todoId,
    required TodoModel todo,
    required List<File> files,
  }) async {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');
    if (files.isEmpty) return const [];

    final ownerUid = (todo.ownerUid != null && todo.ownerUid!.isNotEmpty)
        ? todo.ownerUid!
        : uid;

    final urls = <String>[];
    for (final file in files) {
      final fileName = file.path.split(Platform.pathSeparator).last;
      final ref = FirebaseStorage.instance
          .ref()
          .child('tasks/$todoId/attachments/$fileName');
      await ref.putFile(file);
      urls.add(await ref.getDownloadURL());
    }

    final update = {
      'attachments': urls,
      'updated_at': FieldValue.serverTimestamp(),
    };

    await _userTodosCollection(ownerUid).doc(todoId).update(update);
    await _syncTodoFieldToAssignees(todoId, todo, ownerUid, update);
    return urls;
  }

  /// Insert a new todo — saves under the creator AND under every assigned
  /// member's Firestore path so each user sees it in `_getOwnTodos`.
  Future<String> insertTodo(TodoModel todo) async {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      final todoWithOwner = todo.copyWith(ownerUid: uid);
      final data = _withMembershipFields(todoWithOwner);
      data['recipient_firebase_uids'] =
          await _resolveRecipientFirebaseUids(todoWithOwner, uid);

      // Save under creator
      final docRef = await _userTodosCollection(uid).add(data);
      final todoId = docRef.id;
      print('✅ TodoFirebaseService: Created todo $todoId under creator $uid');

      // Also save a copy under each assigned member's path
      final assignedMembers = todo.assignedMembers ?? const <TaskMember>[];
      for (final member in assignedMembers) {
        final memberUid = await _resolveFirebaseUid(member);
        if (memberUid != null && memberUid != uid) {
          try {
            await _userTodosCollection(memberUid).doc(todoId).set(data);
            print('✅ TodoFirebaseService: Saved todo $todoId under assignee $memberUid (${member.name})');
          } catch (e) {
            print('⚠️ TodoFirebaseService: Could not save under $memberUid: $e');
          }
        }
      }

      return todoId;
    } catch (e) {
      print('❌ TodoFirebaseService: Error creating todo: $e');
      rethrow;
    }
  }

  /// Update an existing todo
  Future<void> updateTodo(TodoModel todo) async {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');
    if (todo.firebaseId == null) throw Exception('Todo has no Firebase ID');

    try {
      final ownerUid = _resolveOwnerUidForTodo(todo, uid);
      final todoWithOwner = todo.copyWith(ownerUid: ownerUid);
      final data = _withMembershipFields(todoWithOwner);
      data['recipient_firebase_uids'] =
          await _resolveRecipientFirebaseUids(todoWithOwner, ownerUid);
      await _userTodosCollection(ownerUid).doc(todo.firebaseId).update(data);
      print('✅ TodoFirebaseService: Updated todo ${todo.firebaseId}');
    } catch (e) {
      print('❌ TodoFirebaseService: Error updating todo: $e');
      rethrow;
    }
  }

  /// Delete a todo
  Future<void> deleteTodo(String todoId, {String? ownerUid}) async {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      await _userTodosCollection(ownerUid ?? uid).doc(todoId).delete();
      print('✅ TodoFirebaseService: Deleted todo $todoId');
    } catch (e) {
      print('❌ TodoFirebaseService: Error deleting todo: $e');
      rethrow;
    }
  }

  /// Get todo by ID
  Future<TodoModel?> getTodoById(String todoId, {String? ownerUid}) async {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      if (ownerUid != null && ownerUid.isNotEmpty) {
        final doc = await _userTodosCollection(ownerUid).doc(todoId).get();
        if (doc.exists) {
          return TodoModel.fromFirestore(doc);
        }
        return null;
      }

      final ownDoc = await _userTodosCollection(uid).doc(todoId).get();
      if (ownDoc.exists) {
        return TodoModel.fromFirestore(ownDoc);
      }

      final doc = await _findTodoDocumentById(todoId);
      if (doc != null && doc.exists) {
        return TodoModel.fromFirestore(doc);
      }

      return null;
    } catch (e) {
      print('❌ TodoFirebaseService: Error getting todo: $e');
      rethrow;
    }
  }

  /// Get all todos for current user.
  /// 1) Own todos from users/{uid}/todos
  /// 2) Assigned todos from ALL users via collectionGroup (covers old + new tasks)
  Future<List<TodoModel>> getAllTodos() async {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      final ownTodos = await _getOwnTodos(uid);
      final assignedTodos = await _getAssignedToCurrentUserFromAllCollections();
      final merged = _mergeUniqueTodos(ownTodos, assignedTodos);
      print('📋 TodoFirebaseService: getAllTodos own=${ownTodos.length} assigned=${assignedTodos.length} merged=${merged.length} uid=$uid');
      return merged;
    } catch (e) {
      print('❌ TodoFirebaseService: Error getting all todos: $e');
      rethrow;
    }
  }

  /// Stream all todos for real-time updates.
  /// Combines own todos stream + collectionGroup stream for assigned tasks.
  Stream<List<TodoModel>> streamAllTodos() {
    return Stream.fromFuture(_ensureSignedIn()).asyncExpand((_) {
      final uid = _currentUid;
      if (uid == null) return Stream.value(const <TodoModel>[]);

      print('📡 TodoFirebaseService: streaming todos for uid=$uid');
      final ownStream = _streamOwnTodos(uid);

      // collectionGroup stream — filtered client-side for assigned tasks
      final assignedStream = _firestore
          .collectionGroup('todos')
          .snapshots()
          .map((snapshot) {
        final all =
            snapshot.docs.map((d) => TodoModel.fromFirestore(d)).toList();
        return all.where(_isAssignedToCurrentUser).toList();
      }).handleError((e) {
        print('⚠️ TodoFirebaseService: collectionGroup stream error: $e');
      });

      return Stream.multi((controller) {
        List<TodoModel> own = const [];
        List<TodoModel> assigned = const [];

        void emit() {
          controller.add(_mergeUniqueTodos(own, assigned));
        }

        final subs = <StreamSubscription>[];

        subs.add(ownStream.listen(
          (data) {
            own = data;
            emit();
          },
          onError: controller.addError,
        ));

        subs.add(assignedStream.listen(
          (data) {
            assigned = data;
            emit();
          },
        ));

        controller.onCancel = () async {
          for (final sub in subs) {
            await sub.cancel();
          }
        };
      });
    });
  }

  /// Get incomplete todos
  Future<List<TodoModel>> getIncompleteTodos() async {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      final todos = await _getOwnTodos(uid);
      return todos.where((todo) => !todo.isCompleted).toList();
    } catch (e) {
      print('❌ TodoFirebaseService: Error getting incomplete todos: $e');
      rethrow;
    }
  }

  /// Get My Day todos
  Future<List<TodoModel>> getMyDayTodos() async {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      final todos = await _getOwnTodos(uid);
      return todos.where((todo) => todo.isMyDay).toList();
    } catch (e) {
      print('❌ TodoFirebaseService: Error getting my day todos: $e');
      rethrow;
    }
  }

  /// Get Important todos
  Future<List<TodoModel>> getImportantTodos() async {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      final todos = await _getOwnTodos(uid);
      return todos.where((todo) => todo.isImportant).toList();
    } catch (e) {
      print('❌ TodoFirebaseService: Error getting important todos: $e');
      rethrow;
    }
  }

  /// Get Planned todos (with due date)
  Future<List<TodoModel>> getPlannedTodos() async {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      final todos = await _getOwnTodos(uid);
      final planned = todos.where((todo) => todo.dueDate != null).toList()
        ..sort((a, b) {
          final aDate = a.dueDate;
          final bDate = b.dueDate;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return aDate.compareTo(bDate);
        });
      return planned;
    } catch (e) {
      print('❌ TodoFirebaseService: Error getting planned todos: $e');
      rethrow;
    }
  }

  /// Get Assigned To Me todos
  Future<List<TodoModel>> getAssignedToMeTodos(String? assignee) async {
    try {
      final allTodos = await getAllTodos();

      final assigned = allTodos.where((todo) {
        if (!_isAssignedToCurrentUser(todo)) return false;
        if (assignee == null || assignee.trim().isEmpty) return true;
        return (todo.assignedTo ?? '').trim() == assignee.trim();
      }).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return assigned;
    } catch (e) {
      print('❌ TodoFirebaseService: Error getting assigned todos: $e');
      rethrow;
    }
  }

  /// Get todos by list ID
  Future<List<TodoModel>> getTodosByListId(String listId) async {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      final todos = await _getOwnTodos(uid);
      return todos.where((todo) => todo.listId == listId).toList();
    } catch (e) {
      print('❌ TodoFirebaseService: Error getting todos by list: $e');
      rethrow;
    }
  }

  /// Get todos by report ID
  Future<List<TodoModel>> getTodosByReportId(String reportId) async {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      final todos = await _getOwnTodos(uid);
      return todos.where((todo) => todo.reportId == reportId).toList();
    } catch (e) {
      print('❌ TodoFirebaseService: Error getting todos by report: $e');
      rethrow;
    }
  }

  /// Get tasks count by report ID
  Future<int> getTasksCountByReportId(String reportId) async {
    final todos = await getTodosByReportId(reportId);
    return todos.length;
  }

  /// Search todos
  Future<List<TodoModel>> searchTodos(String query) async {
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      // Firestore doesn't support full-text search natively
      // We'll get all todos and filter locally
      final allTodos = await getAllTodos();
      final queryLower = query.toLowerCase();

      return allTodos
          .where((todo) =>
              todo.title.toLowerCase().contains(queryLower) ||
              (todo.description?.toLowerCase().contains(queryLower) ?? false))
          .toList();
    } catch (e) {
      print('❌ TodoFirebaseService: Error searching todos: $e');
      rethrow;
    }
  }

  /// Toggle todo complete status
  Future<void> toggleTodoComplete(
    String todoId,
    bool isCompleted, {
    String? ownerUid,
  }) async {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      await _userTodosCollection(ownerUid ?? uid).doc(todoId).update({
        'is_completed': isCompleted,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ TodoFirebaseService: Error toggling complete: $e');
      rethrow;
    }
  }

  /// Toggle todo important status
  Future<void> toggleTodoImportant(
    String todoId,
    bool isImportant, {
    String? ownerUid,
  }) async {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      await _userTodosCollection(ownerUid ?? uid).doc(todoId).update({
        'is_important': isImportant,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ TodoFirebaseService: Error toggling important: $e');
      rethrow;
    }
  }

  /// Toggle todo my day status
  Future<void> toggleTodoMyDay(
    String todoId,
    bool isMyDay, {
    String? ownerUid,
  }) async {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      await _userTodosCollection(ownerUid ?? uid).doc(todoId).update({
        'is_my_day': isMyDay,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ TodoFirebaseService: Error toggling my day: $e');
      rethrow;
    }
  }

  /// Update todo order
  Future<void> updateTodoOrder(List<TodoModel> todos) async {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      final batch = _firestore.batch();

      for (int i = 0; i < todos.length; i++) {
        if (todos[i].firebaseId != null) {
          final ownerUid = _resolveOwnerUidForTodo(todos[i], uid);
          final docRef =
              _userTodosCollection(ownerUid).doc(todos[i].firebaseId);
          batch.update(docRef, {
            'sort_order': i,
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
    } catch (e) {
      print('❌ TodoFirebaseService: Error updating order: $e');
      rethrow;
    }
  }

  // ==================== COUNTS ====================

  Future<int> getTodosCount() async {
    final todos = await getIncompleteTodos();
    return todos.length;
  }

  Future<int> getMyDayCount() async {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) return 0;

    try {
      final todos = await _getOwnTodos(uid);
      return todos.where((todo) => todo.isMyDay && !todo.isCompleted).length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> getImportantCount() async {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) return 0;

    try {
      final todos = await _getOwnTodos(uid);
      return todos
          .where((todo) => todo.isImportant && !todo.isCompleted)
          .length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> getPlannedCount() async {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) return 0;

    try {
      final todos = await _getOwnTodos(uid);
      return todos
          .where((todo) => todo.dueDate != null && !todo.isCompleted)
          .length;
    } catch (e) {
      return 0;
    }
  }

  /// Reset My Day at midnight
  Future<void> resetMyDay() async {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) return;

    try {
      final batch = _firestore.batch();
      final todos = await _getOwnTodos(uid);
      for (final todo in todos.where((item) => item.isMyDay)) {
        if (todo.firebaseId == null) continue;
        batch.update(_userTodosCollection(uid).doc(todo.firebaseId), {
          'is_my_day': false,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      print('❌ TodoFirebaseService: Error resetting my day: $e');
    }
  }

  // ==================== TODO LIST OPERATIONS ====================

  /// Insert a new todo list
  Future<String> insertTodoList(TodoListModel list) async {
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      final docRef =
          await _userTodoListsCollection(uid).add(list.toFirestore());
      print('✅ TodoFirebaseService: Created list ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ TodoFirebaseService: Error creating list: $e');
      rethrow;
    }
  }

  /// Update a todo list
  Future<void> updateTodoList(TodoListModel list) async {
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');
    if (list.firebaseId == null) throw Exception('List has no Firebase ID');

    try {
      await _userTodoListsCollection(uid)
          .doc(list.firebaseId)
          .update(list.toFirestore());
    } catch (e) {
      print('❌ TodoFirebaseService: Error updating list: $e');
      rethrow;
    }
  }

  /// Delete a todo list
  Future<void> deleteTodoList(String listId) async {
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      // First update all todos in this list to have no list
      final todosInList = await getTodosByListId(listId);
      final batch = _firestore.batch();

      for (final todo in todosInList) {
        if (todo.firebaseId != null) {
          batch.update(_userTodosCollection(uid).doc(todo.firebaseId), {
            'list_id': null,
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
      }

      // Delete the list
      batch.delete(_userTodoListsCollection(uid).doc(listId));

      await batch.commit();
      print('✅ TodoFirebaseService: Deleted list $listId');
    } catch (e) {
      print('❌ TodoFirebaseService: Error deleting list: $e');
      rethrow;
    }
  }

  /// Get all todo lists
  Future<List<TodoListModel>> getAllTodoLists() async {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      final snapshot = await _userTodoListsCollection(uid)
          .orderBy('created_at', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => TodoListModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('❌ TodoFirebaseService: Error getting lists: $e');
      rethrow;
    }
  }

  /// Stream all todo lists
  Stream<List<TodoListModel>> streamAllTodoLists() {
    return Stream.fromFuture(_ensureSignedIn()).asyncExpand((_) {
      final uid = _currentUid;
      if (uid == null) return Stream.value(const <TodoListModel>[]);

      return _userTodoListsCollection(uid)
          .orderBy('created_at', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => TodoListModel.fromFirestore(doc))
              .toList());
    });
  }

  /// Get todo list by ID
  Future<TodoListModel?> getTodoListById(String listId) async {
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      final doc = await _userTodoListsCollection(uid).doc(listId).get();
      if (doc.exists) {
        return TodoListModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('❌ TodoFirebaseService: Error getting list: $e');
      rethrow;
    }
  }

  /// Get todo count by list ID
  Future<int> getTodoCountByListId(String listId) async {
    final todos = await getTodosByListId(listId);
    return todos.where((t) => !t.isCompleted).length;
  }

  // ==================== COMMENTS OPERATIONS ====================

  /// Get comments collection for a todo
  CollectionReference<Map<String, dynamic>> _todoCommentsCollection(
          String uid, String todoId) =>
      _userTodosCollection(uid).doc(todoId).collection('comments');

  /// Add a comment to a todo
  Future<String> addComment(
    String todoId,
    String content, {
    String? ownerUid,
  }) async {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      final commentData = {
        'author_name': _currentUserName,
        'author_id': uid,
        'author_photo': _currentUserPhoto,
        'content': content,
        'type': 'text',
        'created_at': FieldValue.serverTimestamp(),
      };

      final docRef = await _todoCommentsCollection(ownerUid ?? uid, todoId)
          .add(commentData);
      print('✅ TodoFirebaseService: Added comment ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ TodoFirebaseService: Error adding comment: $e');
      rethrow;
    }
  }

  /// Add a voice comment to a todo
  Future<String> addVoiceComment(
      String todoId, String audioUrl, String duration,
      {String? ownerUid}) async {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      final commentData = {
        'author_name': _currentUserName,
        'author_id': uid,
        'author_photo': _currentUserPhoto,
        'content': '🎤 Voice comment ($duration)',
        'audio_url': audioUrl,
        'duration': duration,
        'type': 'voice',
        'created_at': FieldValue.serverTimestamp(),
      };

      final docRef = await _todoCommentsCollection(ownerUid ?? uid, todoId)
          .add(commentData);
      print('✅ TodoFirebaseService: Added voice comment ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ TodoFirebaseService: Error adding voice comment: $e');
      rethrow;
    }
  }

  /// Get comments for a todo
  Future<List<Map<String, dynamic>>> getComments(
    String todoId, {
    String? ownerUid,
  }) async {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      final snapshot = await _todoCommentsCollection(ownerUid ?? uid, todoId)
          .orderBy('created_at', descending: false)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('❌ TodoFirebaseService: Error getting comments: $e');
      rethrow;
    }
  }

  /// Stream comments for a todo
  Stream<List<Map<String, dynamic>>> streamComments(
    String todoId, {
    String? ownerUid,
  }) {
    return Stream.fromFuture(_ensureSignedIn()).asyncExpand((_) {
      final uid = _currentUid;
      if (uid == null) return Stream.value(const <Map<String, dynamic>>[]);

      return _todoCommentsCollection(ownerUid ?? uid, todoId)
          .orderBy('created_at', descending: false)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                return data;
              }).toList());
    });
  }

  /// Delete a comment
  Future<void> deleteComment(
    String todoId,
    String commentId, {
    String? ownerUid,
  }) async {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      await _todoCommentsCollection(ownerUid ?? uid, todoId)
          .doc(commentId)
          .delete();
      print('✅ TodoFirebaseService: Deleted comment $commentId');
    } catch (e) {
      print('❌ TodoFirebaseService: Error deleting comment: $e');
      rethrow;
    }
  }

  // ==================== MEMBER OPERATIONS ====================

  /// Update member completion status by name
  Future<void> updateMemberStatus(
      String todoId, String memberName, bool isCompleted,
      {required bool isAssigned, String? ownerUid}) async {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      final todo = await getTodoById(todoId, ownerUid: ownerUid);
      if (todo == null) throw Exception('Todo not found');
      final resolvedOwnerUid = _resolveOwnerUidForTodo(todo, uid);

      if (isAssigned) {
        // Update assigned members
        if (todo.assignedMembers == null || todo.assignedMembers!.isEmpty) {
          throw Exception('No assigned members found');
        }

        final memberIndex =
            todo.assignedMembers!.indexWhere((m) => m.name == memberName);
        if (memberIndex == -1) throw Exception('Member not found');

        final updatedMembers = List<TaskMember>.from(todo.assignedMembers!);
        updatedMembers[memberIndex] = updatedMembers[memberIndex].copyWith(
          isCompleted: isCompleted,
          completedAt: isCompleted ? DateTime.now() : null,
        );

        // Check if all assigned members completed - mark task as complete
        final allCompleted = updatedMembers.every((m) => m.isCompleted);

        await _userTodosCollection(resolvedOwnerUid).doc(todoId).update({
          'assigned_members': updatedMembers.map((m) => m.toMap()).toList(),
          'is_completed': allCompleted,
          'updated_at': FieldValue.serverTimestamp(),
        });
      } else {
        // Update followed by members
        if (todo.followedUpBy == null || todo.followedUpBy!.isEmpty) {
          throw Exception('No followers found');
        }

        final memberIndex =
            todo.followedUpBy!.indexWhere((m) => m.name == memberName);
        if (memberIndex == -1) throw Exception('Follower not found');

        final updatedFollowers = List<TaskMember>.from(todo.followedUpBy!);
        updatedFollowers[memberIndex] = updatedFollowers[memberIndex].copyWith(
          isCompleted: isCompleted,
          completedAt: isCompleted ? DateTime.now() : null,
        );

        await _userTodosCollection(resolvedOwnerUid).doc(todoId).update({
          'followed_up_by': updatedFollowers.map((m) => m.toMap()).toList(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      print('✅ TodoFirebaseService: Updated member status');
    } catch (e) {
      print('❌ TodoFirebaseService: Error updating member status: $e');
      rethrow;
    }
  }
}
