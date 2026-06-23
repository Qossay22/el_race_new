import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/tasks_dashboard/services/teams_api_service.dart';

/// Model for team member fetched from backend
class TeamMember {
  final int id;
  final int? employeeId;
  final int? employeeFileNumber;
  final int? odooUserId;
  final String name;
  final String? email;
  final String? phone;
  final String? jobPosition;
  final String? department;
  final String? image;

  const TeamMember({
    required this.id,
    this.employeeId,
    this.employeeFileNumber,
    this.odooUserId,
    required this.name,
    this.email,
    this.phone,
    this.jobPosition,
    this.department,
    this.image,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    final id = _asInt(
          json['id'] ??
              json['employee_id'] ??
              json['emp_id'] ??
              json['odoo_user_id'] ??
              json['user_id'],
        ) ??
        0;

    return TeamMember(
      id: id,
      employeeId:
          _asInt(json['employee_id'] ?? json['emp_id'] ?? json['id']) ?? id,
      employeeFileNumber: _asInt(
        json['employee_file_number'] ??
            json['emp_id'] ??
            json['emp_profile_id'] ??
            json['file_number'] ??
            json['file_no'] ??
            json['file_id'],
      ),
      odooUserId: _asInt(json['odoo_user_id'] ?? json['user_id']),
      name: _asString(
            json['name'] ??
                json['employee_name'] ??
                json['emp_name'] ??
                json['display_name'],
          ) ??
          '',
      email: _asString(
        json['email'] ??
            json['work_email'] ??
            json['personal_email'] ??
            json['official_email'] ??
            json['mail'],
      ),
      phone: _asString(
        json['phone'] ??
            json['phone_number'] ??
            json['mobile_phone'] ??
            json['mobile'] ??
            json['mobile_number'] ??
            json['work_phone'] ??
            json['telephone'],
      ),
      jobPosition: _resolveJobPosition(json),
      department: _asString(json['department'] ?? json['section']),
      image: _asString(
        json['profile_photo_url'] ??
            json['image_url'] ??
            json['image'] ??
            json['profile_image'] ??
            json['avatar_url'] ??
            json['avatar'] ??
            json['image_1920'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'employee_file_number': employeeFileNumber,
      'odoo_user_id': odooUserId,
      'name': name,
      'email': email,
      'phone': phone,
      'job_position': jobPosition,
      'department': department,
      'image': image,
    };
  }

  TeamMember copyWith({
    int? id,
    int? employeeId,
    int? employeeFileNumber,
    int? odooUserId,
    String? name,
    String? email,
    String? phone,
    String? jobPosition,
    String? department,
    String? image,
  }) {
    return TeamMember(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeFileNumber: employeeFileNumber ?? this.employeeFileNumber,
      odooUserId: odooUserId ?? this.odooUserId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      jobPosition: jobPosition ?? this.jobPosition,
      department: department ?? this.department,
      image: image ?? this.image,
    );
  }

  @override
  String toString() => 'TeamMember(id: $id, name: $name)';

  static String? _resolveJobPosition(Map<String, dynamic> json) {
    final candidates = [
      json['job_position'],
      json['job_title'],
      json['job_name'],
      json['designation'],
      json['position'],
      json['job'],
    ];
    for (final candidate in candidates) {
      final text = _asString(candidate);
      if (text == null) continue;
      if (_looksLikeNumericId(text)) continue;
      return text;
    }
    return null;
  }

  static bool _looksLikeNumericId(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return true;
    if (RegExp(r'^\d+$').hasMatch(trimmed)) return true;
    if (RegExp(r'^role\s*\d+$', caseSensitive: false).hasMatch(trimmed)) {
      return true;
    }
    return false;
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  static String? _asString(dynamic value) {
    if (value == null || value == false) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();
    if (lower == 'null' || lower == 'false' || lower == 'n/a' || lower == '-') {
      return null;
    }
    return text;
  }
}

/// Service to fetch team members from backend API
/// This is the ONLY backend interaction for the task management system
class TeamMembersApiService {
  static TeamMembersApiService? _instance;
  static TeamMembersApiService get instance =>
      _instance ??= TeamMembersApiService._();

  TeamMembersApiService._();

  static const String _baseUrl = 'https://erp.elrace.com/api';
  static const String _employeeListEndpoint = '/employee/listx';
  /// Timesheet labor / employee picker (per backend contract).
  static const String employeeLaborListEndpoint = '/employee/list';

  // Cache for team members
  List<TeamMember>? _cachedMembers;
  DateTime? _lastFetchTime;
  List<TeamMember>? _cachedLaborMembers;
  DateTime? _lastLaborFetchTime;
  static const Duration _cacheTimeout = Duration(minutes: 15);

  /// Get authorization headers
  Map<String, String> _getHeaders() {
    final token = SharedPref.getLoginData().result?.token;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Fetch all team members from backend
  /// Uses caching to minimize API calls
  Future<List<TeamMember>> getTeamMembers({bool forceRefresh = false}) async {
    // Check cache
    if (!forceRefresh &&
        _cachedMembers != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheTimeout) {
      print('📋 TeamMembersApiService: Returning cached members');
      return _cachedMembers!;
    }

    try {
      final headers = _getHeaders();

      final body = jsonEncode({
        'jsonrpc': '2.0',
        'params': {},
      });
      final response = await _sendJsonRequest(
        'GET',
        '$_baseUrl$_employeeListEndpoint',
        headers,
        body,
      );
      print(
          '📡 TeamMembersApiService: GET $_employeeListEndpoint -> ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch members: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final employeesList = _parseEmployeesPayload(data);

        final parsedMembers = employeesList
          .map((e) => TeamMember.fromJson(e as Map<String, dynamic>))
          .toList();

        _cachedMembers = await _enrichMembersWithDepartments(parsedMembers);
      _lastFetchTime = DateTime.now();

      print('✅ TeamMembersApiService: Fetched ${_cachedMembers!.length} members');
      return _cachedMembers!;
    } catch (e) {
      print('❌ TeamMembersApiService: Error fetching members: $e');
      // Return cached data if available
      if (_cachedMembers != null) {
        return _cachedMembers!;
      }
      rethrow;
    }
  }

  /// Employee list for timesheet labor picker (`/api/employee/list`).
  Future<List<TeamMember>> getLaborListMembers({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedLaborMembers != null &&
        _lastLaborFetchTime != null &&
        DateTime.now().difference(_lastLaborFetchTime!) < _cacheTimeout) {
      print('📋 TeamMembersApiService: Returning cached labor list');
      return _cachedLaborMembers!;
    }

    try {
      final headers = _getHeaders();
      final body = jsonEncode({
        'jsonrpc': '2.0',
        'params': {},
      });
      final response = await http.post(
        Uri.parse('$_baseUrl$employeeLaborListEndpoint'),
        headers: headers,
        body: body,
      );
      print(
          '📡 TeamMembersApiService: POST $employeeLaborListEndpoint -> ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch labor list: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final employeesList = _parseEmployeesPayload(data);

      final parsedMembers = employeesList
          .map((e) => TeamMember.fromJson(e as Map<String, dynamic>))
          .toList();

      _cachedLaborMembers = await _enrichMembersWithDepartments(parsedMembers);
      _lastLaborFetchTime = DateTime.now();

      print(
          '✅ TeamMembersApiService: Fetched ${_cachedLaborMembers!.length} labor list members');
      return _cachedLaborMembers!;
    } catch (e) {
      print('❌ TeamMembersApiService: Error fetching labor list: $e');
      if (_cachedLaborMembers != null) {
        return _cachedLaborMembers!;
      }
      rethrow;
    }
  }

  List<dynamic> _parseEmployeesPayload(dynamic data) {
    if (data is! Map) return const [];

    final result = data['result'];
    if (result is Map) {
      final employees = result['employees'];
      if (employees is List) return employees;
      final dataList = result['data'];
      if (dataList is List) return dataList;
    }
    if (result is List) return result;

    final topEmployees = data['employees'];
    if (topEmployees is List) return topEmployees;

    return const [];
  }

  /// Search members by name
  Future<List<TeamMember>> searchMembers(String query) async {
    final members = await getTeamMembers();
    if (query.isEmpty) return members;

    final queryLower = query.toLowerCase();
    return members
        .where((m) => m.name.toLowerCase().contains(queryLower))
        .toList();
  }

  Future<http.Response> _sendJsonRequest(
    String method,
    String url,
    Map<String, String> headers,
    String body,
  ) async {
    final request = http.Request(method, Uri.parse(url))
      ..headers.addAll(headers)
      ..body = body;
    return http.Response.fromStream(await request.send());
  }

  Future<List<TeamMember>> _enrichMembersWithDepartments(
      List<TeamMember> members) async {
    try {
      final teams = await TeamsApiService.getTeams();
      final departmentByNameKey = <String, String>{};

      for (final team in teams) {
        final employeeName = team.employeeName?.trim();
        final department = team.department?.trim();
        if (employeeName == null ||
            employeeName.isEmpty ||
            department == null ||
            department.isEmpty) {
          continue;
        }

        departmentByNameKey[_nameKey(employeeName)] = department;
      }

      if (departmentByNameKey.isEmpty) return members;

      return members.map((member) {
        if (member.department != null && member.department!.trim().isNotEmpty) {
          return member;
        }
        final department = departmentByNameKey[_nameKey(member.name)];
        return department == null ? member : member.copyWith(department: department);
      }).toList();
    } catch (e) {
      print('⚠️ TeamMembersApiService: Could not enrich departments: $e');
      return members;
    }
  }

  String _nameKey(String rawName) {
    final cleaned = rawName
        .replaceFirst(RegExp(r'^\s*\d+\s*[-:|#]*\s*'), '')
        .trim()
        .toLowerCase();
    final parts = cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length <= 2) return parts.join(' ');
    return '${parts[0]} ${parts[1]}';
  }

  /// Get member by ID
  Future<TeamMember?> getMemberById(int id) async {
    final members = await getTeamMembers();
    try {
      return members.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Clear cache
  void clearCache() {
    _cachedMembers = null;
    _lastFetchTime = null;
    _cachedLaborMembers = null;
    _lastLaborFetchTime = null;
  }
}
