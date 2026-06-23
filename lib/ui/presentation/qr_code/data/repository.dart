import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:el_race/ui/presentation/signin/data/repository.dart';
import 'package:el_race/utils/api_query.dart';
import 'package:el_race/utils/urll_utils.dart';

class QrCodeRepository {
  ApiQuery apiQuery = ApiQuery();
  final UserRepo userRepo = UserRepo();

  int? _resolveEmployeeId(LoginResponseModel loginResponse) {
    final data = loginResponse.result?.data;
    if (data == null) return null;

    final profileId = data.emp_profile_id?.trim();
    if (profileId != null && profileId.isNotEmpty) {
      final parsed = int.tryParse(profileId);
      if (parsed != null) return parsed;
    }

    final employeeId = data.emp_id?.trim();
    if (employeeId != null && employeeId.isNotEmpty) {
      return int.tryParse(employeeId);
    }

    return null;
  }

  Future<LoginResponseModel?> _getLoginResponseWhenReady() async {
    LoginResponseModel? lastResponse;

    for (int attempt = 0; attempt < 5; attempt++) {
      lastResponse = await userRepo.getLoginResponse();
      final hasSession = lastResponse?.result?.data != null &&
          (lastResponse?.result?.token?.isNotEmpty ?? false) &&
          lastResponse != null &&
          _resolveEmployeeId(lastResponse) != null;

      if (hasSession) return lastResponse;

      if (attempt < 4) {
        await Future.delayed(Duration(milliseconds: 250 * (attempt + 1)));
      }
    }

    return lastResponse;
  }

  Future<Uint8List?> getQrCodeImage() async {
    try {
      final loginResponse = await _getLoginResponseWhenReady();

      if (loginResponse?.result?.data == null) {
        log('❌ No login data found');
        return null;
      }

      final empId = _resolveEmployeeId(loginResponse!);

      if (empId == null) {
        log('❌ No employee ID found in login response (tried emp_profile_id and emp_id)');
        return null;
      }

      log('🔍 Fetching QR code for employee ID: $empId');

      final token = loginResponse.result?.token;
      if (token == null || token.isEmpty) {
        log('❌ No authentication token found');
        return null;
      }

      Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await apiQuery.getQuery(
        '${UrlUtil.qrCodeApi}$empId',
        headers,
        null,
        'qr_code',
        false,
        true,
        false,
      );

      if (response?.statusCode == 200) {
        if (response?.data is List<int>) {
          return Uint8List.fromList(response!.data);
        } else if (response?.data is String) {
          return base64Decode(response!.data);
        } else {
          log('❌ Unexpected response format for QR code');
          return null;
        }
      } else {
        log('❌ Failed to fetch QR code: ${response?.statusCode}');
        return null;
      }
    } catch (e) {
      log('❌ Error fetching QR code: $e');
      return null;
    }
  }

  Future<Uint8List?> getQrCodeImageDirect() async {
    for (int attempt = 0; attempt < 3; attempt++) {
      final qrCode = await _getQrCodeImageDirectOnce();
      if (qrCode != null && qrCode.isNotEmpty) return qrCode;

      if (attempt < 2) {
        print('🔄 QR Code load retry ${attempt + 1}/2 scheduled...');
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }

    return null;
  }

  Future<Uint8List?> _getQrCodeImageDirectOnce() async {
    try {
      print('\n🚀 ========== QR CODE LOADING START ==========');

      // Get current user's login data
      final loginResponse = await _getLoginResponseWhenReady();
      print('📦 Login Response: ${loginResponse != null ? "Found" : "NULL"}');

      if (loginResponse?.result?.data == null) {
        print('❌ ERROR: No login data found');
        print('🔚 ========== QR CODE LOADING FAILED ==========\n');
        return null;
      }

      // Debug: Print all employee IDs
      print('👤 emp_id: ${loginResponse!.result!.data!.emp_id}');
      print('👤 emp_profile_id: ${loginResponse.result!.data!.emp_profile_id}');

      final empId = _resolveEmployeeId(loginResponse);
      print('✅ Resolved employee ID for QR: $empId');

      if (empId == null) {
        print(
            '❌ ERROR: No employee ID found (emp_profile_id and emp_id both invalid)');
        print('🔚 ========== QR CODE LOADING FAILED ==========\n');
        return null;
      }

      // Get authentication token
      final token = loginResponse.result?.token;
        final tokenPreview = token != null && token.isNotEmpty
          ? '${token.substring(0, token.length < 20 ? token.length : 20)}...'
          : 'NULL/EMPTY';
      print(
          '🔑 Token: $tokenPreview');

      if (token == null || token.isEmpty) {
        print('❌ ERROR: No authentication token found');
        print('🔚 ========== QR CODE LOADING FAILED ==========\n');
        return null;
      }

      // Build API URL
      final apiUrl = '${UrlUtil.baseUrl}${UrlUtil.qrCodeApi}$empId';
      print('🌐 API URL: $apiUrl');

      // Create Dio instance for direct image download
      final dio = Dio();

      // Prepare headers with authentication
      Map<String, String> headers = {
        'Authorization': 'Bearer $token',
      };
      print('📋 Headers: Authorization Bearer ***');

      print('⏳ Making API request...');

      // Make direct GET request to QR code endpoint
      final response = await dio.get(
        apiUrl,
        options: Options(
          headers: headers,
          responseType: ResponseType.bytes, // Important for binary data
        ),
      );

      print('📥 Response Status Code: ${response.statusCode}');
      print('📦 Response Data Type: ${response.data.runtimeType}');
      print('📊 Response Data Length: ${response.data?.length ?? 0} bytes');

      if (response.statusCode == 200) {
        if (response.data != null && response.data.length > 0) {
          print('✅ QR Code loaded successfully!');
          print('🔚 ========== QR CODE LOADING SUCCESS ==========\n');
          final data = response.data;
          if (data is Uint8List) return data;
          if (data is List<int>) return Uint8List.fromList(data);

          print('❌ ERROR: Unexpected QR data type: ${data.runtimeType}');
          print('🔚 ========== QR CODE LOADING FAILED ==========\n');
          return null;
        } else {
          print('❌ ERROR: Response data is empty');
          print('🔚 ========== QR CODE LOADING FAILED ==========\n');
          return null;
        }
      } else {
        print('❌ ERROR: HTTP ${response.statusCode}');
        print('📄 Response Message: ${response.statusMessage}');
        print('🔚 ========== QR CODE LOADING FAILED ==========\n');
        return null;
      }
    } catch (e, stackTrace) {
      print('❌ EXCEPTION: $e');
      print(
          '📍 Stack Trace: ${stackTrace.toString().split('\n').take(5).join('\n')}');
      print('🔚 ========== QR CODE LOADING FAILED ==========\n');
      return null;
    }
  }
}
