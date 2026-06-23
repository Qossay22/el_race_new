import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/attachment_model.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/partner_model.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_model.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_manager_filter_item.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/user_project_model.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/user_projects_response.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/folder_model.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_document_item_model.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

abstract class ProjectRemoteDataSourceImpl {
  Future<List<ProjectModel>> fetchProjects();
  Future<List<AttachmentModel>> fetchProjectAttachments(String projectId,
      {String? folderType});
  Future<List<PartnerModel>> fetchPartnerProjects(
      {int? partnerId, String? keyword});
  Future<List<ProjectModel>> fetchProjectsByPartnerId(int partnerId);
  Future<List<ProjectModel>> fetchProjectsByFilters({
    int? agreementId,
    int? partnerId,
    int? projectManagerId,
    int? cityId,
    String? keyword,
  });
  Future<List<FolderModel>> fetchProjectFolders();
  Future<UserProjectsResponse> fetchClientsList();
  Future<List<ProjectManagerFilterItem>> fetchProjectManagersList();
  Future<List<ProjectManagerFilterItem>> fetchClientsGroupedList(
      {required String groupBy});
  Future<ProjectDocumentsResponse> fetchProjectDocuments(int projectId,
      {String? folderType});
  Future<FolderContentsResponse> fetchFolderContents(
      int projectId, String folderId);
  Future<FileDetailsResponse> fetchFileDetails(int projectId, String fileId);
}

class ProjectRemoteDataSource implements ProjectRemoteDataSourceImpl {
  ProjectRemoteDataSource({
    http.Client? client,
    String Function()? getToken,
  })  : _client = client ?? http.Client(),
        _getToken = getToken ?? _defaultGetToken;

  final http.Client _client;
  final String Function() _getToken;

  static String _defaultGetToken() {
    return SharedPref.getLoginData().result?.token ?? '';
  }

  @override
  Future<List<ProjectModel>> fetchProjects() async {
    final token = _getToken();

    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };

    final url = Uri.parse("https://erp.elrace.com/api/get_projects");

    final body = jsonEncode({
      "jsonrpc": "2.0",
      "params": {
        "keyword": null,
      },
    });

