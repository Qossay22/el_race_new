import 'dart:convert';

import 'package:el_race/core/services/notification_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationStorageService {
  static const String _notificationsKey = 'stored_notifications';
  static const String _unreadCountKey = 'unread_notification_count';
  static const String _muteSettingsKey = 'notification_mute_settings_v1';
  static const String _muteSettingsFetchedAtKey =
      'notification_mute_settings_v1_fetched_at';
  static const String _categoriesKey = 'notification_categories_v1';
  static const String _categoriesFetchedAtKey =
      'notification_categories_v1_fetched_at';

  static const Duration _muteSettingsCacheTtl = Duration(minutes: 5);
  static const Duration _categoriesCacheTtl = Duration(minutes: 5);

  static Map<String, bool>? _memoryMuteSettings;
  static DateTime? _memoryMuteSettingsFetchedAt;
  static List<NotificationCategoryApiModel>? _memoryCategories;
  static DateTime? _memoryCategoriesFetchedAt;

  /// Callback to notify when notification count changes.
  static void Function()? onCountChanged;

  /// Fast badge count from local cache (no API call).
  /// Use this for real-time badge updates (e.g. after a push notification
  /// is saved locally) to avoid a race condition where the API has not yet
  /// indexed the new notification.
  static Future<int> getLocalStoredCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_unreadCountKey) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static String _normalizeKey(String value) {
    return value.trim().toLowerCase();
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value.toString().trim().toLowerCase() == 'true';
  }

  static DateTime? _readFetchedAt(SharedPreferences prefs) {
    final millis = prefs.getInt(_muteSettingsFetchedAtKey);
    if (millis == null || millis <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static bool _isFresh(DateTime? fetchedAt, DateTime now) {
    if (fetchedAt == null) return false;
    return now.difference(fetchedAt) <= _muteSettingsCacheTtl;
  }

  static Map<String, bool> _readCachedMuteSettings(SharedPreferences prefs) {
    final raw = prefs.getString(_muteSettingsKey);
    if (raw == null || raw.trim().isEmpty) {
      return <String, bool>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, bool>{};
      }

      final result = <String, bool>{};
      for (final entry in decoded.entries) {
        final key = _normalizeKey(entry.key.toString());
        if (key.isEmpty) continue;
        result[key] = _asBool(entry.value);
      }
      return result;
    } catch (_) {
      return <String, bool>{};
    }
  }

  static String _humanizeCategory(String value) {
    final text = value.trim();
    if (text.isEmpty) return 'Notification';

    final parts = text
        .split(RegExp(r'[._-]+'))
        .where((part) => part.trim().isNotEmpty)
        .map((part) {
      final p = part.trim();
      return '${p[0].toUpperCase()}${p.substring(1)}';
    }).toList(growable: false);

    if (parts.isEmpty) return 'Notification';
    return parts.join(' ');
  }

  static List<NotificationCategoryApiModel> _readCachedCategories(
    SharedPreferences prefs,
  ) {
    final raw = prefs.getString(_categoriesKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <NotificationCategoryApiModel>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <NotificationCategoryApiModel>[];
      }

      final items = <NotificationCategoryApiModel>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item.cast<String, dynamic>());
        final model = _normalizeKey('${map['model'] ?? ''}');
        if (model.isEmpty) continue;

        items.add(
          NotificationCategoryApiModel(
            model: model,
            title: (map['title'] ?? '').toString().trim().isEmpty
                ? _humanizeCategory(model)
                : map['title'].toString().trim(),
          ),
        );
      }

      return items;
    } catch (_) {
      return const <NotificationCategoryApiModel>[];
    }
  }

  static Future<void> _writeCachedCategories(
    SharedPreferences prefs,
    List<NotificationCategoryApiModel> categories,
  ) async {
    final now = DateTime.now();
    final normalized = <NotificationCategoryApiModel>[];
    final seen = <String>{};

    for (final item in categories) {
      final model = _normalizeKey(item.model);
      if (model.isEmpty || seen.contains(model)) continue;
      seen.add(model);
      normalized.add(
        NotificationCategoryApiModel(
          model: model,
          title: item.title.trim().isEmpty
              ? _humanizeCategory(model)
              : item.title.trim(),
        ),
      );
    }

    await prefs.setString(
      _categoriesKey,
      jsonEncode(normalized.map((e) => e.toMap()).toList(growable: false)),
    );
    await prefs.setInt(_categoriesFetchedAtKey, now.millisecondsSinceEpoch);

    _memoryCategories = List<NotificationCategoryApiModel>.from(normalized);
    _memoryCategoriesFetchedAt = now;
  }

  static Future<void> _writeCachedMuteSettings(
    SharedPreferences prefs,
    Map<String, bool> settings,
  ) async {
    final normalized = <String, bool>{};
    for (final entry in settings.entries) {
      final key = _normalizeKey(entry.key);
      if (key.isEmpty) continue;
      normalized[key] = entry.value;
    }

    final now = DateTime.now();
    await prefs.setString(_muteSettingsKey, jsonEncode(normalized));
    await prefs.setInt(_muteSettingsFetchedAtKey, now.millisecondsSinceEpoch);

    _memoryMuteSettings = Map<String, bool>.from(normalized);
    _memoryMuteSettingsFetchedAt = now;
  }

  static Future<Map<String, bool>> getMuteSettings({
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    if (!forceRefresh &&
        _memoryMuteSettings != null &&
        _isFresh(_memoryMuteSettingsFetchedAt, now)) {
      return Map<String, bool>.from(_memoryMuteSettings!);
    }

    final cachedSettings = _readCachedMuteSettings(prefs);
    final cachedFetchedAt = _readFetchedAt(prefs);

    if (!forceRefresh &&
        cachedSettings.isNotEmpty &&
        _isFresh(cachedFetchedAt, now)) {
      _memoryMuteSettings = Map<String, bool>.from(cachedSettings);
      _memoryMuteSettingsFetchedAt = cachedFetchedAt;
      return cachedSettings;
    }

    try {
      final remoteSettings =
          await NotificationApiService.getNotificationPreferences();
      await _writeCachedMuteSettings(prefs, remoteSettings);
      return Map<String, bool>.from(remoteSettings);
    } catch (e) {
      if (cachedSettings.isNotEmpty) {
        _memoryMuteSettings = Map<String, bool>.from(cachedSettings);
        _memoryMuteSettingsFetchedAt = cachedFetchedAt;
        return cachedSettings;
      }
      if (forceRefresh) {
        throw Exception('Unable to fetch notification preferences: $e');
      }
      return <String, bool>{};
    }
  }

  static Future<List<NotificationCategoryApiModel>> getNotificationCategories({
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    if (!forceRefresh &&
        _memoryCategories != null &&
        _isFresh(_memoryCategoriesFetchedAt, now)) {
      return List<NotificationCategoryApiModel>.from(_memoryCategories!);
    }

    final cachedCategories = _readCachedCategories(prefs);
    final cachedFetchedAt = _readFetchedAtCategories(prefs);

    if (!forceRefresh &&
        cachedCategories.isNotEmpty &&
        _isFresh(cachedFetchedAt, now)) {
      _memoryCategories = List<NotificationCategoryApiModel>.from(
        cachedCategories,
      );
      _memoryCategoriesFetchedAt = cachedFetchedAt;
      return cachedCategories;
    }

    try {
      final remoteCategories =
          await NotificationApiService.getNotificationCategories();
      if (remoteCategories.isNotEmpty) {
        await _writeCachedCategories(prefs, remoteCategories);
        return List<NotificationCategoryApiModel>.from(remoteCategories);
      }
    } catch (_) {
      // Fallback below.
    }

    if (cachedCategories.isNotEmpty) {
      _memoryCategories = List<NotificationCategoryApiModel>.from(
        cachedCategories,
      );
      _memoryCategoriesFetchedAt = cachedFetchedAt;
      return cachedCategories;
    }

    // Last fallback: infer categories from already stored notifications.
    final allNotifications = await _getStoredNotifications();
    final inferred = <String, NotificationCategoryApiModel>{};
    for (final item in allNotifications) {
      final model = _normalizeKey('${item['category'] ?? ''}');
      if (model.isEmpty) continue;
      inferred[model] = NotificationCategoryApiModel(
        model: model,
        title: _humanizeCategory(model),
      );
    }

    if (inferred.isEmpty) {
      inferred['notification'] = const NotificationCategoryApiModel(
        model: 'notification',
        title: 'Notifications',
      );
    }

    final fallback = inferred.values.toList(growable: false)
      ..sort((a, b) => a.title.compareTo(b.title));
    await _writeCachedCategories(prefs, fallback);
    return fallback;
  }

  static DateTime? _readFetchedAtCategories(SharedPreferences prefs) {
    final millis = prefs.getInt(_categoriesFetchedAtKey);
    if (millis == null || millis <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static Future<void> setMuteSetting(String channel, bool muted) async {
    final key = _normalizeKey(channel);
    if (key.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final previous = await getMuteSettings();
    final currentValue = previous[key] == true;
    if (currentValue == muted) return;

    final optimistic = Map<String, bool>.from(previous)..[key] = muted;
    await _writeCachedMuteSettings(prefs, optimistic);

    try {
      final apiResponse =
          await NotificationApiService.updateNotificationPreference(
        model: key,
        muted: muted,
      );
      print('[MuteSettings][UpdateResponse][$key] $apiResponse');
      await _updateUnreadCount();
      onCountChanged?.call();
    } catch (e) {
      await _writeCachedMuteSettings(prefs, previous);
      throw Exception('Unable to update notification preference: $e');
    }
  }

  /// حفظ إعداد كتم محلي فقط (بدون مزامنة مع الـ API).
  /// يُستخدم للفئات المحلية مثل chat_message, task, adhan.
  static Future<void> setLocalMuteSetting(String channel, bool muted) async {
    final key = _normalizeKey(channel);
    if (key.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final previous = await getMuteSettings();
    final currentValue = previous[key] == true;
    if (currentValue == muted) return;

    final optimistic = Map<String, bool>.from(previous)..[key] = muted;
    await _writeCachedMuteSettings(prefs, optimistic);
  }

  static Future<bool> isChannelMuted(String channel) async {
    final key = _normalizeKey(channel);
    if (key.isEmpty) return false;
    final settings = await getMuteSettings();
    return settings[key] == true;
  }

  static Future<bool> shouldMuteNotification({
    String? category,
    Map<String, dynamic>? data,
  }) async {
    final settings = await getMuteSettings();
    if (settings.isEmpty) return false;

    final candidates = <String>[
      if (category != null) category,
      if (data != null) ...[
        '${data['category'] ?? ''}',
        '${data['type'] ?? ''}',
        '${data['model'] ?? ''}',
        '${data['model_name'] ?? ''}',
        '${data['record_type'] ?? ''}',
        '${data['target_type'] ?? ''}',
      ],
    ];

    for (final candidate in candidates) {
      final key = _normalizeKey(candidate);
      if (key.isEmpty) continue;
      if (settings[key] == true) {
        return true;
      }
    }

    return false;
  }

  /// Save a new notification locally.
  static Future<void> saveNotification({
    required String title,
    required String body,
    String? imageUrl,
    Map<String, dynamic>? data,
    String? category,
  }) async {
    try {
      final notificationCategory = _normalizeKey(category ??
          '${data?['category'] ?? data?['type'] ?? 'notification'}');

      final shouldMute = await shouldMuteNotification(
        category: notificationCategory,
        data: data,
      );
      if (shouldMute) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      var notifications = await _getStoredNotifications();

      notifications.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': title,
        'body': body,
        'imageUrl': imageUrl,
        'data': data,
        'category': notificationCategory.isEmpty
            ? 'notification'
            : notificationCategory,
        'timestamp': DateTime.now().toIso8601String(),
        'isRead': false,
      });

      if (notifications.length > 100) {
        notifications = notifications.sublist(0, 100);
      }

      await _saveStoredNotifications(notifications, prefs);
      // Store total local count (consistent with what getTotalCount writes)
      // so the badge updates immediately without an API round-trip.
      await prefs.setInt(_unreadCountKey, notifications.length);
      onCountChanged?.call();
    } catch (_) {
      // Keep silent to avoid crashing push pipeline.
    }
  }

  /// Get notifications. API data is preferred, local cache is fallback.
  static Future<List<Map<String, dynamic>>> getNotifications({
    int limit = 500,
    int offset = 0,
  }) async {
    try {
      final apiResult = await NotificationApiService.getNotifications(
        limit: limit,
        offset: offset,
      );

      final normalized = apiResult.notifications
          .map(_normalizeApiNotification)
          .toList(growable: true);

      final prefs = await SharedPreferences.getInstance();
      if (offset <= 0) {
        await _saveStoredNotifications(normalized, prefs);
      } else {
        final storedNotifications = await _getStoredNotifications();
        final mergedNotifications = List<Map<String, dynamic>>.from(
          storedNotifications,
        );
        final existingIds = mergedNotifications
            .map((notification) => '${notification['id'] ?? ''}')
            .where((id) => id.isNotEmpty)
            .toSet();

        for (final notification in normalized) {
          final id = '${notification['id'] ?? ''}';
          if (id.isNotEmpty && existingIds.contains(id)) continue;
          mergedNotifications.add(notification);
          if (id.isNotEmpty) existingIds.add(id);
        }

        await _saveStoredNotifications(mergedNotifications, prefs);
      }

      // Prefer API unread total. If unavailable, only compute from a full
      // legacy fetch to avoid treating one paged chunk as the full list.
      final unreadCount = apiResult.unreadCount ??
          (offset <= 0 && limit >= 500
              ? normalized.where((n) => n['isRead'] != true).length
              : null);
      if (unreadCount != null) {
        await prefs.setInt(_unreadCountKey, unreadCount);
        onCountChanged?.call();
      }

      return normalized;
    } catch (_) {
      final storedNotifications = await _getStoredNotifications();
      if (limit <= 0) return storedNotifications;
      if (offset >= storedNotifications.length) {
        return const <Map<String, dynamic>>[];
      }
      final end = offset + limit;
      final boundedEnd =
          end > storedNotifications.length ? storedNotifications.length : end;
      return storedNotifications.sublist(offset, boundedEnd);
    }
  }

  /// Get unread notification count (from /api/notifications list).
  static Future<int> getTotalCount() async {
    try {
      final notifications = await getNotifications();
      final count = notifications.where((n) => n['isRead'] != true).length;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_unreadCountKey, count);
      return count;
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getInt(_unreadCountKey) ?? 0;
      } catch (_) {
        return 0;
      }
    }
  }

  static Map<String, dynamic> _normalizeApiNotification(
    Map<String, dynamic> raw,
  ) {
    final normalized = Map<String, dynamic>.from(raw);

    dynamic notificationData = raw['data'] ?? raw['payload'];
    if (notificationData is String && notificationData.trim().isNotEmpty) {
      try {
        notificationData = jsonDecode(notificationData);
      } catch (_) {
        // Keep original value.
      }
    }

    final rawRead = raw['is_read'] ?? raw['isRead'] ?? false;
    final isRead = rawRead == true ||
        rawRead == 1 ||
        rawRead.toString().toLowerCase() == 'true';

    normalized['id'] =
        (raw['id'] ?? DateTime.now().millisecondsSinceEpoch).toString();
    normalized['title'] =
        (raw['title'] ?? raw['subject'] ?? 'Notification').toString();
    normalized['body'] = (raw['body'] ?? raw['message'] ?? '').toString();
    normalized['imageUrl'] = raw['image_url'] ?? raw['imageUrl'];
    normalized['data'] = notificationData;
    normalized['payload'] = notificationData;
    normalized['category'] = _normalizeKey(
      '${raw['category'] ?? raw['type'] ?? (notificationData is Map ? notificationData['model'] : null) ?? 'notification'}',
    );
    normalized['timestamp'] = (raw['created_at'] ??
            raw['timestamp'] ??
            raw['date'] ??
            raw['sent_at'] ??
            '')
        .toString();
    normalized['timeAgo'] =
        (raw['time_ago'] ?? raw['timeAgo'] ?? '').toString();
    normalized['isRead'] = isRead;
    normalized['readAt'] = raw['read_at'] ?? raw['readAt'];

    return normalized;
  }

  static Future<List<Map<String, dynamic>>> _getStoredNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_notificationsKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveStoredNotifications(
    List<Map<String, dynamic>> notifications,
    SharedPreferences prefs,
  ) async {
    final jsonString = jsonEncode(notifications);
    await prefs.setString(_notificationsKey, jsonString);
  }

  /// Mark a single notification as read.
  static Future<void> markAsRead(String notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notifications = await _getStoredNotifications();

      final index = notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        notifications[index]['isRead'] = true;
        notifications[index]['readAt'] = DateTime.now().toIso8601String();
        await _saveStoredNotifications(notifications, prefs);
        await _updateUnreadCount();
        onCountChanged?.call();
      }

      await NotificationApiService.markAsRead(notificationId);
    } catch (_) {
      // Local state has already been updated when possible.
    }
  }

  /// Mark all notifications as read.
  static Future<void> markAllAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notifications = await _getStoredNotifications();

      for (final notification in notifications) {
        notification['isRead'] = true;
      }

      await _saveStoredNotifications(notifications, prefs);
      await prefs.setInt(_unreadCountKey, 0);
      onCountChanged?.call();

      await NotificationApiService.markAllAsRead();
    } catch (_) {
      // Ignore to keep UI stable.
    }
  }

  /// Get unread notification count.
  static Future<int> getUnreadCount() async {
    try {
      final apiUnreadCount = await NotificationApiService.getUnreadCount();
      if (apiUnreadCount != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_unreadCountKey, apiUnreadCount);
        return apiUnreadCount;
      }
    } catch (_) {
      // Fallback to local cache below.
    }

    try {
      final notifications = await _getStoredNotifications();
      return notifications.where((n) => n['isRead'] == false).length;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> _updateUnreadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notifications = await _getStoredNotifications();
      final count = notifications.where((n) => n['isRead'] == false).length;
      await prefs.setInt(_unreadCountKey, count);
    } catch (_) {
      // Ignore cache update failures.
    }
  }

  /// Delete a notification from local cache.
  static Future<void> deleteNotification(String notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notifications = await _getStoredNotifications();

      notifications.removeWhere((n) => n['id'] == notificationId);

      await _saveStoredNotifications(notifications, prefs);
      await _updateUnreadCount();
      onCountChanged?.call();
    } catch (_) {
      // Ignore failures.
    }
  }

  /// Get notifications by category.
  static Future<List<Map<String, dynamic>>> getNotificationsByCategory(
    String category,
  ) async {
    try {
      final allNotifications = await getNotifications();
      final selected = _normalizeKey(category);
      if (selected == 'all') {
        return allNotifications;
      }

      return allNotifications.where((notification) {
        final itemCategory = _normalizeKey('${notification['category'] ?? ''}');
        return itemCategory == selected;
      }).toList(growable: false);
    } catch (_) {
      return [];
    }
  }

  /// Clear all local notifications.
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_notificationsKey);
      await prefs.setInt(_unreadCountKey, 0);
      onCountChanged?.call();
    } catch (_) {
      // Ignore failures.
    }
  }

  /// Add sample notifications for testing.
  static Future<void> addSampleNotifications() async {
    await saveNotification(
      title: 'Leave Approved',
      body: 'Your leave request from Jan 15 to Jan 20 has been approved.',
      category: 'notification',
    );

    await saveNotification(
      title: 'Attendance Reminder',
      body: 'Please ensure to check in before 9:00 AM.',
      category: 'notification',
    );

    await saveNotification(
      title: 'New Project Launch',
      body:
          'We are excited to announce the launch of Abu Dhabi Dialysis Center project.',
      category: 'announcement',
    );

    await saveNotification(
      title: 'Company Meeting',
      body: 'All staff meeting scheduled for tomorrow at 10:00 AM.',
      category: 'announcement',
    );

    await saveNotification(
      title: 'Safety Guidelines',
      body:
          'Please review the updated safety guidelines for construction sites.',
      category: 'circular',
    );

    await saveNotification(
      title: 'Policy Update',
      body: 'New HR policies effective from next month. Please read carefully.',
      category: 'circular',
    );
  }
}
