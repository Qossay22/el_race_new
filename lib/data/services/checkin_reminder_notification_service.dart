import 'dart:io';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// خدمة إشعارات تذكير Check In
///
/// التذكيرات:
/// • إذا ما عمل check in:
///   - من الساعة 8 صباحاً - 9 صباحاً: إشعار كل 15 دقيقة
/// • إذا عمل check in: لا تذكيرات
///
/// التوقيت: الإمارات (GMT+4)
class CheckInReminderNotificationService {
  static final CheckInReminderNotificationService _instance =
      CheckInReminderNotificationService._internal();
  factory CheckInReminderNotificationService() => _instance;
  CheckInReminderNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _exactAlarmGranted = false;

  // Notification IDs
  static const int _checkOutReminderId = 1000;
  static const int _checkInReminderId = 2000;
  static const int _checkInReminderDaysToSchedule = 7;
  static const int _checkInRemindersPerDay = 5;

  Future<void> initialize() async {
    if (_initialized) return;

    // تهيئة منطقة التوقيت
    tz.initializeTimeZones();

    // تعيين توقيت الإمارات (GMT+4)
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Dubai'));
    } catch (e) {
      // print('⚠️ Could not set Asia/Dubai timezone, falling back to UTC+4 offset: $e');
      // Fallback: use a fixed UTC+4 offset so notifications still fire at the right Dubai time
      try {
        tz.setLocalLocation(tz.getLocation('Etc/GMT-4'));
      } catch (_) {}
    }

    // طلب صلاحية الإشعارات
    await _requestNotificationPermissions();

    // NOTE: Do NOT call _notificationsPlugin.initialize() here.\n    // FirebaseService.initialize() already set up the shared native platform\n    // with the unified tap-handler. A second initialize() call would OVERRIDE\n    // that handler, breaking notification-tap routing for all other services.\n    // Channel creation + permission requests work via the static singleton.\n\n    // إنشاء قنوات الإشعارات لـ Android
    await _createNotificationChannels();

