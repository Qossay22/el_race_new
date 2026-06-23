import 'dart:async';
import 'dart:convert';

import 'package:adhan/adhan.dart';
import 'package:el_race/data/services/hive_service.dart';
import 'package:el_race/data/services/prayer_audio_service.dart';
import 'package:el_race/data/services/prayer_background_service.dart';
import 'package:equatable/equatable.dart';
import 'package:el_race/ui/presentation/Attendace_list/repository/attendance_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  static HomeBloc get(BuildContext context) => BlocProvider.of(context);
  DateTime now = DateTime.now();
  String monthName = '';
  HomeBloc() : super(HomeInitial()) {
    on<CheckInStatusChangedEvent>(checkedInMethod);
    on<FetchLastMonthAttendanceSummary>(_fetchLastMonthAttendanceSummary);
    on<ChangeCurrentIndex>((event, emit) {
      changeCurrentIndex(event, emit);
    });
    on<ChangeVisiablityIcon>((event, emit) {
      changeBottomNavVisiblity(event, emit);
    });
    on<InitPrayerTimesEvent>(_initPrayerTimes);
    on<LoadPrayerMuteStateEvent>(_loadPrayerMuteState);
    on<TogglePrayerMuteStateEvent>(_togglePrayerMuteState);
    on<UpdatePrayerTickEvent>(_updatePrayerTick);
    on<AppPausedEvent>(_onAppPaused);
    on<ToggleReorderModeEvent>(_toggleReorderMode);
    monthName = DateFormat('MMMM').format(now);
  }
  bool isNotOpen = false;
  bool isEdit = false;
  bool isReorderMode = false;
  int currentIndex = 1;
  changeCurrentIndex(ChangeCurrentIndex event, emit) {
    emit(ChangeIndexLoading());
    currentIndex = event.index;
    emit(ChangeIndexSuccess());
  }

  bool enableBottomNav = true;
  changeBottomNavVisiblity(ChangeVisiablityIcon event, emit) {
    emit(ChangeIndexLoading());
    enableBottomNav = !enableBottomNav;
    emit(ChangeIndexSuccess());
  }

  void _toggleReorderMode(
      ToggleReorderModeEvent event, Emitter<HomeState> emit) {
    isReorderMode = !isReorderMode;
    emit(ReorderModeChanged(isReorderMode));
  }

  FutureOr<void> checkedInMethod(
      CheckInStatusChangedEvent event, Emitter<HomeState> emit) {
    emit(CheckedInSTHome());
  }

  int attendedDays = 0;

  // Prayer times variables
  PrayerTimes? _prayerTimes;
  Prayer? _nextPrayer;
  DateTime? _nextPrayerTime;
  bool _isSoundMuted = false;
  Timer? _prayerTicker;
  final PrayerAudioService _audioService = PrayerAudioService();

  // Aladhan API prayer times (more accurate)
  DateTime? _aladhanFajr;
  DateTime? _aladhanDhuhr;
  DateTime? _aladhanAsr;
  DateTime? _aladhanMaghrib;
  DateTime? _aladhanIsha;

  Map<String, DateTime>? _currentAladhanTimes() {
    if (_aladhanFajr == null ||
        _aladhanDhuhr == null ||
        _aladhanAsr == null ||
        _aladhanMaghrib == null ||
        _aladhanIsha == null) {
      return null;
    }

    return {
      'fajr': _aladhanFajr!,
      'dhuhr': _aladhanDhuhr!,
      'asr': _aladhanAsr!,
      'maghrib': _aladhanMaghrib!,
      'isha': _aladhanIsha!,
    };
  }

  @override
  Future<void> close() {
    _prayerTicker?.cancel();
    _audioService.dispose();
    return super.close();
  }

  Future<void> _loadPrayerMuteState(
    LoadPrayerMuteStateEvent event,
    Emitter<HomeState> emit,
  ) async {
    try {
      final isMuted = await HiveService.isPrayerSoundMuted();
      _isSoundMuted = isMuted;
      emit(PrayerMuteStateChanged(isMuted));
    } catch (e) {
      // debugPrint('Error loading mute state: $e');
    }
  }

  Future<void> _togglePrayerMuteState(
    TogglePrayerMuteStateEvent event,
    Emitter<HomeState> emit,
  ) async {
    try {
      final newState = !_isSoundMuted;
      await HiveService.setPrayerSoundMuted(newState);
      _isSoundMuted = newState;
      // debugPrint(newState.toString());

      if (_prayerTimes != null) {
        emit(PrayerTimesLoaded(
          prayerTimes: _prayerTimes,
          nextPrayer: _nextPrayer,
          nextTime: _nextPrayerTime,
          isSoundMuted: _isSoundMuted,
          aladhanTimes: _currentAladhanTimes(),
        ));
      } else {
        emit(PrayerMuteStateChanged(newState));
      }
    } catch (e) {
      // debugPrint('Error toggling mute state: $e');
    }
  }

  /// عندما ينتقل التطبيق إلى الخلفية، نعيد جدولة إشعارات الأذان المحلية
  /// التي تم إلغاؤها سابقاً عند دخول المقدمة.
  Future<void> _onAppPaused(
    AppPausedEvent event,
    Emitter<HomeState> emit,
  ) async {
    try {
      await _audioService.rescheduleBackgroundNotifications();
    } catch (_) {}
  }

  Future<void> _initPrayerTimes(
    InitPrayerTimesEvent event,
    Emitter<HomeState> emit,
  ) async {
    // debugPrint('🔄 InitPrayerTimes started');
    emit(const PrayerTimesLoading());

    try {
      // debugPrint('📡 Fetching prayer times from Aladhan API...');

      // Get location coordinates
      Coordinates coords;
      try {
        final last = await Geolocator.getLastKnownPosition();
        coords = last != null
            ? Coordinates(last.latitude, last.longitude)
            : Coordinates(25.2048, 55.2708); // Dubai default
      } catch (_) {
        coords = Coordinates(25.2048, 55.2708);
      }

      // debugPrint('📍 Location: ${coords.latitude}, ${coords.longitude}');

      // Get current date
      final now = DateTime.now();
      final timestamp = (now.millisecondsSinceEpoch / 1000).round();

      // جلب أوقات الصلاة من Aladhan API
      final response = await http.get(
        Uri.parse(
            'https://api.aladhan.com/v1/timings/$timestamp?latitude=${coords.latitude}&longitude=${coords.longitude}&method=5'),
      );

      // debugPrint('📡 Aladhan API Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // debugPrint('📡 Aladhan API Response data: $data');

        if (data['code'] == 200 && data['data'] != null) {
          await _setPrayerTimesFromAladhanAPI(data['data'], coords);

          // debugPrint(
          //     '✅ Prayer times loaded - nextPrayer: $_nextPrayer, nextTime: $_nextPrayerTime');

          emit(PrayerTimesLoaded(
            prayerTimes: _prayerTimes,
            nextPrayer: _nextPrayer,
            nextTime: _nextPrayerTime,
            isSoundMuted: _isSoundMuted,
            aladhanTimes: _currentAladhanTimes(),
          ));

          _startPrayerTicker();

          // تهيئة خدمة الصوت
          if (_prayerTimes != null) {
              await _audioService.initialize(
                _prayerTimes!,
                aladhanTimes: _currentAladhanTimes(),
              );
            // إعادة جدولة المهام الخلفية مع أوقات الصلاة الجديدة
            await PrayerBackgroundService.reschedule();
          }

          return;
        }
      }

      throw Exception('Failed to fetch prayer times from Aladhan API');
    } catch (e) {
      // debugPrint('❌ Prayer times API failed: $e');
      // Fallback: استخدام الحساب المحلي
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          _setPrayerTimesFor(Coordinates(last.latitude, last.longitude));
        } else {
          _setPrayerTimesFor(Coordinates(25.2048, 55.2708)); // Dubai
        }
      } catch (_) {
        _setPrayerTimesFor(Coordinates(25.2048, 55.2708));
      }

      emit(PrayerTimesError(
        error: 'Using local calculation',
        prayerTimes: _prayerTimes,
        isSoundMuted: _isSoundMuted,
      ));

      _startPrayerTicker();

      // تهيئة خدمة الصوت
      if (_prayerTimes != null) {
        await _audioService.initialize(
          _prayerTimes!,
          aladhanTimes: _currentAladhanTimes(),
        );
        // إعادة جدولة المهام الخلفية
        await PrayerBackgroundService.reschedule();
      }
    }
  }

  Future<void> _setPrayerTimesFromAladhanAPI(
      Map<String, dynamic> apiData, Coordinates coords) async {
    final timings = apiData['timings'] as Map<String, dynamic>?;

    // debugPrint('🔍 Aladhan timings data: $timings');

    if (timings == null) {
      throw Exception('No timings data from Aladhan API');
    }

    // استخدام الأوقات من Aladhan API مباشرة (أدق من local calculation)
    // بس نحتفظ بـ PrayerTimes object للـ UI
    final params = CalculationMethod.egyptian.getParameters()
      ..madhab = Madhab.shafi; // تم تغييره من hanafi إلى shafi ليتطابق مع Aladhan API method=5
    final dateComponents = DateComponents.from(DateTime.now());
    _prayerTimes = PrayerTimes(coords, dateComponents, params);

    // Parse and store Aladhan prayer times
    final now = DateTime.now();
    _aladhanFajr = _parseAladhanTime(timings['Fajr']);
    _aladhanDhuhr = _parseAladhanTime(timings['Dhuhr']);
    _aladhanAsr = _parseAladhanTime(timings['Asr']);
    _aladhanMaghrib = _parseAladhanTime(timings['Maghrib']);
    _aladhanIsha = _parseAladhanTime(timings['Isha']);

    // debugPrint(
    //     '🕐 Aladhan Times - Fajr: $_aladhanFajr, Dhuhr: $_aladhanDhuhr, Asr: $_aladhanAsr, Maghrib: $_aladhanMaghrib, Isha: $_aladhanIsha');
    // debugPrint('🕐 Current time: $now');

    // إيجاد الصلاة التالية من أوقات Aladhan
    if (now.isBefore(_aladhanFajr!)) {
      _nextPrayer = Prayer.fajr;
      _nextPrayerTime = _aladhanFajr;
    } else if (now.isBefore(_aladhanDhuhr!)) {
      _nextPrayer = Prayer.dhuhr;
      _nextPrayerTime = _aladhanDhuhr;
    } else if (now.isBefore(_aladhanAsr!)) {
      _nextPrayer = Prayer.asr;
      _nextPrayerTime = _aladhanAsr;
    } else if (now.isBefore(_aladhanMaghrib!)) {
      _nextPrayer = Prayer.maghrib;
      _nextPrayerTime = _aladhanMaghrib;
    } else if (now.isBefore(_aladhanIsha!)) {
      _nextPrayer = Prayer.isha;
      _nextPrayerTime = _aladhanIsha;
    } else {
      // إذا لم تكن هناك صلاة متبقية اليوم، استخدم فجر الغد
      final tomorrow = now.add(const Duration(days: 1));
      final tomorrowComponents = DateComponents.from(tomorrow);
      final tomorrowPrayers = PrayerTimes(coords, tomorrowComponents, params);
      _nextPrayer = Prayer.fajr;
      _nextPrayerTime = tomorrowPrayers.fajr;
      // debugPrint('✅ All prayers passed, using tomorrow Fajr: $_nextPrayerTime');
      return;
    }

    // debugPrint('✅ Next prayer from Aladhan: $_nextPrayer at $_nextPrayerTime');
  }

  DateTime _parseAladhanTime(String? timeStr) {
    if (timeStr == null) throw Exception('Invalid time from Aladhan');

    // Aladhan returns time in format "HH:mm" (24-hour)
    final parts = timeStr.split(':');
    if (parts.length < 2) throw Exception('Invalid time format: $timeStr');

    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  void _setPrayerTimesFor(Coordinates coords) {
    final params = CalculationMethod.egyptian.getParameters()
      ..madhab = Madhab.shafi; // تم تغييره من hanafi إلى shafi ليتطابق مع Aladhan API method=5

    final pt = PrayerTimes.today(coords, params);
    final n = pt.nextPrayer();
    final nt = pt.timeForPrayer(n);

    _prayerTimes = pt;
    _nextPrayer = n;
    _nextPrayerTime = nt;
  }

  void _startPrayerTicker() {
    _prayerTicker?.cancel();
    if (_prayerTimes == null) return;

    _prayerTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isClosed) {
        add(const UpdatePrayerTickEvent());
      }
    });
  }

  Future<void> _updatePrayerTick(
    UpdatePrayerTickEvent event,
    Emitter<HomeState> emit,
  ) async {
    if (_prayerTimes == null) return;

    final now = DateTime.now();
    final previousNextPrayer = _nextPrayer;
    final previousNextPrayerTime = _nextPrayerTime;

    if (previousNextPrayer != null && previousNextPrayerTime != null) {
      final hasReachedPrayerTime =
          now.isAtSameMomentAs(previousNextPrayerTime) ||
              now.isAfter(previousNextPrayerTime);
      if (hasReachedPrayerTime) {
        await _audioService.tryPlayAdhanForPrayer(
          prayer: previousNextPrayer,
          prayerTime: previousNextPrayerTime,
        );
      }
    }

    Prayer? n;
    DateTime? nt;

    // استخدام أوقات Aladhan إذا متوفرة
    if (_aladhanFajr != null &&
        _aladhanDhuhr != null &&
        _aladhanAsr != null &&
        _aladhanMaghrib != null &&
        _aladhanIsha != null) {
      // إيجاد الصلاة التالية من أوقات Aladhan
      if (now.isBefore(_aladhanFajr!)) {
        n = Prayer.fajr;
        nt = _aladhanFajr;
      } else if (now.isBefore(_aladhanDhuhr!)) {
        n = Prayer.dhuhr;
        nt = _aladhanDhuhr;
      } else if (now.isBefore(_aladhanAsr!)) {
        n = Prayer.asr;
        nt = _aladhanAsr;
      } else if (now.isBefore(_aladhanMaghrib!)) {
        n = Prayer.maghrib;
        nt = _aladhanMaghrib;
      } else if (now.isBefore(_aladhanIsha!)) {
        n = Prayer.isha;
        nt = _aladhanIsha;
      } else {
        // كل الصلوات خلصت، استخدم فجر الغد
        n = Prayer.none;
      }
    } else {
      // Fallback to local calculation
      n = _prayerTimes!.nextPrayer();
      nt = _prayerTimes!.timeForPrayer(n);
    }

    // استخدم فجر الغد فقط إذا انتهت جميع صلوات اليوم (Prayer.none)
    if (n == Prayer.none) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        final coords = last != null
            ? Coordinates(last.latitude, last.longitude)
            : Coordinates(25.2048, 55.2708);

        final params = CalculationMethod.egyptian.getParameters()
          ..madhab = Madhab.shafi; // تم تغييره من hanafi إلى shafi ليتطابق مع Aladhan API method=5

        final tomorrow = now.add(const Duration(days: 1));
        final tomorrowComponents = DateComponents.from(tomorrow);
        final tomorrowPrayers = PrayerTimes(coords, tomorrowComponents, params);

        n = Prayer.fajr;
        nt = tomorrowPrayers.fajr;

        // debugPrint('⏭️ All prayers passed, using tomorrow Fajr: $nt');
      } catch (e) {
        // debugPrint('❌ Error calculating tomorrow Fajr: $e');
      }
    }

    if (n != _nextPrayer || nt != _nextPrayerTime) {
      _nextPrayer = n;
      _nextPrayerTime = nt;

      // تحديث خدمة الصوت بأوقات الصلاة الجديدة
      _audioService.updatePrayerTimes(
        _prayerTimes!,
        aladhanTimes: _currentAladhanTimes(),
      );

      emit(PrayerTimesLoaded(
        prayerTimes: _prayerTimes,
        nextPrayer: _nextPrayer,
        nextTime: _nextPrayerTime,
        isSoundMuted: _isSoundMuted,
        aladhanTimes: _currentAladhanTimes(),
      ));
    }
  }

  Future<void> _fetchLastMonthAttendanceSummary(
    FetchLastMonthAttendanceSummary event,
    Emitter<HomeState> emit,
  ) async {
    try {
      emit(const LastMonthAttendanceSummaryLoading());
      final now = DateTime.now();
      final firstDayOfLastMonth = DateTime(now.year, now.month, 1);
      final lastDayOfLastMonth = DateTime(now.year, now.month + 1, 0);

      final summary = await AttendanceRepo().getAttendanceSummary(
        startDate: DateFormat('yyyy-MM-dd').format(firstDayOfLastMonth),
        endDate: DateFormat('yyyy-MM-dd').format(lastDayOfLastMonth),
      );
      attendedDays = summary['working_days'] ?? 0;
      emit(const LastMonthAttendanceSummaryLoaded());
      // No emit here, just set the variable
    } catch (e) {
      emit(LastMonthAttendanceSummaryError(e.toString()));
    }
  }

  int get getAttendedDays => attendedDays;
}
