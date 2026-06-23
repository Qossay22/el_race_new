import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a user profile in the chat system.
/// Stored in Firestore at: users/{uid}
class ChatUser {
  final String uid;
  final int odooUserId;
  final int? employeeId;
  final int? employeeFileNumber;
  final String name;
  final String? email;
  final String? roleName;
  final String? jobTitle;
  final String? phoneNumber;
  final int roleId;
  final int? branchId;
  final int companyId;
  final String? avatarUrl;
  final DateTime? lastSeenAt;
  final DateTime? lastLoginAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> searchKeywords;

  ChatUser({
    required this.uid,
    required this.odooUserId,
    this.employeeId,
    this.employeeFileNumber,
    required this.name,
    this.email,
    this.roleName,
    this.jobTitle,
    this.phoneNumber,
    required this.roleId,
    this.branchId,
    required this.companyId,
    this.avatarUrl,
    this.lastSeenAt,
    this.lastLoginAt,
    required this.createdAt,
    required this.updatedAt,
    this.searchKeywords = const [],
  });

  /// Generate search keywords from name, email, and employee identifiers.
  static List<String> buildSearchKeywords(
    String name,
    String? email, {
    int? employeeId,
    int? employeeFileNumber,
    int? odooUserId,
  }) {
    final keywords = <String>{};

    void addNumeric(int? value) {
      if (value == null || value <= 0) return;
      keywords.add(value.toString());
    }

    addNumeric(employeeId);
    addNumeric(employeeFileNumber);
    addNumeric(odooUserId);

    // Some employee names include the file number prefix (e.g. "1234 - Ahmed").
    final leadingNumber = RegExp(r'^\s*(\d+)').firstMatch(name);
    if (leadingNumber != null) {
      keywords.add(leadingNumber.group(1)!);
    }

    // Process name tokens
    final nameTokens = name.toLowerCase().split(RegExp(r'\s+'));
    for (final token in nameTokens) {
      if (token.isEmpty) continue;
      // Add full token and prefixes (min 2 chars)
      keywords.add(token);
      for (int i = 2; i < token.length; i++) {
        keywords.add(token.substring(0, i));
      }
    }

    // Process email if present
    if (email != null && email.isNotEmpty) {
      final emailLower = email.toLowerCase();
      keywords.add(emailLower);

      // Extract username part (before @)
      final atIndex = emailLower.indexOf('@');
      if (atIndex > 0) {
        final username = emailLower.substring(0, atIndex);
        keywords.add(username);
        for (int i = 2; i < username.length; i++) {
          keywords.add(username.substring(0, i));
        }
      }
    }

    return keywords.toList();
  }

  factory ChatUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final resolvedEmail = _readString(data, const [
      'email',
      'work_email',
      'personal_email',
      'official_email',
      'mail',
      'username',
    ]);
    final resolvedJobTitle = _readString(data, const [
      'job_title',
      'job_position',
      'job',
      'designation',
      'position',
      'title',
    ]);
    final resolvedPhone = _readString(data, const [
      'phone',
      'phone_number',
      'mobile_phone',
      'mobile',
      'mobile_number',
      'work_phone',
      'emp_phone',
      'telephone',
    ]);

    if (resolvedEmail == null || resolvedPhone == null) {
      print('👤 ChatUser.fromFirestore: uid=${doc.id} missingFields '
          'email=${resolvedEmail ?? 'null'} phone=${resolvedPhone ?? 'null'}');
      print('👤 ChatUser.fromFirestore: available keys=${data.keys.toList()}');
      print('👤 ChatUser.fromFirestore: email candidates -> '
          'email=${data['email']} work_email=${data['work_email']} '
          'personal_email=${data['personal_email']} official_email=${data['official_email']} '
          'mail=${data['mail']} username=${data['username']}');
      print('👤 ChatUser.fromFirestore: phone candidates -> '
          'phone=${data['phone']} phone_number=${data['phone_number']} '
          'mobile_phone=${data['mobile_phone']} mobile=${data['mobile']} '
          'mobile_number=${data['mobile_number']} work_phone=${data['work_phone']} '
          'emp_phone=${data['emp_phone']} telephone=${data['telephone']}');
    }

    return ChatUser(
      uid: doc.id,
      odooUserId: data['odoo_user_id'] ?? 0,
      employeeId: data['employee_id'],
      employeeFileNumber: _readInt(data, const [
        'employee_file_number',
        'emp_id',
        'emp_profile_id',
        'file_number',
        'file_no',
        'file_id',
      ]),
      name: data['name'] ?? '',
      email: resolvedEmail,
      roleName: data['role_name']?.toString(),
      jobTitle: resolvedJobTitle,
      phoneNumber: resolvedPhone,
      roleId: data['role_id'] ?? 0,
      branchId: data['branch_id'],
      companyId: data['company_id'] ?? 0,
      avatarUrl: data['avatar_url'],
      lastSeenAt: (data['last_seen_at'] as Timestamp?)?.toDate(),
      lastLoginAt: (data['last_login_at'] as Timestamp?)?.toDate(),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      searchKeywords: List<String>.from(data['search_keywords'] ?? []),
    );
  }

  static String? _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null || value == false) continue;
      final text = value.toString().trim();
      if (text.isEmpty) continue;
      final lower = text.toLowerCase();
      if (lower == 'null' ||
          lower == 'false' ||
          lower == 'n/a' ||
          lower == '-') {
        continue;
      }
      return text;
    }
    return null;
  }

  static int? _readInt(Map<String, dynamic> data, List<String> keys) {
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

  Map<String, dynamic> toFirestore({bool isUpdate = false}) {
    final map = <String, dynamic>{
      'odoo_user_id': odooUserId,
      'employee_id': employeeId,
      'employee_file_number': employeeFileNumber,
      'name': name,
      'email': email,
      'role_name': roleName,
      'job_title': jobTitle,
      'phone': phoneNumber,
      'role_id': roleId,
      'branch_id': branchId,
      'company_id': companyId,
      'avatar_url': avatarUrl,
      'last_login_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'search_keywords': searchKeywords,
    };

    if (!isUpdate) {
      map['created_at'] = FieldValue.serverTimestamp();
    }

    return map;
  }

  ChatUser copyWith({
    String? uid,
    int? odooUserId,
    int? employeeId,
    int? employeeFileNumber,
    String? name,
    String? email,
    String? roleName,
    String? jobTitle,
    String? phoneNumber,
    int? roleId,
    int? branchId,
    int? companyId,
    String? avatarUrl,
    DateTime? lastSeenAt,
    DateTime? lastLoginAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? searchKeywords,
  }) {
    return ChatUser(
      uid: uid ?? this.uid,
      odooUserId: odooUserId ?? this.odooUserId,
      employeeId: employeeId ?? this.employeeId,
      employeeFileNumber: employeeFileNumber ?? this.employeeFileNumber,
      name: name ?? this.name,
      email: email ?? this.email,
      roleName: roleName ?? this.roleName,
      jobTitle: jobTitle ?? this.jobTitle,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      roleId: roleId ?? this.roleId,
      branchId: branchId ?? this.branchId,
      companyId: companyId ?? this.companyId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      searchKeywords: searchKeywords ?? this.searchKeywords,
    );
  }

  @override
  String toString() => 'ChatUser(uid: $uid, name: $name, email: $email)';
}
