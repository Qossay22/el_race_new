import 'dart:convert';

import 'package:adhan/adhan.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/home_screen/bloc/home_bloc.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/parayer_widgets/label_widget.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/parayer_widgets/prayer_countdown_timer.dart';
import 'package:el_race/utils/dimens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ParayerWidget extends StatefulWidget {
  const ParayerWidget({super.key});
  @override
  State<ParayerWidget> createState() => _ParayerWidgetState();
}

class _ParayerWidgetState extends State<ParayerWidget>
    with WidgetsBindingObserver {
  // Keep track of last known values
  DateTime? _lastNextTime;
  Prayer? _lastNextPrayer;
  PrayerTimes? _lastPrayerTimes;

  String? _locationLabel;
  bool _isFetchingLocation = false;

  String _prayerKey(Prayer p) {
    switch (p) {
      case Prayer.fajr:
        return 'home.Fajr';
      case Prayer.dhuhr:
        return 'home.Dhuhr';
      case Prayer.asr:
        return 'home.Asr';
      case Prayer.maghrib:
        return 'home.Maghrib';
      case Prayer.isha:
        return 'home.Isha';
      default:
        return 'home.Fajr';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<HomeBloc>().add(const InitPrayerTimesEvent());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<HomeBloc>().add(const InitPrayerTimesEvent());
    }
  }

  String _fmt(DateTime dt) {
    final locale = Localizations.localeOf(context).languageCode;
    return DateFormat('hh:mm a', locale).format(dt);
  }

  Widget _prayerIcon({required Prayer prayer, required Color color}) {
    switch (prayer) {
      case Prayer.fajr:
        return SvgPicture.asset(
          'assets/newapp/newicon/fajar_new.svg',
          width: 20.w,
          height: 14.w,
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        );
      case Prayer.dhuhr:
        return SvgPicture.asset(
          'assets/newapp/newicon/duhur.svg',
          width: 30.w,
          height: 14.w,
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        );
      case Prayer.isha:
        return Image.asset(
          'assets/newapp/Ellipse 107.png',
          width: 14.w,
          height: 14.w,
          color: color,
          colorBlendMode: BlendMode.srcIn,
          filterQuality: FilterQuality.high,
        );
      case Prayer.maghrib:
        return SvgPicture.asset(
          'assets/newapp/newicon/maghrib.svg',
          width: 14.w,
          height: 14.w,
          fit: BoxFit.contain,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        );
      case Prayer.asr:
        return SvgPicture.asset(
          'assets/newapp/newicon/asr_new.svg',
          width: 14.w,
          height: 14.w,
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        );
      default:
        return Icon(Icons.wb_sunny_outlined, size: 14.w, color: color);
    }
  }

  Widget _labelWithIcon({
    required Widget label,
    required Widget icon,
    Alignment iconAlignment = Alignment.center,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        label,
        Positioned(
          left: 15,
          right: 15,
          bottom: -14.h,
          child: IgnorePointer(
            child: Align(
              alignment: iconAlignment,
              child: icon,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sunriseIcon({required Color color}) {
    return Icon(Icons.wb_twilight_outlined, size: 14.w, color: color);
  }

  Future<void> _loadLocationLabel() async {
    if (_isFetchingLocation) return;
    _isFetchingLocation = true;

    try {
      // Best effort: try to fetch a position (permission-safe).
      Position? pos;
      try {
        pos = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      if (pos == null) {
        try {
          final permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            await Geolocator.requestPermission();
          }
          pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 4),
          );
        } catch (_) {
          // Ignore, will fallback.
        }
      }

      if (pos == null) {
        if (!mounted) return;
        setState(() {
          _locationLabel ??= '...';
        });
        return;
      }

      final label = await _reverseGeocodeCity(
        latitude: pos.latitude,
        longitude: pos.longitude,
      );

      if (!mounted) return;
      setState(() {
        _locationLabel = label ?? _locationLabel ?? '...';
      });
    } finally {
      _isFetchingLocation = false;
    }
  }

  Future<String?> _reverseGeocodeCity({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'zoom': '12',
        'addressdetails': '1',
      });

      final res = await http.get(
        uri,
        headers: const {
          'User-Agent': 'el_race_app/1.0 (Flutter; reverse geocoding)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode != 200) return null;

      final body = jsonDecode(res.body);
      final address = body is Map ? body['address'] : null;
      if (address is! Map) return null;

      String? pick(String key) {
        final v = address[key];
        if (v is String && v.trim().isNotEmpty) return v.trim();
        return null;
      }

      return pick('city') ??
          pick('town') ??
          pick('village') ??
          pick('municipality') ??
          pick('county') ??
          pick('state') ??
          pick('country');
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_locationLabel == null && !_isFetchingLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadLocationLabel();
      });
    }

    return BlocBuilder<HomeBloc, HomeState>(
      buildWhen: (previous, current) =>
          current is PrayerTimesLoading ||
          current is PrayerTimesLoaded ||
          current is PrayerTimesError,
      builder: (context, state) {
        PrayerTimes? pt;
        Prayer? nextPrayer;
        DateTime? nextTime;
        String? error;
        Map<String, DateTime>? aladhanTimes;

        if (state is PrayerTimesLoaded) {
          pt = state.prayerTimes;
          nextPrayer = state.nextPrayer;
          nextTime = state.nextTime;
          error = state.error;
          aladhanTimes = state.aladhanTimes;

          // Update cached values
          _lastPrayerTimes = pt;
          _lastNextPrayer = nextPrayer;
          _lastNextTime = nextTime;
        } else if (state is PrayerTimesError) {
          pt = state.prayerTimes ?? _lastPrayerTimes;
          error = state.error;
          // Use last known values
          nextPrayer = _lastNextPrayer;
          nextTime = _lastNextTime;
        }

        // debugPrint('🕐 Prayer Widget Build - nextTime: $nextTime, nextPrayer: $nextPrayer');

        // If no prayer times yet, show loading
        // if (pt == null) {
        //   return const SizedBox.shrink();
        // }

        return Opacity(
          opacity: !SharedPref.isUserAuthenticated() ? .5 : 1,
          child: SizedBox(
            width: double.infinity,
            height: AppDimen.homeWidgetCardHeight.w + 13.w,
            child: Stack(
              children: [
                Container(
                    width: double.infinity,
                    height: AppDimen.homeWidgetCardHeight.w + 13.w,
                    padding: EdgeInsets.symmetric(vertical: 6.h),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.r),
                      image: const DecorationImage(
                        image: AssetImage(
                            'assets/newapp/newicon/Prayer_widget_packground.png'),
                        fit: BoxFit.fill,
                      ),
                    ),
                    child: Stack(alignment: Alignment.centerRight, children: [
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Image.asset(
                          'assets/png/pray_decoration.png',
                          width: 200.w,
                          height: 200.w,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 30.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      translate('home.prayer_times')
                                          .toUpperCase(),
                                      maxLines: 1,
                                      style: GoogleFonts.poppins(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.9,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      color: Colors.white,
                                      size: 18.sp,
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      _locationLabel ?? '...',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                if (error != null)
                                  Padding(
                                    padding: EdgeInsets.only(right: 6.w),
                                    child: Icon(Icons.error_outline,
                                        color: Colors.yellow.shade200,
                                        size: 16.sp),
                                  ),
                              ],
                            ),
                            SizedBox(height: 4.h),
                            SizedBox(
                              height: 140.h,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: SvgPicture.asset(
                                      'assets/png/prayer_curve.svg',
                                      height: 80.h,
                                      fit: BoxFit.fill,
                                    ),
                                  ),
                                  Positioned(
                                      bottom: 40.h,
                                      left: -1.w,
                                      child: _labelWithIcon(
                                        label: LabelWidget(
                                            name: translate('home.Fajr'),
                                            time: _fmt(aladhanTimes?['fajr'] ??
                                                pt?.fajr ??
                                                DateTime.now()),
                                            textColor: nextPrayer == Prayer.fajr
                                                ? const Color(0xFFFFD700)
                                                : Colors.white),
                                        icon: _prayerIcon(
                                          prayer: Prayer.fajr,
                                          color: nextPrayer == Prayer.fajr
                                              ? const Color(0xFFFFD700)
                                              : Colors.white,
                                        ),
                                        iconAlignment: Alignment.centerRight,
                                      )),
                                  Positioned(
                                    bottom: 80.h,
                                    left: 60.w,
                                    child: _labelWithIcon(
                                      label: LabelWidget(
                                        name: "Shuruk",
                                        time: _fmt(
                                          aladhanTimes?['sunrise'] ??
                                              aladhanTimes?['shurooq'] ??
                                              pt?.sunrise ??
                                              DateTime.now(),
                                        ),
                                        textColor: Colors.white,
                                      ),
                                      icon: _sunriseIcon(color: Colors.white),
                                      iconAlignment: Alignment.center,
                                    ),
                                  ),
                                  Positioned(
                                      bottom: 110.w,
                                      left: 0,
                                      right: 0,
                                      child: Center(
                                        child: _labelWithIcon(
                                          label: LabelWidget(
                                              name: translate('home.Dhuhr'),
                                              time: _fmt(
                                                  aladhanTimes?['dhuhr'] ??
                                                      pt?.dhuhr ??
                                                      DateTime.now()),
                                              textColor:
                                                  nextPrayer == Prayer.dhuhr
                                                      ? const Color(0xFFFFD700)
                                                      : Colors.white),
                                          icon: _prayerIcon(
                                            prayer: Prayer.dhuhr,
                                            color: nextPrayer == Prayer.dhuhr
                                                ? const Color(0xFFFFD700)
                                                : Colors.white,
                                          ),
                                          iconAlignment: Alignment.center,
                                        ),
                                      )),
                                  Positioned(
                                      bottom: 95.w,
                                      right: 70.w,
                                      child: _labelWithIcon(
                                        label: LabelWidget(
                                            name: translate('home.Asr'),
                                            time: _fmt(aladhanTimes?['asr'] ??
                                                pt?.asr ??
                                                DateTime.now()),
                                            textColor: nextPrayer == Prayer.asr
                                                ? const Color(0xFFFFD700)
                                                : Colors.white),
                                        icon: _prayerIcon(
                                          prayer: Prayer.asr,
                                          color: nextPrayer == Prayer.asr
                                              ? const Color(0xFFFFD700)
                                              : Colors.white,
                                        ),
                                        iconAlignment: Alignment.centerLeft,
                                      )),
                                  Positioned(
                                      bottom: 68.w,
                                      right: 5.w,
                                      child: _labelWithIcon(
                                        label: LabelWidget(
                                            name: translate('home.Maghrib'),
                                            time: _fmt(
                                                aladhanTimes?['maghrib'] ??
                                                    pt?.maghrib ??
                                                    DateTime.now()),
                                            textColor:
                                                nextPrayer == Prayer.maghrib
                                                    ? const Color(0xFFFFD700)
                                                    : Colors.white),
                                        icon: _prayerIcon(
                                          prayer: Prayer.maghrib,
                                          color: nextPrayer == Prayer.maghrib
                                              ? const Color(0xFFFFD700)
                                              : Colors.white,
                                        ),
                                        iconAlignment: Alignment.centerLeft,
                                      )),
                                  Positioned(
                                      bottom: 25.h,
                                      right: -20.w,
                                      child: _labelWithIcon(
                                        label: LabelWidget(
                                            name: translate('home.Isha'),
                                            time: _fmt(aladhanTimes?['isha'] ??
                                                pt?.isha ??
                                                DateTime.now()),
                                            textColor: nextPrayer == Prayer.isha
                                                ? const Color(0xFFFFD700)
                                                : Colors.white),
                                        icon: _prayerIcon(
                                          prayer: Prayer.isha,
                                          color: nextPrayer == Prayer.isha
                                              ? const Color(0xFFFFD700)
                                              : Colors.white,
                                        ),
                                        iconAlignment: Alignment.centerLeft,
                                      )),
                                  Positioned(
                                    bottom: 18.h,
                                    right: 0,
                                    left: 0,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Builder(builder: (context) {
                                          final Prayer prayerToUse =
                                              nextPrayer ?? Prayer.fajr;
                                          final nextPrayerName = translate(
                                              _prayerKey(prayerToUse));

                                          return Text(
                                            translate('home.till_prayer',
                                                args: {
                                                  'prayer': nextPrayerName
                                                }),
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                              color: Colors.white,
                                            ),
                                          );
                                        }),
                                        Builder(builder: (context) {
                                          // debugPrint('🕐 Prayer Timer - nextTime: $nextTime');
                                          return PrayerCountdownTimer(
                                            nextPrayerTime: nextTime,
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ])),
              ],
            ),
          ),
        );
      },
    );
  }
}
