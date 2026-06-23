import 'package:el_race/report_module/data/models/folder_model.dart';
import 'package:el_race/report_module/data/models/report_model.dart';
import 'package:el_race/report_module/data/models/report_item_model.dart';
import 'package:el_race/report_module/data/models/report_pdf_model.dart';
import 'package:el_race/report_module/data/services/report_hive_service.dart';
import 'package:el_race/ui/presentation/call_screen/data/repository.dart';
import 'package:flutter/foundation.dart';
import 'package:el_race/report_module/core/utils/flush_bar.dart';
import 'package:el_race/report_module/data/models/report_detail_model.dart';
import 'package:dio/dio.dart' as dio;
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';

import '../../../core/app_globals.dart';

ReportProvider reportProvider =
    Provider.of<ReportProvider>(navKey.currentContext!, listen: false);

typedef UploadProgressCallback = void Function(double progress);

class ReportProvider extends ChangeNotifier {
  static String baseUrl = "";
  static String empID = "";
  static String companyId = "";

  List<FolderModel> _folders = [];
  List<ReportModel> _reports = [];

  bool _isLoading = false;

  // ── Local report-type cache (survives app restart) ──────────────
  static const _reportTypePrefix = 'report_type_';
  static const _pdfReportPrefix = 'pdf_report_';

  Future<void> _saveReportType(String reportId, String reportType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_reportTypePrefix$reportId', reportType);
  }

  Future<String?> _getReportType(String reportId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_reportTypePrefix$reportId');
  }

  Future<void> _savePdfReportId(String pdfKey, String reportId) async {
    if (pdfKey.trim().isEmpty || reportId.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_pdfReportPrefix$pdfKey', reportId);
  }

  String _extractPdfReportId(Map<String, dynamic> item) {
    final direct = item['report_id'] ??
        item['reportId'] ??
        item['site_report_id'] ??
        item['parent_report_id'] ??
        item['project_report_id'] ??
        item['main_report_id'];
    if (direct != null && direct != false) {
      final value = direct.toString().trim();
      if (value.isNotEmpty) return value;
    }

    final report = item['report'];
    if (report is Map && report['id'] != null) {
      final value = report['id'].toString().trim();
      if (value.isNotEmpty) return value;
    }

    return '';
  }

  Future<void> _restoreReportTypes() async {
    final prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < _reports.length; i++) {
      if (_reports[i].reportType == null) {
        final cached = prefs.getString('$_reportTypePrefix${_reports[i].id}');
        if (cached != null) {
          _reports[i] = ReportModel(
            id: _reports[i].id,
            name: _reports[i].name,
            companyId: _reports[i].companyId,
            folderId: _reports[i].folderId,
            createdAt: _reports[i].createdAt,
            updatedAt: _reports[i].updatedAt,
            reportType: cached,
          );
        }
      }
    }
  }

  int _compareReportsNewestFirst(ReportModel a, ReportModel b) {
    final createdAtOrder = b.createdAt.compareTo(a.createdAt);
    if (createdAtOrder != 0) return createdAtOrder;

    final updatedAtOrder = b.updatedAt.compareTo(a.updatedAt);
    if (updatedAtOrder != 0) return updatedAtOrder;

    final aId = int.tryParse(a.id);
    final bId = int.tryParse(b.id);
    if (aId != null && bId != null) {
      return bId.compareTo(aId);
    }

    return b.id.compareTo(a.id);
  }

  void _sortReportsNewestFirst() {
    _reports.sort(_compareReportsNewestFirst);
  }

  List<ReportModel> get reports => _reports;
  List<FolderModel> get folders => _folders;
  bool get isLoading => _isLoading;

