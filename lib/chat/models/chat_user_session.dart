/// Chat user session model that captures backend login response
/// for Firebase chat setup.
///
/// This model extracts and normalizes the fields needed for chat initialization
/// from the existing backend login response.
class ChatUserSession {
  /// Backend JWT token (for other API calls, not Firebase)
  final String backendJwt;

  /// Odoo user ID - MUST NOT be null
  final int odooUserId;

  /// Employee ID (optional)
  final int? employeeId;

  /// Employee file number (optional, usually backend emp_id)
  final int? employeeFileNumber;

  /// User's display name
  final String name;

  /// User's email (optional but desirable)
  final String? email;

  /// Role ID for role-based chat groups
  final int roleId;

  /// Branch ID (optional)
  final int? branchId;

  /// Company ID
  final int companyId;

  /// Firebase UID - expected format: "odoo_{odoo_user_id}"
  final String firebaseUid;

  /// Firebase custom token for signInWithCustomToken
  final String? firebaseCustomToken;

  /// Role chat ID (optional, backend may provide specific ID)
  final String? roleChatId;

  /// Role name (e.g., "IT Admin", "Engineer")
  final String? roleName;

  /// Avatar URL (must be URL, NOT base64)
  final String? avatarUrl;

  /// Job title (optional)
  final String? jobTitle;

  /// Phone number (optional)
  final String? phoneNumber;

  ChatUserSession({
    required this.backendJwt,
    required this.odooUserId,
    this.employeeId,
    this.employeeFileNumber,
    required this.name,
    this.email,
    required this.roleId,
    this.roleName,
    this.branchId,
    required this.companyId,
    required this.firebaseUid,
    this.firebaseCustomToken,
    this.roleChatId,
    this.avatarUrl,
    this.jobTitle,
    this.phoneNumber,
  });

