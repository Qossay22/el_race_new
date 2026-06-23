import 'package:el_race/data/models/pdf_model.dart';
import 'package:el_race/data/models/report_detail_model.dart';

import '../models/report_model.dart';

abstract class IReportRepository {
  Future<void> addReport(ReportModel report);
  Future<void> deleteReport(ReportModel report);
  Future<void> updateReport(ReportModel report);
  Future<List<ReportModel>> getAllReports();
  Future<List<ReportModel>> getAllReportsForFolder(String id);
  Future<ReportDetailModel> getReportDetail(String id);
  Future<void> updateReportDetail(ReportDetailModel report);
  Future<void> saveReportPdf(PdfModel pdf);
  Future<void> deletePdf(PdfModel pdf);
  Future<List<PdfModel>> getReportPdfs(ReportModel report);
}
