import 'dart:async';
import 'package:adhan/adhan.dart';
import 'package:el_race/data/services/prayer_notification_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

// اسم المهمة
const String prayerCheckTaskName = 'prayerCheckTask';
const String rescheduleTaskName = 'reschedulePrayerTasks';

// NOTE: The background callbackDispatcher has been moved to
// unified_workmanager_dispatcher.dart to avoid conflicts between
// prayer, auto-checkout, and counter-reset services.
// Only ONE callbackDispatcher can be active per app.

// Background notification / audio helpers have been moved to
// unified_workmanager_dispatcher.dart

class PrayerBackgroundService {
  static Future<void> initialize() async {
    // NOTE: Workmanager().initialize() is now called once from main.dart
    // with the unified dispatcher. Do NOT call it here.

    // جدولة المهام على أوقات الصلاة
    await _schedulePrayerTasks();

    // debugPrint('Prayer background service initialized');
  }

  static Future<void> _schedulePrayerTasks() async {
    try {
      // debugPrint('🔄 Scheduling prayer tasks...');
      // IMPORTANT: do not call cancelAll() هنا حتى لا نلغي مهام خدمات أخرى.

      final notificationService = PrayerNotificationService();
      await notificationService.initialize();

      // حساب أوقات الصلاة
      // Try to use device last-known location for accurate local Adhan times
      Position? last;
      try {
        last = await Geolocator.getLastKnownPosition();
      } catch (_) {
        last = null;
      }

      final coords = last != null
          ? Coordinates(last.latitude, last.longitude)
          : Coordinates(25.2048, 55.2708); // fallback Dubai
      final params = CalculationMethod.egyptian.getParameters()
        ..madhab = Madhab
            .shafi; // تم تغييره من hanafi إلى shafi ليتطابق مع Aladhan API method=5
      final prayerTimes = PrayerTimes.today(coords, params);

      final now = DateTime.now();
      // debugPrint('🕐 Current time: ${now.hour}:${now.minute}:${now.second}');

      final prayers = [
        {'name': 'fajr', 'time': prayerTimes.fajr},
        {'name': 'dhuhr', 'time': prayerTimes.dhuhr},
        {'name': 'asr', 'time': prayerTimes.asr},
        {'name': 'maghrib', 'time': prayerTimes.maghrib},
        {'name': 'isha', 'time': prayerTimes.isha},
      ];

      for (var prayerData in prayers) {
        final prayerTime = prayerData['time'] as DateTime;
        final prayerName = prayerData['name'] as String;

        // جدول المهمة فقط إذا كان الوقت لم يمر بعد
        if (prayerTime.isAfter(now)) {
          // جدولة إشعار محلي يشتغل حتى لو التطبيق مغلق
          // هذا هو المسار الوحيد للأذان في الخلفية (بدون WorkManager)
          // لتفادي تشغيل صوتين أو إشعارين في نفس الوقت.
          await notificationService.scheduleAdhanNotification(
            prayerName,
            prayerTime,
          );

          // إلغاء أي مهمة WorkManager قديمة لهذه الصلاة (تنظيف)
          final ms = prayerTime.millisecondsSinceEpoch;
          final taskUniqueName = 'prayer-$prayerName-$ms';
          await Workmanager().cancelByUniqueName(taskUniqueName);

          // debugPrint(
          //     '✅ Scheduled $prayerName at ${prayerTime.hour}:${prayerTime.minute} (in ${delay.inMinutes}m ${delay.inSeconds % 60}s)');
        } else {
          // debugPrint('⏭️ Skipped $prayerName (already passed)');
        }
      }

      // جدول مهمة لإعادة الجدولة في منتصف الليل (للصلوات القادمة)
      final tomorrow = DateTime(now.year, now.month, now.day + 1, 0, 5);
      final delayUntilTomorrow = tomorrow.difference(now);

      final rescheduleUniqueName =
          'reschedule-prayers-${now.year}-${now.month}-${now.day}';
      await Workmanager().cancelByUniqueName(rescheduleUniqueName);
      await Workmanager().registerOneOffTask(
        rescheduleUniqueName,
        'reschedulePrayerTasks',
        initialDelay: delayUntilTomorrow,
        constraints: Constraints(
          networkType: NetworkType.notRequired,
        ),
      );

      // debugPrint('Scheduled $taskId prayer tasks for today');
    } catch (e) {
      // debugPrint('Error scheduling prayer tasks: $e');
    }
  }

  static Future<void> reschedule() async {
    await _schedulePrayerTasks();
  }

  static Future<void> cancelAll() async {
    final now = DateTime.now();
    final keys = <String>[
      'fajr',
      'dhuhr',
      'asr',
      'maghrib',
      'isha',
    ];

    for (final prayer in keys) {
      for (int dayOffset = 0; dayOffset <= 1; dayOffset++) {
        final date = now.add(Duration(days: dayOffset));
        final roughMs =
            DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
        await Workmanager().cancelByUniqueName('prayer-$prayer-$roughMs');
      }
    }

    await Workmanager().cancelByUniqueName(
      'reschedule-prayers-${now.year}-${now.month}-${now.day}',
    );
    // debugPrint('Prayer background service cancelled');
  }
}
