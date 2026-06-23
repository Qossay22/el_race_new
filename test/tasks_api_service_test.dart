import 'dart:convert';

import 'package:el_race/ui/presentation/tasks/data/tasks_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('TasksApiService.fetchTasks', () {
    test('parses status success responses with tasks payload', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(),
            'https://erp.elrace.com/api/get_user_tasks');
        expect(request.headers['Authorization'], 'Bearer token');
        expect(jsonDecode(request.body), equals({'jsonrpc': '2.0'}));

        return http.Response(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': null,
            'result': {
              'status': 'success',
              'message': 'Tasks fetched successfully.',
              'tasks': [
                {
                  'id': 10,
                  'name': 'Site inspection',
                  'description': 'Check site progress',
                  'priority': 'high',
                  'stage': 'new',
                  'assigned_user': 'Ahmed',
                  'team': 'Operations',
                  'create_date': '2026-04-30 09:00:00',
                },
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = TasksApiService(client: client);

      final tasks = await service.fetchTasks(token: 'token');

      expect(tasks, hasLength(1));
      expect(tasks.first.id, 10);
      expect(tasks.first.name, 'Site inspection');
      expect(tasks.first.assignedUser, 'Ahmed');
    });

    test('keeps supporting success true responses with data payload', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'result': {
              'success': true,
              'data': [
                {'id': 20, 'name': 'Prepare report'},
              ],
            },
          }),
          200,
        );
      });

      final service = TasksApiService(client: client);

      final tasks = await service.fetchTasks(token: 'token');

      expect(tasks, hasLength(1));
      expect(tasks.first.id, 20);
      expect(tasks.first.name, 'Prepare report');
    });
  });
}
