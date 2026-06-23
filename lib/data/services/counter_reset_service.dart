import 'dart:async';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/data/services/checkin_reminder_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

/// خدمة تصفير عدادات الـ Check-in/Check-out يومياً الساعة 5 صباحاً
///
/// تعمل هذه الخدمة على:
/// 1. تصفير العدادات فور فتح التطبيق إذا فات وقت الـ 5 صباحاً
/// 2. جدولة تصفير تلقائي يومياً الساعة 5 صباحاً حتى لو التطبيق مغلق
class CounterResetService {
  static const String taskName = 'counter_reset_task';
  static const String uniqueName = 'daily_counter_reset_5am';

  /// تهيئة الخدمة
  static Future<void> initialize() async {
    try {
      debugPrint('🔄 CounterResetService: Initializing...');

      // NOTE: Workmanager().initialize() is now called once from main.dart
      // with the unified dispatcher. Do NOT call it here.

      // جدولة المهمة اليومية
      await scheduleDailyReset();

      debugPrint('✅ CounterResetService: Initialized successfully');
    } catch (e) {
      debugPrint('❌ CounterResetService: Error initializing: $e');
    }
  }

  /// تصفير العدادات فور فتح التطبيق إذا فات وقت الـ 5 صباحاً
  ///
  /// يجب استدعاء هذه الدالة في main.dart فور بدء التطبيق
  static Future<void> checkAndResetOnAppStart() async {
    try {
      debugPrint('🔄 CounterResetService: Checking reset on app start...');

      final isCheckedIn = SharedPref().getPreferenceBoolean('isCheckedIn');
      final checkInTime = SharedPref().getPreferenceInt('checkInTime');
      final checkInDisplayTime =
          SharedPref().getPreferenceString('checkInDisplayTime');
      final checkOutDisplayTime =
          SharedPref().getPreferenceString('checkOutDisplayTime');

      debugPrint('🔄 isCheckedIn = $isCheckedIn');
      debugPrint('🔄 checkInTime (milliseconds) = $checkInTime');
      debugPrint('🔄 checkInDisplayTime = "$checkInDisplayTime"');
      debugPrint('🔄 checkOutDisplayTime = "$checkOutDisplayTime"');

      // تحقق إذا كانت هناك عدادات تحتاج تصفير
      final hasDisplayTimes = (checkInDisplayTime.isNotEmpty &&
              checkInDisplayTime != '00:00:00' &&
              checkInDisplayTime != '--:--') ||
          (checkOutDisplayTime.isNotEmpty &&
              checkOutDisplayTime != '00:00:00' &&
              checkOutDisplayTime != '--:--');

      debugPrint('🔄 hasDisplayTimes = $hasDisplayTimes');

      // إذا لا يوجد عدادات ولا checkInTime، لا حاجة للتصفير
      if (!hasDisplayTimes && checkInTime == 0) {
        debugPrint(
            'ℹ️ No display times or check-in time saved, no reset needed');
        return;
      }

      // إذا لا يوجد checkInTime لكن يوجد عدادات قديمة، صفّرها
      if (checkInTime == 0 && hasDisplayTimes) {
        debugPrint('🔄 Display times exist but no checkInTime, resetting...');
        await _performReset();
        debugPrint('✅ Counters reset (no checkInTime but had display times)');
        return;
      }

      final checkInDateTime = DateTime.fromMillisecondsSinceEpoch(checkInTime);
      final now = DateTime.now();

      // احسب توقيت دبي (UTC+4)
      final dubaiNow = now.toUtc().add(const Duration(hours: 4));

      // احسب آخر وقت reset (5 صباحاً بتوقيت دبي)
      DateTime lastResetTime;
      if (dubaiNow.hour >= 5) {
        // اليوم الساعة 5 صباحاً بتوقيت دبي
        lastResetTime =
            DateTime.utc(dubaiNow.year, dubaiNow.month, dubaiNow.day, 5, 0);
      } else {
        // أمس الساعة 5 صباحاً بتوقيت دبي
        final yesterday = dubaiNow.subtract(const Duration(days: 1));
        lastResetTime =
            DateTime.utc(yesterday.year, yesterday.month, yesterday.day, 5, 0);
      }

      // تحويل checkInDateTime لتوقيت دبي
      final checkInDubaiTime =
          checkInDateTime.toUtc().add(const Duration(hours: 4));

      debugPrint('⏰ ===== COUNTER RESET CHECK ON APP START =====');
      debugPrint('⏰ Now (local): $now');
      debugPrint('⏰ Dubai Now: $dubaiNow');
      debugPrint('⏰ Check-in Time (stored local): $checkInDateTime');
      debugPrint('⏰ Check-in Dubai Time: $checkInDubaiTime');
      debugPrint('⏰ Last Reset Time (5 AM Dubai): $lastResetTime');
      debugPrint(
          '⏰ checkInDubaiTime.isBefore(lastResetTime) = ${checkInDubaiTime.isBefore(lastResetTime)}');
      debugPrint('⏰ ==============================================');

      // إذا كان check-in قبل آخر وقت reset، يجب reset الحالة
      if (checkInDubaiTime.isBefore(lastResetTime)) {
        debugPrint(
            '🔄 Check-in was before 5:00 AM reset time. Resetting counters...');
        await _performReset();
        debugPrint('✅ Counters reset successfully on app start');
      } else {
        debugPrint('ℹ️ No reset needed - check-in is after last reset time');
      }
    } catch (e) {
      debugPrint('❌ CounterResetService: Error checking reset: $e');
    }
  }

