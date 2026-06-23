import 'package:el_race/core/utils/directory_operation.dart';
import 'package:el_race/data/models/pdf_model.dart';
import 'package:el_race/data/models/report_detail_model.dart';
import 'package:el_race/data/repositories/company_repository.dart';
import 'package:el_race/data/services/hive_service.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/report_model.dart';
import 'i_report_repository.dart';

class ReportRepository implements IReportRepository {
  static Box<ReportModel>? _reportBox;
  static Box? _reportDetailBox;
  static Box<PdfModel>? _reportPdfBox;

  Future<Box<ReportModel>> _getReportBox() async {
    if (_reportBox == null || !_reportBox!.isOpen) {
      _reportBox = await HiveService.getReportBox();
    }
    return _reportBox!;
  }

  Future<Box> _getReportDetailBox() async {
    if (_reportDetailBox == null || !_reportDetailBox!.isOpen) {
      _reportDetailBox = await HiveService.getReportDetailBox();
    }
    return _reportDetailBox!;
  }

  Future<Box<PdfModel>> _getReportPdfBox() async {
    if (_reportPdfBox == null || !_reportPdfBox!.isOpen) {
      _reportPdfBox = await HiveService.getPdfBox();
    }
    return _reportPdfBox!;
  }

  @override
  Future<void> addReport(ReportModel report) async {
    final box = await _getReportBox();
    await box.put(report.id, report);
    _addReportDetail(report);
  }

  Future<void> _addReportDetail(ReportModel report) async {
    final box = await _getReportDetailBox();
    await box.put(
        report.id, ReportDetailModel(id: report.id, items: [], sections: []));
  }

  @override
  Future<void> deleteReport(ReportModel report) async {
    final box = await _getReportBox();
    await box.delete(report.id);
  }

  @override
  Future<void> updateReport(ReportModel report) async {
    final box = await _getReportBox();
    await box.put(report.id, report);
  }

  @override
  Future<void> updateReportDetail(ReportDetailModel report) async {
    final box = await _getReportDetailBox();
    await box.put(report.id, report);
  }

  @override
  Future<List<ReportModel>> getAllReports() async {
    final box = await _getReportBox();
    return box.values
        .toList()
        .where((r) => r.folderID == "" || r.folderID == null)
        .where(
            (r) => r.companyID == CompanyRepository.selectedCompany.toString())
        .toList();
  }

  @override
  Future<List<ReportModel>> getAllReportsForFolder(String id) async {
    final box = await _getReportBox();
    return box.values.toList().where((r) => r.folderID == id).toList();
  }

  @override
  Future<ReportDetailModel> getReportDetail(String id) async {
    final box = await _getReportDetailBox();
    return box.get(id) ??
        ReportDetailModel(id: const Uuid().v4(), items: [], sections: []);
  }

  @override
  Future<List<PdfModel>> getReportPdfs(ReportModel report) async {
    final box = await _getReportPdfBox();
    return box.values.toList().where((r) => r.reportID == report.id).toList();
  }

  @override
  Future<void> saveReportPdf(PdfModel pdf) async {
    final box = await _getReportPdfBox();
    return box.put(pdf.id, pdf);
  }

  @override
  Future<void> deletePdf(PdfModel pdf) async {
    final box = await _getReportPdfBox();
    await deleteFileViaPath(pdf.path);
    return box.delete(pdf.id);
  }
}
