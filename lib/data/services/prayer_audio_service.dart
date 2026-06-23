import 'dart:async';
import 'package:adhan/adhan.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/data/services/hive_service.dart';
import 'package:el_race/data/services/prayer_notification_service.dart';
import 'package:volume_controller/volume_controller.dart';

class PrayerAudioService {
  static final PrayerAudioService _instance = PrayerAudioService._internal();
  factory PrayerAudioService() => _instance;
  PrayerAudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final PrayerNotificationService _notificationService =
      PrayerNotificationService();
  Timer? _checkTimer;
  PrayerTimes? _currentPrayerTimes;
  Map<String, DateTime>? _aladhanTimes;
  DateTime? _lastPlayedTime;
  bool _isPlaying = false; // منع تشغيل متعدد
  StreamSubscription<double>? _volumeSubscription;
  double? _volumeAtStart; // مستوى الصوت عند بداية الأذان

  // تهيئة الخدمة
  Future<void> initialize(
    PrayerTimes prayerTimes, {
    Map<String, DateTime>? aladhanTimes,
  }) async {
    // debugPrint('🕌 PrayerAudioService: Initializing...');
    _currentPrayerTimes = prayerTimes;
    _aladhanTimes = aladhanTimes;
    await _notificationService.initialize();

    // عندما يكون التطبيق في المقدمة، نلغي جميع إشعارات الأذان المجدولة
    // لأن الـ foreground timer + AudioPlayer سيتولى التشغيل.
    // هذا يمنع تشغيل صوت الأذان مرتين (مرة من الإشعار المجدول ومرة من AudioPlayer).
    await _cancelAllScheduledPrayerNotifications();

    await _startChecking();
    // debugPrint('🕌 PrayerAudioService: Initialized successfully');
  }

  /// إلغاء جميع إشعارات الأذان المجدولة لليوم (التي لم يحن وقتها بعد).
  /// نفعل هذا عندما يكون التطبيق في المقدمة لأن الـ foreground timer
  /// سيتولى تشغيل الأذان عبر AudioPlayer + إشعار صامت.
  Future<void> _cancelAllScheduledPrayerNotifications() async {
    if (_currentPrayerTimes == null) return;

    final now = DateTime.now();
    final prayers = [
      {'name': 'fajr', 'time': _currentPrayerTimes!.fajr},
      {'name': 'dhuhr', 'time': _currentPrayerTimes!.dhuhr},
      {'name': 'asr', 'time': _currentPrayerTimes!.asr},
      {'name': 'maghrib', 'time': _currentPrayerTimes!.maghrib},
      {'name': 'isha', 'time': _currentPrayerTimes!.isha},
    ];

    for (final p in prayers) {
      final time = p['time'] as DateTime;
      if (time.isAfter(now)) {
        try {
          await _notificationService.cancelScheduledAdhan(
            p['name'] as String,
            time.millisecondsSinceEpoch,
          );
        } catch (_) {}
      }
    }
    // debugPrint('🔕 Cancelled all scheduled prayer notifications (foreground active)');
  }

