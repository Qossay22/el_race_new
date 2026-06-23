import 'dart:io';

import 'package:el_race/data/models/pdf_model.dart';
import 'package:el_race/data/models/report_detail_item.dart';
import 'package:el_race/data/models/report_detail_model.dart';
import 'package:el_race/report_module/data/models/company_model.dart';
import 'package:el_race/report_module/data/models/cover_page_model.dart';
import 'package:el_race/report_module/data/models/report_detail_model.dart'
    as report_module;
import 'package:el_race/report_module/data/models/report_item_model.dart';
import 'package:el_race/report_module/data/models/report_model.dart'
    as report_module;
import 'package:hive_flutter/adapters.dart';
import 'package:path_provider/path_provider.dart';
import '../models/report_model.dart';
import '../../core/constants/hive_constants.dart';

class HiveService {
  static Box<ReportModel>? _reportBox;
  static Box<ReportDetailModel>? _reportDetailBox;
  static Box<CompanyModel>? _companyBox;
  static Box<PdfModel>? _pdfBox;
  static Box? _preferencesBox;

  static Future<void> setupHive() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocDir.path);
    // Main app adapters
    Hive.registerAdapter(ReportModelAdapter());
    Hive.registerAdapter(ReportDetailModelAdapter());
    Hive.registerAdapter(ReportDetailItemAdapter());
    Hive.registerAdapter(CompanyModelAdapter());
    Hive.registerAdapter(PdfModelAdapter());
    // Report module adapters
    Hive.registerAdapter(CoverPageModelAdapter());
    Hive.registerAdapter(ReportItemModelAdapter());
    Hive.registerAdapter(report_module.ReportModelAdapter());
    Hive.registerAdapter(report_module.ReportDetailModelAdapter());
  }

  static Future<Box<PdfModel>> getPdfBox() async {
    if (_pdfBox == null || !_pdfBox!.isOpen) {
      _pdfBox = await Hive.openBox<PdfModel>(HiveConstants.reportPdfBox);
    }
    return _pdfBox!;
  }

  static Future<Box<ReportModel>> getReportBox() async {
    if (_reportBox == null || !_reportBox!.isOpen) {
      _reportBox = await Hive.openBox<ReportModel>(HiveConstants.reportBox);
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

  static Future<Box> getPreferencesBox() async {
    if (_preferencesBox == null || !_preferencesBox!.isOpen) {
      _preferencesBox = await Hive.openBox(HiveConstants.preferencesBox);
    }
    return _preferencesBox!;
  }

  // Prayer sound mute preference methods
  static Future<bool> isPrayerSoundMuted() async {
    final box = await getPreferencesBox();
    return box.get(HiveConstants.prayerSoundMutedKey, defaultValue: false);
  }

  static Future<void> setPrayerSoundMuted(bool isMuted) async {
    final box = await getPreferencesBox();
    await box.put(HiveConstants.prayerSoundMutedKey, isMuted);
  }

  // User authentication state for background service
  static Future<bool> isUserLoggedIn() async {
    final box = await getPreferencesBox();
    return box.get('user_logged_in', defaultValue: false);
  }

  static Future<void> setUserLoggedIn(bool isLoggedIn) async {
    final box = await getPreferencesBox();
    await box.put('user_logged_in', isLoggedIn);
  }

  // Track whether a prayer (by unique key) has already been played/shown
  static Future<bool> hasPlayedPrayer(String key) async {
    final box = await getPreferencesBox();
    return box.get(key, defaultValue: false) as bool;
  }

  static Future<void> markPrayerPlayed(String key) async {
    final box = await getPreferencesBox();
    await box.put(key, true);
  }
}
