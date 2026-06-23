import 'dart:async';
import 'package:flutter/material.dart';

class PrayerCountdownTimer extends StatefulWidget {
  final DateTime? nextPrayerTime;

  const PrayerCountdownTimer({
    super.key,
    required this.nextPrayerTime,
  });

  @override
  State<PrayerCountdownTimer> createState() => _PrayerCountdownTimerState();
}

class _PrayerCountdownTimerState extends State<PrayerCountdownTimer> {
  Timer? _timer;
  String _timeLeft = '--:--:--';

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(PrayerCountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // إعادة تشغيل Timer إذا تغير وقت الصلاة القادمة
    if (oldWidget.nextPrayerTime != widget.nextPrayerTime) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _updateTime();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _updateTime();
      }
    });
  }

  void _updateTime() {
    // debugPrint('🔄 Update Time - nextPrayerTime: ${widget.nextPrayerTime}');

    if (widget.nextPrayerTime == null) {
      // debugPrint('⚠️ nextPrayerTime is NULL!');
      if (mounted) {
        setState(() {
          _timeLeft = '--:--:--';
        });
      }
      return;
    }

    final now = DateTime.now();
    final diff = widget.nextPrayerTime!.difference(now);

    // debugPrint('⏱️ Time difference: ${diff.inSeconds} seconds');

    if (diff.isNegative) {
      // debugPrint('⚠️ Time is negative!');
      if (mounted) {
        setState(() {
          _timeLeft = '00:00:00';
        });
      }
      return;
    }

    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    final seconds = diff.inSeconds.remainder(60);

    final timeString = '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';

    // debugPrint('✅ Time calculated: $timeString');

    if (mounted) {
      setState(() {
        _timeLeft = timeString;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _timeLeft,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        fontFamily: 'Poppins',
      ),
      textDirection: TextDirection.ltr,
    );
  }
}
