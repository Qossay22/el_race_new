import 'dart:convert';

import 'package:el_race/ui/presentation/my_projects/data/datasources/project_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ProjectRemoteDataSource.fetchClientsList', () {
    test('returns parsed response on success', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        // Detailed logging for mock request
        print('=== MOCK REQUEST ===');
        print('URL: ${request.url}');
        print('Method: ${request.method}');
        print('Headers: ${request.headers}');
        print('Body: ${request.body}');
        print('Body Length: ${request.body.length}');
        print('====================');

        expect(
            request.url.toString(), 'https://erp.elrace.com/api/clients/list');
        expect(request.method, 'GET');
        expect(request.body, contains('"method":"call"'));

        final mockResponse = http.Response(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': null,
            'result': {
              'status': 'success',
              'message': 'Clients fetched successfully.',
              'data': [
                {
                  'id': 11380,
                  'name': 'Abu Dhabi Police',
                  'total_projects': 558,
                  'total_projects_amount': 1431401691.12,
                  'photo_url':
                      'https://erp.elrace.compublic/partner/image/11380',
                }
              ],
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );

        print('=== MOCK RESPONSE ===');
        print('Status Code: 200');
        print('Body: ${mockResponse.body}');
        print('====================');

        return mockResponse;
      });

      final dataSource = ProjectRemoteDataSource(
        client: mockClient,
        getToken: () => 'mock_token',
      );

      final result = await dataSource.fetchClientsList();

      expect(result.success, isTrue);
      expect(result.projects, hasLength(1));
      expect(result.projects.first.projectId, 11380);
      expect(result.projects.first.projectName, 'Abu Dhabi Police');
      expect(result.projects.first.totalProjects, 558);
      expect(result.projects.first.totalProjectsAmount, 1431401691.12);
      expect(callCount, 1);
    });

    test('falls back to grouped client list when default payload is empty',
        () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final params = body['params'] as Map<String, dynamic>? ?? {};

        if (params['group_by'] == 'client') {
          return http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'id': null,
              'result': {
                'status': 'success',
                'data': [
                  {
                    'id': 99,
                    'name': 'Fallback Client',
                    'project_count': 12,
                    'photo_url':
                        'https://erp.elrace.com/public/partner/image/99',
                  }
                ],
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': null,
            'result': {
              'status': 'success',
              'data': [],
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final dataSource = ProjectRemoteDataSource(
        client: mockClient,
        getToken: () => 'mock_token',
      );

      final result = await dataSource.fetchClientsList();

      expect(result.projects, hasLength(1));
      expect(result.projects.first.projectId, 99);
      expect(result.projects.first.projectName, 'Fallback Client');
      expect(result.projects.first.totalProjects, 12);
      expect(callCount, greaterThanOrEqualTo(2));
    });

    test('throws an exception on non-200 status', () async {
      final mockClient = MockClient((request) async {
        print('=== MOCK ERROR REQUEST ===');
        print('URL: ${request.url}');
        print('Method: ${request.method}');
        print('Headers: ${request.headers}');
        print('Body: ${request.body}');
        print('===========================');

        return http.Response('error', 500);
      });

      final dataSource = ProjectRemoteDataSource(
        client: mockClient,
        getToken: () => 'mock_token',
      );

      expect(() => dataSource.fetchClientsList(), throwsA(isA<Exception>()));
    });
  });
}
