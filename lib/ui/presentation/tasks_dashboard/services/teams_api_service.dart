import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:el_race/core/utils/shared_pref.dart';
import '../models/team_model.dart';

/// Service for fetching teams/departments from ERP API
/// API Response format:
/// {
///   "jsonrpc": "2.0",
///   "id": null,
///   "result": {
///     "status": "success",
///     "message": "Teams fetched successfully.",
///     "data": [{ "id": 1, "name": "Software Development | Hassan Mohamed M Abuebeid" }, ...]
///   }
/// }
class TeamsApiService {
  static const String _baseUrl = 'https://erp.elrace.com/api';

  // Cache for teams
  static List<TeamModel>? _cachedTeams;
  static DateTime? _teamsCacheTime;
  static const Duration _cacheDuration = Duration(minutes: 15);
  
  // Cache for unique departments
  static List<String>? _cachedDepartments;

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

  /// Fetch teams from backend
  static Future<List<TeamModel>> getTeams({bool forceRefresh = false}) async {
    // Check cache
    if (!forceRefresh &&
        _cachedTeams != null &&
        _teamsCacheTime != null &&
        DateTime.now().difference(_teamsCacheTime!) < _cacheDuration) {
      debugPrint('TeamsApiService: Returning ${_cachedTeams!.length} cached teams');
      return _cachedTeams!;
    }

    try {
      debugPrint('TeamsApiService: Fetching teams from API...');

      final url = Uri.parse('$_baseUrl/get_teams');
      
      // Use GET request with body (non-standard but required by this API)
      final request = http.Request('GET', url)
        ..headers.addAll(_getHeaders())
        ..body = jsonEncode({
          'jsonrpc': '2.0',
          'params': {},
        });

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('TeamsApiService: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['result'] != null) {
          final result = data['result'];

          // Handle the response structure: { status, message, data }
          List<dynamic> teamsList = [];
          
          if (result is Map<String, dynamic>) {
            // Check for success status
            final status = result['status'] as String?;
            if (status == 'success') {
              if (result['data'] != null && result['data'] is List) {
                teamsList = result['data'] as List<dynamic>;
              }
            } else {
              // Handle error status
              final message = result['message'] ?? 'Unknown error';
              throw Exception('API returned error: $message');
            }
          } else if (result is List<dynamic>) {
            teamsList = result;
          }

          _cachedTeams = teamsList
              .map((json) => TeamModel.fromJson(json as Map<String, dynamic>))
              .toList();
          _teamsCacheTime = DateTime.now();
          
          // Update unique departments cache
          _cachedDepartments = TeamModel.getUniqueDepartments(_cachedTeams!);

          debugPrint('✅ TeamsApiService: Fetched ${_cachedTeams!.length} teams');
          debugPrint('✅ TeamsApiService: Found ${_cachedDepartments!.length} unique departments');
          return _cachedTeams!;
        } else {
          throw Exception('Invalid response format: missing result');
        }
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['result']?['message'] ?? 
                            errorData['error']?['message'] ?? 
                            'Failed to fetch teams';
        throw Exception('API Error: $errorMessage (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('❌ TeamsApiService: Error fetching teams: $e');
      
      // Return cached data if available
      if (_cachedTeams != null) {
        debugPrint('⚠️ TeamsApiService: Returning stale cached data');
        return _cachedTeams!;
      }
      
      rethrow;
    }
  }
  
  /// Get unique departments from teams
  static Future<List<String>> getUniqueDepartments({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedDepartments != null) {
      return _cachedDepartments!;
    }
    
    await getTeams(forceRefresh: forceRefresh);
    return _cachedDepartments ?? [];
  }
  
  /// Get teams filtered by department
  static Future<List<TeamModel>> getTeamsByDepartment(String department) async {
    final teams = await getTeams();
    if (department.isEmpty) return teams;
    
    return teams
        .where((team) => team.department?.toLowerCase() == department.toLowerCase())
        .toList();
  }

  /// Search teams by name
  static Future<List<TeamModel>> searchTeams(String query) async {
    final teams = await getTeams();
    if (query.isEmpty) return teams;

    final queryLower = query.toLowerCase();
    return teams
        .where((team) => 
            team.name.toLowerCase().contains(queryLower) ||
            (team.department?.toLowerCase().contains(queryLower) ?? false) ||
            (team.employeeName?.toLowerCase().contains(queryLower) ?? false))
        .toList();
  }

  /// Get team by ID
  static Future<TeamModel?> getTeamById(int id) async {
    final teams = await getTeams();
    try {
      return teams.firstWhere((team) => team.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Clear cache
  static void clearCache() {
    _cachedTeams = null;
    _teamsCacheTime = null;
    _cachedDepartments = null;
    debugPrint('TeamsApiService: Cache cleared');
  }
}
