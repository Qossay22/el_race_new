import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:el_race/core/utils/shared_pref.dart';

/// Data class holding the latest attendance status from the server.
class AttendanceStatus {
  final bool checkedIn;
  final bool checkedOut;
  final String checkInTime; // HH:mm:ss or empty
  final String checkOutTime; // HH:mm:ss or empty
  final bool isToday;

  const AttendanceStatus({
    required this.checkedIn,
    required this.checkedOut,
    required this.checkInTime,
    required this.checkOutTime,
    required this.isToday,
  });
}

/// Service that fetches `/api/attendance/today_status` and broadcasts the
/// result so the attendance widget (CustomSwipeButton) can refresh in
/// real-time when a push notification is received.
class AttendanceSyncService {
  AttendanceSyncService._();

  static final _controller = StreamController<AttendanceStatus>.broadcast();

  /// Stream that the attendance widget subscribes to.
  static Stream<AttendanceStatus> get stream => _controller.stream;

  /// Call the API and push the result into [stream].
  /// Returns `true` when the API call succeeds.
  static Future<bool> fetchAndBroadcast() async {
    try {
      final loginData = SharedPref.getLoginData();
      final token = loginData.result?.token;
      if (token == null || token.isEmpty) {
        debugPrint('🔄 AttendanceSyncService: No token, skipping refresh');
        return false;
      }

      final url =
          Uri.parse('https://erp.elrace.com/api/attendance/today_status');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'params': {},
        }),
      );

      debugPrint(
          '🔄 AttendanceSyncService: status=${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['result'];
        if (result == null) {
          debugPrint('🔄 AttendanceSyncService: result is null');
          return false;
        }

        final checkedIn = result['checked_in'] == true;
        final checkedOut = result['checked_out'] == true;
        final checkInTime = result['check_in_time']?.toString() ?? '';
        final checkOutTime = result['check_out_time']?.toString() ?? '';
        final isToday = result['is_today'] == true;

        debugPrint('🔄 AttendanceSyncService: '
            'checkedIn=$checkedIn, checkedOut=$checkedOut, '
            'checkInTime=$checkInTime, checkOutTime=$checkOutTime, '
            'isToday=$isToday');

        // ---- Persist to SharedPref so the widget picks up changes ----
        if (isToday) {
          // Update checked-in state
          await SharedPref()
              .setPreferencesBoolean('isCheckedIn', checkedIn && !checkedOut);

          // Update display times
          if (checkInTime.isNotEmpty) {
            await SharedPref()
                .setPreferencesString('checkInDisplayTime', checkInTime);
          }

          if (checkedOut && checkOutTime.isNotEmpty) {
            await SharedPref()
                .setPreferencesString('checkOutDisplayTime', checkOutTime);
          } else if (!checkedOut) {
            await SharedPref()
                .setPreferencesString('checkOutDisplayTime', '00:00:00');
          }

          // Store check-in timestamp for reset logic (use current time as
          // fallback if no precise epoch is available from the API).
          if (checkedIn) {
            final existing =
                SharedPref().getPreferenceInt('checkInTime');
            if (existing == 0) {
              await SharedPref().setPreferenceInt(
                  'checkInTime', DateTime.now().millisecondsSinceEpoch);
            }
          }
        }

        final status = AttendanceStatus(
          checkedIn: checkedIn,
          checkedOut: checkedOut,
          checkInTime: checkInTime,
          checkOutTime: checkOutTime,
          isToday: isToday,
        );

        _controller.add(status);
        return true;
      }
    } catch (e) {
      debugPrint('🔄 AttendanceSyncService error: $e');
    }
    return false;
  }

  /// Dispose the stream controller (call on app shutdown if needed).
  static void dispose() {
    _controller.close();
  }
}