  Future<void> init({required String base}) async {
    baseUrl = base;
    empID =
        (await userRepo.getLoginResponse())!.result!.data!.emp_id.toString();
    companyId =
        (await userRepo.getLoginResponse())!.result!.data!.companyId.toString();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<Map<String, dynamic>> _handleResponse(http.StreamedResponse response,
      {bool alwaysShowMessage = false, bool neverShowMessage = false}) async {
    final res = await response.stream.bytesToString();
    final jsonData = json.decode(res);

    if (jsonData is Map && jsonData['status'] == "upcoming") {
      debugPrint(
          '⚠️ API returned "upcoming" — feature not enabled on backend yet. Message: ${jsonData['message']}');
      if (!neverShowMessage) {
        showFlushBar(navKey.currentContext!, message: jsonData['message']);
      }
      return {};
    }

    if (!neverShowMessage &&
        (alwaysShowMessage ||
            (jsonData is Map && jsonData['status'] != "success"))) {
      showFlushBar(navKey.currentContext!, message: jsonData['message']);
    }
    if (jsonData is List) {
      return {"data": jsonData};
    }

    return jsonData;
  }

  Future<void> createFolder(
      {required String title, String description = ""}) async {
    _setLoading(true);
    var request = http.MultipartRequest(
        'POST', Uri.parse('$baseUrl/api/create_report_folder'))
      ..fields.addAll({
        'emp_id': empID,
        'folder_name': title,
        'description': description,
        'company_id': companyId,
        'report_id': "1", //todo remove
        'company': "test" //todo remove
      });
    // print(companyId);
    final jsonData = await _handleResponse(await request.send());
    // print(jsonData);
    _setLoading(false);

    if (jsonData['data'] == null) return;
    var createdFolder = FolderModel.fromJson(jsonData['data']);
    _folders.insert(0, createdFolder);
    notifyListeners();

    final createdReport = await createReport(
      title: createdFolder.name,
      folderID: createdFolder.id,
      companyName: description,
    );
    if (createdReport != null) {
      createdFolder = createdFolder.copyWith(reportCount: 1);
      final index = _folders.indexWhere((f) => f.id == createdFolder.id);
      if (index != -1) {
        _folders[index] = createdFolder;
        notifyListeners();
      }
    }
  }

  Future<ReportModel?> createReport({
    required String title,
    required String folderID,
    String? companyName,
    String? reportType,
  }) async {
    _setLoading(true);
    var request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/api/create_report'))
          ..fields.addAll({
            'emp_id': empID,
            'name': title,
            'company_id': companyId,
            'folder_id': folderID,
            'company': (companyName?.trim().isNotEmpty ?? false)
                ? companyName!.trim()
                : "test",
            if (reportType?.trim().isNotEmpty ?? false)
              'report_type': reportType!.trim(),
          });
    final jsonData = await _handleResponse(await request.send());
    print(jsonData);
    _setLoading(false);
    if (jsonData['data'] == null) return null;
    var createdReport = ReportModel.fromJson(jsonData['data']);
    if (createdReport.reportType == null &&
        (reportType?.trim().isNotEmpty ?? false)) {
      createdReport = ReportModel(
        id: createdReport.id,
        name: createdReport.name,
        companyId: createdReport.companyId,
        folderId: createdReport.folderId,
        createdAt: createdReport.createdAt,
        updatedAt: createdReport.updatedAt,
        reportType: reportType!.trim(),
      );
    }
    // Persist report type locally so it survives app restart
    if (createdReport.reportType != null) {
      _saveReportType(createdReport.id, createdReport.reportType!);
    }
    _reports.insert(0, createdReport);
    _sortReportsNewestFirst();
    notifyListeners();
    return createdReport;
  }

  Future<void> updateReport(
      {required String name, required String reportId}) async {
    try {
      var request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/reports/update'))
            ..fields.addAll({
              'emp_id': empID,
              'report_id': reportId,
              'name': name,
            });

      final jsonData = await _handleResponse(await request.send());
      _setLoading(false);
      final updatedReport = ReportModel.fromJson(jsonData['data']);
      int index = _reports.indexWhere((r) => r.id == updatedReport.id);
      if (index != -1) {
        _reports[index] = updatedReport;
        notifyListeners();
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> deleteReport({required String reportId}) async {
    try {
      _reports.removeWhere((r) => r.id == reportId);
      var request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/reports/delete'))
            ..fields.addAll({
              'emp_id': empID,
              'report_id': reportId,
            });

      final jsonData = await _handleResponse(await request.send());
      _setLoading(false);
      final updatedReport = ReportModel.fromJson(jsonData['data']);
      int index = _reports.indexWhere((r) => r.id == updatedReport.id);
      if (index != -1) {
        _reports.removeAt(index);
        notifyListeners();
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> fetchAllFolders() async {
    // Ensure empID and companyId are initialized before proceeding
    if (empID.isEmpty || companyId.isEmpty) {
      await init(base: baseUrl); // Ensure init is complete
    }

    _setLoading(true);
    try {
      var request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/reports/list'))
            ..fields.addAll({
              'emp_id': empID,
              'company_id': companyId,
            });

      final jsonData = await _handleResponse(await request.send());

      _folders = (jsonData['data'] as List)
          .map((e) => FolderModel.fromJson(e))
          .toList()
          .reversed
          .toList();
    } catch (e) {
      debugPrint('Error in fetchAllFolders: $e');
      _folders = []; // Avoid crash if data is bad
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchAllReports({required String folderID}) async {
    _setLoading(true);
    var request = http.MultipartRequest(
        'POST', Uri.parse('$baseUrl/api/get_folder_report_list'))
      ..fields.addAll({
        'emp_id': empID,
        'company_id': companyId,
        'folder_id': folderID,
      });
    final jsonData = await _handleResponse(await request.send());

    if (kDebugMode) {
      print('🔍 get_folder_report_list response: $jsonData');
    }
    _setLoading(false);
    // Preserve locally-stored reportTypes before overwriting
    final Map<String, String?> oldTypes = {};
    for (final r in _reports) {
      if (r.reportType != null) {
        oldTypes[r.id] = r.reportType;
      }
    }
    final rawList = (jsonData['data'] as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final filteredList = rawList.where((item) {
      // upload_site_report can create file rows inside get_folder_report_list.
      // These rows belong to Generated Reports history, not editable project reports.
      final rawS3 = item['s3_key'];
      final hasS3Key =
          rawS3 != null && rawS3 != false && rawS3.toString().trim().isNotEmpty;

      final rawFileName = item['file_name'];
      final hasFileName = rawFileName != null &&
          rawFileName != false &&
          rawFileName.toString().trim().isNotEmpty;

      final rawName = item['name'];
      final hasDisplayName = rawName != null &&
          rawName != false &&
          rawName.toString().trim().isNotEmpty;

      final isGeneratedFileArtifact =
          hasS3Key || hasFileName || (hasS3Key && !hasDisplayName);
      return !isGeneratedFileArtifact;
    }).toList();

    if (kDebugMode) {
      final dropped = rawList.length - filteredList.length;
      if (dropped > 0) {
        print(
            '🧹 Filtered out $dropped generated-file artifacts from project reports list');
      }
    }

    _reports = filteredList.map(ReportModel.fromJson).toList();
    // Re-apply preserved reportTypes from in-memory cache first
    for (int i = 0; i < _reports.length; i++) {
      if (_reports[i].reportType == null &&
          oldTypes.containsKey(_reports[i].id)) {
        _reports[i] = ReportModel(
          id: _reports[i].id,
          name: _reports[i].name,
          companyId: _reports[i].companyId,
          folderId: _reports[i].folderId,
          createdAt: _reports[i].createdAt,
          updatedAt: _reports[i].updatedAt,
          reportType: oldTypes[_reports[i].id],
        );
      }
    }
    // Then restore any remaining null types from persistent local storage
    await _restoreReportTypes();

    // Always show newest reports first in My Report screens.
    _sortReportsNewestFirst();

    debugPrint(
        '🔍 Loaded ${_reports.length} reports. Types: ${_reports.map((r) => '${r.name}:${r.reportType}').join(', ')}');
    notifyListeners();
  }

  Future<ReportModel?> getOrCreateSingleReportForFolder(
      FolderModel folder) async {
    await fetchAllReports(folderID: folder.id);

    if (_reports.isNotEmpty) {
      final normalizedFolderName = folder.name.trim().toLowerCase();
      final sameNameIndex = _reports.indexWhere(
        (report) => report.name.trim().toLowerCase() == normalizedFolderName,
      );
      if (sameNameIndex != -1) return _reports[sameNameIndex];

      // Existing folders may already have old reports with custom names.
      // Keep the user's data and open the newest report instead of creating
      // duplicates; all newly created folders get a same-name report below.
      return _reports.first;
    }

    return createReport(
      title: folder.name,
      folderID: folder.id,
      companyName: folder.description,
    );
  }

  Future<ReportDetailModel?> getReportDetail(ReportModel report) async {
    Box<ReportDetailModel> reportDetailBox =
        await ReportHiveService.getReportDetailBox();
    return reportDetailBox.get("$empID-${report.folderId}-${report.id}");
  }

  Future<void> updateReportDetail(ReportDetailModel report) async {
    try {
      Box<ReportDetailModel> reportDetailBox =
          await ReportHiveService.getReportDetailBox();
      await reportDetailBox.put(
          "$empID-${report.report.folderId}-${report.report.id}", report);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<bool> deleteCoverPage(ReportDetailModel report) async {
    Box<ReportDetailModel> reportDetailBox =
        await ReportHiveService.getReportDetailBox();
    await reportDetailBox.put(
        "$empID-${report.report.folderId}-${report.report.id}",
        report.copyWith(coverPage: null));
    return true;
  }

  /// Fetches generated PDF reports from the server.
  ///
  /// The `/api/get_report_list` endpoint is unreliable (often returns
  /// "No reports found"), so we use `/api/get_folder_report_list` instead
  /// and filter for items that have a valid `s3_key` and `report_link`
  /// (these are the generated PDF artifacts).
  Future<List<ReportPdfModel>> fetchReports(
      {required String empId,
      required String reportId,
      required String folderId}) async {
    try {
      var request = http.MultipartRequest(
          'POST', Uri.parse('$baseUrl/api/get_folder_report_list'))
        ..fields.addAll({
          'emp_id': empId,
          'company_id': companyId,
          'folder_id': folderId,
          'report_id': reportId,
        });
      final streamed = await request.send();
      final res = await streamed.stream.bytesToString();
      print('📋 fetchReports (via get_folder_report_list) response: $res');

      if (streamed.statusCode != 200) return [];

      final body = jsonDecode(res);
      if (body['status'] != 'success' || body['data'] == null) return [];

      final List<dynamic> data = body['data'];
      final prefs = await SharedPreferences.getInstance();

      // Filter: generated PDFs have a non-empty s3_key and/or report_link
      final pdfItems = data.where((item) {
        if (item is! Map) return false;
        final map = Map<String, dynamic>.from(item);
        final rawS3 = map['s3_key'];
        final hasS3 = rawS3 != null &&
            rawS3 != false &&
            rawS3.toString().trim().isNotEmpty;
        final rawLink = map['report_link'];
        final hasLink = rawLink != null &&
            rawLink != false &&
            rawLink.toString().trim().isNotEmpty;
        if (!hasS3 && !hasLink) return false;

        final serverReportId = _extractPdfReportId(map);
        if (serverReportId.isNotEmpty) return serverReportId == reportId;

        final localKeys = [
          map['s3_key'],
          map['file_id'],
          map['id'],
          map['report_link'],
        ];
        for (final key in localKeys) {
          final value = key?.toString().trim() ?? '';
          if (value.isEmpty) continue;
          final localReportId = prefs.getString('$_pdfReportPrefix$value');
          if (localReportId != null) return localReportId == reportId;
        }

        // If the backend does not return report_id and we do not have a local
        // association, do not show the file for every report in the folder.
        return false;
      }).toList();

      print(
          '📋 Found ${pdfItems.length} generated PDFs out of ${data.length} items');

      return pdfItems.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final pdfReportId = _extractPdfReportId(map);
        return ReportPdfModel(
          fileId: (map['s3_key'] ?? map['file_id'] ?? '').toString(),
          id: (map['id'] ?? '').toString(),
          reportId: pdfReportId.isNotEmpty ? pdfReportId : reportId,
          fileName: (map['name'] ?? map['file_name'] ?? '').toString(),
          createdAt: (map['create_at'] ?? map['created_at'] ?? '').toString(),
          reportLink: (map['report_link'] ?? '').toString(),
        );
      }).toList();
    } catch (e) {
      print('📋 fetchReports error: $e');
      return [];
    }
  }

  /// No longer needed — fetchReports now uses get_folder_report_list directly.
  // ignore: unused_element
  Future<List<ReportPdfModel>> _enrichPdfsWithIds({
    required List<ReportPdfModel> pdfs,
    required String empId,
    required String reportId,
    required String folderId,
  }) async {
    return pdfs;
  }

  /// Uploads a report PDF and returns the resulting [ReportPdfModel] on
  /// success, or `null` on failure.  The server appends `.pdf` to the
  /// filename automatically, so we send the raw name without extension.
  Future<ReportPdfModel?> uploadReportPdf({
    required String empId,
    required Uint8List pdfBytes,
    required String reportId,
    required String folderId,
    required String fileName,
    UploadProgressCallback? onProgress,
  }) async {
    // Do NOT append .pdf here — the server adds the extension itself.
    final cleanName = fileName.trim();

    try {
      final client = dio.Dio(
        dio.BaseOptions(
          connectTimeout: const Duration(seconds: 45),
          receiveTimeout: const Duration(seconds: 90),
          sendTimeout: const Duration(seconds: 90),
        ),
      );

      final formData = dio.FormData.fromMap({
        'emp_id': empId,
        'report_id': reportId,
        'folder_id': folderId,
        'file_name': cleanName,
        'file': dio.MultipartFile.fromBytes(pdfBytes, filename: cleanName),
      });

      final response = await client.post(
        '$baseUrl/api/upload_site_report',
        queryParameters: {
          'folder_id': folderId,
          'report_id': reportId,
          'file_name': cleanName,
        },
        data: formData,
        onSendProgress: (sent, total) {
          if (onProgress == null || total <= 0) return;
          final progress = (sent / total).clamp(0.0, 1.0);
          onProgress(progress.toDouble());
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        print('📤 upload_site_report response: $data');
        Map<String, dynamic>? body;
        if (data is Map<String, dynamic>) {
          body = data;
        } else if (data is String) {
          final decoded = jsonDecode(data);
          if (decoded is Map<String, dynamic>) {
            body = decoded;
          }
        }
        if (body?['status'] == 'success' && body?['data'] != null) {
          final d = body!['data'] is Map<String, dynamic>
              ? body['data'] as Map<String, dynamic>
              : <String, dynamic>{};
          final uploadedPdf = ReportPdfModel(
            fileId: (d['file_id'] ?? d['s3_key'] ?? '').toString(),
            id: (d['id'] ?? '').toString(),
            reportId: reportId,
            fileName: (d['file_name'] ?? d['name'] ?? cleanName).toString(),
            createdAt: (d['created_at'] ?? d['create_at'] ?? '').toString(),
            reportLink: (d['report_link'] ?? '').toString(),
          );
          await _savePdfReportId(uploadedPdf.fileId, reportId);
          await _savePdfReportId(uploadedPdf.id, reportId);
          await _savePdfReportId(uploadedPdf.reportLink, reportId);
          return uploadedPdf;
        }
      }

      print(
          'Upload failed with status: ${response.statusCode} body: ${response.data}');
      return null;
    } on dio.DioException catch (e) {
      print('Dio exception during PDF upload: ${e.message}');
      print('Dio response status: ${e.response?.statusCode}');
      print('Dio response data: ${e.response?.data}');
      return null;
    } catch (e) {
      print("Exception caught during PDF upload: $e");
      return null;
    }
  }

  Future<bool> deleteReportPdf({
    required String fileId,
  }) async {
    try {
      final fields = {
        'emp_id': empID,
        'report_id': fileId,
      };
      print('🗑️ deleteReportPdf REQUEST fields: $fields');
      var request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/reports/delete'))
            ..fields.addAll(fields);
      final response = await request.send();
      final res = await response.stream.bytesToString();
      print('🗑️ deleteReportPdf STATUS: ${response.statusCode}');
      print('🗑️ deleteReportPdf RESPONSE: $res');
      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      print('🗑️ deleteReportPdf error: $e');
      return false;
    }
  }

  Future<bool> renameReportPdf({
    required String fileId,
    required String newFileName,
  }) async {
    try {
      final fields = {
        'emp_id': empID,
        'report_id': fileId,
        'name': newFileName,
      };
      print('✏️ renameReportPdf REQUEST fields: $fields');
      var request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/reports/update'))
            ..fields.addAll(fields);
      final response = await request.send();
      final res = await response.stream.bytesToString();
      print('✏️ renameReportPdf STATUS: ${response.statusCode}');
      print('✏️ renameReportPdf RESPONSE: $res');
      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      print('✏️ renameReportPdf error: $e');
      return false;
    }
  }

  // ── Report Items API (server-side) ──

  /// Add a report item (image + location + description) to the server
  Future<ReportItemModel?> addReportItem({
    required String reportId,
    required File imageFile,
    required String location,
    required String description,
    String type = 'image',
    int index = 0,
  }) async {
    try {
      debugPrint(
          '📤 addReportItem: reportId=$reportId, location=$location, image=${imageFile.path}');
      var request = http.MultipartRequest(
          'POST', Uri.parse('$baseUrl/api/upload_report_item'))
        ..fields.addAll({
          'emp_id': empID,
          'report_id': reportId,
          'location': location,
          'description': description,
          'type': type,
        });

      request.files
          .add(await http.MultipartFile.fromPath('item_data', imageFile.path));

      final response = await request.send();
      final res = await response.stream.bytesToString();
      debugPrint('📤 upload_report_item response: $res');
      final jsonData = json.decode(res);

      if (jsonData is Map<String, dynamic> &&
          jsonData.containsKey('data') &&
          jsonData['data'] != null) {
        final data = jsonData['data'];
        if (data is List && data.isNotEmpty) {
          return ReportItemModel.fromJson(
              data[0] as Map<String, dynamic>, reportId);
        } else if (data is Map<String, dynamic>) {
          return ReportItemModel.fromJson(data, reportId);
        }
      }
      return null;
    } catch (e, stackTrace) {
      debugPrint('❌ Error adding report item: $e');
      debugPrint('❌ Stack: $stackTrace');
      return null;
    }
  }

  /// Update a report item on the server
  Future<ReportItemModel?> updateReportItem({
    required String reportId,
    required String itemId,
    String? location,
    String? description,
    File? imageFile,
    int index = 0,
  }) async {
    try {
      var request = http.MultipartRequest(
          'POST', Uri.parse('$baseUrl/report-items/update'))
        ..fields.addAll({
          'emp_id': empID,
          'report_id': reportId,
          'item_id': itemId,
          if (location != null) 'location': location,
          if (description != null) 'description': description,
          'index': index.toString(),
        });

      if (imageFile != null) {
        request.files
            .add(await http.MultipartFile.fromPath('image', imageFile.path));
      }

      debugPrint(
          '📤 updateReportItem: url=${request.url} fields=${request.fields}');
      final jsonData =
          await _handleResponse(await request.send(), neverShowMessage: true);
      debugPrint('📤 updateReportItem response: $jsonData');
      if (jsonData.containsKey('data') && jsonData['data'] != null) {
        return ReportItemModel.fromJson(jsonData['data'], reportId);
      }
      return null;
    } catch (e) {
      debugPrint('📤 Error updating report item: $e');
      return null;
    }
  }

  /// Delete a report item from the server
  Future<bool> deleteReportItem({
    required String reportId,
    required String itemId,
  }) async {
    final endpointCandidates = <String>[
      '$baseUrl/api/delete_report_item',
      '$baseUrl/report-items/delete',
    ];

    final fieldCandidates = <Map<String, String>>[
      {
        'emp_id': empID,
        'report_id': reportId,
        'item_id': itemId,
      },
      {
        'emp_id': empID,
        'report_id': reportId,
        'id': itemId,
      },
    ];

    for (final endpoint in endpointCandidates) {
      for (final fields in fieldCandidates) {
        try {
          final request = http.MultipartRequest('POST', Uri.parse(endpoint))
            ..fields.addAll(fields);
          debugPrint('🗑️ deleteReportItem: url=$endpoint fields=$fields');

          final response = await request.send();
          final res = await response.stream.bytesToString();
          debugPrint(
              '🗑️ deleteReportItem response ${response.statusCode}: $res');

          if (response.statusCode < 200 || response.statusCode >= 300) {
            continue;
          }

          final jsonData = json.decode(res);
          if (jsonData is Map<String, dynamic>) {
            final status = jsonData['status']?.toString().toLowerCase();
            final success = jsonData['success'];
            if (status == 'success' || success == true) {
              return true;
            }
          }
        } catch (e) {
          debugPrint('Error deleting report item via $endpoint: $e');
        }
      }
    }

    return false;
  }

  /// Fetch full report detail (with items) from the server
  Future<ReportDetailModel?> fetchReportDetailFromApi(String reportId) async {
    try {
      debugPrint(
          '🔍 fetchReportDetailFromApi: reportId=$reportId, baseUrl=$baseUrl');
      var request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/reports/detail'))
            ..fields.addAll({
              'emp_id': empID,
              'report_id': reportId,
            });

      final response = await request.send();
      final res = await response.stream.bytesToString();
      debugPrint('🔍 reports/detail raw response: $res');
      final jsonData = json.decode(res);

      if (jsonData is Map<String, dynamic> &&
          jsonData.containsKey('data') &&
          jsonData['data'] != null) {
        return ReportDetailModel.fromJson(jsonData['data']);
      }
      debugPrint('🔍 reports/detail: no data in response');
      return null;
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching report detail: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return null;
    }
  }
}
