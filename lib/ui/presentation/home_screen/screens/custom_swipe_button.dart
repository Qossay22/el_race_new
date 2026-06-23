import 'dart:async';
import 'package:el_race/core/services/attendance_status_sync_service.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/data/services/auto_checkout_service.dart';
import 'package:el_race/data/services/checkin_reminder_notification_service.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/project_list_dialog.dart';
import 'package:el_race/ui/presentation/landing_screen/bloc/checkin_in_bloc/check_in_bloc.dart';
import 'package:el_race/ui/presentation/landing_screen/bloc/checkin_out_bloc/check_out_bloc.dart';
import 'package:el_race/utils/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:el_race/core/services/app_config_service.dart';
import 'package:google_fonts/google_fonts.dart' show GoogleFonts;
import 'package:el_race/core/biometric/unified_biometric_helper.dart';

import '../widgets/timer_controller.dart';

/// Shared signal so the surrounding card background can switch its color
/// (blue -> gray) once the user has swiped to the checked-in state.
final ValueNotifier<bool> swipeCheckedInNotifier = ValueNotifier<bool>(false);

class CustomSwipeButton extends StatefulWidget {
  const CustomSwipeButton({super.key});

  @override
  State<CustomSwipeButton> createState() => _CustomSwipeButtonState();
}