  /// جدولة مهمة التصفير اليومية الساعة 5 صباحاً
  static Future<void> scheduleDailyReset() async {
    try {
      // إلغاء أي مهام سابقة
      await Workmanager().cancelByUniqueName(uniqueName);

      // احسب توقيت دبي (UTC+4)
      final now = DateTime.now();
      final dubaiNow = now.toUtc().add(const Duration(hours: 4));

      // حساب الوقت حتى الساعة 5 صباحاً القادمة بتوقيت دبي
      DateTime targetDubaiTime = DateTime(
        dubaiNow.year,
        dubaiNow.month,
        dubaiNow.day,
        5, // الساعة 5 صباحاً
        0,
        0,
      );

      // إذا كانت الساعة الآن بعد 5 صباحاً، جدول للغد
      if (dubaiNow.isAfter(targetDubaiTime)) {
        targetDubaiTime = targetDubaiTime.add(const Duration(days: 1));
      }

      final delay = targetDubaiTime.difference(dubaiNow);

      debugPrint('🕐 Scheduling counter reset at 5:00 AM Dubai time');
      debugPrint(
          '⏱️ Next reset in: ${delay.inHours} hours ${delay.inMinutes % 60} minutes');

      // جدولة المهمة اليومية
      await Workmanager().registerPeriodicTask(
        uniqueName,
        taskName,
        frequency: const Duration(days: 1), // يومياً
        initialDelay: delay,
      );

      debugPrint('✅ Daily counter reset scheduled at 5:00 AM Dubai time');
    } catch (e) {
      debugPrint('❌ Error scheduling daily reset: $e');
    }
  }

  /// تنفيذ عملية التصفير
  static Future<void> _performReset() async {
    try {
      debugPrint('🔄 Performing counter reset...');

      // Reset check in/out state
      await SharedPref().setPreferencesBoolean('isCheckedIn', false);
      await SharedPref().setPreferenceInt('checkInRecordId', 0);
      await SharedPref().setPreferencesString('checkInDisplayTime', '00:00:00');
      await SharedPref()
          .setPreferencesString('checkOutDisplayTime', '00:00:00');
      await SharedPref().removePreference('checkInProjectId');
      await SharedPref().removePreference('checkInBranchId');
      await SharedPref().removePreference('checkInAuthMethod');
      await SharedPref().setPreferenceInt('checkInTime', 0);

      // مسح وقت آخر تشيك اوت محلي حتى لا يمنع مزامنة بيانات السيرفر الجديدة
      await SharedPref().setPreferenceInt('lastLocalCheckOutTime', 0);

      // Reset timer
      await SharedPref().setPreferencesBoolean('isTimerRunning', false);
      await SharedPref().removePreference('timeLeft');

      // Update notifications
      try {
        CheckInReminderNotificationService().updateReminders();
      } catch (e) {
        debugPrint('⚠️ Error updating reminders: $e');
      }

      debugPrint('✅ Counter reset completed');
    } catch (e) {
      debugPrint('❌ Error performing reset: $e');
    }
  }

  /// تنفيذ التصفير الآن (للاختبار)
  static Future<void> executeResetNow() async {
    try {
      debugPrint('🚀 Executing counter reset now...');
      await _performReset();
    } catch (e) {
      debugPrint('❌ Error executing reset: $e');
    }
  }
}

// NOTE: The callbackDispatcher has been moved to
// unified_workmanager_dispatcher.dart to avoid conflicts.
