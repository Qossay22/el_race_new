import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:el_race/utils/urll_utils.dart';

/// Global app configuration fetched from backend
class AppConfigService {
  AppConfigService._internal();
  static final AppConfigService instance = AppConfigService._internal();

  static const _cacheKeyIsTestMode = 'app_config_is_test_mode';
  static const _cacheKeySkipVpnCheck = 'app_config_skip_vpn_check';
  static const _cacheKeyFaceIdEnabled = 'app_config_face_id_enabled';

  bool _isTestMode = false;
  bool get isTestMode => _isTestMode;

  bool _skipVpnCheck = false;
  bool get skipVpnCheck => _skipVpnCheck;

  /// Whether VPN check should be skipped (test mode OR backend flag)
  bool get shouldSkipVpnCheck => _isTestMode || _skipVpnCheck;

  /// Whether face ID is enabled (default: true)
  /// Backend key: faceIdEnabled
  bool _faceIdEnabled = true;
  bool get faceIdEnabled => _faceIdEnabled;

  /// Whether face ID should be skipped (only when faceIdEnabled=false from backend)
  /// Note: Test mode no longer bypasses face ID for security
  bool get shouldSkipFaceId => !_faceIdEnabled;

  /// Load config from remote API and cache locally
  Future<void> load() async {
    // Try read cached values first
    try {
      final prefs = await SharedPreferences.getInstance();
      _isTestMode = prefs.getBool(_cacheKeyIsTestMode) ?? false;
      _skipVpnCheck = prefs.getBool(_cacheKeySkipVpnCheck) ?? false;
      _faceIdEnabled = prefs.getBool(_cacheKeyFaceIdEnabled) ?? true;
    } catch (_) {}

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {'Content-Type': 'application/json'},
      ));

      const String url = '${UrlUtil.baseUrl}app/config';
      final resp = await dio.get(
        url,
        data: {'jsonrpc': '2.0', 'params': {}},
      );

      // print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      // print('🔧 AppConfigService API Response:');
      // print('📡 URL: $url');
      // print('📊 Status Code: ${resp.statusCode}');
      // print('📦 Raw Response: ${resp.data}');
      // print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // Response can be jsonrpc envelope: { jsonrpc, id, result: { success, isTestMode } }
      final data = resp.data;
      bool? remoteIsTest;
      bool? remoteSkipVpn;
      Map<String, dynamic>? payload;
      if (data is Map<String, dynamic>) {
        payload = data['result'] is Map<String, dynamic>
            ? data['result'] as Map<String, dynamic>
            : data;
      } else if (data is String) {
        try {
          final parsed = jsonDecode(data);
          if (parsed is Map<String, dynamic>) {
            payload = parsed['result'] is Map<String, dynamic>
                ? parsed['result'] as Map<String, dynamic>
                : parsed;
          }
        } catch (_) {}
      }

      if (payload != null) {
        remoteIsTest = payload['isTestMode'] as bool?;
        remoteSkipVpn = payload['skipVpnCheck'] as bool?;
        final remoteFaceId = payload['faceIdEnabled'] as bool?;
        if (remoteFaceId != null) _faceIdEnabled = remoteFaceId;
      }

      if (remoteIsTest != null) {
        _isTestMode = remoteIsTest;
      }
      if (remoteSkipVpn != null) {
        _skipVpnCheck = remoteSkipVpn;
      }

      // print('✅ AppConfigService: isTestMode=$_isTestMode, skipVpnCheck=$_skipVpnCheck, faceIdEnabled=$_faceIdEnabled');

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_cacheKeyIsTestMode, _isTestMode);
        await prefs.setBool(_cacheKeySkipVpnCheck, _skipVpnCheck);
        await prefs.setBool(_cacheKeyFaceIdEnabled, _faceIdEnabled);
      } catch (_) {}

      if (kDebugMode) {
        // debugPrint('AppConfigService: isTestMode=$_isTestMode, skipVpnCheck=$_skipVpnCheck, faceIdEnabled=$_faceIdEnabled');
      }
    } catch (e) {
      if (kDebugMode) {
        // debugPrint('AppConfigService: failed to load config: $e');
      }
      // Keep cached value
    }
  }
}