  /// Create session from backend login response JSON.
  /// Call this when backend adds firebase_* fields to login response.
  factory ChatUserSession.fromLoginResponse(Map<String, dynamic> json) {
    // DEBUG: Print the full structure to find firebase_custom_token
    print('🔍 ChatUserSession: Parsing login response...');
    print('🔍 Top-level keys: ${json.keys.toList()}');

    final result = json['result'];
    if (result != null && result is Map) {
      print('🔍 result keys: ${(result as Map).keys.toList()}');
    }

    final data = json['result']?['data'] ?? json['data'] ?? json;
    print(
        '🔍 data keys: ${data is Map ? (data as Map).keys.toList() : "not a map"}');

    // Check for firebase_custom_token at different levels
    final tokenFromData = data['firebase_custom_token'];
    final tokenFromResult = json['result']?['firebase_custom_token'];
    final tokenFromRoot = json['firebase_custom_token'];

    print('🔍 firebase_custom_token locations:');
    print(
        '   - In data: ${tokenFromData != null ? "FOUND (${tokenFromData.toString().length} chars)" : "NOT FOUND"}');
    print(
        '   - In result: ${tokenFromResult != null ? "FOUND (${tokenFromResult.toString().length} chars)" : "NOT FOUND"}');
    print(
        '   - In root: ${tokenFromRoot != null ? "FOUND (${tokenFromRoot.toString().length} chars)" : "NOT FOUND"}');

    // Use token from wherever it's found
    final String? firebaseToken = tokenFromData?.toString() ??
        tokenFromResult?.toString() ??
        tokenFromRoot?.toString();

    print(
        '🔍 Final firebase_custom_token: ${firebaseToken != null ? "FOUND (${firebaseToken.length} chars)" : "NOT FOUND ❌"}');

    // Check for firebase_uid at different levels
    final uidFromData = data['firebase_uid'];
    final uidFromResult = json['result']?['firebase_uid'];
    final uidFromRoot = json['firebase_uid'];

    print('🔍 firebase_uid locations:');
    print('   - In data: ${uidFromData ?? "NOT FOUND"}');
    print('   - In result: ${uidFromResult ?? "NOT FOUND"}');
    print('   - In root: ${uidFromRoot ?? "NOT FOUND"}');

    final token = json['result']?['token'] ?? json['token'] ?? '';

    // odoo_user_id: prefer explicit field, fallback to uid or user_id
    final int odooUserId = _extractInt(data['odoo_user_id']) ??
        _extractInt(data['user_id']) ??
        _extractInt(data['uid']) ??
        0;

    print('🔍 odoo_user_id: $odooUserId');

    // Firebase UID: use provided or generate from odoo_user_id
    final String firebaseUid = uidFromData?.toString() ??
        uidFromResult?.toString() ??
        uidFromRoot?.toString() ??
        'odoo_$odooUserId';

    print('🔍 Final firebase_uid: $firebaseUid');

    // Role ID extraction - try multiple possible field names
    final int roleId = _extractInt(data['role_id']) ??
        _extractInt(data['default_role_id']) ??
        0;

    // Role name extraction from roles list
    final roles = data['roles'];
    String? roleName;
    if (roles != null && roles is List && roles.isNotEmpty) {
      roleName = roles.first?.toString();
      print('🔍 Role name from roles list: $roleName');
    }

    // Avatar URL extraction - check multiple locations
    final avatarFromData = data['image_url'] ?? data['avatar_url'];
    final avatarFromResult =
        json['result']?['image_url'] ?? json['result']?['avatar_url'];
    final avatarFromRoot = json['image_url'] ?? json['avatar_url'];

    print('🖼️ Avatar URL locations:');
    print('   - In data: ${avatarFromData ?? "NOT FOUND"}');
    print('   - In result: ${avatarFromResult ?? "NOT FOUND"}');
    print('   - In root: ${avatarFromRoot ?? "NOT FOUND"}');

    final rawAvatarUrl = avatarFromData ?? avatarFromResult ?? avatarFromRoot;
    final String? avatarUrl = _extractAvatarUrl(rawAvatarUrl);
    print('🖼️ Final avatar URL: ${avatarUrl ?? "NONE"}');

    // Branch ID: prefer default_operating_unit_id as per backend update
    final int? branchId = _extractInt(data['default_operating_unit_id']) ??
        _extractInt(data['branch_id']);

    return ChatUserSession(
      backendJwt: token,
      odooUserId: odooUserId,
      employeeId:
          _extractInt(data['employee_id']) ?? _extractInt(data['emp_id']),
      employeeFileNumber: _extractInt(data['employee_file_number']) ??
          _extractInt(data['emp_id']) ??
          _extractInt(data['emp_profile_id']) ??
          _extractInt(data['file_number']) ??
          _extractInt(data['file_no']) ??
          _extractInt(data['file_id']),
      name: data['name']?.toString() ??
          data['emp_name']?.toString() ??
          data['username']?.toString() ??
          '',
      email: _extractEmail(data),
      roleId: roleId,
      roleName: roleName,
      branchId: branchId,
      companyId:
          _extractInt(data['company_id']) ?? 1, // Always 1 as per backend
      firebaseUid: firebaseUid,
      firebaseCustomToken: firebaseToken, // Use the token found at any level
      roleChatId: data['role_chat_id']?.toString(),
      avatarUrl: avatarUrl,
      jobTitle: _extractString(data, const [
        'job_title',
        'job_position',
        'designation',
        'position',
        'title',
      ]),
      phoneNumber: _extractString(data, const [
        'phone',
        'phone_number',
        'mobile_phone',
        'mobile',
        'mobile_number',
        'work_phone',
        'emp_phone',
        'telephone',
      ]),
    );
  }

  static String? _extractEmail(Map<String, dynamic> data) {
    final raw = _extractString(data, const [
      'email',
      'work_email',
      'official_email',
      'personal_email',
      'email_address',
      'mail',
      'username',
    ]);
    if (raw == null) return null;
    // Keep only realistic email values.
    if (!raw.contains('@')) return null;
    return raw;
  }

