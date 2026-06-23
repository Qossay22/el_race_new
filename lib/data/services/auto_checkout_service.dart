import 'dart:async';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/data/services/checkin_reminder_notification_service.dart';
import 'package:el_race/ui/presentation/landing_screen/bloc/checkin_out_bloc/check_out_bloc.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/timer_controller.dart';
import 'package:el_race/utils/di.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:workmanager/workmanager.dart';

/// خدمة تنفيذ الـ Auto Check-out التلقائي في الساعة 5:10 مساءً
///
/// هذه الخدمة تستخدم WorkManager لجدولة check-out تلقائي يومياً في الساعة 5:10 مساءً
/// بدون طلب Face ID authentication
class AutoCheckoutService {
  static const String taskName = 'auto_checkout_task';
  static const String uniqueName = 'daily_auto_checkout';
  static const int _autoCheckoutHour = 17;
  static const int _autoCheckoutMinute = 10;

  /// تهيئة خدمة الـ Auto Check-out
  static Future<void> initialize() async {
    try {
      // NOTE: Workmanager().initialize() is now called once from main.dart
      // with the unified dispatcher. Do NOT call it here.
      debugPrint('✅ AutoCheckoutService initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing AutoCheckoutService: $e');
    }
  }

  /// جدولة مهمة Auto Check-out اليومية
  ///
  /// هذه المهمة تُنفذ يومياً في الساعة 5:10 مساءً (17:10)
  static Future<void> scheduleAutoCheckout() async {
    try {
      // إلغاء أي مهام سابقة
      await Workmanager().cancelByUniqueName(uniqueName);

      // حساب الوقت حتى الساعة 5:10 مساءً القادمة
      final now = DateTime.now();
      DateTime targetTime = DateTime(
        now.year,
        now.month,
        now.day,
        _autoCheckoutHour, // الساعة 5 مساءً
        _autoCheckoutMinute, // 10 دقائق
        0, // ثانية
      );

      // إذا كانت الساعة الآن بعد 5:10 مساءً، جدول للغد
      if (now.isAfter(targetTime)) {
        targetTime = targetTime.add(const Duration(days: 1));
      }

      final delay = targetTime.difference(now);

      debugPrint('🕐 Scheduling auto checkout at: ${targetTime.toString()}');
      debugPrint('⏱️ Delay: ${delay.inMinutes} minutes');

      // جدولة المهمة اليومية
      await Workmanager().registerPeriodicTask(
        uniqueName,
        taskName,
        frequency: const Duration(days: 1), // يومياً
        initialDelay: delay,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );

      debugPrint('✅ Auto checkout scheduled successfully');
    } catch (e) {
      debugPrint('❌ Error scheduling auto checkout: $e');
    }
  }

  /// إلغاء جدولة Auto Check-out
  static Future<void> cancelAutoCheckout() async {
    try {
      await Workmanager().cancelByUniqueName(uniqueName);
      debugPrint('✅ Auto checkout cancelled');
    } catch (e) {
      debugPrint('❌ Error cancelling auto checkout: $e');
    }
  }

  /// تنفيذ Auto Check-out الآن (للاختبار)
  static Future<void> executeAutoCheckoutNow() async {
    try {
      debugPrint('🚀 Executing auto checkout now...');
      await _performAutoCheckout();
    } catch (e) {
      debugPrint('❌ Error executing auto checkout: $e');
    }
  }

  /// تنفيذ عملية Auto Check-out الفعلية
  static Future<void> _performAutoCheckout() async {
    try {
      // التحقق من حالة Check-in
      final isCheckedIn = SharedPref().getPreferenceBoolean('isCheckedIn');

      if (!isCheckedIn) {
        debugPrint('ℹ️ User is not checked in, skipping auto checkout');
        return;
      }

      // الحصول على checkInRecordId
      final checkInRecordId = SharedPref().getPreferenceInt('checkInRecordId');

      if (checkInRecordId == 0) {
        debugPrint('⚠️ No check-in record found');
        return;
      }

      debugPrint('🔄 Performing auto checkout for record: $checkInRecordId');

      // تنفيذ Check-out بدون Face ID (isAutoCheckout = true)
      sl
          .get<CheckOutBloc>()
          .add(CheckOutET(checkInRecordId, isAutoCheckout: true));

      // إيقاف المؤقت
      try {
        Get.find<TimerController>().stopTimer();
      } catch (e) {
        debugPrint('⚠️ Timer not found (app might be closed): $e');
      }

      // تحديث الحالة
      await SharedPref().setPreferencesBoolean('isCheckedIn', false);
      await SharedPref().setPreferenceInt('checkInRecordId', 0);
      await SharedPref().removePreference('checkInProjectId');
      await SharedPref().removePreference('checkInBranchId');
      await SharedPref().removePreference('checkInAuthMethod');

      try {
        await CheckInReminderNotificationService().updateReminders();
      } catch (e) {
        debugPrint('⚠️ Error updating reminders after auto checkout: $e');
      }

      debugPrint('✅ Auto checkout completed successfully');
    } catch (e) {
      debugPrint('❌ Error performing auto checkout: $e');
    }
  }
}

// NOTE: The callbackDispatcher has been moved to
// unified_workmanager_dispatcher.dart to avoid conflicts.
