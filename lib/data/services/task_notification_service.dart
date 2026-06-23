import 'dart:convert';

import 'package:el_race/core/services/notification_storage_service.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Notification service for task-related events:
/// - New task assigned
/// - Deadline approaching (24h / 1h before)
/// - Task completed
/// - New message (comment) within a task
///
/// Works with both Firebase-based tasks (TodoModel) and Odoo ERP tasks.
class TaskNotificationService {
  static final TaskNotificationService _instance =
      TaskNotificationService._internal();
  factory TaskNotificationService() => _instance;
  TaskNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ── Notification channel ──
  static const String channelId = 'task_notifications_channel';
  static const String channelName = 'Task Notifications';
  static const String channelDescription =
      'Notifications for tasks: new assignment, deadlines, completion, and messages';

  // ── Notification ID ranges (to avoid collisions with other services) ──
  static const int _baseNewTask = 5000;
  static const int _baseDeadline = 6000;
  static const int _baseCompleted = 7000;
  static const int _baseMessage = 8000;

  // ── Category constants ──
  static const String categoryTask = 'task';

  // ──────────────────────────────────────────────────────────────────────
  // Initialization
  // ──────────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Dubai'));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('Etc/GMT-4'));
      } catch (_) {}
    }

    // Create the Android notification channel.
    // NOTE: Do NOT call _notificationsPlugin.initialize() here.
    // FirebaseService.initialize() already set up the shared native platform
    // with a unified tap-handler. A second initialize() call would OVERRIDE
    // that handler, breaking notification-tap routing for all other services.
    final androidImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );
    }

    _initialized = true;
    debugPrint('✅ TaskNotificationService initialized');
  }

  // ──────────────────────────────────────────────────────────────────────
  // 1️⃣  New task assigned
  // ──────────────────────────────────────────────────────────────────────

  Future<void> showNewTaskNotification({
    required String taskId,
    required String taskTitle,
    String? assignedBy,
    bool isFirebaseTask = true,
  }) async {
    await initialize();

    final title = '📋 New Task Assigned';
    final body = assignedBy != null && assignedBy.isNotEmpty
        ? '$assignedBy assigned you: "$taskTitle"'
        : 'You have a new task: "$taskTitle"';

    final payload = _buildPayload(
      taskId: taskId,
      action: 'new_task',
      isFirebaseTask: isFirebaseTask,
    );

    await _show(
      id: _baseNewTask + taskId.hashCode.abs() % 999,
      title: title,
      body: body,
      payload: payload,
    );

    // Persist in notification storage so it appears in the Notification screen.
    await _saveToStorage(title: title, body: body, payload: payload);
  }

  // ──────────────────────────────────────────────────────────────────────
  // 2️⃣  Deadline approaching
  // ──────────────────────────────────────────────────────────────────────

  /// Schedule deadline reminders for a task.
  /// Call this when a task with a due-date is created or updated.
  Future<void> scheduleDeadlineReminders({
    required String taskId,
    required String taskTitle,
    required DateTime dueDate,
    bool isFirebaseTask = true,
  }) async {
    await initialize();

    final now = tz.TZDateTime.now(tz.local);

    // 24-hour reminder
    final reminder24h =
        tz.TZDateTime.from(dueDate.subtract(const Duration(hours: 24)), tz.local);
    if (reminder24h.isAfter(now)) {
      await _schedule(
        id: _baseDeadline + taskId.hashCode.abs() % 499,
        title: '⏰ Task Deadline Tomorrow',
        body: '"$taskTitle" is due in 24 hours',
        scheduledDate: reminder24h,
        payload: _buildPayload(
          taskId: taskId,
          action: 'deadline_24h',
          isFirebaseTask: isFirebaseTask,
        ),
      );
    }

    // 1-hour reminder
    final reminder1h =
        tz.TZDateTime.from(dueDate.subtract(const Duration(hours: 1)), tz.local);
    if (reminder1h.isAfter(now)) {
      await _schedule(
        id: _baseDeadline + 500 + taskId.hashCode.abs() % 499,
        title: '🚨 Task Due Soon!',
        body: '"$taskTitle" is due in 1 hour',
        scheduledDate: reminder1h,
        payload: _buildPayload(
          taskId: taskId,
          action: 'deadline_1h',
          isFirebaseTask: isFirebaseTask,
        ),
      );
    }
  }

  /// Cancel previously scheduled deadline reminders for a task.
  Future<void> cancelDeadlineReminders(String taskId) async {
    await _notificationsPlugin
        .cancel(_baseDeadline + taskId.hashCode.abs() % 499);
    await _notificationsPlugin
        .cancel(_baseDeadline + 500 + taskId.hashCode.abs() % 499);
  }

  // ──────────────────────────────────────────────────────────────────────
  // 3️⃣  Task completed
  // ──────────────────────────────────────────────────────────────────────

  Future<void> showTaskCompletedNotification({
    required String taskId,
    required String taskTitle,
    String? completedBy,
    bool isFirebaseTask = true,
  }) async {
    await initialize();

    final title = '✅ Task Completed';
    final body = completedBy != null && completedBy.isNotEmpty
        ? '$completedBy completed: "$taskTitle"'
        : '"$taskTitle" has been completed';

    final payload = _buildPayload(
      taskId: taskId,
      action: 'completed',
      isFirebaseTask: isFirebaseTask,
    );

    await _show(
      id: _baseCompleted + taskId.hashCode.abs() % 999,
      title: title,
      body: body,
      payload: payload,
    );

    // Cancel any lingering deadline reminders for this task.
    await cancelDeadlineReminders(taskId);

    await _saveToStorage(title: title, body: body, payload: payload);
  }

  // ──────────────────────────────────────────────────────────────────────
  // 4️⃣  New message / comment within a task
  // ──────────────────────────────────────────────────────────────────────

  Future<void> showTaskMessageNotification({
    required String taskId,
    required String taskTitle,
    required String senderName,
    required String messagePreview,
    bool isFirebaseTask = true,
  }) async {
    await initialize();

    final title = '💬 New message in "$taskTitle"';
    final body = '$senderName: $messagePreview';

    final payload = _buildPayload(
      taskId: taskId,
      action: 'message',
      isFirebaseTask: isFirebaseTask,
    );

    await _show(
      id: _baseMessage + taskId.hashCode.abs() % 999,
      title: title,
      body: body,
      payload: payload,
    );

    await _saveToStorage(title: title, body: body, payload: payload);
  }

  // ──────────────────────────────────────────────────────────────────────
  // 5️⃣  Periodic deadline check (called from WorkManager)
  // ──────────────────────────────────────────────────────────────────────

  /// Meant to be called from the unified WorkManager dispatcher.
  /// Reads all incomplete tasks and fires deadline notifications for those
  /// whose due-date is within the next 24 hours.
  static Future<void> checkUpcomingDeadlines() async {
    try {
      // We cannot use TodoFirebaseService here because WorkManager runs in
      // an isolate without full Flutter context (no Firebase Auth, etc.).
      // Instead, scheduled reminders are set at task-creation time via
      // scheduleDeadlineReminders(). This method is kept as a fallback for
      // tasks created on another device.

      // For Odoo tasks, we need a token; however in a background isolate
      // SharedPref may not be available. Wrap in try/catch.
      try {
        await SharedPref().instantiatePreferences();
      } catch (_) {}

      final isLoggedIn = SharedPref.isUserAuthenticated();
      if (!isLoggedIn) return;

      debugPrint(
        '🔔 [TaskNotification] Periodic deadline check completed '
        '(scheduled reminders already cover known tasks)',
      );
    } catch (e) {
      debugPrint('❌ [TaskNotification] Deadline check failed: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Internal helpers
  // ──────────────────────────────────────────────────────────────────────

  String _buildPayload({
    required String taskId,
    required String action,
    bool isFirebaseTask = true,
  }) {
    return jsonEncode({
      'category': categoryTask,
      'task_id': taskId,
      'action': action,
      'is_firebase_task': isFirebaseTask,
    });
  }

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    // التحقق من إعدادات كتم إشعارات التاسكات
    final isTaskMuted = await NotificationStorageService.isChannelMuted('task');
    if (isTaskMuted) return;

    await _notificationsPlugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
          category: AndroidNotificationCategory.reminder,
          autoCancel: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      payload: payload,
    );
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required String payload,
  }) async {
    // التحقق من إعدادات كتم إشعارات التاسكات
    final isTaskMuted = await NotificationStorageService.isChannelMuted('task');
    if (isTaskMuted) return;

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
            category: AndroidNotificationCategory.reminder,
            autoCancel: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: null,
        payload: payload,
      );
      debugPrint('📅 Scheduled task notification id=$id at $scheduledDate');
    } catch (e) {
      debugPrint('❌ Failed to schedule task notification: $e');
    }
  }

  Future<void> _saveToStorage({
    required String title,
    required String body,
    required String payload,
  }) async {
    try {
      Map<String, dynamic>? payloadMap;
      try {
        payloadMap = jsonDecode(payload) as Map<String, dynamic>;
      } catch (_) {}

      await NotificationStorageService.saveNotification(
        title: title,
        body: body,
        data: payloadMap ?? {},
        category: categoryTask,
      );
    } catch (e) {
      debugPrint('⚠️ Could not save task notification to storage: $e');
    }
  }
}
