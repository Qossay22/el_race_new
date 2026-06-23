import 'dart:developer';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:el_race/ui/presentation/signin/data/repository.dart';
import 'package:el_race/utils/api_query.dart';
import 'package:intl/intl.dart';

import '../../../../utils/urll_utils.dart';

UserRepo _userRepo = UserRepo();

ApiQuery _apiQuery = ApiQuery();

class CheckInREpo {
  Future<Response?> checkInUser(String lat, String long) async {
    final loginResponse = await _userRepo.getLoginResponse();

    var token = loginResponse!.result!.token!;

    var userResponse = await _userRepo.getLoginResponse();
    var deviceInfo = await _userRepo.getDeviceInfo();
    try {
      final userData = userResponse!.result!.data;
      final resolvedUserId = userData?.uid ??
          userData?.odoo_user_id ??
          userData?.employee_id ??
          int.tryParse(userData?.emp_id ?? '') ??
          int.tryParse(userData?.emp_profile_id ?? '') ??
          0;

      Map<String, String> header = {
        "Content-Type": "application/json",
        'Accept': 'application/json',
        "Authorization": "Bearer $token"
      };

      // Compute fresh timestamp at call time (NOT at import time)
      final String formattedDate =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final parsedDeviceId = int.tryParse(deviceInfo ?? '');
      final parsedLat = double.tryParse(lat);
      final parsedLong = double.tryParse(long);
      final normalizedLat =
          parsedLat != null ? double.parse(parsedLat.toStringAsFixed(2)) : null;
      final normalizedLong = parsedLong != null
          ? double.parse(parsedLong.toStringAsFixed(2))
          : null;

      Map<String, dynamic> data = {
        "jsonrpc": "2.0",
        "params": {
          "user_id": resolvedUserId,
          "device_id": parsedDeviceId ?? deviceInfo,
          "checkin_date_time": formattedDate,
          "check_in_long": normalizedLong ?? long,
          "check_in_lat": normalizedLat ?? lat,
        }
      };

      final checkInUrl = UrlUtil.baseUrl + UrlUtil.checkInApi;
      final prettyPayload = const JsonEncoder.withIndent('  ').convert(data);

      print('📤 [CHECK-IN API] URL: $checkInUrl');
      print('📤 [CHECK-IN API] Headers: $header');
        print('🆔 [CHECK-IN API] Resolved user_id: $resolvedUserId '
          '(uid=${userData?.uid}, odoo_user_id=${userData?.odoo_user_id}, '
          'employee_id=${userData?.employee_id}, emp_id=${userData?.emp_id}, '
          'emp_profile_id=${userData?.emp_profile_id})');
      print('📤 [CHECK-IN API] Payload:\n$prettyPayload');

      Response? response = await _apiQuery.postQuery(
          UrlUtil.checkInApi, header, data, 'checkin', true);
      return response!;
    } catch (e) {
      log('checkInUser $e');
    }
    return null;
  }
}
