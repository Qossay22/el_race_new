import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/core/services/attendance_status_sync_service.dart';
import 'package:el_race/data/services/checkin_reminder_notification_service.dart';
import 'package:el_race/ui/presentation/Attendace_list/repository/attendance_repository.dart';
import 'package:el_race/ui/presentation/landing_screen/repository/check_out_repo.dart';
import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';

import '../../repository/location_reop.dart';

part 'check_out_event.dart';
part 'check_out_state.dart';

LocationRepo _locationRepo = LocationRepo();
CheckOutRepo _checkOutRepo = CheckOutRepo();

class CheckOutBloc extends Bloc<CheckOutEvent, CheckOutState> {
  CheckOutBloc() : super(CheckOutInitial()) {
    on<CheckOutET>(checkOutMethod);
  }

  int _parseRecordId(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  int _resolveRecordIdFromTodayStatus(Map<String, dynamic> todayStatus) {
    final direct = _parseRecordId(todayStatus['check_in_record_id']);
    if (direct > 0) return direct;

    final attendanceId = _parseRecordId(todayStatus['attendance_id']);
    if (attendanceId > 0) return attendanceId;

    final nestedData = todayStatus['data'];
    if (nestedData is Map) {
      final nested = Map<String, dynamic>.from(nestedData);
      final nestedDirect = _parseRecordId(nested['check_in_record_id']);
      if (nestedDirect > 0) return nestedDirect;
      final nestedAttendance = _parseRecordId(nested['attendance_id']);
      if (nestedAttendance > 0) return nestedAttendance;
    }

    return 0;
  }

  Map<String, dynamic>? _getResult(dynamic data) {
    if (data is Map && data['result'] is Map) {
      return Map<String, dynamic>.from(data['result'] as Map);
    }
    return null;
  }

  String _getMessage(Map<String, dynamic>? result, String fallback) {
    return result?['message']?.toString().trim().isNotEmpty == true
        ? result!['message'].toString()
        : fallback;
  }

  Future<void> checkOutMethod(
      CheckOutET event, Emitter<CheckOutState> emit) async {
    try {
      int recordId = event.checkInRecordId;

      print('\n🔴 ===== CHECK-OUT BLOC: API CALL =====');
      print('🔴 checkInRecordId from event = $recordId');
      print('🔴 isAutoCheckout = ${event.isAutoCheckout}');

      // If checkInRecordId is 0, try to fetch it from today_status API
      if (recordId == 0) {
        print('🔴 checkInRecordId is 0! Trying to fetch from today_status...');
        try {
          final todayStatus = await AttendanceRepo().getTodayStatus();
          final serverRecordId = _resolveRecordIdFromTodayStatus(todayStatus);
          print(
              '🔴 today_status returned check_in_record_id = $serverRecordId');
          if (serverRecordId > 0) {
            recordId = serverRecordId;
            await SharedPref().setPreferenceInt('checkInRecordId', recordId);
            print('🔴 ✅ Recovered checkInRecordId = $recordId from server');
          }
        } catch (e) {
          print('🔴 ⚠️ Failed to fetch today_status: $e');
        }
      }

      if (recordId == 0) {
        print(
            '🔴 ❌ checkInRecordId is still 0 after fallback! Checkout will likely fail.');
      }

      // Emit loading state
      emit(const CheckOutLoadingST(isLoading: true));

      // Simulate fetching the current location
      Position location = await _locationRepo.getCurrentLocation();

      // Call the API with location data and check_in_record_id
      Response? response = await _checkOutRepo.checkOutUser(
        location.latitude.toString(),
        location.longitude.toString(),
        recordId, // Pass the check_in_record_id (possibly recovered from server)
      );

      // Handle response and emit corresponding states
      if (response != null && response.data != null) {
        final responseData = _getResult(response.data);
        if (responseData == null) {
          emit(const CheckOutErrorST('Invalid response from server.'));
        } else if (responseData['status'] == 'success') {
          // Save check-out time in UAE timezone (GMT+4) for display
          final uaeTime = DateTime.now().toUtc().add(const Duration(hours: 4));
          final displayTime =
              '${uaeTime.hour.toString().padLeft(2, '0')}:${uaeTime.minute.toString().padLeft(2, '0')}:${uaeTime.second.toString().padLeft(2, '0')}';

          print('\n🔴 ===== CHECK-OUT BLOC =====');
          print('🔴 checkOutDisplayTime = $displayTime');
          print('🔴 isCheckedIn = false');
          print('🔴 checkInRecordId = 0');

          await SharedPref()
              .setPreferencesString('checkOutDisplayTime', displayTime);

          // Mark as checked out in SharedPref so pull-to-refresh won't revert
          await SharedPref().setPreferencesBoolean('isCheckedIn', false);
          await SharedPref().setPreferenceInt('checkInRecordId', 0);

          // Log final SharedPref state after checkout
          final savedCheckIn =
              SharedPref().getPreferenceString('checkInDisplayTime');
          final savedCheckOut =
              SharedPref().getPreferenceString('checkOutDisplayTime');
          final savedIsCheckedIn =
              SharedPref().getPreferenceBoolean('isCheckedIn');
          final savedCheckInTime = SharedPref().getPreferenceInt('checkInTime');
          print('🔴 --- SharedPref state after checkout ---');
          print('🔴 isCheckedIn = $savedIsCheckedIn');
          print('🔴 checkInDisplayTime = $savedCheckIn');
          print('🔴 checkOutDisplayTime = $savedCheckOut');
          print('🔴 checkInTime (ms) = $savedCheckInTime');
          print('🔴 ===== END CHECK-OUT BLOC =====\n');

          // Record local check-out so smart sync won't revert it
          AttendanceStatusSyncService.markLocalCheckOut();

          try {
            await CheckInReminderNotificationService().updateReminders();
          } catch (_) {}

          // Emit success state with the message
          emit(
              CheckedOutST(_getMessage(responseData, 'Check-out successful.')));
        } else if (responseData['status'] == 'warning') {
          // Save check-out time even on warning
          final uaeTime = DateTime.now().toUtc().add(const Duration(hours: 4));
          final displayTime =
              '${uaeTime.hour.toString().padLeft(2, '0')}:${uaeTime.minute.toString().padLeft(2, '0')}:${uaeTime.second.toString().padLeft(2, '0')}';

          print('\n🟡 ===== CHECK-OUT BLOC (WARNING) =====');
          print('🟡 checkOutDisplayTime = $displayTime');
          print('🟡 isCheckedIn = false');
          print('🟡 ===========================================\n');

          await SharedPref()
              .setPreferencesString('checkOutDisplayTime', displayTime);

          // Mark as checked out in SharedPref so pull-to-refresh won't revert
          await SharedPref().setPreferencesBoolean('isCheckedIn', false);
          await SharedPref().setPreferenceInt('checkInRecordId', 0);

          // Log final SharedPref state
          final savedCheckIn2 =
              SharedPref().getPreferenceString('checkInDisplayTime');
          final savedCheckOut2 =
              SharedPref().getPreferenceString('checkOutDisplayTime');
          final savedIsCheckedIn2 =
              SharedPref().getPreferenceBoolean('isCheckedIn');
          final savedCheckInTime2 =
              SharedPref().getPreferenceInt('checkInTime');
          print('🟡 --- SharedPref state after checkout (warning) ---');
          print('🟡 isCheckedIn = $savedIsCheckedIn2');
          print('🟡 checkInDisplayTime = $savedCheckIn2');
          print('🟡 checkOutDisplayTime = $savedCheckOut2');
          print('🟡 checkInTime (ms) = $savedCheckInTime2');
          print('🟡 ==================================================\n');

          // Record local check-out so smart sync won't revert it
          AttendanceStatusSyncService.markLocalCheckOut();

          try {
            await CheckInReminderNotificationService().updateReminders();
          } catch (_) {}

          // Emit warning state with the warning message
          emit(CheckOutWarningST(
              _getMessage(responseData, 'Check-out warning.')));
        } else {
          // Emit error state with the error message
          print('\n🔴 ===== CHECK-OUT BLOC: FAILED =====');
          print('🔴 Error: ${responseData['message']}');
          print('🔴 Full response: $responseData');
          print('🔴 ===================================\n');
          emit(CheckOutErrorST(_getMessage(responseData, 'Checkout failed.')));
        }
      } else {
        print('\n🔴 ===== CHECK-OUT BLOC: NO RESPONSE =====');
        print('🔴 response = $response');
        print('🔴 response.data = ${response?.data}');
        print('🔴 ===========================================\n');
        emit(const CheckOutErrorST('No response data from server.'));
      }
    } catch (e) {
      print('\n🔴 ===== CHECK-OUT BLOC: EXCEPTION =====');
      print('🔴 Error: $e');
      print('🔴 ========================================\n');
      emit(CheckOutErrorST('Error during checkout: $e'));
    } finally {
      // Emit loading complete
      emit(const CheckOutLoadingST(isLoading: false));
    }
  }
}
