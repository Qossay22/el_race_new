import 'package:el_race/data/services/hive_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class PrayerNotificationService {
  static const String prayerAdhanChannelId = 'prayer_adhan_channel_sound_v3';
  static const String prayerSilentChannelId = 'prayer_adhan_channel_silent_v1';

  static final PrayerNotificationService _instance =
      PrayerNotificationService._internal();
  factory PrayerNotificationService() => _instance;
  PrayerNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // تهيئة منطقة التوقيت لـ zonedSchedule
    tz.initializeTimeZones();

    // Channel creation and permission requests don't require initialize().

    // NOTE: Do NOT call _notificationsPlugin.initialize() here.
    // FirebaseService.initialize() already initialised the shared native
    // platform with the unified tap-handler. Calling initialize() again
    // would OVERRIDE that handler (only the last one wins), breaking
    // notification-tap navigation for FCM and other services.
    // Channel creation + permission requests work without a second init
    // because they go through the static platform singleton.

    final androidImpl =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImpl != null) {
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          prayerAdhanChannelId,
          'Prayer Adhan (Sound)',
          description: 'Sound notifications for prayer times',
          importance: Importance.high,
          sound: RawResourceAndroidNotificationSound('athan'),
          playSound: true,
          enableVibration: true,
        ),
      );

      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          prayerSilentChannelId,
          'Prayer Adhan (Silent In-App)',
          description: 'Silent in-app prayer notifications',
          importance: Importance.high,
          playSound: false,
          enableVibration: true,
        ),
      );

      await androidImpl.requestNotificationsPermission();
      await androidImpl.requestExactAlarmsPermission();
    }

    _initialized = true;
    // debugPrint('🔔 Prayer notification service initialized');
  }

  Future<void> showAdhanNotification(String prayerName) async {
    // playSound=false هنا لأن AudioPlayer يتولى تشغيل الصوت مستقلاً
    // لتفادي تشغيل صوتين للأذان في نفس الوقت
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      prayerSilentChannelId,
      'Prayer Adhan (Silent In-App)',
      channelDescription: 'Silent in-app prayer notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: false,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      autoCancel: true, // تختفي تلقائياً عند الضغط عليها
      ongoing: false,
      fullScreenIntent: false,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false, // الصوت يشتغل من AudioPlayer
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      0, // notification ID - استخدام 0 لاستبدال الإشعار السابق
      '🕌 Prayer Time',
      '🔔 It\'s now time for ${_englishPrayerName(prayerName)} prayer',
      details,
    );

    // debugPrint('🔔 Adhan notification shown for $prayerName');
  }

  Future<void> scheduleAdhanNotification(
    String prayerName,
    DateTime scheduledTime,
  ) async {
    await initialize();

    // لا تجدول الإشعار إذا كان صوت الأذان مكتوماً
    final isMuted = await HiveService.isPrayerSoundMuted();
    if (isMuted) return;

    // استخدم وقت محلي مباشر مع exactAllowWhileIdle لضمان العمل حتى في وضع Doze
    final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

    await _notificationsPlugin.zonedSchedule(
      _buildId(prayerName, scheduledTime),
      '🕌 Prayer Time',
      '🔔 It\'s now time for ${_englishPrayerName(prayerName)} prayer',
      tzTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          prayerAdhanChannelId,
          'Prayer Adhan (Sound)',
          channelDescription: 'Sound notifications for prayer times',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          sound: RawResourceAndroidNotificationSound('athan'),
          enableVibration: true,
          visibility: NotificationVisibility.public,
          autoCancel: true,
          ongoing: false,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'athan.mp3',
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'prayer:$prayerName:${scheduledTime.millisecondsSinceEpoch}',
    );
  }

  Future<void> cancelScheduledAdhan(String prayerName, int ms) async {
    await initialize();
    final id = _buildId(prayerName, DateTime.fromMillisecondsSinceEpoch(ms));
    await _notificationsPlugin.cancel(id);
  }

  /// إلغاء جميع إشعارات الأذان المعلقة (يُستدعى عند كتم صوت الأذان).
  Future<void> cancelAllPendingAdhan() async {
    await initialize();
    // إلغاء الإشعارات المعلقة فقط (المجدولة) وليس كل الإشعارات
    final pending = await _notificationsPlugin.pendingNotificationRequests();
    for (final p in pending) {
      // الإشعارات المجدولة للأذان تحتوي على payload يبدأ بـ 'prayer:'
      if (p.payload != null && p.payload!.startsWith('prayer:')) {
        await _notificationsPlugin.cancel(p.id);
      }
    }
  }

  int _buildId(String prayerName, DateTime time) {
    // توليد معرف ثابت لكل صلاة/وقت لتجنب تكرار غير ضروري
    final base = prayerName.hashCode & 0x7fffffff;
    final t = time.millisecondsSinceEpoch ~/ 1000;
    return (base ^ t) & 0x7fffffff;
  }

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
}
