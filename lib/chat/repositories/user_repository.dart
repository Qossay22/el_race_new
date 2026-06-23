import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:el_race/ui/presentation/todo_list/services/team_members_api_service.dart';

import '../models/models.dart';

/// Repository for user-related Firestore operations.
///
/// Handles:
/// - User profile upsert
/// - User search with keyword-based prefix matching
/// - FCM token management
class UserRepository {
  static UserRepository? _instance;
  static UserRepository get instance => _instance ??= UserRepository._();

  UserRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// In-memory user cache to avoid repeated Firestore reads
  final Map<String, ChatUser> _userCache = {};

  /// Cache expiry tracking (5 minutes)
  final Map<String, DateTime> _cacheTimestamps = {};
  static const _cacheDuration = Duration(minutes: 5);

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  /// Upsert user profile in Firestore.
  /// Creates the document if it doesn't exist, updates if it does.
  Future<void> upsertUser(ChatUserSession session) async {
    final docRef = _usersCollection.doc(session.firebaseUid);
    final keywords = ChatUser.buildSearchKeywords(
      session.name,
      session.email,
      employeeId: session.employeeId,
      employeeFileNumber: session.employeeFileNumber,
      odooUserId: session.odooUserId,
    );

    final data = <String, dynamic>{
      'odoo_user_id': session.odooUserId,
      'employee_id': session.employeeId,
      'employee_file_number': session.employeeFileNumber,
      'name': session.name,
      'role_name': session.roleName,
      'role_id': session.roleId,
      'branch_id': session.branchId,
      'company_id': session.companyId,
      'avatar_url': session.avatarUrl,
      'last_login_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'search_keywords': keywords,
    };

    final safeEmail = _normalizeNullableString(session.email);
    final safePhone = _normalizeNullableString(session.phoneNumber);
    final safeJobTitle = _normalizeNullableString(session.jobTitle);

    if (safeEmail != null) {
      data['email'] = safeEmail;
      data['work_email'] = safeEmail;
    }
    if (safePhone != null) {
      data['phone'] = safePhone;
      data['mobile_phone'] = safePhone;
    }
    if (safeJobTitle != null) {
      data['job_title'] = safeJobTitle;
    }

    try {
      final doc = await docRef.get();
      if (doc.exists) {
        final existing = doc.data() ?? <String, dynamic>{};

        // Never overwrite existing non-empty contact fields with null/empty values.
        if (!data.containsKey('email')) {
          final existingEmail = _normalizeNullableString(
            existing['email']?.toString() ?? existing['work_email']?.toString(),
          );
          if (existingEmail != null) {
            data['email'] = existingEmail;
            data['work_email'] = existingEmail;
          }
        }

        if (!data.containsKey('phone')) {
          final existingPhone = _normalizeNullableString(
            existing['phone']?.toString() ??
                existing['mobile_phone']?.toString() ??
                existing['mobile']?.toString(),
          );
          if (existingPhone != null) {
            data['phone'] = existingPhone;
            data['mobile_phone'] = existingPhone;
          }
        }

        if (!data.containsKey('job_title')) {
          final existingJob = _normalizeNullableString(
            existing['job_title']?.toString() ??
                existing['job_position']?.toString() ??
                existing['designation']?.toString(),
          );
          if (existingJob != null) {
            data['job_title'] = existingJob;
          }
        }

        // Update existing user
        await docRef.update(data);
        print('✅ UserRepository: Updated user ${session.firebaseUid}');
      } else {
        // Create new user
        data['created_at'] = FieldValue.serverTimestamp();
        await docRef.set(data);
        print('✅ UserRepository: Created user ${session.firebaseUid}');
      }
    } catch (e) {
      print('❌ UserRepository: Error upserting user: $e');
      rethrow;
    }
  }

  String? _normalizeNullableString(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    final lower = text.toLowerCase();
    if (lower == 'null' || lower == 'false' || lower == 'n/a' || lower == '-') {
      return null;
    }
    return text;
  }

