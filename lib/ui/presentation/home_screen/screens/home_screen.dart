import 'dart:async';

import 'package:el_race/core/services/attendance_status_sync_service.dart';
import 'package:el_race/ui/presentation/home_screen/bloc/home_bloc.dart';
import 'package:el_race/ui/presentation/home_screen/bloc/location_bloc/location_bloc.dart';
import 'package:el_race/ui/presentation/home_screen/screens/main_home_content_widget.dart';
import 'package:el_race/ui/presentation/home_screen/screens/main_screens.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/timer_controller.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:location/location.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const MainScreen();
  }
}

class HomeScreenPage extends StatefulWidget {
  const HomeScreenPage({
    super.key,
  });

  /// Reset the biometric gate so the next login triggers it again.
  static void resetAuthSession() {}

  @override
  State<HomeScreenPage> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreenPage>
    with WidgetsBindingObserver {
  // auth flags are stored on the widget class so they can be reset from outside

  // bool isMuted = false; // default value
  bool isCheckedIn = false;
  final _locationBloc = LocationBloc();
  final Location _location = Location();

  // _loadMuteStatus() {
  //   setState(() {
  //     isMuted = SharedPref().getPreferenceBoolean('mute_notifications');
  //   });
  // }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // مراقبة حالة التطبيق
    Get.put(TimerController()); // only once!
    // _loadMuteStatus();
    // Future.delayed(const Duration(seconds: 5), () {
    //   showBabyGirlPopup(context);
    // });
    _checkLocationService(); // Check location service on initialization
    _locationBloc.add(GetCurrentLocationET());
    // List of pages or widgets that you want to display for each navigation ite
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // إزالة المراقبة
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLocationService(); // إعادة التحقق عند العودة
      _locationBloc.add(GetCurrentLocationET()); // إعادة جلب اللوكيشن

      // مزامنة حالة الحضور من السيرفر عند العودة من الخلفية
      // لضمان تحديث الأوقات والعداد بدون الحاجة لتسجيل خروج/دخول
      AttendanceStatusSyncService.refreshFromServer(reason: 'app_resumed');
    }
  }

  Future<void> _checkLocationService() async {
    // Check if location service is enabled
    bool isServiceEnabled = await _location.serviceEnabled();
    if (!isServiceEnabled) {
      // If not enabled, show popup
      _showLocationServiceDialog();
    }
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(translate('location.enable_service')),
          content: Text(translate('location.please_enable')),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close the dialog
                bool serviceEnabled = await _location.requestService();
                if (!serviceEnabled) {
                  // If still not enabled, show the dialog again
                  _showLocationServiceDialog();
                }
              },
              child: Text(translate('common.ok')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // final screenWidth = MediaQuery.of(context).size.width;
    // final drawerWidth = screenWidth * 0.75; // 75% of screen width
    return Scaffold(
      appBar: const HeaderWidget(),
      backgroundColor: lightGrey,
      extendBody:
          false, // Changed to false since bottomNavigationBar is commented out
      // bottomNavigationBar: CustomBottomNavbar(
      //   currentIndex: _selectedIndex,
      //   onItemTapped: _onItemTapped,
      // ),
      body: Stack(
        children: [
          // Main Content
          const MainHomeContentWidget(),
        ],
      ),
    );
  }
}
