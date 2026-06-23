// import 'package:el_race/ui/presentation/Attendace_list/repository/attendance_repository.dart';
// import 'package:flutter/material.dart';
// import 'package:el_race/main.dart';
// import 'package:el_race/report_module/core/utils/flush_bar.dart';
// import 'package:el_race/report_module/data/models/cover_page_model.dart';
// import 'package:el_race/report_module/data/models/report_item_model.dart';
// import 'package:el_race/report_module/data/models/report_detail_model.dart';
// import 'package:el_race/report_module/data/repositories/company_repository.dart';
// import 'package:el_race/report_module/data/repositories/i_report_repository.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'dart:io';
//
//
// class ReportProvider extends ChangeNotifier
//     implements AbstractReportRepository {
//   static String baseUrl = "";
//   static String empID = "";
//
//   List<ReportModel> _reports = [];
//   bool _isLoading = false;
//
//   List<ReportModel> get reports => _reports;
//   bool get isLoading => _isLoading;
//
//   Future<void> init({required String base}) async {
//     baseUrl = base;
//     empID = (await userRepo.getLoginResponse())!.result!.data!.uid.toString();
//   }
//
//   void _setLoading(bool value) {
//     _isLoading = value;
//     notifyListeners();
//   }
//
//   Future<Map<String, dynamic>> _handleResponse(http.StreamedResponse response,
//       {bool alwaysShowMessage = false}) async {
//     final res = await http.Response.fromStream(response);
//     final jsonData = json.decode(res.body);
//     print(jsonData);
//     if (alwaysShowMessage || jsonData['success'] == false) {
//       showFlushBar(navKey.currentContext!, message: jsonData['message']);
//     }
//     return jsonData;
//   }
//
//   @override
//   Future<ReportModel> createReportOrFolder(ReportModel model) async {
//     _setLoading(true);
//     var request =
//         http.MultipartRequest('POST', Uri.parse('$baseUrl/reports/create'))
//           ..fields.addAll({
//             'emp_id': empID,
//             'name': model.name,
//             'company': model.company,
//             'report': model.report.toString(),
//             'description': model.description ?? '',
//             'folder_id': model.folderId ?? '',
//             'company_id': model.companyId,
//           });
//
//     final jsonData = await _handleResponse(await request.send());
//     _setLoading(false);
//
//     final createdReport = ReportModel.fromJson(jsonData['data']);
//     _reports.add(createdReport);
//     notifyListeners();
//     return createdReport;
//   }
//
//   @override
//   Future<ReportModel> updateReportOrFolderName(ReportModel model) async {
//     _setLoading(true);
//     var request =
//         http.MultipartRequest('POST', Uri.parse('$baseUrl/reports/update'))
//           ..fields.addAll({
//             'emp_id': empID,
//             'report_id': model.id!,
//             'name': model.name,
//           });
//
//     final jsonData = await _handleResponse(await request.send());
//     _setLoading(false);
//
//     final updatedReport = ReportModel.fromJson(jsonData['data']);
//     int index = _reports.indexWhere((r) => r.id == updatedReport.id);
//     if (index != -1) {
//       _reports[index] = updatedReport;
//       notifyListeners();
//     }
//
//     return updatedReport;
//   }
//
//   @override
//   Future<void> deleteReportOrFolder(String reportId) async {
//     _setLoading(true);
//     var request =
//         http.MultipartRequest('POST', Uri.parse('$baseUrl/reports/delete'))
//           ..fields.addAll({
//             'emp_id': empID,
//             'report_id': reportId,
//           });
//
//     await _handleResponse(await request.send(), alwaysShowMessage: true);
//     _reports.removeWhere((r) => r.id == reportId);
//     _setLoading(false);
//     notifyListeners();
//   }
//
//   @override
//   Future<List<ReportModel>> getAllReportsOrFolders({String? folderId}) async {
//     _setLoading(true);
//     var request =
//         http.MultipartRequest('POST', Uri.parse('$baseUrl/reports/list'))
//           ..fields.addAll({
//             'emp_id': empID,
//             if (CompanyRepository.selectedCompany != null)
//               'company_id': CompanyRepository.selectedCompany.toString(),
//             if (folderId != null) 'folder_id': folderId,
//           });
//
//     final jsonData = await _handleResponse(await request.send());
//     _setLoading(false);
//
//     _reports =
//         (jsonData['data'] as List).map((e) => ReportModel.fromJson(e)).toList();
//     notifyListeners();
//
//     return _reports;
//   }
//
//   @override
//   Future<ReportModel> getReportDetail(String reportId) async {
//     var request =
//         http.MultipartRequest('POST', Uri.parse('$baseUrl/reports/detail'))
//           ..fields.addAll({
//             'emp_id': empID,
//             'report_id': reportId,
//           });
//
//     final jsonData = await _handleResponse(await request.send());
//     return ReportModel.fromJson(jsonData['data']);
//   }
//
//   @override
//   Future<CoverPageModel> addCoverPage(CoverPageModel model) async {
//     var request =
//         http.MultipartRequest('POST', Uri.parse('$baseUrl/report-cover/create'))
//           ..fields.addAll({
//             'emp_id': empID,
//             'report_id': model.reportId,
//             'title': model.title,
//             'description': model.description ?? '',
//           });
//
//     final jsonData = await _handleResponse(await request.send());
//     return CoverPageModel.fromJson(jsonData['data']);
//   }
//
//   @override
//   Future<CoverPageModel> editCoverPage(CoverPageModel model) async {
//     var request =
//         http.MultipartRequest('POST', Uri.parse('$baseUrl/report-cover/update'))
//           ..fields.addAll({
//             'emp_id': empID,
//             'cover_id': model.id!,
//             'title': model.title,
//             'description': model.description ?? '',
//           });
//
//     final jsonData = await _handleResponse(await request.send());
//     return CoverPageModel.fromJson(jsonData['data']);
//   }
//
//   @override
//   Future<void> deleteCoverPage(String coverId) async {
//     var request =
//         http.MultipartRequest('POST', Uri.parse('$baseUrl/report-cover/delete'))
//           ..fields.addAll({
//             'emp_id': empID,
//             'cover_id': coverId,
//           });
//
//     await _handleResponse(await request.send(), alwaysShowMessage: true);
//   }
//
//   @override
//   Future<ReportItemModel> addReportItem(ReportItemModel model,
//       {File? imageFile}) async {
//     var request =
//         http.MultipartRequest('POST', Uri.parse('$baseUrl/report-items/create'))
//           ..fields.addAll({
//             'emp_id': empID,
//             'report_id': model.reportId,
//             'location': model.location ?? '',
//             'description': model.description ?? '',
//             'type': model.type,
//             'index': model.index.toString(),
//           });
//
//     if (imageFile != null) {
//       request.files
//           .add(await http.MultipartFile.fromPath('image', imageFile.path));
//     }
//
//     final jsonData = await _handleResponse(await request.send());
//     return ReportItemModel.fromJson(jsonData['data']);
//   }
//
//   @override
//   Future<ReportItemModel> updateReportItem(ReportItemModel model,
//       {File? imageFile}) async {
//     var request =
//         http.MultipartRequest('POST', Uri.parse('$baseUrl/report-items/update'))
//           ..fields.addAll({
//             'emp_id': empID,
//             'report_id': model.reportId,
//             'item_id': model.id!,
//             'location': model.location ?? '',
//             'index': model.index.toString(),
//           });
//
//     if (imageFile != null) {
//       request.files
//           .add(await http.MultipartFile.fromPath('image', imageFile.path));
//     }
//
//     final jsonData = await _handleResponse(await request.send());
//     return ReportItemModel.fromJson(jsonData['data']);
//   }
//
//   @override
//   Future<void> deleteReportItem(String itemId, String reportId) async {
//     var request =
//         http.MultipartRequest('POST', Uri.parse('$baseUrl/report-items/delete'))
//           ..fields.addAll({
//             'emp_id': empID,
//             'report_id': reportId,
//             'item_id': itemId,
//           });
//
//     await _handleResponse(await request.send(), alwaysShowMessage: true);
//   }
// }
