import 'dart:io';

import 'package:el_race/core/constants/hive_constants.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/data/services/auto_checkout_service.dart';
import 'package:el_race/data/services/counter_reset_service.dart';
import 'package:el_race/data/services/hive_service.dart';
import 'package:el_race/data/services/prayer_background_service.dart';
import 'package:el_race/data/services/task_notification_service.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';

/// WorkManager task name for periodic task-deadline checks.
const String taskDeadlineCheckTaskName = 'taskDeadlineCheck';

/// Unified WorkManager callback dispatcher.
///
/// **CRITICAL:** WorkManager only supports ONE `callbackDispatcher` per app.
/// Previously, three separate files each defined their own `callbackDispatcher`,
/// but only the LAST one registered via `Workmanager().initialize()` was active.
/// This meant prayer tasks, counter-reset tasks, or auto-checkout tasks would
/// silently fail depending on initialization order.
///
/// This file merges all three into a single entry point.
@pragma('vm:entry-point')
void unifiedCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint('📱 [WorkManager] Task received: $task');

    try {
      // ─── Prayer tasks ───
      if (task == prayerCheckTaskName ||
          task == rescheduleTaskName ||
          task.startsWith('reschedule-prayers-') ||
          task.startsWith('prayer-')) {
        return await _handlePrayerTask(task, inputData);
      }

      // ─── Counter reset task ───
      if (task == CounterResetService.taskName) {
        return await _handleCounterResetTask();
      }

      // ─── Auto checkout task ───
      if (task == AutoCheckoutService.taskName) {
        return await _handleAutoCheckoutTask();
      }

      // ─── Task deadline check ───
      if (task == taskDeadlineCheckTaskName) {
        return await _handleTaskDeadlineCheck();
      }

      debugPrint('⚠️ [WorkManager] Unknown task: $task');
      return true;
    } catch (e) {
      debugPrint('❌ [WorkManager] Error in task "$task": $e');
      return false;
    }
  });
}

// ──────────────────────────────────────────────────────────────────────────
// Prayer
// ──────────────────────────────────────────────────────────────────────────

Future<bool> _handlePrayerTask(
    String task, Map<String, dynamic>? inputData) async {
  // Reschedule all prayer tasks for the next day
  if (task == rescheduleTaskName || task.startsWith('reschedule-prayers-')) {
    try {
      await PrayerBackgroundService.reschedule();
      return true;
    } catch (e) {
      debugPrint('❌ Error rescheduling prayer tasks: $e');
      return false;
    }
  }

  try {
    // Ensure Hive is ready
    // Hive.initFlutter() uses path_provider internally, which fails on iOS
    // background isolates (WorkManager) because the platform channel is not
    // available. We fall back to Hive.init() with a manually derived path.
    if (!Hive.isBoxOpen(HiveConstants.preferencesBox)) {
      try {
        await Hive.initFlutter();
      } catch (_) {
        // iOS background isolate: derive Documents dir from systemTemp
        // systemTemp = <sandbox>/tmp  →  parent = <sandbox>
        final docsDir = Directory(
            '${Directory.systemTemp.parent.path}/Documents');
        if (!docsDir.existsSync()) docsDir.createSync(recursive: true);
        Hive.init(docsDir.path);
      }
    }

    // Skip if user not logged in
    final isLoggedIn = await HiveService.isUserLoggedIn();
    if (!isLoggedIn) return true;

    final prayerName = inputData?['prayer'] as String?;
    final rawMs = inputData?['ms'];
    final parsedMs = rawMs is int ? rawMs : int.tryParse('$rawMs');

    if (prayerName != null && parsedMs != null) {
      // فقط نعلّم الصلاة كـ "تم تشغيلها" لمنع التكرار.
      // الإشعار المجدول (zonedSchedule) يتولى الصوت والإشعار بشكل مستقل.
      // لا نشغل صوت أو إشعار من WorkManager لتفادي التكرار.
      final playedKey = 'played_${prayerName}_$parsedMs';
      await HiveService.markPrayerPlayed(playedKey);
    }

    return true;
  } catch (e) {
    debugPrint('❌ Error handling prayer task: $e');
    return false;
  }
}

// _playAdhanInBackground removed: the scheduled local notification
// (zonedSchedule with exactAllowWhileIdle + athan sound channel)
// is now the sole background adhan mechanism, preventing the
// duplicate-notification / two-sounds-at-once issue.

// ──────────────────────────────────────────────────────────────────────────
// Counter Reset
// ──────────────────────────────────────────────────────────────────────────

Future<bool> _handleCounterResetTask() async {
  try {
    await SharedPref().instantiatePreferences();

    // إذا المستخدم مو مسجّل دخول، لا تصفّر ولا تجدول تذكيرات
    final isLoggedIn = await HiveService.isUserLoggedIn();
    if (!isLoggedIn) {
      debugPrint('ℹ️ User not logged in — skipping counter reset & reminders');
      return true;
    }

    await CounterResetService.executeResetNow();
    debugPrint('✅ Counter reset task completed');
    return true;
  } catch (e) {
    debugPrint('❌ Error in counter reset task: $e');
    return false;
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Auto Checkout
// ──────────────────────────────────────────────────────────────────────────

Future<bool> _handleAutoCheckoutTask() async {
  try {
    await AutoCheckoutService.executeAutoCheckoutNow();
    await AutoCheckoutService.scheduleAutoCheckout();
    return true;
  } catch (e) {
    debugPrint('❌ Error in auto checkout task: $e');
    return false;
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Task Deadline Check
// ──────────────────────────────────────────────────────────────────────────

Future<bool> _handleTaskDeadlineCheck() async {
  try {
    await TaskNotificationService.checkUpcomingDeadlines();
    debugPrint('✅ Task deadline check completed');
    return true;
  } catch (e) {
    debugPrint('❌ Error in task deadline check: $e');
    return false;
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────────────────

String _englishPrayerName(String prayerName) {
  switch (prayerName.toLowerCase()) {
    case 'fajr':
      return 'Fajr';
    case 'dhuhr':
    case 'duhr':
    case 'zuhr':
    case 'zhuhr':
      return 'Dhuhr';
    case 'asr':
      return 'Asr';
    case 'maghrib':
    case 'magrib':
      return 'Maghrib';
    case 'isha':
    case 'isha\'':
    case 'ishaa':
    case 'esha':
      return 'Isha';
    default:
      return prayerName;
  }
}