    final request = http.Request('GET', url)
      ..headers.addAll(headers)
      ..body = body;

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint("fetchProjects: ${request.url} \n${response.body}");

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final List data = decoded['result']['data'];
      return data.map((e) => ProjectModel.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load projects: ${response.statusCode}');
    }
  }

  @override
  Future<List<AttachmentModel>> fetchProjectAttachments(String projectId,
      {String? folderType}) async {
    debugPrint(
        "🔶 fetchProjectAttachments CALLED with projectId: $projectId, folderType: $folderType");
    final token = _getToken();

    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };

    final url = Uri.parse("https://erp.elrace.com/api/get_project_attachments");

    // Build params with optional folder_type
    final params = <String, dynamic>{
      "project_id": int.tryParse(projectId) ?? 0,
    };
    if (folderType != null) {
      params["folder_type"] = folderType;
    }

    final body = jsonEncode({
      "jsonrpc": "2.0",
      "params": params,
    });

    debugPrint("===============================");
    debugPrint("fetchProjectAttachments REQUEST:");
    debugPrint("URL: $url");
    debugPrint("Body: $body");
    debugPrint("===============================");

    final response = await _client.post(url, headers: headers, body: body);

    debugPrint("fetchProjectAttachments RESPONSE: ${response.statusCode}");
    debugPrint("fetchProjectAttachments: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);

      // Check for success status
      if (decoded['result'] != null &&
          decoded['result']['status'] == 'success' &&
          decoded['result']['data'] != null) {
        final List data = decoded['result']['data'];
        return data.map((e) => AttachmentModel.fromJson(e)).toList();
      } else {
        throw Exception('Invalid response format');
      }
    } else {
      throw Exception('Failed to load attachments: ${response.statusCode}');
    }
  }

  @override
  Future<List<PartnerModel>> fetchPartnerProjects(
      {int? partnerId, String? keyword}) async {
    final token = _getToken();

    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };

    final url = Uri.parse("https://erp.elrace.com/api/get_partner_projects");

    final body = jsonEncode({
      "jsonrpc": "2.0",
      "params": {
        "partner_id": partnerId,
        "keyword": keyword,
      },
    });

    final response = await _client.post(url, headers: headers, body: body);

    debugPrint("fetchPartnerProjects: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final List data = decoded['result']['data'];
      return data.map((e) => PartnerModel.fromJson(e)).toList();
    } else {
      throw Exception(
          'Failed to load partner projects: ${response.statusCode}');
    }
  }

  @override
  Future<List<ProjectModel>> fetchProjectsByPartnerId(int partnerId) async {
    return fetchProjectsByFilters(partnerId: partnerId);
  }

  @override
  Future<List<ProjectModel>> fetchProjectsByFilters({
    int? agreementId,
    int? partnerId,
    int? projectManagerId,
    int? cityId,
    String? keyword,
  }) async {
    final token = _getToken();

    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };

    final url = Uri.parse("https://erp.elrace.com/api/get_partner_projects");

    final body = jsonEncode({
      "jsonrpc": "2.0",
      "method": "call",
      "params": {
        "agreement": agreementId,
        "agreement_id": agreementId,
        "partner_id": partnerId,
        "project_manager_id": projectManagerId,
        "city_id": cityId,
        "keyword": keyword,
      },
    });

    final response = await _client.post(url, headers: headers, body: body);

    debugPrint("fetchProjectsByFilters: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);

      if (decoded['result'] != null &&
          decoded['result']['status'] == 'success' &&
          decoded['result']['data'] != null) {
        final List data = decoded['result']['data'];

        final List<ProjectModel> allProjects = [];
        for (final partnerData in data) {
          if (partnerData is! Map) continue;

          final partnerMap = Map<String, dynamic>.from(partnerData);
          final projectsList = partnerMap['projects'];
          if (projectsList is List) {
            for (final projectJson in projectsList) {
              if (projectJson is Map<String, dynamic>) {
                allProjects.add(ProjectModel.fromJson(projectJson));
              } else if (projectJson is Map) {
                allProjects.add(ProjectModel.fromJson(
                    Map<String, dynamic>.from(projectJson)));
              }
            }
          } else if (partnerMap.containsKey('project_id')) {
            allProjects.add(ProjectModel.fromJson(partnerMap));
          }
        }

        return allProjects;
      } else {
        throw Exception('Invalid response format');
      }
    } else {
      throw Exception(
          'Failed to load filtered projects: ${response.statusCode}');
    }
  }

  @override
  Future<List<FolderModel>> fetchProjectFolders() async {
    final token = _getToken();

    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };

    final url = Uri.parse("https://erp.elrace.com/api/project_folders");

    final body = jsonEncode({
      "jsonrpc": "2.0",
      "id": null,
    });

    final request = http.Request('GET', url)
      ..headers.addAll(headers)
      ..body = body;

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint("fetchProjectFolders: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);

      if (decoded['result'] != null &&
          decoded['result']['status'] == 'success' &&
          decoded['result']['data'] != null) {
        final List data = decoded['result']['data'];
        return data.map((e) => FolderModel.fromJson(e)).toList();
      } else {
        throw Exception('Invalid response format');
      }
    } else {
      throw Exception('Failed to load folders: ${response.statusCode}');
    }
  }

  List<UserProjectModel> _parseUserProjectsFromResult(
      Map<String, dynamic>? result) {
    if (result == null) return const [];

    final candidates = <dynamic>[
      result['data'],
      result['clients'],
      result['partners'],
      result['items'],
    ];

    for (final candidate in candidates) {
      if (candidate is! List || candidate.isEmpty) continue;

      final projects = candidate
          .whereType<Map>()
          .map((e) => UserProjectModel.fromJson(Map<String, dynamic>.from(e)))
          .where((p) => p.projectId > 0 && p.projectName.trim().isNotEmpty)
          .toList(growable: false);

      if (projects.isNotEmpty) return projects;
    }

    return const [];
  }

  UserProjectModel _userProjectFromFilterItem(ProjectManagerFilterItem item) {
    return UserProjectModel(
      projectId: item.id,
      projectName: item.name,
      totalProjects: item.projectCount,
      totalProjectsAmount: 0,
      photoUrl: item.photoUrl,
    );
  }

  Future<List<UserProjectModel>> _requestClientsList({
    String? groupBy,
  }) async {
    final token = _getToken();

    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };

    final url = Uri.parse("https://erp.elrace.com/api/clients/list");

    final params = <String, dynamic>{};
    if (groupBy != null && groupBy.isNotEmpty) {
      params['group_by'] = groupBy;
    }

    final body = jsonEncode({
      "jsonrpc": "2.0",
      "method": "call",
      "params": params,
    });

    debugPrint("=== fetchClientsList REQUEST ===");
    debugPrint("URL: $url");
    debugPrint("Method: GET");
    debugPrint("Body: $body");
    debugPrint("===================================");

    final request = http.Request('GET', url)
      ..headers.addAll(headers)
      ..body = body;

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint("=== fetchClientsList RESPONSE ===");
    debugPrint("Status Code: ${response.statusCode}");
    debugPrint("Response Body: ${response.body}");
    debugPrint("===================================");

    if (response.statusCode != 200) {
      throw Exception('Failed to load clients list: ${response.statusCode}');
    }

    final decoded = json.decode(response.body) as Map<String, dynamic>;
    final result = decoded['result'] as Map<String, dynamic>?;
    if (result == null || result['status'] != 'success') {
      throw Exception('Invalid response format');
    }

    return _parseUserProjectsFromResult(result);
  }

  @override
  Future<UserProjectsResponse> fetchClientsList() async {
    try {
      var projects = await _requestClientsList();

      // Same endpoint used by filter screens when the default payload is empty.
      if (projects.isEmpty) {
        projects = await _requestClientsList(groupBy: 'client');
      }

      if (projects.isEmpty) {
        final grouped = await fetchClientsGroupedList(groupBy: 'client');
        projects = grouped.map(_userProjectFromFilterItem).toList(growable: false);
      }

      return UserProjectsResponse(
        success: true,
        employeeId: 0,
        projects: projects,
      );
    } catch (e) {
      debugPrint('fetchClientsList failed, trying grouped fallback: $e');
      final grouped = await fetchClientsGroupedList(groupBy: 'client');
      final projects =
          grouped.map(_userProjectFromFilterItem).toList(growable: false);
      return UserProjectsResponse(
        success: true,
        employeeId: 0,
        projects: projects,
      );
    }
  }

  @override
  Future<List<ProjectManagerFilterItem>> fetchProjectManagersList() async {
    return fetchClientsGroupedList(groupBy: 'project_manager');
  }

  @override
  Future<List<ProjectManagerFilterItem>> fetchClientsGroupedList(
      {required String groupBy}) async {
    final token = _getToken();

    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };

    final url = Uri.parse("https://erp.elrace.com/api/clients/list");

    final body = jsonEncode({
      "jsonrpc": "2.0",
      "method": "call",
      "params": {
        "group_by": groupBy,
      },
    });

    final request = http.Request('GET', url)
      ..headers.addAll(headers)
      ..body = body;

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Failed to load grouped clients: ${response.statusCode}');
    }

    final decoded = json.decode(response.body) as Map<String, dynamic>;
    final result = decoded['result'] as Map<String, dynamic>?;
    if (result == null || result['status'] != 'success') {
      throw Exception('Invalid grouped clients response format');
    }

    final list = (result['data'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((e) =>
            ProjectManagerFilterItem.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);

    return list;
  }

  @override
  Future<ProjectDocumentsResponse> fetchProjectDocuments(int projectId,
      {String? folderType}) async {
    final token = _getToken();

    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };

    final url = Uri.parse("https://erp.elrace.com/api/projects/documents");

    // Only include folder_type if provided
    final params = <String, dynamic>{
      "project_id": projectId,
    };
    if (folderType != null) {
      params["folder_type"] = folderType;
    }

    final body = jsonEncode({
      "jsonrpc": "2.0",
      "params": params,
    });

    debugPrint("===============================");
    debugPrint("fetchProjectDocuments REQUEST:");
    debugPrint("URL: $url");
    debugPrint("Body: $body");
    debugPrint("===============================");

    // Use GET request with body
    final request = http.Request('GET', url)
      ..headers.addAll(headers)
      ..body = body;

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint("fetchProjectDocuments RESPONSE: ${response.statusCode}");
    debugPrint("fetchProjectDocuments: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body) as Map<String, dynamic>;
      return ProjectDocumentsResponse.fromJson(decoded);
    } else {
      throw Exception(
          'Failed to load project documents: ${response.statusCode}');
    }
  }

  @override
  Future<FolderContentsResponse> fetchFolderContents(
      int projectId, String folderId) async {
    final token = _getToken();

    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };

    final url =
        Uri.parse("https://erp.elrace.com/api/projects/documents/folder");

    final body = jsonEncode({
      "jsonrpc": "2.0",
      "params": {
        "project_id": projectId,
        "folder_id": folderId,
      },
    });

    debugPrint("===============================");
    debugPrint("fetchFolderContents REQUEST:");
    debugPrint("URL: $url");
    debugPrint("Body: $body");
    debugPrint("===============================");

    // Use GET request with body
    final request = http.Request('GET', url)
      ..headers.addAll(headers)
      ..body = body;

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint("fetchFolderContents RESPONSE: ${response.statusCode}");
    debugPrint("fetchFolderContents: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body) as Map<String, dynamic>;
      return FolderContentsResponse.fromJson(decoded);
    } else {
      throw Exception('Failed to load folder contents: ${response.statusCode}');
    }
  }

  @override
  Future<FileDetailsResponse> fetchFileDetails(
      int projectId, String fileId) async {
    final token = _getToken();

    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };

    final url = Uri.parse("https://erp.elrace.com/api/projects/documents/file");

    final body = jsonEncode({
      "jsonrpc": "2.0",
      "params": {
        "project_id": projectId,
        "file_id": fileId,
      },
    });

    debugPrint("===============================");
    debugPrint("fetchFileDetails REQUEST:");
    debugPrint("URL: $url");
    debugPrint("Body: $body");
    debugPrint("===============================");

    // Use GET request with body
    final request = http.Request('GET', url)
      ..headers.addAll(headers)
      ..body = body;

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint("fetchFileDetails RESPONSE: ${response.statusCode}");
    debugPrint("fetchFileDetails: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body) as Map<String, dynamic>;
      return FileDetailsResponse.fromJson(decoded);
    } else {
      throw Exception('Failed to load file details: ${response.statusCode}');
    }
  }
}
