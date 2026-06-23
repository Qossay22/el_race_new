import 'dart:io';

import 'package:el_race/report_module/data/models/company_model.dart';
import 'package:el_race/report_module/data/models/cover_page_model.dart';
import 'package:el_race/report_module/data/models/report_detail_model.dart';
import 'package:el_race/report_module/data/models/report_item_model.dart';
import 'package:el_race/report_module/data/models/report_model.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/hive_constants.dart';

class ReportHiveService {
  static Box<ReportDetailModel>? _reportDetailBox;
  static Box<CompanyModel>? _companyBox;

  static Future<void> setupHive() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocDir.path);
    Hive.registerAdapter(CompanyModelAdapter());
    Hive.registerAdapter(ReportItemModelAdapter());
    Hive.registerAdapter(CoverPageModelAdapter());
    Hive.registerAdapter(ReportModelAdapter());
    Hive.registerAdapter(ReportDetailModelAdapter());
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
