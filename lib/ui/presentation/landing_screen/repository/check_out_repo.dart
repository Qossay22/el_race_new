import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:el_race/ui/presentation/signin/data/repository.dart';
import 'package:el_race/utils/api_query.dart';
import 'package:intl/intl.dart';

import '../../../../utils/urll_utils.dart';

UserRepo _userRepo = UserRepo();

ApiQuery _apiQuery = ApiQuery();

/// Check-Out Repository
///
/// Time Tracking Rules:
/// • Check-out is global and unified across all projects
/// • Uses check_in_record_id to match with corresponding check-in
/// • Does not send project-specific information in the API call
/// • Total working time is calculated server-side based on check-in/out times
/// • Project-specific time allocation handled through job missions
///
/// NOTE: The 8 working hours are global and shared across all projects.
///       Switching projects does NOT reset or create a new timer.
class CheckOutRepo {
  Future<Response?> checkOutUser(
      String lat, String long, int checkInRecordId) async {
    final loginResponse = await _userRepo.getLoginResponse();

    var token = loginResponse!.result!.token!;

    var userResponse = await _userRepo.getLoginResponse();
    var deviceInfo = await _userRepo.getDeviceInfo();
    try {
      var userID = userResponse!.result!.data!.uid.toString();
      Map<String, String> header = {
        "Content-Type": "application/json",
        'Accept': 'application/json',
        "Authorization": "Bearer $token"
      };

      // Compute fresh timestamp at call time (NOT at import time)
      final String formattedDate =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final parsedDeviceId = int.tryParse(deviceInfo ?? '');

      Map<String, dynamic> data = {
        "jsonrpc": "2.0",
        "params": {
          "user_id": int.tryParse(userID.toString()) ?? 0,
          "device_id": parsedDeviceId ?? deviceInfo,
          "checkout_date_time": formattedDate,
          "check_out_long": double.tryParse(long) ?? long,
          "check_out_lat": double.tryParse(lat) ?? lat,
          "check_in_record_id": checkInRecordId,
        }
      };

      log(data.toString());

      Response? response = await _apiQuery.postQuery(
          UrlUtil.checkOutApi, header, data, 'checkout', true);
      log(UrlUtil.checkOutApi);
      log(data.toString());
      log(response.toString());

      return response!;
    } catch (e) {
      log('checkOutUser $e');
    }
    return null;
  }
}
