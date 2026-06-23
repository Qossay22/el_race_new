import 'dart:convert';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../utils/di.dart';
import '../../signin/data/repository.dart';

final userRepo = sl.get<UserRepo>();

class AttendanceRepo {
  int? _extractAttendanceId(Map<String, dynamic> source) {
    int? parse(dynamic value) {
      if (value is int && value > 0) return value;
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null && parsed > 0) return parsed;
      }
      return null;
    }

    final direct = parse(source['check_in_record_id']) ??
        parse(source['attendance_id']) ??
        parse(source['checkin_record_id']) ??
        parse(source['attendanceId']) ??
        parse(source['id']);
    if (direct != null) return direct;

    final nestedData = source['data'];
    if (nestedData is Map) {
      final nested = Map<String, dynamic>.from(nestedData);
      return parse(nested['check_in_record_id']) ??
          parse(nested['attendance_id']) ??
          parse(nested['checkin_record_id']) ??
          parse(nested['attendanceId']) ??
          parse(nested['id']);
    }

    return null;
  }

  Future<http.Response> getAttendanceList({
    String? keyword,
    int? month,
    int? year,
    int limit = 500,
    int offset = 0,
  }) async {
    try {
      final loginResponse = await userRepo.getLoginResponse();
      final token = loginResponse?.result?.token;
      if (token == null || token.isEmpty) {
        throw Exception('Invalid token');
      }

      Map<String, String> headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token"
      };

      var url = Uri.parse("https://erp.elrace.com/api/attendance/list");
      final body = jsonEncode({
        "jsonrpc": "2.0",
        "params": {
          "keyword": keyword,
          "limit": limit,
          "offset": offset,
          "month": month,
          if (year != null) "year": year,
        }
      });

      debugPrint('\n========== [ATTENDANCE_LIST] API REQUEST ==========');
      debugPrint('🌐 URL: $url');
      debugPrint('📤 Body:');
      try {
        debugPrint(
            const JsonEncoder.withIndent('  ').convert(jsonDecode(body)));
      } catch (_) {
        debugPrint(body);
      }
      debugPrint('====================================================\n');

      final request = http.Request('POST', url)
        ..headers.addAll(headers)
        ..body = body;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('========== [ATTENDANCE_LIST] API RESPONSE ==========');
      debugPrint('📊 Status Code: ${response.statusCode}');
      debugPrint('📦 Full Response Body:');
      try {
        debugPrint(const JsonEncoder.withIndent('  ')
            .convert(jsonDecode(response.body)));
      } catch (_) {
        debugPrint(response.body);
      }
      debugPrint('====================================================\n');

      return response;
    } catch (e) {
      log('Error in getAttendanceList: $e');
      rethrow;
    }
  }

  Future<http.Response> getAttendanceDetail({
    required int empId,
    required int month,
    required int year,
  }) async {
    try {
      final loginResponse = await userRepo.getLoginResponse();
      final token = loginResponse?.result?.token;
      if (token == null || token.isEmpty) {
        throw Exception('Invalid token');
      }

      Map<String, String> headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token"
      };

      final url = Uri.parse("https://erp.elrace.com/api/attendance/detail");
      final body = jsonEncode({
        "jsonrpc": "2.0",
        "params": {
          "employee_id": empId,
          "month": month,
          "year": year,
        }
      });

      debugPrint('\n========== [ATTENDANCE_DETAIL] API REQUEST ==========');
      debugPrint('🌐 URL: $url');
      debugPrint('📤 Body:');
      try {
        debugPrint(
            const JsonEncoder.withIndent('  ').convert(jsonDecode(body)));
      } catch (_) {
        debugPrint(body);
      }
      debugPrint('======================================================\n');

      final request = http.Request('POST', url)
        ..headers.addAll(headers)
        ..body = body;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('========== [ATTENDANCE_DETAIL] API RESPONSE ==========');
      debugPrint('📊 Status Code: ${response.statusCode}');
      debugPrint('📦 Full Response Body:');
      try {
        debugPrint(const JsonEncoder.withIndent('  ')
            .convert(jsonDecode(response.body)));
      } catch (_) {
        debugPrint(response.body);
      }
      debugPrint('======================================================\n');

      return response;
    } catch (e) {
      log('Error in getAttendanceDetail: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAttendanceSummary({
    required String startDate,
    required String endDate,
  }) async {
    try {
      final loginResponse = await userRepo.getLoginResponse();
      final token = loginResponse?.result?.token;
      if (token == null || token.isEmpty) {
        throw Exception('Invalid token');
      }

      final headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token"
      };

      final body = jsonEncode({
        "jsonrpc": "2.0",
        "params": {
          "start_date": startDate,
          "end_date": endDate,
        }
      });

      final response = await http.post(
        Uri.parse("https://erp.elrace.com/attendance/summary"),
        headers: headers,
        body: body,
      );

      debugPrint('\n========== [ATTENDANCE_SUMMARY] API REQUEST ==========');
      debugPrint('🌐 URL: https://erp.elrace.com/attendance/summary');
      debugPrint('📤 Body:');
      try {
        debugPrint(
            const JsonEncoder.withIndent('  ').convert(jsonDecode(body)));
      } catch (_) {
        debugPrint(body);
      }
      debugPrint('======================================================');
      debugPrint('📊 Status Code: ${response.statusCode}');
      debugPrint('📦 Full Response Body:');
      try {
        debugPrint(const JsonEncoder.withIndent('  ')
            .convert(jsonDecode(response.body)));
      } catch (_) {
        debugPrint(response.body);
      }
      debugPrint('=======================================================\n');

      final decoded = jsonDecode(response.body);
      // Handle error structure {result: {status: 'error', message: 'Invalid token'}}
      final result = decoded is Map<String, dynamic> ? decoded['result'] : null;
      if (result is Map<String, dynamic>) {
        final status = result['status'];
        if (status == 'error') {
          final message = result['message']?.toString() ?? 'Unknown error';
          throw Exception(message);
        }
        final data = result['data'];
        return data;
      }
      throw Exception('Malformed response');
    } catch (e) {
      log("Error in getAttendanceSummary: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getTodayStatus() async {
    try {
      final loginResponse = await userRepo.getLoginResponse();
      final token = loginResponse?.result?.token;
      if (token == null || token.isEmpty) {
        throw Exception('Invalid token');
      }

      final headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token"
      };

      final body = jsonEncode({
        "jsonrpc": "2.0",
        "params": {},
      });

      final response = await http.post(
        Uri.parse("https://erp.elrace.com/api/attendance/today_status"),
        headers: headers,
        body: body,
      );

      debugPrint(
          '\n========== [ATTENDANCE_TODAY_STATUS] API REQUEST ==========');
      debugPrint('🌐 URL: https://erp.elrace.com/api/attendance/today_status');
      debugPrint('📤 Body:');
      try {
        debugPrint(
            const JsonEncoder.withIndent('  ').convert(jsonDecode(body)));
      } catch (_) {
        debugPrint(body);
      }
      debugPrint('==========================================================');
      debugPrint('📊 Status Code: ${response.statusCode}');
      debugPrint('📦 Full Response Body:');
      try {
        debugPrint(const JsonEncoder.withIndent('  ')
            .convert(jsonDecode(response.body)));
      } catch (_) {
        debugPrint(response.body);
      }
      debugPrint(
          '===========================================================\n');

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to fetch today status: HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Malformed response');
      }

      final result = decoded['result'];
      if (result is! Map<String, dynamic>) {
        throw Exception('Malformed response result');
      }

      final status = result['status']?.toString();
      if (status == 'error') {
        final message = result['message']?.toString() ?? 'Unknown error';
        throw Exception(message);
      }

      final rawData = (result['data'] is Map<String, dynamic>)
          ? result['data'] as Map<String, dynamic>
          : result;
      final attendanceId = _extractAttendanceId(rawData);

      return {
        'checked_in': _toBool(rawData['checked_in']),
        'checked_out': _toBool(rawData['checked_out']),
        'check_in_time': rawData['check_in_time']?.toString(),
        'check_out_time': rawData['check_out_time']?.toString(),
        'is_today': _toBool(rawData['is_today']),
        'check_in_record_id': attendanceId,
      };
    } catch (e) {
      log("Error in getTodayStatus: $e");
      rethrow;
    }
  }

  bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value == null) {
      return false;
    }

    final normalized = value.toString().trim().toLowerCase();
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'y';
  }
}
