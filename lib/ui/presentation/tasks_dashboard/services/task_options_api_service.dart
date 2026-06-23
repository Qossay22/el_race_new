import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:el_race/core/utils/shared_pref.dart';

/// Model for Project
class ProjectOption {
  final int id;
  final String name;
  final String? partnerId;
  final String? status;

  const ProjectOption({
    required this.id,
    required this.name,
    this.partnerId,
    this.status,
  });

  factory ProjectOption.fromJson(Map<String, dynamic> json) {
    return ProjectOption(
      id: json['project_id'] ?? json['id'] ?? 0,
      name: json['name']?.toString() ?? '',
      partnerId: json['partner_id']?.toString(),
      status: json['project_status']?.toString(),
    );
  }

  @override
  String toString() => name;
}

/// Model for Department
class DepartmentOption {
  final int id;
  final String name;

  const DepartmentOption({
    required this.id,
    required this.name,
  });

  factory DepartmentOption.fromJson(Map<String, dynamic> json) {
    return DepartmentOption(
      id: json['id'] ?? json['department_id'] ?? 0,
      name: json['name']?.toString() ?? json['department']?.toString() ?? '',
    );
  }

  @override
  String toString() => name;
}

/// Service for fetching task options (Projects & Departments) from Backend
class TaskOptionsApiService {
  static const String _baseUrl = 'https://erp.elrace.com/api';

  // Cache for projects
  static List<ProjectOption>? _cachedProjects;
  static DateTime? _projectsCacheTime;
  static const Duration _cacheDuration = Duration(minutes: 15);

  // Cache for departments
  static List<DepartmentOption>? _cachedDepartments;
  static DateTime? _departmentsCacheTime;

  /// Get auth token
  static String _getToken() {
    return SharedPref.getLoginData().result?.token ?? '';
  }

  /// Get headers with auth
  static Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer ${_getToken()}',
    };
  }

  /// Fetch projects from backend
  static Future<List<ProjectOption>> getProjects({bool forceRefresh = false}) async {
    // Check cache
    if (!forceRefresh &&
        _cachedProjects != null &&
        _projectsCacheTime != null &&
        DateTime.now().difference(_projectsCacheTime!) < _cacheDuration) {
      debugPrint('TaskOptionsApiService: Returning ${_cachedProjects!.length} cached projects');
      return _cachedProjects!;
    }

    try {
      debugPrint('TaskOptionsApiService: Fetching projects from API...');

      final url = Uri.parse('$_baseUrl/get_projects');
      final body = jsonEncode({
        'jsonrpc': '2.0',
        'params': {
          'keyword': null,
        },
      });

      final request = http.Request('GET', url)
        ..headers.addAll(_getHeaders())
        ..body = body;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('TaskOptionsApiService: Projects response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['result']?['data'] as List<dynamic>? ?? [];

        _cachedProjects = data.map((e) => ProjectOption.fromJson(e)).toList();
        _projectsCacheTime = DateTime.now();

        debugPrint('TaskOptionsApiService: Fetched ${_cachedProjects!.length} projects');
        return _cachedProjects!;
      } else {
        throw Exception('Failed to load projects: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('TaskOptionsApiService: Error fetching projects: $e');
      return _cachedProjects ?? [];
    }
  }

  /// Fetch departments from backend (extracted from employees)
  static Future<List<DepartmentOption>> getDepartments({bool forceRefresh = false}) async {
    // Check cache
    if (!forceRefresh &&
        _cachedDepartments != null &&
        _departmentsCacheTime != null &&
        DateTime.now().difference(_departmentsCacheTime!) < _cacheDuration) {
      debugPrint('TaskOptionsApiService: Returning ${_cachedDepartments!.length} cached departments');
      return _cachedDepartments!;
    }

    try {
      debugPrint('TaskOptionsApiService: Fetching departments from API...');

      final url = Uri.parse('$_baseUrl/employee/listx');
      final response = await http.post(
        url,
        headers: _getHeaders(),
        body: jsonEncode({
          'jsonrpc': '2.0',
          'params': {},
        }),
      );

      debugPrint('TaskOptionsApiService: Departments response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final employees = decoded['result']?['employees'] as List<dynamic>? ?? [];

        // Extract unique departments
        final departmentsMap = <String, DepartmentOption>{};
        for (var emp in employees) {
          final deptName = emp['department']?.toString();
          final deptId = emp['department_id'];
          if (deptName != null && deptName.isNotEmpty && !departmentsMap.containsKey(deptName)) {
            departmentsMap[deptName] = DepartmentOption(
              id: deptId is int ? deptId : int.tryParse(deptId?.toString() ?? '') ?? 0,
              name: deptName,
            );
          }
        }

        _cachedDepartments = departmentsMap.values.toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        _departmentsCacheTime = DateTime.now();

        debugPrint('TaskOptionsApiService: Fetched ${_cachedDepartments!.length} departments');
        return _cachedDepartments!;
      } else {
        throw Exception('Failed to load departments: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('TaskOptionsApiService: Error fetching departments: $e');
      return _cachedDepartments ?? [];
    }
  }

  /// Clear all cache
  static void clearCache() {
    _cachedProjects = null;
    _projectsCacheTime = null;
    _cachedDepartments = null;
    _departmentsCacheTime = null;
    debugPrint('TaskOptionsApiService: Cache cleared');
  }
}
