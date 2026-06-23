import 'dart:convert';

import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPref {
  static final SharedPref preferences = SharedPref._internal();

  static late SharedPreferences sharedPreferences;

  factory SharedPref() {
    return preferences;
  }

  SharedPref._internal();

  ///Below method is to initialize the SharedPreference instance.
  Future instantiatePreferences() async {
    sharedPreferences = await SharedPreferences.getInstance();
  }

  ///Below method is to return the SharedPreference instance.
  SharedPreferences getPreferenceInstance() {
    return sharedPreferences;
  }

  ///Below method is to set the string value in the SharedPreferences.
  Future<bool> setPreferencesString(String key, String stringValue) async {
    return await sharedPreferences.setString(key, stringValue);
  }

  ///Below method is to get the string value from the SharedPreferences.
  String getPreferenceString(String key) {
    return sharedPreferences.getString(key) ?? "";
  }

  ///Below method is to set the boolean value in the SharedPreferences.
  Future<bool> setPreferencesBoolean(String key, bool booleanValue) async {
    return await sharedPreferences.setBool(key, booleanValue);
  }

  ///Below method is to get the boolean value from the SharedPreferences.
  bool getPreferenceBoolean(String key) {
    return sharedPreferences.getBool(key) ?? false;
  }

  ///Below method is to set the double value in the SharedPreferences.
  Future<bool> setPreferenceDouble(String key, double doubleValue) async {
    return await sharedPreferences.setDouble(key, doubleValue);
  }

  ///Below method is to set the double value from the SharedPreferences.
  double getPreferenceDouble(String key) {
    return sharedPreferences.getDouble(key) ?? 0.0;
  }

  ///Below method is to set the int value in the SharedPreferences.
  Future<bool> setPreferenceInt(String key, int intValue) async {
    return await sharedPreferences.setInt(key, intValue);
  }

  ///Below method is to get the int value from the SharedPreferences.
  int getPreferenceInt(String key) {
    return sharedPreferences.getInt(key) ?? 0;
  }

  ///Below method is to remove the received preference.
  Future<bool> removePreference(String key) async {
    return await sharedPreferences.remove(key);
  }

  ///Below method is to check the availability of the received preference .
  bool containPreference(String key) {
    if (sharedPreferences.get(key) == null) {
      return false;
    } else {
      return true;
    }
  }

  ///Below method is to clear the SharedPreference.
  clearPreferences() async {
    await sharedPreferences.clear();
  }

  /// Set the app language code in SharedPreferences.
  Future<void> setAppLanguage(String languageCode) async {
    await sharedPreferences.setString('app_language', languageCode);
  }

  /// Get the app language code from SharedPreferences.
  String getAppLanguage() {
    return sharedPreferences.getString('app_language') ?? '';
  }

  bool isArabic() {
    return getAppLanguage() == 'ar';
  }

  ////[helper_functions]
  static bool isUserAuthenticated() {
    final data = checkLoginAndRegistration();
    final isRegistered = data['isRegistered'] as bool;
    final loginData = data['loginResponse'] as LoginResponseModel?;

    return isRegistered && loginData != null;
  }

  static LoginResponseModel getLoginData() {
    final data = checkLoginAndRegistration();
    final loginData = data['loginResponse'] as LoginResponseModel?;

    // Debug: Print all user data fields (silenced to reduce noise)
    // if (loginData?.result?.data != null) {
    //   print('\n🔐 ===== LOGIN DATA DEBUG =====');
    //   print('uid: ${loginData!.result!.data!.uid}');
    //   print('emp_id: ${loginData.result!.data!.emp_id}');
    //   print('emp_profile_id: ${loginData.result!.data!.emp_profile_id}');
    //   print('username: ${loginData.result!.data!.username}');
    //   print('name: ${loginData.result!.data!.name}');
    //   print('emp_name: ${loginData.result!.data!.emp_name}');
    //   print('===============================\n');
    // }

    // Return empty model if not authenticated (for guest mode)
    return loginData ?? LoginResponseModel();
  }

  static String getCachedLeaveBalance({String fallback = '0'}) {
    final modeled = getLoginData().result?.data?.leaveBalance?.toString().trim();
    if (modeled != null &&
        modeled.isNotEmpty &&
        modeled.toLowerCase() != 'null' &&
        modeled.toLowerCase() != 'false') {
      return modeled;
    }

    final loginJson = sharedPreferences.getString('loginResponse') ??
        sharedPreferences.getString('LOGIN_RESPONSE');
    if (loginJson == null || loginJson.isEmpty) {
      return fallback;
    }

    try {
      final decoded = jsonDecode(loginJson) as Map<String, dynamic>;
      final data = decoded['result']?['data'];
      if (data is! Map<String, dynamic>) return fallback;

      final raw = data['leave_balance'] ?? data['leaveBalance'];
      final value = raw?.toString().trim();
      if (value == null ||
          value.isEmpty ||
          value.toLowerCase() == 'null' ||
          value.toLowerCase() == 'false') {
        return fallback;
      }
      return value;
    } catch (_) {
      return fallback;
    }
  }

  static LoginResponseModel? getLoginDataOrNull() {
    final data = checkLoginAndRegistration();
    return data['loginResponse'] as LoginResponseModel?;
  }

  static Map<String, dynamic> checkLoginAndRegistration() {
    final isRegistered = sharedPreferences.getBool('isRegistered') ?? false;

    // Try 'loginResponse' key first (new/correct key)
    String? loginJson = sharedPreferences.getString('loginResponse');

    // Fallback to 'LOGIN_RESPONSE' key if not found (old key for migration)
    if (loginJson == null || loginJson.isEmpty) {
      loginJson = sharedPreferences.getString('LOGIN_RESPONSE');
      // If found in old key, migrate it to new key
      if (loginJson != null && loginJson.isNotEmpty) {
        sharedPreferences.setString('loginResponse', loginJson);
      }
    }

    LoginResponseModel? loginResponse;
    if (loginJson != null) {
      loginResponse = LoginResponseModel.fromJson(jsonDecode(loginJson));
    }

    return {
      'isRegistered': isRegistered,
      'loginResponse': loginResponse,
    };
  }

  static int getSelectedCompany() {
    final id = sharedPreferences.getInt("selectedCompany") ?? 1;
    print('🏢 SharedPref.getSelectedCompany() → $id');
    return id;
  }

  static Future<void> saveSelectedCompany(int id) async {
    print('🏢 SharedPref.saveSelectedCompany($id)');
    await sharedPreferences.setInt("selectedCompany", id);
  }

  getUserBase64Image() {
    final userJson = sharedPreferences.getString('loginResponse');
    if (userJson != null) {
      final parsed = json.decode(userJson);
      final imageBase64 = parsed['result']?['data']?['image_url'] ?? '';
      return imageBase64;
    }
    return '';
  }
}
