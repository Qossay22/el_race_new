import 'dart:async';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:get/get.dart';

/// Global Timer Controller for Check-in/Check-out System
///
/// Time Tracking Rules:
/// • Total working hours (8 hours) are the same across all projects
/// • Check-in/check-out is global and unified (not project-specific)
/// • Detailed time management is handled through job missions requests
/// • Timer continues running even when app is closed
///
/// NOTE: The 8 working hours are global and shared across all projects.
///       Switching projects does NOT reset or create a new timer.
class TimerController extends GetxController {
  /// Global working hours duration - applies to all projects
  /// NOTE: The 8 working hours are global and shared across all projects.
  ///       Switching projects does NOT reset or create a new timer.
  final Rx<Duration> timeLeft = const Duration(hours: 8).obs;
  final Rx<bool> isTimerRunning = false.obs;

  Timer? _timer;
  DateTime? _checkInTime;

  /// Default working hours for all users and projects
  /// NOTE: The 8 working hours are global and shared across all projects.
  ///       Switching projects does NOT reset or create a new timer.
  Duration _initialRemaining = const Duration(hours: 8);

  @override
  void onInit() {
    super.onInit();
    _loadState();
  }

  Future<void> _loadState() async {
    final isCheckedIn = SharedPref().getPreferenceBoolean('isCheckedIn');
    final checkInMillis = SharedPref().getPreferenceInt('checkInTime');
    final savedTimeLeftMillis = SharedPref().getPreferenceInt('timeLeft');

    // print('🔄 Loading global timer state...');
    // print('   isCheckedIn: $isCheckedIn');
    // print('   checkInMillis: $checkInMillis');
    // print('   savedTimeLeftMillis: $savedTimeLeftMillis');

    // Timer is global - not tied to any specific project
    // If user is checked in, calculate remaining time from check-in time
    if (isCheckedIn && checkInMillis > 0) {
      _checkInTime = DateTime.fromMillisecondsSinceEpoch(checkInMillis);

      // Calculate how much time has elapsed since check-in
      final elapsed = DateTime.now().difference(_checkInTime!);
      // print('   ⏱️ Time elapsed since check-in: ${elapsed.inMinutes} minutes');

      // Start with 8 hours and subtract elapsed time
      _initialRemaining = const Duration(hours: 8) - elapsed;

      // If time has run out, set to zero
      if (_initialRemaining.inSeconds <= 0) {
        // print('   ⚠️ Timer has expired!');
        _initialRemaining = Duration.zero;
        timeLeft.value = Duration.zero;
        isTimerRunning.value = false;
      } else {
        print(
            '   ✅ Continuing timer with ${_initialRemaining.inMinutes} minutes left');
        timeLeft.value = _initialRemaining;
        isTimerRunning.value = true;
        _startCountdown();
      }
    } else {
      // User is not checked in, restore saved time or default to 8 hours
      if (savedTimeLeftMillis > 0) {
        _initialRemaining = Duration(milliseconds: savedTimeLeftMillis);
        print(
            '   📝 Restored saved time: ${_initialRemaining.inMinutes} minutes');
      } else {
        _initialRemaining = const Duration(hours: 8);
        // print('   🆕 Starting with default 8 hours');
      }
      timeLeft.value = _initialRemaining;
      isTimerRunning.value = false;
    }
  }

  Future<void> startTimer() async {
    // print('▶️ Starting global timer (applies to all projects)...');

    _checkInTime = DateTime.now();
    // Fixed 8-hour duration for all projects
    // NOTE: The 8 working hours are global and shared across all projects.
    //       Switching projects does NOT reset or create a new timer.
    _initialRemaining = const Duration(hours: 8);

    await SharedPref()
        .setPreferenceInt('checkInTime', _checkInTime!.millisecondsSinceEpoch);
    await SharedPref().setPreferencesBoolean('isCheckedIn', true);

    isTimerRunning.value = true;
    // print('   ✅ Global check-in time saved: ${_checkInTime}');

    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();

    if (_checkInTime == null) {
      // print('⚠️ Cannot start countdown: checkInTime is null');
      return;
    }

    final startTime = _checkInTime!;
    final initial = _initialRemaining;

    // print('🔄 Starting global countdown from ${initial.inMinutes} minutes');
    // print('   (Same duration applies to all projects)');

    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      // Always recalculate from the original check-in time
      // This ensures accuracy even if the app was in background
      // Timer is project-independent - tracks total working time
      final elapsed = DateTime.now().difference(startTime);
      final remaining = const Duration(hours: 8) - elapsed;

      if (remaining.inSeconds <= 0) {
        // print('⏰ Timer completed!');
        timeLeft.value = Duration.zero;
        isTimerRunning.value = false;
        _timer?.cancel();
        _timer = null;
      } else {
        timeLeft.value = remaining;
        // Save current state every minute for recovery
        if (remaining.inSeconds % 60 == 0) {
          await SharedPref()
              .setPreferenceInt('timeLeft', remaining.inMilliseconds);
        }
      }
    });
  }

  Future<void> stopTimer() async {
    // print('⏹️ Stopping timer...');

    _timer?.cancel();
    _timer = null;
    isTimerRunning.value = false;

    if (_checkInTime == null) {
      // print('   ⚠️ No check-in time found, clearing all data');
      SharedPref().removePreference('checkInTime');
      SharedPref().removePreference('isCheckedIn');
      SharedPref().removePreference('timeLeft');
      return;
    }

    // Calculate final remaining time based on elapsed time
    final elapsed = DateTime.now().difference(_checkInTime!);
    final updatedRemaining = const Duration(hours: 8) - elapsed;

    // print('   📊 Total time worked: ${elapsed.inMinutes} minutes');
    // print('   💾 Saving remaining time: ${updatedRemaining.inMinutes} minutes');

    await SharedPref().setPreferencesBoolean('isCheckedIn', false);
    await SharedPref().removePreference('checkInTime');

    // Save the remaining time for next session
    if (updatedRemaining.inSeconds > 0) {
      await SharedPref()
          .setPreferenceInt('timeLeft', updatedRemaining.inMilliseconds);
      _initialRemaining = updatedRemaining;
      timeLeft.value = updatedRemaining;
    } else {
      await SharedPref().setPreferenceInt('timeLeft', 0);
      _initialRemaining = Duration.zero;
      timeLeft.value = Duration.zero;
    }

    _checkInTime = null;
    // print('   ✅ Timer stopped successfully');
  }

  /// Reload timer state from SharedPreferences.
  ///
  /// Call this after an external check-in/check-out sync so the timer
  /// reflects the server's authoritative check-in time.
  Future<void> reloadState() => _loadState();

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