  int? _readInt(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null || value == false) continue;
      if (value is int) return value;
      if (value is double) return value.toInt();
      final parsed = int.tryParse(value.toString().trim());
      if (parsed != null) return parsed;
    }
    return null;
  }

  Iterable<String> _readSearchCandidateStrings(
    Map<String, dynamic> data,
    List<String> keys,
  ) sync* {
    for (final key in keys) {
      final value = data[key];
      if (value == null || value == false) continue;
      if (value is int || value is double) {
        final parsed = value is int ? value : value.toInt();
        if (parsed > 0) yield parsed.toString();
        continue;
      }
      final normalized = _normalizeNullableString(value.toString());
      if (normalized != null) yield normalized.toLowerCase();
    }
  }

  bool _isNumericQuery(String query) => RegExp(r'^\d+$').hasMatch(query);

  bool _numericSearchMatches(String candidate, String rawQuery) {
    final normalizedCandidate = candidate.trim();
    final normalizedQuery = rawQuery.trim();
    if (normalizedCandidate.isEmpty || normalizedQuery.isEmpty) return false;

    if (normalizedCandidate == normalizedQuery) return true;

    final candidateNoZeros =
        normalizedCandidate.replaceFirst(RegExp(r'^0+'), '');
    final queryNoZeros = normalizedQuery.replaceFirst(RegExp(r'^0+'), '');
    if (candidateNoZeros.isNotEmpty &&
        queryNoZeros.isNotEmpty &&
        candidateNoZeros == queryNoZeros) {
      return true;
    }

    return normalizedCandidate.contains(normalizedQuery);
  }

  Set<String> _collectNumericSearchTokens(
    ChatUser user,
    Map<String, dynamic> data,
  ) {
    final tokens = <String>{
      if (user.employeeId != null && user.employeeId! > 0)
        user.employeeId.toString(),
      if (user.employeeFileNumber != null && user.employeeFileNumber! > 0)
        user.employeeFileNumber.toString(),
      if (user.odooUserId > 0) user.odooUserId.toString(),
      ..._readSearchCandidateStrings(data, const [
        'employee_id',
        'employee_file_number',
        'emp_id',
        'emp_profile_id',
        'file_number',
        'file_no',
        'file_id',
        'odoo_user_id',
        'user_id',
      ]),
    };

    final leadingNumber = RegExp(r'^\s*(\d+)').firstMatch(user.name)?.group(1);
    if (leadingNumber != null) {
      tokens.add(leadingNumber);
    }

    for (final keyword in user.searchKeywords) {
      if (_isNumericQuery(keyword)) {
        tokens.add(keyword);
      }
    }

    return tokens;
  }

  Set<String> _collectMemberNumericTokens(TeamMember member) {
    final tokens = <String>{
      member.id.toString(),
      if (member.employeeId != null && member.employeeId! > 0)
        member.employeeId.toString(),
      if (member.employeeFileNumber != null && member.employeeFileNumber! > 0)
        member.employeeFileNumber.toString(),
      if (member.odooUserId != null && member.odooUserId! > 0)
        member.odooUserId.toString(),
    };

    final leadingNumber =
        RegExp(r'^\s*(\d+)').firstMatch(member.name)?.group(1);
    if (leadingNumber != null) {
      tokens.add(leadingNumber);
    }

    return tokens;
  }

  bool _userMatchesSearchQuery(
    ChatUser user,
    Map<String, dynamic> data,
    String searchTerm,
    String rawQuery,
  ) {
    final name = user.name.toLowerCase();
    final email = (user.email ?? '').toLowerCase();
    if (name.contains(searchTerm) || email.contains(searchTerm)) {
      return true;
    }

    final numericTokens = _collectNumericSearchTokens(user, data);
    if (_isNumericQuery(rawQuery)) {
      return numericTokens.any((token) => _numericSearchMatches(token, rawQuery));
    }

    return numericTokens.any((token) => token.contains(searchTerm));
  }

  bool _memberMatchesSearchQuery(
    TeamMember member,
    String searchTerm,
    String rawQuery,
  ) {
    final name = member.name.toLowerCase();
    final email = (member.email ?? '').toLowerCase();
    if (name.contains(searchTerm) || email.contains(searchTerm)) {
      return true;
    }

    final numericTokens = _collectMemberNumericTokens(member);
    if (_isNumericQuery(rawQuery)) {
      return numericTokens.any((token) => _numericSearchMatches(token, rawQuery));
    }

    return numericTokens.any((token) => token.contains(searchTerm));
  }

  String _firebaseUidForMember(TeamMember member) {
    if (member.odooUserId != null && member.odooUserId! > 0) {
      return 'odoo_${member.odooUserId}';
    }
    return 'odoo_${member.id}';
  }

  ChatUser _chatUserFromTeamMember(TeamMember member) {
    final now = DateTime.now();
    final odooUserId = member.odooUserId ?? member.id;
    return ChatUser(
      uid: _firebaseUidForMember(member),
      odooUserId: odooUserId,
      employeeId: member.employeeId ?? member.id,
      employeeFileNumber: member.employeeFileNumber ?? member.employeeId,
      name: member.name,
      email: member.email,
      jobTitle: member.jobPosition,
      phoneNumber: member.phone,
      roleId: 0,
      companyId: 1,
      avatarUrl: member.image,
      createdAt: now,
      updatedAt: now,
      searchKeywords: ChatUser.buildSearchKeywords(
        member.name,
        member.email,
        employeeId: member.employeeId ?? member.id,
        employeeFileNumber: member.employeeFileNumber,
        odooUserId: odooUserId,
      ),
    );
  }

  Future<void> _appendDirectoryMatches({
    required Map<String, ChatUser> matchedByUid,
    required String searchTerm,
    required String rawQuery,
  }) async {
    try {
      final members = await TeamMembersApiService.instance
          .getTeamMembers()
          .timeout(const Duration(seconds: 12));
      for (final member in members) {
        if (!_memberMatchesSearchQuery(member, searchTerm, rawQuery)) continue;

        final uid = _firebaseUidForMember(member);
        matchedByUid.putIfAbsent(uid, () => _chatUserFromTeamMember(member));
      }
    } catch (e) {
      print('⚠️ UserRepository: Directory search fallback failed: $e');
    }
  }

  /// Get a user by UID (cached)
  Future<ChatUser?> getUser(String uid) async {
    // Check cache first
    final cached = _userCache[uid];
    final cachedAt = _cacheTimestamps[uid];
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _cacheDuration) {
      return cached;
    }

    try {
      final doc = await _usersCollection.doc(uid).get();
      if (!doc.exists) return null;
      final user = ChatUser.fromFirestore(doc);
      _userCache[uid] = user;
      _cacheTimestamps[uid] = DateTime.now();
      return user;
    } catch (e) {
      print('❌ UserRepository: Error getting user: $e');
      return cached; // Return stale cache on error
    }
  }

  /// Get a user from cache only (sync, no Firestore call)
  ChatUser? getCachedUser(String uid) => _userCache[uid];

  /// Pre-warm user cache for multiple UIDs
  Future<void> prefetchUsers(List<String> uids) async {
    final uncached = uids.where((uid) {
      final cachedAt = _cacheTimestamps[uid];
      return cachedAt == null ||
          DateTime.now().difference(cachedAt) >= _cacheDuration;
    }).toList();
    if (uncached.isEmpty) return;
    final users = await getUsersByIds(uncached);
    for (final user in users) {
      _userCache[user.uid] = user;
      _cacheTimestamps[user.uid] = DateTime.now();
    }
  }

  /// Get user stream by UID
  Stream<ChatUser?> subscribeToUser(String uid) {
    return _usersCollection.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ChatUser.fromFirestore(doc);
    });
  }

  /// Lookup employee directory row for a chat user (cached API).
  Future<TeamMember?> findDirectoryMatchForUser(ChatUser user) async {
    try {
      final members = await TeamMembersApiService.instance.getTeamMembers();
      if (members.isEmpty) return null;
      return _findBestDirectoryMatch(user, members);
    } catch (e) {
      print('❌ UserRepository: findDirectoryMatchForUser failed: $e');
      return null;
    }
  }

  /// Fills missing email/phone/job fields from employee directory API and
  /// persists the resolved values to Firestore.
  Future<bool> hydrateUserProfileFromEmployeeDirectory(ChatUser user) async {
    final needsEmail = !_hasValidEmail(user.email);
    final needsPhone = _normalizeNullableString(user.phoneNumber) == null;
    final needsJob = !_hasValidJobTitle(user);
    final needsFileNumber = _resolveEmployeeFileNumber(user) == null;

    if (!needsEmail && !needsPhone && !needsJob && !needsFileNumber) {
      return false;
    }

    try {
      final members = await TeamMembersApiService.instance.getTeamMembers();
      if (members.isEmpty) {
        print('⚠️ UserRepository: employee directory is empty');
        return false;
      }

      final match = _findBestDirectoryMatch(user, members);
      if (match == null) {
        print('⚠️ UserRepository: no directory match for ${user.uid} '
            '(employeeId=${user.employeeId}, odooUserId=${user.odooUserId}, name=${user.name})');
        return false;
      }

      final resolvedEmail = _normalizeNullableString(match.email);
      final resolvedPhone = _normalizeNullableString(match.phone);
      final resolvedJob = _normalizeNullableString(match.jobPosition);
      final resolvedFileNumber = match.employeeFileNumber;

      final patch = <String, dynamic>{
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (needsEmail && resolvedEmail != null) {
        patch['email'] = resolvedEmail;
        patch['work_email'] = resolvedEmail;
      }
      if (needsPhone && resolvedPhone != null) {
        patch['phone'] = resolvedPhone;
        patch['mobile_phone'] = resolvedPhone;
      }
      if (needsJob && resolvedJob != null && !_isWeakJobTitleValue(resolvedJob)) {
        patch['job_title'] = resolvedJob;
      }
      if (needsFileNumber && resolvedFileNumber != null) {
        patch['employee_file_number'] = resolvedFileNumber;
        if (user.employeeId == null || user.employeeId == 0) {
          patch['employee_id'] = match.employeeId ?? match.id;
        }
      }

      if (patch.length == 1) {
        print(
            '⚠️ UserRepository: matched member ${match.id} has no usable contact values');
        return false;
      }

      await _usersCollection.doc(user.uid).set(patch, SetOptions(merge: true));
      _userCache.remove(user.uid);
      _cacheTimestamps.remove(user.uid);

      print('✅ UserRepository: hydrated ${user.uid} from directory '
          '(memberId=${match.id}, email=${patch['email']}, phone=${patch['phone']}, job=${patch['job_title']})');
      return true;
    } catch (e) {
      print('❌ UserRepository: Error hydrating profile from directory: $e');
      return false;
    }
  }

  int? _odooIdFromFirebaseUid(String uid) {
    final match = RegExp(r'^odoo_(\d+)$').firstMatch(uid.trim());
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  int? _employeeNumberFromName(String? name) {
    if (name == null) return null;
    final leading = RegExp(r'^\s*(\d+)').firstMatch(name.trim());
    if (leading == null) return null;
    return int.tryParse(leading.group(1)!);
  }

  int? _resolveEmployeeFileNumber(ChatUser user) {
    if (user.employeeFileNumber != null && user.employeeFileNumber! > 0) {
      return user.employeeFileNumber;
    }
    final fromName = _employeeNumberFromName(user.name);
    if (fromName != null && fromName > 0) return fromName;
    if (user.employeeId != null && user.employeeId! > 0) {
      return user.employeeId;
    }
    final fromUid = _odooIdFromFirebaseUid(user.uid);
    if (fromUid != null && fromUid > 0) return fromUid;
    if (user.odooUserId > 0) return user.odooUserId;
    return null;
  }

  bool _hasValidEmail(String? email) {
    final normalized = _normalizeNullableString(email);
    if (normalized == null) return false;
    return normalized.contains('@') && normalized.contains('.');
  }

  bool _isWeakJobTitleValue(String? value) {
    final normalized = _normalizeNullableString(value);
    if (normalized == null) return true;
    if (RegExp(r'^\d+$').hasMatch(normalized)) return true;
    if (RegExp(r'^role\s*\d+$', caseSensitive: false).hasMatch(normalized)) {
      return true;
    }
    return false;
  }

  bool _hasValidJobTitle(ChatUser user) {
    final job = _normalizeNullableString(user.jobTitle);
    if (job != null && !_isWeakJobTitleValue(job)) {
      final roleName = _normalizeNullableString(user.roleName);
      if (roleName == null || job.toLowerCase() != roleName.toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  TeamMember? _findBestDirectoryMatch(ChatUser user, List<TeamMember> members) {
    final firebaseOdooId = _odooIdFromFirebaseUid(user.uid);
    if (firebaseOdooId != null) {
      for (final member in members) {
        if (member.odooUserId == firebaseOdooId ||
            member.id == firebaseOdooId ||
            member.employeeId == firebaseOdooId) {
          return member;
        }
      }
    }

    final employeeId = user.employeeId;
    if (employeeId != null) {
      for (final member in members) {
        if (member.employeeId == employeeId ||
            member.employeeFileNumber == employeeId ||
            member.id == employeeId) {
          return member;
        }
      }
    }

    final employeeFileNumber = user.employeeFileNumber;
    if (employeeFileNumber != null) {
      for (final member in members) {
        if (member.employeeFileNumber == employeeFileNumber ||
            member.id == employeeFileNumber ||
            member.employeeId == employeeFileNumber) {
          return member;
        }
      }
    }

    if (user.odooUserId > 0) {
      for (final member in members) {
        if (member.odooUserId == user.odooUserId) {
          return member;
        }
      }
    }

    final normalizedName = user.name.trim().toLowerCase();
    if (normalizedName.isNotEmpty) {
      for (final member in members) {
        if (member.name.trim().toLowerCase() == normalizedName) {
          return member;
        }
      }
    }

    return null;
  }

  /// Bulk-hydrate missing email/phone/job for ALL users in Firestore
  /// by matching against the employee directory API.
  /// Runs in background — safe to fire-and-forget.
  Future<int> hydrateAllUsersFromDirectory() async {
    try {
      final members = await TeamMembersApiService.instance.getTeamMembers();
      if (members.isEmpty) {
        print('⚠️ UserRepository: employee directory is empty, skipping bulk hydration');
        return 0;
      }

      // Fetch all Firestore users
      final snapshot = await _usersCollection.get();
      int updatedCount = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final email = _normalizeNullableString(data['email']?.toString() ?? data['work_email']?.toString());
        final phone = _normalizeNullableString(data['phone']?.toString() ?? data['mobile_phone']?.toString());
        final job = _normalizeNullableString(data['job_title']?.toString());
        final employeeFileNumber = _readInt(data, const [
          'employee_file_number',
          'emp_id',
          'file_number',
          'file_no',
          'file_id',
        ]);

        // Skip if already has all fields
        if (email != null &&
            phone != null &&
            job != null &&
            employeeFileNumber != null) {
          continue;
        }

        // Build a lightweight ChatUser for matching
        final tempUser = ChatUser(
          uid: doc.id,
          odooUserId: data['odoo_user_id'] ?? 0,
          employeeId: data['employee_id'],
          employeeFileNumber: employeeFileNumber,
          name: data['name'] ?? '',
          email: email,
          phoneNumber: phone,
          jobTitle: job,
          roleId: data['role_id'] ?? 0,
          companyId: data['company_id'] ?? 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final match = _findBestDirectoryMatch(tempUser, members);
        if (match == null) continue;

        final patch = <String, dynamic>{
          'updated_at': FieldValue.serverTimestamp(),
        };

        final resolvedEmail = _normalizeNullableString(match.email);
        final resolvedPhone = _normalizeNullableString(match.phone);
        final resolvedJob = _normalizeNullableString(match.jobPosition);
        final resolvedFileNumber = match.employeeFileNumber;

        if (email == null && resolvedEmail != null) {
          patch['email'] = resolvedEmail;
          patch['work_email'] = resolvedEmail;
        }
        if (phone == null && resolvedPhone != null) {
          patch['phone'] = resolvedPhone;
          patch['mobile_phone'] = resolvedPhone;
        }
        if (job == null && resolvedJob != null) {
          patch['job_title'] = resolvedJob;
        }
        if (employeeFileNumber == null && resolvedFileNumber != null) {
          patch['employee_file_number'] = resolvedFileNumber;
        }

        if (patch.length <= 1) continue; // only 'updated_at'

        await _usersCollection.doc(doc.id).set(patch, SetOptions(merge: true));
        _userCache.remove(doc.id);
        _cacheTimestamps.remove(doc.id);
        updatedCount++;
      }

      print('✅ UserRepository: Bulk hydration complete — updated $updatedCount users');
      return updatedCount;
    } catch (e) {
      print('❌ UserRepository: Error during bulk hydration: $e');
      return 0;
    }
  }

  /// Whether two profiles refer to the same employee.
  static bool isSameChatPerson(ChatUser a, ChatUser b) {
    if (a.uid == b.uid) return true;
    if (a.odooUserId > 0 && a.odooUserId == b.odooUserId) return true;
    if (a.employeeFileNumber != null &&
        a.employeeFileNumber == b.employeeFileNumber) {
      return true;
    }
    if (a.employeeId != null && a.employeeId == b.employeeId) return true;

    final aName = a.name
        .replaceFirst(RegExp(r'^\s*\d+\s*[-:|#]*\s*'), '')
        .trim()
        .toLowerCase();
    final bName = b.name
        .replaceFirst(RegExp(r'^\s*\d+\s*[-:|#]*\s*'), '')
        .trim()
        .toLowerCase();
    if (aName.isNotEmpty && aName == bName) return true;
    return false;
  }

  /// Prefer canonical Firebase uid (`odoo_{id}`) when duplicates exist.
  Future<ChatUser> resolveCanonicalChatUser(ChatUser user) async {
    if (user.odooUserId > 0) {
      final canonicalUid = 'odoo_${user.odooUserId}';
      if (canonicalUid != user.uid) {
        final canonical = await getUser(canonicalUid);
        if (canonical != null && isSameChatPerson(canonical, user)) {
          return canonical;
        }
      }
    }
    return user;
  }

  /// Search users by fetching all and filtering client-side.
  /// No Firestore index required.
  Future<UserSearchResult> searchUsers({
    required String query,
    int limit = 20,
    DocumentSnapshot? startAfter,
    int? companyId, // Optional filter by company
  }) async {
    final rawQuery = query.trim();
    if (rawQuery.isEmpty) {
      return UserSearchResult(users: [], hasMore: false);
    }

    final searchTerm = rawQuery.toLowerCase();
    final isNumericQuery = _isNumericQuery(rawQuery);

    try {
      final matchedByUid = <String, ChatUser>{};

      // File-number / employee-id searches are best served from the employee
      // directory API. Avoid downloading the entire Firestore users collection
      // unless we still need a name/email lookup fallback.
      if (isNumericQuery) {
        await _appendDirectoryMatches(
          matchedByUid: matchedByUid,
          searchTerm: searchTerm,
          rawQuery: rawQuery,
        );
      }

      if (!isNumericQuery || matchedByUid.isEmpty) {
        Query<Map<String, dynamic>> queryBuilder = _usersCollection;

        if (companyId != null) {
          queryBuilder =
              queryBuilder.where('company_id', isEqualTo: companyId);
        }

        final snapshot = await queryBuilder
            .get()
            .timeout(const Duration(seconds: 12));

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final user = ChatUser.fromFirestore(doc);
          if (!_userMatchesSearchQuery(user, data, searchTerm, rawQuery)) {
            continue;
          }
          matchedByUid[user.uid] = user;
        }
      }

      // For numeric queries, directory is primary. For text queries, use it
      // only as a fallback when Firestore returned nothing.
      if (!isNumericQuery && matchedByUid.isEmpty) {
        await _appendDirectoryMatches(
          matchedByUid: matchedByUid,
          searchTerm: searchTerm,
          rawQuery: rawQuery,
        );
      }

      final allUsers = matchedByUid.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      // Apply limit
      final hasMore = allUsers.length > limit;
      final users = hasMore ? allUsers.sublist(0, limit) : allUsers;

      return UserSearchResult(
        users: users,
        hasMore: hasMore,
        lastDocument: null, // Not using pagination with this approach
      );
    } catch (e) {
      print('❌ UserRepository: Error searching users: $e');
      return UserSearchResult(users: [], hasMore: false, error: e.toString());
    }
  }

  /// Get multiple users by UIDs
  Future<List<ChatUser>> getUsersByIds(List<String> uids) async {
    if (uids.isEmpty) return [];

    try {
      // Firestore whereIn has a limit of 10, so batch if needed
      final users = <ChatUser>[];
      final batches = <List<String>>[];

      for (var i = 0; i < uids.length; i += 10) {
        final end = (i + 10 < uids.length) ? i + 10 : uids.length;
        batches.add(uids.sublist(i, end));
      }

      for (final batch in batches) {
        final snapshot = await _usersCollection
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        users.addAll(snapshot.docs.map((doc) => ChatUser.fromFirestore(doc)));
      }

      return users;
    } catch (e) {
      print('❌ UserRepository: Error getting users by IDs: $e');
      return [];
    }
  }

  /// Update user's last seen timestamp
  Future<void> updateLastSeen(String uid) async {
    try {
      await _usersCollection.doc(uid).update({
        'last_seen_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ UserRepository: Error updating last seen: $e');
    }
  }

  // ============== FCM Token Management ==============

  /// Store FCM token for user
  Future<void> storeFcmToken(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) {
        print('⚠️ UserRepository: FCM token is null');
        return;
      }

      final platform = Platform.isIOS ? 'ios' : 'android';

      await _usersCollection.doc(uid).collection('fcm_tokens').doc(token).set({
        'created_at': FieldValue.serverTimestamp(),
        'platform': platform,
      });

      print('✅ UserRepository: Stored FCM token for $uid');

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _usersCollection.doc(uid).collection('fcm_tokens').doc(newToken).set({
          'created_at': FieldValue.serverTimestamp(),
          'platform': platform,
        });
        print('✅ UserRepository: Updated FCM token for $uid');
      });
    } catch (e) {
      print('❌ UserRepository: Error storing FCM token: $e');
    }
  }

  /// Remove FCM token (e.g., on logout)
  Future<void> removeFcmToken(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      await _usersCollection
          .doc(uid)
          .collection('fcm_tokens')
          .doc(token)
          .delete();

      print('✅ UserRepository: Removed FCM token for $uid');
    } catch (e) {
      print('❌ UserRepository: Error removing FCM token: $e');
    }
  }

  /// Subscribe to FCM topic for role-based notifications
  Future<void> subscribeToRoleTopic(String topicName) async {
    try {
      await _messaging.subscribeToTopic(topicName);
      print('✅ UserRepository: Subscribed to topic $topicName');
    } catch (e) {
      print('❌ UserRepository: Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from FCM topic
  Future<void> unsubscribeFromRoleTopic(String topicName) async {
    try {
      await _messaging.unsubscribeFromTopic(topicName);
      print('✅ UserRepository: Unsubscribed from topic $topicName');
    } catch (e) {
      print('❌ UserRepository: Error unsubscribing from topic: $e');
    }
  }
}

/// Result of user search with pagination support
class UserSearchResult {
  final List<ChatUser> users;
  final bool hasMore;
  final DocumentSnapshot? lastDocument;
  final String? error;

  UserSearchResult({
    required this.users,
    required this.hasMore,
    this.lastDocument,
    this.error,
  });

  bool get hasError => error != null;
}
