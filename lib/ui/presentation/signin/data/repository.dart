import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:el_race/utils/api_query.dart';
import 'package:el_race/utils/string_utils.dart';
import 'package:el_race/utils/urll_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserRepo {
  ApiQuery apiQuery = ApiQuery();

  Future<Response> loginApiCall(
      String email, String password, String deviceId) async {
    print('\n🔐 ========== LOGIN API START ==========');
    print('📧 Email: $email');
    print('🔒 Password: ${password.replaceAll(RegExp(r'.'), '*')}');
    print('📱 Device ID: $deviceId');

    // Get FCM token from SharedPreferences
    String? fcmToken = SharedPref().getPreferenceString(fcm_token);

    // If FCM token is null or empty, log a warning
    if (fcmToken.isEmpty) {
      print('⚠️ Warning: FCM token is empty during login');
    } else {
      print('✅ FCM token available: ${fcmToken.substring(0, 20)}...');
    }

    Map<String, dynamic> body = {
      "jsonrpc": "2.0",
      "params": {
        "db": "odoo.elrace.com",
        "login": email,
        "password": password,
        "device_id": deviceId,
        "fcm_token": fcmToken,
      }
    };

    print('\n📤 Login Request Body:');
    print(const JsonEncoder.withIndent('  ').convert(body));

    var headers = {
      'Content-Type': 'application/json',
    };

    print('\n⏳ Sending login request to: ${UrlUtil.login}');

    Response? response =
        await apiQuery.postQuery(UrlUtil.login, headers, body, 'login', true);

    print('\n📥 Login Response Status: ${response?.statusCode}');
    print('📦 Response Data Type: ${response?.data.runtimeType}');

    if (response?.data != null) {
      print('📄 Full Login Response:');
      print(const JsonEncoder.withIndent('  ').convert(response!.data));

      // Parse and display important data
      try {
        final data = response.data;
        if (data['result'] != null) {
          final result = data['result'];
          print('\n✅ Login Successful!');
          print('🔑 Token: ${result['token']?.toString().substring(0, 30)}...');

          if (result['data'] != null) {
            final userData = result['data'];
            print('\n👤 User Data:');
            print('  - Employee ID: ${userData['emp_id']}');
            print('  - Employee Profile ID: ${userData['emp_profile_id']}');
            print('  - Name: ${userData['name']}');
            print('  - Username: ${userData['username']}');
            print('  - Company ID: ${userData['company_id']}');
            print('  - QR Status: ${userData['qr_status']}');
          }
        } else if (data['error'] != null) {
          print('\n❌ Login Failed!');
          print('Error: ${data['error']}');
        }
      } catch (e) {
        print('⚠️ Could not parse login response: $e');
      }
    } else {
      print('❌ No response data received');
    }

    print('🔐 ========== LOGIN API END ==========\n');

    return response!;
  }

  setLoginResponse(LoginResponseModel? loginResponse) async {
    if (loginResponse != null) {
      // print('\n💾 ========== SAVING LOGIN RESPONSE ==========');
      SharedPreferences sharedPreferences =
          await SharedPreferences.getInstance();
      String userData = json.encode(loginResponse.toJson());
      await sharedPreferences.setString('loginResponse', userData);

      // print('✅ Login response saved to SharedPreferences');
      // print('📦 Saved Data:');
      // print(const JsonEncoder.withIndent('  ').convert(loginResponse.toJson()));
      // print('💾 ========== SAVE COMPLETE ==========\n');
    } else {
      // print('⚠️ Attempted to save NULL login response');
    }
  }

  Future<LoginResponseModel?> getLoginResponse() async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    String? userData = sharedPreferences.getString('loginResponse');

    if (userData == null) {
      // print('⚠️ No login data found in SharedPreferences');
      return null;
    }

    // print('\n📖 Retrieved login data from SharedPreferences');
    final loginData = LoginResponseModel.fromJson(jsonDecode(userData));

    // print('👤 Current User:');
    // print('  - Employee ID: ${loginData.result?.data?.emp_id}');
    // print('  - Employee Profile ID: ${loginData.result?.data?.emp_profile_id}');
    // print('  - Token: ${loginData.result?.token?.substring(0, 30)}...');
    // print('  - QR Status: ${loginData.result?.data?.qr_status}');

    return loginData;
  }

  setISLoggedIn(bool isLoggedIn) async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.setBool(isLoggedIN, isLoggedIn);
  }

  Future<bool?> getIsLoggedIn() async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getBool(isLoggedIN) ?? false;
  }

  setDeviceInfo(String deviceInfo) async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.setString(deviceInfoString, deviceInfo);
  }

  Future<String?> getDeviceInfo() async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getString(deviceInfoString) ?? '';
  }
}
