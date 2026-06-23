import 'dart:convert';
import 'package:el_race/ui/presentation/tasks/data/assignable_user_model.dart';
import 'package:el_race/ui/presentation/tasks/data/task_model.dart';
import 'package:el_race/utils/api_logger.dart';
import 'package:http/http.dart' as http;

class TasksApiException implements Exception {
  final String message;
  final int? code;
  TasksApiException(this.message, {this.code});

  @override
  String toString() => 'TasksApiException(code: $code, message: $message)';
}

class TasksUnauthorizedException extends TasksApiException {
  TasksUnauthorizedException() : super('Unauthorized', code: 401);
}

class TasksApiService {
  final String baseUrl;
  final http.Client _client;

  TasksApiService({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? 'https://erp.elrace.com',
        _client = client ?? http.Client();

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  Future<http.Response> _getWithBody({
    required Uri uri,
    required Map<String, String> headers,
    required Map<String, dynamic> body,
  }) async {
    final request = http.Request('GET', uri)
      ..headers.addAll(headers)
      ..body = jsonEncode(body);
    final streamed = await _client.send(request);
    return http.Response.fromStream(streamed);
  }

  void _guardStatus(http.Response response) {
    if (response.statusCode == 401) {
      throw TasksUnauthorizedException();
    }
    if (response.statusCode >= 500) {
      // Try to extract error details from response body
      try {
        final decoded = jsonDecode(response.body);
        final errorMsg = decoded['error']?['message'] ??
            decoded['message'] ??
            'Server error (${response.statusCode})';
        throw TasksApiException(errorMsg, code: response.statusCode);
      } catch (e) {
        throw TasksApiException('Server error (${response.statusCode})',
            code: response.statusCode);
      }
    }
  }

  dynamic _decodeResult(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      final result = decoded['result'];
      return result;
    } catch (e) {
      // print('Error decoding response: $e');
      // print('Response body: ${response.body}');
      throw TasksApiException('Invalid response from server');
    }
  }

  bool _isSuccessResult(dynamic result) {
    if (result is! Map) return false;

    final success = result['success'];
    final status = result['status']?.toString().toLowerCase();

    return success == true || status == 'success';
  }

  List<dynamic>? _extractTasksPayload(dynamic result) {
    if (result is List) return result;
    if (result is! Map) return null;

    final data = result['data'];
    if (data is List) return data;
    if (data is Map) return _extractTasksPayload(data);

    final tasks = result['tasks'];
    if (tasks is List) return tasks;

    return null;
  }

  List<TaskModel> _parseTaskList(List<dynamic> data) {
    return data
        .whereType<Map>()
        .map((e) => TaskModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<TaskModel>> fetchTasks({required String token}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/get_user_tasks');

      // 📤 Log Request
      ApiLogger.logRequest(
        endpoint: uri.toString(),
        method: 'GET',
        headers: _headers(token),
        body: {'jsonrpc': '2.0'},
      );

      final startTime = DateTime.now();
      final response = await _getWithBody(
        uri: uri,
        headers: _headers(token),
        body: {'jsonrpc': '2.0'},
      );
      final duration = DateTime.now().difference(startTime);

      // print('====== GET USER TASKS REQUEST ======');
      // print('URL: $uri');
      // print('Status Code: ${response.statusCode}');
      // print('Response Body: ${response.body}');
      // print('====================================');

      _guardStatus(response);
      if (response.statusCode != 200) {
        throw TasksApiException(
            'Failed to fetch tasks (${response.statusCode})',
            code: response.statusCode);
      }

      final result = _decodeResult(response);

      // 📥 Log Response
      ApiLogger.logResponse(
        endpoint: uri.toString(),
        statusCode: response.statusCode,
        responseBody: result,
        duration: duration,
      );

      // Print response for debugging
      // print('====== GET USER TASKS RESPONSE ======');
      // print('Result: $result');
      // print('=====================================');

      if (_isSuccessResult(result) || result is List) {
        final data = _extractTasksPayload(result);
        if (data == null) return const [];
        return _parseTaskList(data);
      }

      final message =
          (result is Map ? result['message'] : null) ?? 'Unable to fetch tasks';
      throw TasksApiException(message);
    } catch (e) {
      // print('Error in fetchTasks: $e');
      if (e is TasksApiException) {
        rethrow;
      }
      throw TasksApiException('Network error: ${e.toString()}');
    }
  }

  Future<List<AssignableUser>> fetchAssignableUsers(
      {required String token}) async {
    final uri = Uri.parse('$baseUrl/api/get_assignable_users');
    final response = await _getWithBody(
      uri: uri,
      headers: _headers(token),
      body: {'jsonrpc': '2.0'},
    );
    _guardStatus(response);
    if (response.statusCode != 200) {
      throw TasksApiException('Failed to fetch assignable users',
          code: response.statusCode);
    }

    final result = _decodeResult(response);
    if (result is Map && result['status'] == 'success') {
      final data = result['data'];
      if (data is List) {
        return data
            .map((e) => AssignableUser.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return const [];
    }

    throw TasksApiException(
        (result is Map ? result['message'] : null) ?? 'Unable to fetch users');
  }

  Future<TaskModel> createTask({
    required String token,
    required String name,
    String? description,
    String? priority,
    int? userId,
    String? attachmentBase64,
    String? attachmentFilename,
    String? comment,
  }) async {
    final uri = Uri.parse('$baseUrl/api/create_task');
    final params = <String, dynamic>{
      'name': name,
      'description': description ?? '',
      'priority': priority ?? '3',
    };

    // Include comment if provided (fallback to description for backward compat)
    final resolvedComment = comment ?? description;
    if (resolvedComment != null && resolvedComment.isNotEmpty) {
      params['comment'] = resolvedComment;
    }

    // Attach file payload only when both parts are available
    final hasAttachmentData = attachmentBase64 != null &&
        attachmentBase64.isNotEmpty &&
        attachmentFilename != null &&
        attachmentFilename.isNotEmpty;
    if (hasAttachmentData) {
      params['attachment'] = attachmentBase64;
      params['attachment_filename'] = attachmentFilename;
    }
    if (userId != null) {
      params['user_id'] = userId;
    }
    final response = await _getWithBody(
      uri: uri,
      headers: _headers(token),
      body: {
        'jsonrpc': '2.0',
        'params': params,
      },
    );

    _guardStatus(response);
    if (response.statusCode != 200) {
      throw TasksApiException('Failed to create task',
          code: response.statusCode);
    }

    final result = _decodeResult(response);
    if (result is Map && result['status'] == 'success') {
      final data = result['data'];
      if (data is Map) {
        return TaskModel.fromJson(Map<String, dynamic>.from(data));
      }
      throw TasksApiException('Unexpected task payload');
    }

    throw TasksApiException(
        (result is Map ? result['message'] : null) ?? 'Unable to create task');
  }

  Future<String> submitTask(
      {required String token, required int taskId}) async {
    final uri = Uri.parse('$baseUrl/api/submit_task');
    final body = {
      'jsonrpc': '2.0',
      'params': {
        'task_id': taskId,
      },
    };

    print('═══════════════════════════════════════════════════');
    print('🔵 SUBMIT TASK API CALL');
    print('═══════════════════════════════════════════════════');
    print('📍 URL: $uri');
    print('🔑 Token: ${token.substring(0, 20)}...');
    print('📦 Body: $body');
    print('📋 Task ID: $taskId');
    print('═══════════════════════════════════════════════════');

    final response = await _getWithBody(
      uri: uri,
      headers: _headers(token),
      body: body,
    );

    print('📥 Response Status Code: ${response.statusCode}');
    print('📥 Response Body: ${response.body}');
    print('═══════════════════════════════════════════════════');

    _guardStatus(response);
    if (response.statusCode != 200) {
      print('❌ Submit task failed with status: ${response.statusCode}');
      throw TasksApiException('Failed to submit task',
          code: response.statusCode);
    }

    final result = _decodeResult(response);
    print('✅ Decoded Result: $result');

    if (result is Map && result['status'] == 'success') {
      print('✅ Task submitted successfully: ${result['message']}');
      print('═══════════════════════════════════════════════════\n');
      return (result['message'] as String?) ?? 'Task submitted';
    }

    print(
        '❌ Submit task failed: ${result is Map ? result['message'] : result}');
    print('═══════════════════════════════════════════════════\n');
    throw TasksApiException(
        (result is Map ? result['message'] : null) ?? 'Unable to submit task');
  }

  Future<String> linkReportToTask({
    required String token,
    required int taskId,
    required String reportId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/link_report_to_task');
    final response = await _getWithBody(
      uri: uri,
      headers: _headers(token),
      body: {
        'jsonrpc': '2.0',
        'params': {
          'task_id': taskId,
          'report_id': reportId,
        },
      },
    );

    _guardStatus(response);
    if (response.statusCode != 200) {
      throw TasksApiException('Failed to link report',
          code: response.statusCode);
    }

    final result = _decodeResult(response);
    if (result is Map && result['status'] == 'success') {
      return (result['message'] as String?) ?? 'Report linked to task';
    }

    throw TasksApiException(
        (result is Map ? result['message'] : null) ?? 'Unable to link report');
  }

  Future<String> updateTask({
    required String token,
    required int taskId,
    String? name,
    String? description,
    String? priority,
  }) async {
    final uri = Uri.parse('$baseUrl/api/update_task');

    final params = <String, dynamic>{'task_id': taskId};
    if (name != null && name.trim().isNotEmpty) {
      params['name'] = name.trim();
    }
    if (description != null && description.trim().isNotEmpty) {
      params['description'] = description.trim();
    }
    if (priority != null && priority.trim().isNotEmpty) {
      params['priority'] = priority.trim();
    }

    if (params.keys.length == 1) {
      throw TasksApiException('Nothing to update');
    }

    final response = await _getWithBody(
      uri: uri,
      headers: _headers(token),
      body: {
        'jsonrpc': '2.0',
        'params': params,
      },
    );

    _guardStatus(response);
    if (response.statusCode != 200) {
      throw TasksApiException('Failed to update task',
          code: response.statusCode);
    }

    final result = _decodeResult(response);
    if (result is Map && result['status'] == 'success') {
      return (result['message'] as String?) ?? 'Task updated successfully';
    }

    throw TasksApiException(
        (result is Map ? result['message'] : null) ?? 'Unable to update task');
  }

  Future<String> deleteTask({
    required String token,
    required int taskId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/delete_task');

    final response = await _getWithBody(
      uri: uri,
      headers: _headers(token),
      body: {
        'jsonrpc': '2.0',
        'params': {'task_id': taskId},
      },
    );

    _guardStatus(response);
    if (response.statusCode != 200) {
      throw TasksApiException('Failed to delete task',
          code: response.statusCode);
    }

    final result = _decodeResult(response);
    if (result is Map && result['status'] == 'success') {
      return (result['message'] as String?) ?? 'Task deleted successfully';
    }

    throw TasksApiException(
        (result is Map ? result['message'] : null) ?? 'Unable to delete task');
  }
}