  // بدء التحقق الدوري من أوقات الصلاة
  Future<void> _startChecking() async {
    // إلغاء أي timer سابق
    _checkTimer?.cancel();
    // debugPrint('⏰ Starting prayer check timer (every 30 seconds)');

    // التحقق كل 30 ثانية
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      // debugPrint('⏰ Timer tick - checking prayer times...');
      await _checkAndPlayAdhan();
    });

    // تحقق فوري عند البداية
    // debugPrint('⏰ Initial check at startup');
    await _checkAndPlayAdhan();
  }

  // التحقق وتشغيل الأذان إذا حان الوقت
  Future<void> _checkAndPlayAdhan() async {
    // منع التشغيل المتعدد
    if (_isPlaying) {
      // debugPrint('⏭️ Adhan already playing, skipping check');
      return;
    }

    if (_currentPrayerTimes == null) {
      // debugPrint('❌ Prayer times not initialized');
      return;
    }

    try {
      // التحقق من تسجيل الدخول
      final isLoggedIn = SharedPref.isUserAuthenticated();
      // debugPrint('🔑 User logged in: $isLoggedIn');
      if (!isLoggedIn) {
        // debugPrint('🚫 User not logged in, skipping adhan');
        return;
      }

      // التحقق من حالة كتم الصوت
      final isMuted = await HiveService.isPrayerSoundMuted();
      // debugPrint('🔊 Sound muted: $isMuted');
      if (isMuted) {
        // debugPrint('🔇 Prayer sound is muted, skipping adhan');
        return;
      }

      final now = DateTime.now();
      // debugPrint('🕐 Current time: ${now.hour}:${now.minute}:${now.second}');

      final prayers = _buildPrayerEntries();

      for (var prayerData in prayers) {
        final prayerTime = prayerData['time'] as DateTime;
        final prayer = prayerData['prayer'] as Prayer;

        // التحقق إذا كان الوقت الحالي بين وقت الصلاة و 5 دقائق بعدها
        final timeDiff = now.difference(prayerTime);

        // debugPrint(
        //     '📋 Checking $prayerName: time=${prayerTime.hour}:${prayerTime.minute}, diff=${timeDiff.inSeconds}s');

        if (timeDiff.inSeconds >= 0 && timeDiff.inMinutes < 5) {
          final didPlay = await _handlePrayerTrigger(
            prayer: prayer,
            prayerTime: prayerTime,
          );
          if (didPlay) {
            break;
          }
        }
      }
      // debugPrint('✓ Check completed');
    } catch (e) {
      // debugPrint('❌ Error checking prayer times: $e');
      _isPlaying = false; // التأكد من إعادة الحالة في حالة الخطأ
    }
  }

  // بدء مراقبة زر الصوت لإيقاف الأذان عند الضغط على أي زر
  void _startVolumeListener() {
    _volumeSubscription?.cancel();
    // حفظ مستوى الصوت الحالي
    VolumeController.instance.getVolume().then((vol) {
      _volumeAtStart = vol;
    });
    // لا نريد أن يظهر مؤشر الصوت الخاص بالنظام
    VolumeController.instance.showSystemUI = false;
    _volumeSubscription =
        VolumeController.instance.addListener((volume) {
      if (_isPlaying && _volumeAtStart != null) {
        // إذا تغير مستوى الصوت (أي كبسة) → أوقف الأذان
        if ((volume - _volumeAtStart!).abs() > 0.01) {
          stopAdhan();
          // إعادة مستوى الصوت للقيمة الأصلية
          VolumeController.instance.setVolume(_volumeAtStart!);
        }
      }
    });
  }

  // إيقاف مراقبة زر الصوت
  void _stopVolumeListener() {
    _volumeSubscription?.cancel();
    _volumeSubscription = null;
    _volumeAtStart = null;
    VolumeController.instance.showSystemUI = true;
  }

  // تشغيل صوت الأذان
  Future<void> _playAdhan() async {
    try {
      // debugPrint('🎵 Starting adhan playback...');
      await _audioPlayer.stop();
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      // start with low volume and fade in
      await _audioPlayer.setVolume(0.1);
      // debugPrint('🔊 Volume set to 10% (starting fade-in)');

      // بدء مراقبة أزرار الصوت
      _startVolumeListener();

      // تشغيل ملف الصوت من assets
      await _audioPlayer.play(AssetSource('mp3/athan.mp3'));

      // Gradually increase volume to full over ~3 seconds
      for (int i = 1; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 300));
        try {
          await _audioPlayer.setVolume(0.1 * i);
        } catch (_) {}
      }

      // debugPrint('✅ Adhan started playing successfully (with fade-in)!');

      // إيقاف الصوت تلقائياً بعد 4 دقائق (مدة الأذان الكاملة)
      Future.delayed(const Duration(minutes: 4), () async {
        if (_isPlaying) {
          await stopAdhan();
          _isPlaying = false;
        }
      });
    } catch (e) {
      // debugPrint('❌ Error playing adhan: $e');
      _isPlaying = false;
    }
  }

  // إيقاف صوت الأذان
  Future<void> stopAdhan() async {
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
      _stopVolumeListener();
      // debugPrint('Adhan stopped');
    } catch (e) {
      // debugPrint('Error stopping adhan: $e');
    }
  }

  // تحديث أوقات الصلاة
  void updatePrayerTimes(
    PrayerTimes prayerTimes, {
    Map<String, DateTime>? aladhanTimes,
  }) {
    _currentPrayerTimes = prayerTimes;
    _aladhanTimes = aladhanTimes;
    _lastPlayedTime = null; // إعادة تعيين آخر وقت تشغيل
    // إلغاء الإشعارات المجدولة للأوقات الجديدة أيضاً (التطبيق مفتوح)
    _cancelAllScheduledPrayerNotifications();
  }

  Future<void> tryPlayAdhanForPrayer({
    required Prayer prayer,
    required DateTime prayerTime,
  }) async {
    final now = DateTime.now();
    final timeDiff = now.difference(prayerTime);
    if (timeDiff.inSeconds < 0 || timeDiff.inMinutes >= 5) {
      return;
    }

    await _handlePrayerTrigger(prayer: prayer, prayerTime: prayerTime);
  }

  List<Map<String, dynamic>> _buildPrayerEntries() {
    DateTime resolve(String key, DateTime fallback) {
      return _aladhanTimes?[key] ?? fallback;
    }

    return [
      {
        'prayer': Prayer.fajr,
        'time': resolve('fajr', _currentPrayerTimes!.fajr),
      },
      {
        'prayer': Prayer.dhuhr,
        'time': resolve('dhuhr', _currentPrayerTimes!.dhuhr),
      },
      {
        'prayer': Prayer.asr,
        'time': resolve('asr', _currentPrayerTimes!.asr),
      },
      {
        'prayer': Prayer.maghrib,
        'time': resolve('maghrib', _currentPrayerTimes!.maghrib),
      },
      {
        'prayer': Prayer.isha,
        'time': resolve('isha', _currentPrayerTimes!.isha),
      },
    ];
  }

  Future<bool> _handlePrayerTrigger({
    required Prayer prayer,
    required DateTime prayerTime,
  }) async {
    final prayerName = _getPrayerName(prayer);
    final normalizedPrayerName = prayerName.toLowerCase();

    // التحقق من أننا لم نشغل الأذان لهذه الصلاة مسبقاً
    final playedKey =
        'played_${normalizedPrayerName}_${prayerTime.millisecondsSinceEpoch}';
    final alreadyPlayed = await HiveService.hasPlayedPrayer(playedKey);

    if (alreadyPlayed) {
      return false;
    }

    if (_lastPlayedTime != null &&
        _lastPlayedTime!.difference(prayerTime).abs().inMinutes <= 10) {
      return false;
    }

    // debugPrint('✅ Time for $prayerName prayer! Playing adhan...');
    _isPlaying = true;

    try {
      await _notificationService.cancelScheduledAdhan(
        normalizedPrayerName,
        prayerTime.millisecondsSinceEpoch,
      );
    } catch (_) {}

    await _notificationService.showAdhanNotification(prayerName);
    await _playAdhan();
    _lastPlayedTime = prayerTime;
    await HiveService.markPrayerPlayed(playedKey);
    _isPlaying = false;
    return true;
  }

  /// إعادة جدولة إشعارات الأذان المحلية للصلوات القادمة.
  /// يُستدعى عندما ينتقل التطبيق إلى الخلفية لضمان وصول الإشعار
  /// حتى لو أوقف النظام الـ foreground timer.
  Future<void> rescheduleBackgroundNotifications() async {
    if (_currentPrayerTimes == null) return;

    final now = DateTime.now();
    final prayers = [
      {'name': 'fajr', 'time': _currentPrayerTimes!.fajr},
      {'name': 'dhuhr', 'time': _currentPrayerTimes!.dhuhr},
      {'name': 'asr', 'time': _currentPrayerTimes!.asr},
      {'name': 'maghrib', 'time': _currentPrayerTimes!.maghrib},
      {'name': 'isha', 'time': _currentPrayerTimes!.isha},
    ];

    for (final p in prayers) {
      final time = p['time'] as DateTime;
      if (time.isAfter(now)) {
        try {
          await _notificationService.scheduleAdhanNotification(
            p['name'] as String,
            time,
          );
        } catch (_) {}
      }
    }
  }

  // الحصول على اسم الصلاة
  String _getPrayerName(Prayer prayer) {
    switch (prayer) {
      case Prayer.fajr:
        return 'Fajr';
      case Prayer.dhuhr:
        return 'Dhuhr';
      case Prayer.asr:
        return 'Asr';
      case Prayer.maghrib:
        return 'Maghrib';
      case Prayer.isha:
        return 'Isha';
      default:
        return 'Unknown';
    }
  }

  // تنظيف الموارد
  Future<void> dispose() async {
    _checkTimer?.cancel();
    _stopVolumeListener();
    await _audioPlayer.stop();
    await _audioPlayer.dispose();
    _isPlaying = false;
    // debugPrint('PrayerAudioService disposed');
  }
}