    _initialized = true;
    // print('🔔 Check-in/out reminder notification service initialized');
  }

  /// طلب صلاحيات الإشعارات والإشعارات الدقيقة + إيقاف تحسين البطارية (Samsung)
  Future<void> _requestNotificationPermissions() async {
    try {
      // طلب صلاحية الإشعارات العادية (Android 13+)
      final notificationStatus = await Permission.notification.request();
      // print('📱 Notification permission: ${notificationStatus.isGranted}');

      if (Platform.isAndroid) {
        // طلب إيقاف تحسين البطارية (مهم جداً لـ Samsung)
        // Samsung One UI يوقف الإشعارات المجدولة بسبب "Sleeping apps"
        await _requestBatteryOptimizationExemption();

        // طلب صلاحية الإشعارات الدقيقة (Exact Alarms)
        // على Android 12 (API 31) وما فوق
        try {
          if (await Permission.scheduleExactAlarm.isDenied) {
            // print('⚠️ Requesting exact alarm permission...');
            await Permission.scheduleExactAlarm.request();
          }

          final alarmStatus = await Permission.scheduleExactAlarm.status;
          _exactAlarmGranted = alarmStatus.isGranted;
          // print('⏰ Exact alarm permission: $_exactAlarmGranted');

          if (!_exactAlarmGranted) {
            // print('⚠️ Exact alarm NOT granted - will use inexact alarms as fallback');
          }
        } catch (e) {
          // print('⚠️ Error checking exact alarm permission: $e');
          _exactAlarmGranted = false;
        }
      } else {
        // iOS لا يحتاج exact alarm permission
        _exactAlarmGranted = true;
      }
    } catch (e) {
      // print('⚠️ Error requesting permissions: $e');
    }
  }

  /// طلب إيقاف تحسين البطارية - مهم جداً لأجهزة Samsung
  /// Samsung One UI يضع التطبيقات في "Sleeping apps" مما يمنع الإشعارات المجدولة
  Future<void> _requestBatteryOptimizationExemption() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      // print('🔋 Battery optimization status: ${status.isGranted ? "EXEMPT" : "NOT EXEMPT"}');

      if (!status.isGranted) {
        // print('🔋 Requesting battery optimization exemption (important for Samsung)...');
        final result = await Permission.ignoreBatteryOptimizations.request();
        // print('🔋 Battery optimization exemption result: ${result.isGranted ? "GRANTED" : "DENIED"}');

        if (!result.isGranted) {
          // print('⚠️ Battery optimization NOT disabled!');
          // print('💡 Samsung users: Go to Settings > Apps > El Race > Battery > Unrestricted');
        }
      }

      // تسجيل معلومات الجهاز للتشخيص
      try {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        // print('📱 Device: ${androidInfo.manufacturer} ${androidInfo.model}');
        // print('📱 Android SDK: ${androidInfo.version.sdkInt}');

        if (androidInfo.manufacturer.toLowerCase().contains('samsung')) {
          // print('⚠️ Samsung device detected - aggressive battery optimization may block notifications');
          // print('💡 Ensure app is NOT in "Sleeping apps" or "Deep sleeping apps"');
          // print('💡 Settings > Battery > Background usage limits > Never sleeping apps > Add El Race');
        }
      } catch (e) {
        // print('⚠️ Could not get device info: $e');
      }
    } catch (e) {
      // print('⚠️ Error requesting battery optimization exemption: $e');
    }
  }

  /// إنشاء قنوات الإشعارات لـ Android
  Future<void> _createNotificationChannels() async {
    // قناة تذكيرات Check In
    const AndroidNotificationChannel checkInChannel =
        AndroidNotificationChannel(
      'check_in_reminder_channel',
      'Check In Reminders',
      description: 'Check-in reminders',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(checkInChannel);

    // print('✅ Check-in reminder notification channel created');
  }

  /// جدولة إشعارات التذكير بـ check in (من 8 صباحاً - 9 صباحاً)
  Future<void> scheduleCheckInReminders() async {
    await initialize();
    await cancelCheckInReminders(); // إلغاء أي إشعارات سابقة

    // إعادة فحص صلاحية exact alarm قبل الجدولة
    if (Platform.isAndroid) {
      try {
        final alarmStatus = await Permission.scheduleExactAlarm.status;
        _exactAlarmGranted = alarmStatus.isGranted;
      } catch (_) {}
    }

    final now = tz.TZDateTime.now(tz.local);
    // print('⏰ Current time: ${now.toString()}');
    // print('⏰ Schedule mode: ${_exactAlarmGranted ? "EXACT" : "INEXACT (fallback)"}');

    // جدول إشعارات كل 15 دقيقة من الساعة 8 صباحاً حتى 9 صباحاً
    // لمدة عدة أيام قادمة مع استثناء يوم السبت.
    final reminderMinuteSlots = <int>[0, 15, 30, 45, 60];

    int idCounter = _checkInReminderId;
    int scheduledCount = 0;
    // Capture exact-alarm capability ONCE; never mutate the shared instance field
    // inside the loop — a single failure must not force ALL remaining notifications
    // into inexact mode for the rest of the app session.
    final bool useExactAlarm = _exactAlarmGranted;
    for (int dayOffset = 0;
        dayOffset < _checkInReminderDaysToSchedule;
        dayOffset++) {
      final day = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + dayOffset,
      );

      // لا ترسل تذكيرات Check-in يوم السبت.
      if (day.weekday == DateTime.saturday) {
        continue;
      }

      for (final minuteSlot in reminderMinuteSlots) {
        final targetTime = tz.TZDateTime(
          tz.local,
          day.year,
          day.month,
          day.day,
          8,
          minuteSlot,
        );

        // تجاهل أي وقت مرّ بالفعل (غالباً لليوم الحالي).
        if (!targetTime.isAfter(now)) {
          continue;
        }

        try {
          await _notificationsPlugin.zonedSchedule(
            idCounter,
            '⏰ Check In Reminder',
            'Don\'t forget to Check In',
            targetTime,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'check_in_reminder_channel',
                'Check In Reminders',
                channelDescription: 'Check-in reminders',
                importance: Importance.max,
                priority: Priority.max,
                category: AndroidNotificationCategory.alarm,
                icon: '@mipmap/ic_launcher',
                playSound: true,
                enableVibration: true,
                fullScreenIntent: false,
              ),
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            androidScheduleMode: useExactAlarm
                ? AndroidScheduleMode.exactAllowWhileIdle
                : AndroidScheduleMode.inexactAllowWhileIdle,
            // No repeating: each slot is scheduled explicitly so Saturday can be skipped.
            matchDateTimeComponents: null,
          );
          scheduledCount++;
          print(
              '✅ Scheduled check-in reminder #${idCounter - _checkInReminderId + 1} at ${targetTime.toString()}');
        } catch (e) {
          // print('❌ Error scheduling check-in reminder #${idCounter}: $e');
          // محاولة ثانية بوضع inexact إذا فشل exact
          // NOTE: Do NOT modify _exactAlarmGranted here; use the captured local value.
          if (useExactAlarm) {
            try {
              await _notificationsPlugin.zonedSchedule(
                idCounter,
                '⏰ Check In Reminder',
                'Don\'t forget to Check In',
                targetTime,
                const NotificationDetails(
                  android: AndroidNotificationDetails(
                    'check_in_reminder_channel',
                    'Check In Reminders',
                    channelDescription: 'Check-in reminders',
                    importance: Importance.max,
                    priority: Priority.max,
                    category: AndroidNotificationCategory.alarm,
                    icon: '@mipmap/ic_launcher',
                    playSound: true,
                    enableVibration: true,
                    fullScreenIntent: false,
                  ),
                  iOS: DarwinNotificationDetails(
                    presentAlert: true,
                    presentBadge: true,
                    presentSound: true,
                  ),
                ),
                androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
                matchDateTimeComponents: null,
              );
              scheduledCount++;
              // print('✅ Retry with inexact mode succeeded for #${idCounter}');
            } catch (e2) {
              // print('❌ Retry also failed for #${idCounter}: $e2');
            }
          }
        }

        idCounter++;
      }
    }

    print(
        '✅ Successfully scheduled $scheduledCount check-in reminders (8 AM - 9 AM), excluding Saturday');
  }

  /// إلغاء تذكيرات check out
  Future<void> cancelCheckOutReminders() async {
    await initialize();
    // إلغاء 5 إشعارات (4:00, 4:15, 4:30, 4:45, 5:00)
    for (int i = 0; i < 5; i++) {
      await _notificationsPlugin.cancel(_checkOutReminderId + i);
    }
    // print('🔕 Cancelled check-out reminders');
  }

  /// إلغاء تذكيرات check in
  Future<void> cancelCheckInReminders() async {
    await initialize();
    // إلغاء جميع إشعارات check-in المجدولة للأيام القادمة.
    for (int i = 0;
        i < _checkInReminderDaysToSchedule * _checkInRemindersPerDay;
        i++) {
      await _notificationsPlugin.cancel(_checkInReminderId + i);
    }
    // print('🔕 Cancelled check-in reminders');
  }

  /// تحديث الإشعارات حسب حالة check in/out
  /// يتحقق أولاً من حالة تسجيل الدخول — إذا كان المستخدم عامل logout يلغي كل التذكيرات
  Future<void> updateReminders() async {
    // إذا المستخدم مو مسجّل دخول، ألغي كل التذكيرات ولا تجدول شي جديد
    if (!SharedPref.isUserAuthenticated()) {
      await cancelAllReminders();
      print('📱 User not authenticated — cancelled all check-in/out reminders');
      return;
    }

    final effectiveCheckedInState = _hasActiveCheckInState();
    print(
        '📱 updateReminders: effectiveCheckedInState=$effectiveCheckedInState');

    if (effectiveCheckedInState) {
      // المستخدم عامل check in: ألغي كل التذكيرات (لا check-out reminders)
      await cancelAllReminders();
      print('📱 Updated: Cancelled all reminders (user IS checked in)');
    } else {
      // المستخدم ما عامل check in (أو عمل check out): جدول تذكيرات check in فقط
      await cancelCheckOutReminders();
      await scheduleCheckInReminders();
      print(
          '📱 Updated: Scheduled check-in reminders (user is NOT checked in)');
    }
  }

  /// إلغاء جميع التذكيرات
  Future<void> cancelAllReminders() async {
    await cancelCheckInReminders();
    await cancelCheckOutReminders();
    // print('🔕 Cancelled all check-in/out reminders');
  }

  /// [للاختبار] إرسال إشعار تجريبي فوري
  Future<void> sendTestNotification() async {
    await initialize();
    try {
      await _notificationsPlugin.show(
        99999, // رقم مؤقت للاختبار
        '🧪 Test: Check In Reminder',
        'This is a test notification - Don\'t forget to Check In',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'check_in_reminder_channel',
            'Check In Reminders',
            channelDescription: 'Check-in reminders',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
            fullScreenIntent: false,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
      print('✅ Test check-in reminder notification sent successfully');
    } catch (e) {
      // print('❌ Error sending test notification: $e');
    }
  }

  /// Whether the employee is currently checked in (no reminders while checked in).
  ///
  /// Uses [isCheckedIn] as the single source of truth. Stale display times or
  /// record IDs must not keep reminders active after check-out, or suppress
  /// them after check-in.
  bool _hasActiveCheckInState() {
    final isCheckedIn = SharedPref().getPreferenceBoolean('isCheckedIn');

    print('📱 Reminder state: isCheckedIn=$isCheckedIn');

    return isCheckedIn;
  }
}
