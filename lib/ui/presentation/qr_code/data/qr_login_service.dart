import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:el_race/core/utils/shared_pref.dart';

class QrLoginService {
  final Dio _dio = Dio();
  static const String baseUrl = 'https://rcc.sawatech.ae/api/auth';

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  int? _resolveUserId(dynamic data) {
    if (data == null) return null;
    final map = data as dynamic;
    return _asInt(map.odoo_user_id) ?? _asInt(map.uid) ?? _asInt(map.user_id);
  }

  String _extractCodeFromQr(String qrRaw) {
    final raw = qrRaw.trim();

    // JSON payload support: {"code":"..."} and common variants.
    try {
      final qrJson = jsonDecode(raw);
      if (qrJson is Map) {
        for (final key in ['code', 'qr_code', 'token', 'login_code']) {
          final value = qrJson[key];
          final parsed = value?.toString().trim();
          if (parsed != null && parsed.isNotEmpty) {
            return parsed;
          }
        }
      }
    } catch (_) {
      // Not JSON, continue with URL/text parsing.
    }

    final uri = Uri.tryParse(raw);
    if (uri != null && (uri.hasScheme || uri.host.isNotEmpty)) {
      for (final key in ['code', 'qr', 'token', 'login_code']) {
        final q = uri.queryParameters[key]?.trim();
        if (q != null && q.isNotEmpty) {
          return q;
        }
      }

      if (uri.pathSegments.isNotEmpty) {
        final last = uri.pathSegments.last.trim();
        if (last.isNotEmpty &&
            !last.contains('.php') &&
            !last.contains('.html')) {
          return last;
        }
      }
    }

    // Fallback: plain text scanned content.
    return raw;
  }

  /// Login to website using QR code
  /// Similar to WhatsApp Web login
  Future<Map<String, dynamic>> loginWithQrCode(String qrCode) async {
    try {
      print('\n🟢 ========== QR LOGIN SERVICE ==========');
      // Get odoo_id from current user session
      final loginData = SharedPref.getLoginData();
      print('📦 Login Data Retrieved:');
      print('   - Has Result: ${loginData.result != null}');
      print('   - Has Data: ${loginData.result?.data != null}');

      final odooId = _resolveUserId(loginData.result?.data);
      print('🆔 User IDs Available:');
      print('   - resolved_user_id: $odooId');
      print('   - uid: ${loginData.result?.data?.uid}');
      print('   - emp_id: ${loginData.result?.data?.emp_id}');
      print('   - emp_profile_id: ${loginData.result?.data?.emp_profile_id}');

      if (odooId == null) {
        print('❌ QR Login: No odoo_user_id found in session');
        print('🟢 ========================================\n');
        return {
          'success': false,
          'message': 'User session not found. Please login again.',
        };
      }

      final actualCode = _extractCodeFromQr(qrCode);
      final encodedCode = Uri.encodeComponent(actualCode);

      print('\n📡 API Request Details:');
      print('   - Original QR: $qrCode');
      print('   - Actual Code to Send: $actualCode');
      print('   - Encoded Code to Send: $encodedCode');
      print('   - Odoo ID: $odooId');
      print('   - Code Length: ${actualCode.length}');

      final url = '$baseUrl/login-with-code/$encodedCode';
      print('\n🌐 Making HTTP Request:');
      print('   - Method: POST');
      print('   - URL: $url');
      print('   - Body: {"odoo_id": $odooId}');
      print(
          '   - Headers: {"Content-Type": "application/json", "Accept": "application/json"}');

      final response = await _dio.post(
        url,
        data: {'odoo_id': odooId},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          validateStatus: (status) => true, // Accept all status codes
        ),
      );

      print('\n📥 HTTP Response Received:');
      print('   - Status Code: ${response.statusCode}');
      print('   - Status Message: ${response.statusMessage}');
      print('   - Headers: ${response.headers}');
      print('   - Data Type: ${response.data.runtimeType}');
      print('   - Data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('\n✅ SUCCESS: Status ${response.statusCode}');
        print('🟢 ========================================\n');
        return {
          'success': true,
          'message': 'Login successful',
          'data': response.data,
        };
      } else {
        print('\n⚠️ FAILED: Status ${response.statusCode}');
        print('   - Error Message: ${response.data?['message']}');
        print('🟢 ========================================\n');
        return {
          'success': false,
          'message': response.data?['message'] ?? 'Login failed',
          'data': response.data,
        };
      }
    } catch (e, stackTrace) {
      print('\n❌ EXCEPTION CAUGHT:');
      print('   - Error: $e');
      print('   - Type: ${e.runtimeType}');
      print('   - Stack Trace: $stackTrace');
      print('🟢 ========================================\n');
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }
}