  static String? _extractString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null || value == false) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return null;
  }

  /// Extract int from various possible types (int, String, etc.)
  static int? _extractInt(dynamic value) {
    if (value == null || value == false) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Extract avatar URL, filtering out base64 data
  static String? _extractAvatarUrl(dynamic value) {
    if (value == null || value == false || value == '') return null;
    final str = value.toString();
    // Skip base64 images
    if (str.startsWith('data:') || str.length > 500) return null;
    // Only accept http/https URLs
    if (str.startsWith('http://') || str.startsWith('https://')) {
      return str;
    }
    return null;
  }

  /// Check if Firebase chat is available (has custom token)
  bool get isChatAvailable =>
      firebaseCustomToken != null && firebaseCustomToken!.isNotEmpty;

  /// Computed role chat ID based on configuration
  String getRoleChatId({bool groupByBranch = false}) {
    if (roleChatId != null && roleChatId!.isNotEmpty) {
      return roleChatId!;
    }
    if (groupByBranch && branchId != null) {
      return 'role_${roleId}_branch_$branchId';
    }
    return 'role_$roleId';
  }

  /// Get FCM topic name for role group (sanitized)
  String getRoleTopicName({bool groupByBranch = false}) {
    final baseTopic = getRoleChatId(groupByBranch: groupByBranch);
    // Sanitize: only letters, numbers, underscores, hyphens allowed
    return baseTopic.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  @override
  String toString() =>
      'ChatUserSession(uid: $firebaseUid, name: $name, roleId: $roleId)';

  Map<String, dynamic> toJson() => {
        'backend_jwt': backendJwt,
        'odoo_user_id': odooUserId,
        'employee_id': employeeId,
        'employee_file_number': employeeFileNumber,
        'name': name,
        'email': email,
        'role_id': roleId,
        'role_name': roleName,
        'branch_id': branchId,
        'company_id': companyId,
        'firebase_uid': firebaseUid,
        'firebase_custom_token': firebaseCustomToken != null ? '***' : null,
        'role_chat_id': roleChatId,
        'avatar_url': avatarUrl,
        'job_title': jobTitle,
        'phone': phoneNumber,
      };

  factory ChatUserSession.fromJson(Map<String, dynamic> json) =>
      ChatUserSession(
        backendJwt: json['backend_jwt'] ?? '',
        odooUserId: json['odoo_user_id'] ?? 0,
        employeeId: json['employee_id'],
        employeeFileNumber: json['employee_file_number'] ?? json['emp_id'],
        name: json['name'] ?? '',
        email: json['email'],
        roleId: json['role_id'] ?? 0,
        roleName: json['role_name'],
        branchId: json['branch_id'],
        companyId: json['company_id'] ?? 1,
        firebaseUid: json['firebase_uid'] ?? '',
        firebaseCustomToken: json['firebase_custom_token'],
        roleChatId: json['role_chat_id'],
        avatarUrl: json['avatar_url'],
        jobTitle: json['job_title'],
        phoneNumber: json['phone'],
      );
}

/// Result of chat setup after backend login
class ChatSetupResult {
  final bool success;
  final String? firebaseUid;
  final String? error;
  final bool chatEnabled;
  final String? roleChatId;

  ChatSetupResult({
    required this.success,
    this.firebaseUid,
    this.error,
    this.chatEnabled = false,
    this.roleChatId,
  });

  factory ChatSetupResult.success({
    required String firebaseUid,
    required String roleChatId,
  }) =>
      ChatSetupResult(
        success: true,
        firebaseUid: firebaseUid,
        chatEnabled: true,
        roleChatId: roleChatId,
      );

  factory ChatSetupResult.failed(String error) => ChatSetupResult(
        success: false,
        error: error,
        chatEnabled: false,
      );

  factory ChatSetupResult.disabled(String reason) => ChatSetupResult(
        success: true, // Not a failure, just not available
        error: reason,
        chatEnabled: false,
      );

  @override
  String toString() =>
      'ChatSetupResult(success: $success, chatEnabled: $chatEnabled, uid: $firebaseUid)';
}