class _CustomSwipeButtonState extends State<CustomSwipeButton>
    with TickerProviderStateMixin {
  bool isCheckedIn = false;
  double dragOffset = 0.0;
  bool isDragging = false;
  bool _isVisualCheckedIn = false; // Visual state for transitions
  late AnimationController _arrowController;
  bool? matchResult; // null = no result, true = matched, false = not matched
  late AnimationController _checkmarkController;
  late AnimationController _bounceController;
  bool isProcessingFace = false;
  bool _isApiLoading = false;

  // Time display variables - updated via BlocListener
  String _checkInDisplayTime = '00:00:00';
  String _checkOutDisplayTime = '00:00:00';
  String _totalHoursDisplay = '00:00';

  // Timer للعداد التصاعدي
  Timer? _liveTimer;
  StreamSubscription<AttendanceStatusSnapshot>? _attendanceSyncSubscription;

  final double buttonWidth = 300.w;
  final double buttonHeight = 48.w; // Reduced from 56.w to 48.w for shorter bar
  final double knobSize =
      35.w; // Reduced from 40.w to 35.w to maintain proportion

  void _resetPosition() {
    setState(() {
      dragOffset = isCheckedIn ? (buttonWidth - knobSize) : 0;
      isDragging = false;
      startSwipe = false;
      _isVisualCheckedIn =
          isCheckedIn; // Reset visual state to match actual state
    });
  }

  @override
  void initState() {
    super.initState();
    // IMPORTANT: Load display times FIRST so _checkInDisplayTime has a value
    // before _loadCheckInState starts the live timer calculation.
    _loadDisplayTimes();
    _loadCheckInState();
    _attendanceSyncSubscription = AttendanceStatusSyncService.updates.listen(
      (snapshot) {
        if (!mounted) return;

        _loadDisplayTimes();
        _loadCheckInState();

        if (snapshot.checkedIn && !snapshot.checkedOut) {
          _startLiveTimer();
        } else {
          _stopLiveTimer();
        }
      },
    );

    // Trigger a fresh sync immediately after subscribing to the stream.
    // This guarantees the counter starts on every app open regardless of
    // whether the main.dart fire-and-forget sync already completed.
    AttendanceStatusSyncService.refreshFromServer(reason: 'widget_init');
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _checkmarkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Forward movement animation controller
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    if (!AppConfigService.instance.isTestMode) {
      if (mounted) {
        _bounceController.repeat(reverse: true);
      }
    }
  }

  /// Load display times from SharedPref
  void _loadDisplayTimes() {
    final checkIn = SharedPref().getPreferenceString('checkInDisplayTime');
    final checkOut = SharedPref().getPreferenceString('checkOutDisplayTime');

    // print('\n⏰ ===== LOADING DISPLAY TIMES =====');
    // print('⏰ Reading from SharedPref:');
    // print('⏰   checkInDisplayTime = "$checkIn"');
    // print('⏰   checkOutDisplayTime = "$checkOut"');

    setState(() {
      _checkInDisplayTime =
          (checkIn.isEmpty || checkIn == '--:--') ? '00:00:00' : checkIn;
      _checkOutDisplayTime =
          (checkOut.isEmpty || checkOut == '--:--') ? '00:00:00' : checkOut;
      _calculateTotalHours();
    });

    // print('⏰ After setState:');
    // print('⏰   _checkInDisplayTime (GREEN/LEFT) = $_checkInDisplayTime');
    // print('⏰   _checkOutDisplayTime (RED/RIGHT) = $_checkOutDisplayTime');
    // print('⏰ ===================================\n');
  }

  /// Calculate total hours between check-in and check-out
  void _calculateTotalHours() {
    if (_checkInDisplayTime == '00:00:00' ||
        _checkOutDisplayTime == '00:00:00') {
      _totalHoursDisplay = '00:00';
      return;
    }

    try {
      // Parse times (format: HH:mm:ss)
      final checkInParts = _checkInDisplayTime.split(':');
      final checkOutParts = _checkOutDisplayTime.split(':');

      if (checkInParts.length >= 2 && checkOutParts.length >= 2) {
        final checkInMinutes =
            int.parse(checkInParts[0]) * 60 + int.parse(checkInParts[1]);
        final checkOutMinutes =
            int.parse(checkOutParts[0]) * 60 + int.parse(checkOutParts[1]);

        int totalMinutes = checkOutMinutes - checkInMinutes;
        if (totalMinutes < 0) {
          totalMinutes += 24 * 60; // Handle crossing midnight
        }

        final hours = totalMinutes ~/ 60;
        final minutes = totalMinutes % 60;

        _totalHoursDisplay =
            '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      _totalHoursDisplay = '00:00';
    }
  }

  /// حساب الوقت التصاعدي من check-in حتى الآن
  void _calculateLiveTotalHours() {
    if (_checkInDisplayTime == '00:00:00') {
      _totalHoursDisplay = '00:00';
      return;
    }

    try {
      // Parse check-in time (format: HH:mm:ss)
      final checkInParts = _checkInDisplayTime.split(':');
      if (checkInParts.length >= 2) {
        final checkInMinutes =
            int.parse(checkInParts[0]) * 60 + int.parse(checkInParts[1]);

        // Get current Dubai time
        final now = DateTime.now().toUtc().add(const Duration(hours: 4));
        final currentMinutes = now.hour * 60 + now.minute;

        int totalMinutes = currentMinutes - checkInMinutes;
        if (totalMinutes < 0) {
          totalMinutes += 24 * 60; // Handle crossing midnight
        }

        final hours = totalMinutes ~/ 60;
        final minutes = totalMinutes % 60;

        _totalHoursDisplay =
            '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      _totalHoursDisplay = '00:00';
    }
  }

  /// بدء العداد التصاعدي
  void _startLiveTimer() {
    _liveTimer?.cancel();
    // Update every second so the display is always current
    _liveTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && isCheckedIn) {
        setState(() {
          _calculateLiveTotalHours();
        });
      } else {
        timer.cancel();
      }
    });
    // Update immediately on the first frame
    setState(() {
      _calculateLiveTotalHours();
    });
  }

  /// إيقاف العداد التصاعدي
  void _stopLiveTimer() {
    _liveTimer?.cancel();
    _liveTimer = null;
  }

  /// التحقق من أن الوقت الحالي ضمن فترة السماح بـ Check-in
  /// Check-in مسموح من 5:00 AM حتى 11:59 AM بتوقيت دبي
  bool _isCheckInAllowed() {
    final dubaiTime = DateTime.now().toUtc().add(const Duration(hours: 4));
    // Check-in مسموح من الساعة 5 صباحاً حتى 11:59 صباحاً
    if (dubaiTime.hour >= 5 && dubaiTime.hour < 12) {
      return true;
    }
    return false;
  }

  /// الحصول على الوقت الحالي بتوقيت دبي
  DateTime _getDubaiTime() {
    return DateTime.now().toUtc().add(const Duration(hours: 4));
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _attendanceSyncSubscription?.cancel();
    _arrowController.dispose();
    _checkmarkController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  _loadCheckInState() {
    final storedState = SharedPref().getPreferenceBoolean('isCheckedIn');

    // التحقق من نظام reset عند الساعة 5 صباحاً بتوقيت دبي
    if (storedState) {
      final checkInTime = SharedPref().getPreferenceInt('checkInTime');
      if (checkInTime != 0) {
        final checkInDateTime =
            DateTime.fromMillisecondsSinceEpoch(checkInTime);
        final now = DateTime.now();

        // احسب توقيت دبي (UTC+4)
        final dubaiNow = now.toUtc().add(const Duration(hours: 4));

        // احسب آخر وقت reset (5 صباحاً بتوقيت دبي)
        DateTime lastResetTime;
        if (dubaiNow.hour >= 5) {
          // اليوم الساعة 5 صباحاً
          lastResetTime =
              DateTime(dubaiNow.year, dubaiNow.month, dubaiNow.day, 5, 0);
        } else {
          // أمس الساعة 5 صباحاً
          final yesterday = dubaiNow.subtract(const Duration(days: 1));
          lastResetTime =
              DateTime(yesterday.year, yesterday.month, yesterday.day, 5, 0);
        }

        // تحويل checkInDateTime لتوقيت دبي
        final checkInDubaiTime =
            checkInDateTime.toUtc().add(const Duration(hours: 4));

        // DEBUG: طباعة معلومات التشخيص
        // debugPrint('⏰ ===== CHECK-IN RESET DEBUG =====');
        // debugPrint('⏰ Dubai Now: $dubaiNow');
        // debugPrint('⏰ Check-in Time (stored): $checkInDateTime');
        // debugPrint('⏰ Check-in Dubai Time: $checkInDubaiTime');
        // debugPrint('⏰ Last Reset Time (5 AM): $lastResetTime');
        // debugPrint(
        //     '⏰ Should reset? ${checkInDubaiTime.isBefore(lastResetTime)}');
        // debugPrint('⏰ ================================');

        // إذا كان check-in قبل آخر وقت reset، يجب reset الحالة
        if (checkInDubaiTime.isBefore(lastResetTime)) {
          // debugPrint(
          //     '⏰ Check-in was before 5:00 AM reset time. Resetting state...');
          // debugPrint('⏰ Check-in Dubai time: $checkInDubaiTime');
          // debugPrint('⏰ Last reset time: $lastResetTime');

          // Reset check in/out state
          SharedPref().setPreferencesBoolean('isCheckedIn', false);
          SharedPref().setPreferenceInt('checkInRecordId', 0);
          SharedPref().setPreferencesString('checkInDisplayTime', '00:00:00');
          SharedPref().setPreferencesString('checkOutDisplayTime', '00:00:00');
          SharedPref().removePreference('checkInProjectId');
          SharedPref().removePreference('checkInBranchId');
          SharedPref().removePreference('checkInAuthMethod');
          SharedPref().setPreferenceInt('checkInTime', 0);

          // مسح وقت آخر تشيك اوت محلي حتى لا يمنع مزامنة بيانات السيرفر
          SharedPref().setPreferenceInt('lastLocalCheckOutTime', 0);

          // Update notifications
          CheckInReminderNotificationService().updateReminders();

          // إيقاف العداد التصاعدي
          _stopLiveTimer();

          setState(() {
            isCheckedIn = false;
            _isVisualCheckedIn = false;
            dragOffset = 0;
            _checkInDisplayTime = '00:00:00';
            _checkOutDisplayTime = '00:00:00';
            _totalHoursDisplay = '00:00';
          });
          return;
        }
      }
    }

    setState(() {
      isCheckedIn = storedState;
      _isVisualCheckedIn = storedState; // Sync visual state with actual state
      dragOffset = isCheckedIn ? (buttonWidth - knobSize) : 0;
    });

    // بدء العداد إذا كان checked in
    if (isCheckedIn && _checkOutDisplayTime == '00:00:00') {
      _startLiveTimer();
    }
  }

  void animateTo(double target, VoidCallback onComplete) {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    late Animation<double> animation;
    animation =
        Tween<double>(begin: dragOffset, end: target).animate(controller);

    animation.addListener(() {
      setState(() {
        dragOffset = animation.value;
        if (dragOffset < 2.0) {
          startSwipe = false;
        }
        // Update visual state based on animation progress
        final progress = dragOffset / (buttonWidth - knobSize);
        if (progress > 0.5) {
          _isVisualCheckedIn = true;
        } else {
          _isVisualCheckedIn = false;
        }
      });
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        onComplete();
        controller.dispose();
      }
    });

    controller.forward();
  }

  bool startSwipe = false;

  void _showCheckInNotAvailablePopup({String? currentTime}) {
    final message = currentTime == null || currentTime.isEmpty
        ? 'check in is not available'
        : 'check in is not available\nCurrent time: $currentTime';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF5F5), Color(0xFFFFEBEE)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD32F2F),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.block,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'ACTION BLOCKED',
                  style: TextStyle(
                    color: Color(0xFFB71C1C),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF3A3A3A),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAttendanceApiMessage({
    required String title,
    required String message,
    required Color color,
    required IconData icon,
  }) {
    if (!mounted || message.trim().isEmpty) return;

    final normalizedMessage = message.replaceAll(RegExp(r'\s+'), ' ').trim();
    final messageHeader = _attendanceMessageHeader(normalizedMessage);
    final messageItems = _attendanceMessageItems(normalizedMessage);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 320,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(dialogContext).size.height * 0.42,
              ),
              child: Scrollbar(
                thumbVisibility: messageItems.length > 6,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        messageHeader,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color: Color(0xFF303030),
                        ),
                      ),
                      if (messageItems.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ...messageItems.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Text(
                                    '•',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      height: 1.35,
                                      color: Color(0xFF3A3A3A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'OK',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _setApiLoading(bool isLoading) {
    if (!mounted || _isApiLoading == isLoading) return;
    setState(() {
      _isApiLoading = isLoading;
    });
  }

  String _attendanceMessageHeader(String message) {
    final colonIndex = message.indexOf(':');
    if (colonIndex > 0) {
      final header = message.substring(0, colonIndex + 1).trim();
      final hasListAfterColon =
          message.substring(colonIndex + 1).contains(RegExp(r'[,،]\s*'));
      return hasListAfterColon ? header : message;
    }

    final commaParts = message
        .split(RegExp(r'[,،]\s*'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (commaParts.length >= 3) {
      final firstPart = _sanitizeAttendanceText(commaParts.first);
      if (firstPart.endsWith(':')) return firstPart;
      return '$firstPart:';
    }

    return _sanitizeAttendanceText(message);
  }

  List<String> _attendanceMessageItems(String message) {
    final colonIndex = message.indexOf(':');
    if (colonIndex > 0) {
      final tail = message.substring(colonIndex + 1).trim();
      if (!tail.contains(RegExp(r'[,،]\s*'))) return const [];

      final items = tail
          .split(RegExp(r'[,،]\s*'))
          .map((item) => _sanitizeAttendanceText(item))
          .where((item) => item.isNotEmpty)
          .toList();

      return items.length > 1 ? items : const [];
    }

    final parts = message
        .split(RegExp(r'[,،]\s*'))
        .map((part) => _sanitizeAttendanceText(part))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.length < 3) return const [];

    final items = parts.sublist(1);

    return items.length > 1 ? items : const [];
  }

  String _sanitizeAttendanceText(String text) {
    return text
        .trim()
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  Future<void> _restoreAfterCheckInFailure() async {
    await SharedPref().setPreferencesBoolean('isCheckedIn', false);
    await SharedPref().setPreferenceInt('checkInRecordId', 0);
    await SharedPref().setPreferencesString('checkInDisplayTime', '00:00:00');
    await Get.find<TimerController>().stopTimer();
    await AutoCheckoutService.cancelAutoCheckout();
    await CheckInReminderNotificationService().updateReminders();
    _stopLiveTimer();

    if (!mounted) return;
    setState(() {
      isCheckedIn = false;
      _isVisualCheckedIn = false;
      dragOffset = 0;
      _checkInDisplayTime = '00:00:00';
      _totalHoursDisplay = '00:00';
      startSwipe = false;
    });
  }

  Future<void> _restoreAfterCheckOutFailure() async {
    await SharedPref().setPreferencesBoolean('isCheckedIn', true);
    await Get.find<TimerController>().startTimer();
    await AutoCheckoutService.scheduleAutoCheckout();
    await CheckInReminderNotificationService().updateReminders();
    _startLiveTimer();

    if (!mounted) return;
    setState(() {
      isCheckedIn = true;
      _isVisualCheckedIn = true;
      dragOffset = buttonWidth - knobSize;
      startSwipe = false;
    });
  }

  void _onDragEnd() async {
    final threshold = buttonWidth * 0.6;
    if ((!isCheckedIn && dragOffset >= threshold) ||
        (isCheckedIn && dragOffset <= (buttonWidth - knobSize - threshold))) {
      // التحقق من وقت Check-in قبل السماح (فقط عند محاولة check-in وليس check-out)
      // ⚠️ تم تعطيل شرط الوقت مؤقتاً
      // if (!isCheckedIn && !_isCheckInAllowed()) {
      //   final dubaiTime = _getDubaiTime();
      //   final timeStr =
      //       '${dubaiTime.hour.toString().padLeft(2, '0')}:${dubaiTime.minute.toString().padLeft(2, '0')}';
      //   _showCheckInNotAvailablePopup(currentTime: timeStr);
      //   _resetPosition();
      //   return;
      // }

      final targetOffset = isCheckedIn ? 0.0 : (buttonWidth - knobSize);
      SharedPref()
          .setPreferencesBoolean('wasCheckedInBeforeFaceAuth', isCheckedIn);
      SharedPref().setPreferencesBoolean('isCheckedIn', isCheckedIn);
      if (!isCheckedIn) SharedPref().setPreferenceInt('checkInRecordId', 0);
      animateTo(targetOffset, () {
        showLeftToRightPopupClean(
          context: context,
          loginResponseModel: SharedPref.getLoginData(),
          isCheckedIn: isCheckedIn,
          onConfirmed: () async {
            // Bypass authentication if test mode OR faceIdEnabled=false from backend config
            print(
                '🔐 Face ID check: shouldSkipFaceId=${AppConfigService.instance.shouldSkipFaceId}, '
                'isTestMode=${AppConfigService.instance.isTestMode}, '
                'faceIdEnabled=${AppConfigService.instance.faceIdEnabled}');
            if (AppConfigService.instance.shouldSkipFaceId) {
              print('⏭️ Skipping face verification (shouldSkipFaceId=true)');
              _performCheckInOut();
              _resetPosition();
              return;
            }

            // Show platform-specific biometric authentication (Face ID on iOS, Fingerprint on Android)
            final authenticated =
                await UnifiedBiometricHelper.authenticateForAttendance(context);

            if (authenticated) {
              // Authentication successful - perform check-in/out
              _performCheckInOut();
              _resetPosition();
            } else {
              // Authentication failed or cancelled - reset position
              _resetPosition();
            }
          },
          onCancelled: () {
            // User cancelled the dialog - reset position
            _resetPosition();
          },
        );
      });
    } else {
      animateTo(isCheckedIn ? (buttonWidth - knobSize) : 0.0, () {});
    }
  }

  /// Perform check-in or check-out action
  ///
  /// Note: Check-in/Check-out is global and unified
  /// - Timer applies to all projects (8 hours fixed)
  /// - Project selection is for display/reference only
  /// - Detailed time management handled via job missions
  ///
  /// NOTE: The 8 working hours are global and shared across all projects.
  ///       Switching projects does NOT reset or create a new timer.
  void _performCheckInOut() async {
    if (!isCheckedIn) {
      // Perform global check-in
      sl.get<CheckInBloc>().add(CheckInET());
      // await startTimer to guarantee isCheckedIn=true is persisted
      // BEFORE updateReminders() reads SharedPref
      await Get.find<TimerController>().startTimer();

      // جدولة Auto Check-out في الساعة 5:10 مساءً
      await AutoCheckoutService.scheduleAutoCheckout();
      // debugPrint('✅ Auto checkout scheduled for 5:10 PM after check-in');

      await CheckInReminderNotificationService().updateReminders();
    } else {
      // Perform global check-out (manual)
      final checkInRecordId = SharedPref().getPreferenceInt('checkInRecordId');
      print(
          '🔴 _performCheckInOut: CHECK-OUT requested, checkInRecordId=$checkInRecordId');
      if (checkInRecordId == 0) {
        print(
            '⚠️ _performCheckInOut: checkInRecordId is 0! Sending anyway — backend should resolve.');
      }
      sl
          .get<CheckOutBloc>()
          .add(CheckOutET(checkInRecordId, isAutoCheckout: false));
      // await stopTimer to guarantee isCheckedIn=false is persisted
      // BEFORE updateReminders() reads SharedPref
      await Get.find<TimerController>().stopTimer();

      // إلغاء جدولة Auto Check-out عند Check-out اليدوي
      await AutoCheckoutService.cancelAutoCheckout();
      // debugPrint('✅ Auto checkout cancelled after manual check-out');

      // Clear saved check-in project (used for display only)
      SharedPref().removePreference('checkInProjectId');
      SharedPref().removePreference('checkInBranchId');
      SharedPref().removePreference('checkInAuthMethod');

      // تحديث الإشعارات لجدولة تذكيرات check in (من 8 صباحاً - 9 صباحاً)
      await CheckInReminderNotificationService().updateReminders();
      // debugPrint('✅ Check-in reminder notifications scheduled');
    }

    setState(() {
      isCheckedIn = !isCheckedIn;
      _isVisualCheckedIn = isCheckedIn;
      dragOffset = isCheckedIn ? (buttonWidth - knobSize) : 0;
    });
    SharedPref().setPreferencesBoolean('isCheckedIn', isCheckedIn);
  }

  @override
  Widget build(BuildContext context) {
    final isAfterSwipeTheme = _isVisualCheckedIn;
    // Notify the surrounding card so its background switches blue -> gray
    // together with the swipe theme (done after frame to avoid setState during build).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      swipeCheckedInNotifier.value = isAfterSwipeTheme;
    });
    final timelineColor = isAfterSwipeTheme
        ? const Color(0xFF323958)
        : const Color(0xFF37D9EA);
    final timeTextColor = isAfterSwipeTheme ? const Color(0xFF232A47) : Colors.white;
    final swipeTrackColor =
        isAfterSwipeTheme ? const Color(0xFF2F365F) : Colors.white;
    final swipeLabelColor =
        isAfterSwipeTheme ? Colors.white : const Color(0xFF151544);
    final middleCounterLabel =
        '${isCheckedIn ? _totalHoursDisplay : '08:00'}:H';

    return MultiBlocListener(
      listeners: [
        // Listen to CheckInBloc to update time display after successful check-in
        BlocListener<CheckInBloc, CheckInState>(
          bloc: sl.get<CheckInBloc>(),
          listener: (context, state) async {
            if (state is CheckInLoadingST) {
              if (state.isLoading) {
                _setApiLoading(true);
              } else {
                _setApiLoading(false);
              }
            } else if (state is CheckedInST) {
              _setApiLoading(false);
              // Reload display times after successful check-in
              _loadDisplayTimes();
              // بدء العداد التصاعدي
              _startLiveTimer();
              _showAttendanceApiMessage(
                title: 'Check-In Success',
                message: state.message,
                color: const Color(0xFF28A745),
                icon: Icons.check_circle,
              );
            } else if (state is CheckInWarningST) {
              _setApiLoading(false);
              _loadDisplayTimes();
              _startLiveTimer();
              _showAttendanceApiMessage(
                title: 'Check-In Warning',
                message: state.warningMessage,
                color: const Color(0xFFFFA000),
                icon: Icons.warning,
              );
            } else if (state is CheckInErrorST) {
              _setApiLoading(false);
              await _restoreAfterCheckInFailure();
              _showAttendanceApiMessage(
                title: 'Invalid Project Location',
                message: state.errorMessage,
                color: const Color(0xFFDC3545),
                icon: Icons.error,
              );
            } else if (state is CheckInBlockedST) {
              _setApiLoading(false);
              // Check-in is blocked due to time restriction (after 11:59 AM)
              _resetPosition();
              final timeStr =
                  '${state.currentDubaiTime.hour.toString().padLeft(2, '0')}:${state.currentDubaiTime.minute.toString().padLeft(2, '0')}';
              _showCheckInNotAvailablePopup(currentTime: timeStr);
            }
          },
        ),
        // Listen to CheckOutBloc to update time display after successful check-out
        BlocListener<CheckOutBloc, CheckOutState>(
          bloc: sl.get<CheckOutBloc>(),
          listener: (context, state) async {
            if (state is CheckOutLoadingST) {
              if (state.isLoading) {
                _setApiLoading(true);
              } else {
                _setApiLoading(false);
              }
            } else if (state is CheckedOutST) {
              _setApiLoading(false);
              // Reload display times after successful check-out
              _loadDisplayTimes();
              // إيقاف العداد التصاعدي
              _stopLiveTimer();
              _showAttendanceApiMessage(
                title: 'Check-Out Success',
                message: state.message,
                color: const Color(0xFF28A745),
                icon: Icons.check_circle,
              );
            } else if (state is CheckOutWarningST) {
              _setApiLoading(false);
              _loadDisplayTimes();
              _stopLiveTimer();
              _showAttendanceApiMessage(
                title: 'Check-Out Warning',
                message: state.warningMessage,
                color: const Color(0xFFFFA000),
                icon: Icons.warning,
              );
            } else if (state is CheckOutErrorST) {
              _setApiLoading(false);
              await _restoreAfterCheckOutFailure();
              _showAttendanceApiMessage(
                title: 'Check-Out Error',
                message: state.errorMessage,
                color: const Color(0xFFDC3545),
                icon: Icons.error,
              );
            }
          },
        ),
      ],
      child: Stack(
        children: [
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Finger animation GIF on top left (kept before and after swipe)
                Positioned(
                  left: -80,
                  top: -80,
                  child: Opacity(
                    opacity: 0.4,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomRight: Radius.circular(23),
                      ),
                      child: Image.asset(
                        'assets/gif/finger-print.gif',
                        width: 150,
                        height: 160,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Main swipe button container
                    GestureDetector(
                      onHorizontalDragStart: (_) =>
                          setState(() => isDragging = true),
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          dragOffset += details.delta.dx;
                          dragOffset =
                              dragOffset.clamp(0.0, buttonWidth - knobSize);

                          // Calculate swipe progress for smooth visual transitions
                          final progress =
                              dragOffset / (buttonWidth - knobSize);

                          if (dragOffset > 2.0) {
                            startSwipe = true;
                            // Smooth visual state transition based on swipe progress
                            if (progress > 0.5) {
                              if (_isVisualCheckedIn != !isCheckedIn) {
                                _isVisualCheckedIn = !isCheckedIn;
                                // Haptic feedback when visual state changes
                                HapticFeedback.lightImpact();
                              }
                            } else {
                              if (_isVisualCheckedIn != isCheckedIn) {
                                _isVisualCheckedIn = isCheckedIn;
                              }
                            }
                          } else {
                            startSwipe = false;
                            if (_isVisualCheckedIn != isCheckedIn) {
                              _isVisualCheckedIn = isCheckedIn;
                            }
                          }
                        });
                      },
                      onHorizontalDragEnd: (_) => _onDragEnd(),
                      child: Container(
                        width: buttonWidth,
                        height: buttonHeight,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
                          color: swipeTrackColor,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(40),
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            children: [
                              // Center text with dynamic color and opacity transition
                              Center(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // First text (SWIPE TO CHECK IN) - fades out during swipe
                                    Opacity(
                                      opacity: _isVisualCheckedIn
                                          ? 0.0
                                          : 1.0 -
                                              (dragOffset /
                                                      (buttonWidth - knobSize))
                                                  .clamp(0.0, 1.0),
                                      child: Text(
                                        translate(
                                            'custom_swipe_button.swipe_to_check_in'),
                                        style: GoogleFonts.poppins(
                                          color: swipeLabelColor,
                                          fontSize: 18.sp,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    // Second text (SWIPE TO CHECK OUT) - fades in during swipe
                                    Opacity(
                                      opacity: _isVisualCheckedIn
                                          ? 1.0
                                          : (dragOffset /
                                                  (buttonWidth - knobSize))
                                              .clamp(0.0, 1.0),
                                      child: Text(
                                        translate(
                                            'custom_swipe_button.swipe_to_check_out'),
                                        style: GoogleFonts.poppins(
                                          color: swipeLabelColor,
                                          fontSize: 18.sp,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Dynamic chevron GIF that changes based on state
                              Positioned(
                                left:
                                    _isVisualCheckedIn ? null : dragOffset + 2,
                                right: _isVisualCheckedIn
                                    ? (buttonWidth - dragOffset - knobSize)
                                    : null,
                                top: (buttonHeight - 40) / 2,
                                child: Builder(
                                  builder: (context) {
                                    // Calculate progress (0.0 to 1.0)
                                    final progress =
                                        (dragOffset / (buttonWidth - knobSize))
                                            .clamp(0.0, 1.0);

                                    // Calculate opacity and scaleX based on progress
                                    // Gradually fade out and shrink horizontally as approaching center
                                    // Then fade in and expand horizontally after passing center
                                    double opacity;
                                    double scaleX;

                                    if (progress <= 0.5) {
                                      // First half: gradually fade out and shrink towards center
                                      opacity =
                                          1.0 - (progress * 2); // 1.0 -> 0.0
                                      scaleX =
                                          1.0 - (progress * 2); // 1.0 -> 0.0
                                    } else {
                                      // Second half: gradually fade in and expand from center
                                      opacity =
                                          (progress - 0.5) * 2; // 0.0 -> 1.0
                                      scaleX =
                                          (progress - 0.5) * 2; // 0.0 -> 1.0
                                    }

                                    return AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      transitionBuilder: (child, anim) =>
                                          FadeTransition(
                                              opacity: anim, child: child),
                                      child: Transform(
                                        transform: Matrix4.identity()
                                          ..scale(scaleX, 1.0),
                                        alignment: Alignment.center,
                                        child: Opacity(
                                          opacity: opacity,
                                          child: Transform.flip(
                                            key: ValueKey(_isVisualCheckedIn),
                                            flipX: _isVisualCheckedIn,
                                            child: ColorFiltered(
                                              colorFilter: ColorFilter.mode(
                                                _isVisualCheckedIn
                                                    ? const Color(0xFFAEB4C8)
                                                    : const Color(0xFF8B8E9A),
                                                BlendMode.srcIn,
                                              ),
                                              child: Image.asset(
                                                'assets/gif/arrow_animation.gif',
                                                width: 50,
                                                height: 36.88,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              // Old icon animation code (commented for reference)
                              // PositionedDirectional(
                              //   start: _isVisualCheckedIn ? null : 8,
                              //   end: _isVisualCheckedIn ? 8 : null,
                              //   top: (buttonHeight - 32) / 2,
                              //   child: AnimatedBuilder(
                              //     animation: _bounceAnimation,
                              //     builder: (context, _) {
                              //       return Transform.translate(
                              //         offset: Offset(_bounceAnimation.value, 0),
                              //         child: AnimatedSwitcher(
                              //           duration: const Duration(milliseconds: 300),
                              //           layoutBuilder: (current, previous) => Stack(
                              //             alignment: Alignment.center,
                              //             clipBehavior: Clip.none,
                              //             children: [
                              //               ...previous,
                              //               if (current != null) current,
                              //             ],
                              //           ),
                              //           transitionBuilder: (child, anim) =>
                              //               FadeTransition(opacity: anim, child: child),
                              //           child: SizedBox(
                              //             key: ValueKey(_isVisualCheckedIn),
                              //             width: 44,
                              //             height: 32,
                              //             child: Stack(
                              //               alignment: Alignment.centerLeft,
                              //               clipBehavior: Clip.none,
                              //               children: [
                              //                 Icon(iconData, size: 32, weight: 900, color: iconColor),
                              //                 Transform.translate(
                              //                   offset: Offset(isRTL ? overlap : -overlap, 0),
                              //                   child: Icon(iconData, size: 32, weight: 900, color: iconColor),
                              //                 ),
                              //               ],
                              //             ),
                              //           ),
                              //         ),
                              //       );
                              //     },
                              //   ),
                              // ),

                              // Swipe knob (invisible but functional)
                              Positioned(
                                left: dragOffset,
                                top: (buttonHeight - knobSize) / 2,
                                child: Container(
                                  width: knobSize,
                                  height: knobSize,
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius:
                                        BorderRadius.circular(knobSize / 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Timeline component below the button
                    SizedBox(height: 24.h),
                    SizedBox(
                      width: buttonWidth * 1.0, // Adjusted width for timeline
                      child: Column(
                        children: [
                          // Time labels above the timeline
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Left time label - shows check-in time
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _checkInDisplayTime,
                                  style: GoogleFonts.poppins(
                                    color: timeTextColor,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),

                              // Middle label - working hours counter
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  middleCounterLabel,
                                  style: GoogleFonts.poppins(
                                    color: timeTextColor,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),

                              // Right time label - shows check-out time
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _checkOutDisplayTime,
                                  style: GoogleFonts.poppins(
                                    color: timeTextColor,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 8.h),

                          // Timeline with circles on the line
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 25.w),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // The line in the middle
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        height: 3,
                                        decoration: BoxDecoration(
                                          color: timelineColor,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                // Circles on top
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 10.w,
                                      height: 10.w,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: timelineColor,
                                      ),
                                    ),

                                    Container(
                                      width: 10.w,
                                      height: 10.w,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: timelineColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isApiLoading)
            const Positioned.fill(
              child: AbsorbPointer(
                absorbing: true,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
