import 'package:el_race/report_module/data/models/company_model.dart';
import 'package:el_race/report_module/data/models/report_detail_model.dart';
import 'package:hive_flutter/adapters.dart';
import '../../core/constants/hive_constants.dart';

class HiveService {
  static Box<ReportDetailModel>? _reportBox;
  static Box<ReportDetailModel>? _reportDetailBox;
  static Box<CompanyModel>? _companyBox;

  static Future<Box<ReportDetailModel>> getReportBox() async {
    if (_reportBox == null || !_reportBox!.isOpen) {
      _reportBox =
          await Hive.openBox<ReportDetailModel>(HiveConstants.reportBox);
    }
    return _reportBox!;
  }

  static Future<Box<CompanyModel>> getCompanyBox() async {
    if (_companyBox == null || !_companyBox!.isOpen) {
      _companyBox = await Hive.openBox<CompanyModel>(HiveConstants.companyBox);
    }
    return _companyBox!;
  }

  static Future<Box<ReportDetailModel>> getReportDetailBox() async {
    if (_reportDetailBox == null || !_reportDetailBox!.isOpen) {
      _reportDetailBox = await Hive.openBox(HiveConstants.reportDetailBox);
    }
    return _reportDetailBox!;
  }
}
