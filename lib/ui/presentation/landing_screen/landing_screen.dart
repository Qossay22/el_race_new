import 'package:el_race/ui/presentation/landing_screen/bloc/location_bloc/location_bloc.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:el_race/ui/presentation/signin/data/repository.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';

import '../../widgets/custom_navbar.dart';
import '../call_screen/call_screen.dart';
import '../home_screen/screens/home_screen.dart';

class LandingScreen extends StatefulWidget {
  final LoginResponseModel loginResponseModel;
  const LandingScreen({super.key, required this.loginResponseModel});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  var _selectedIndex = 0;
  late List<Widget> _pages;
  final _userRepo = UserRepo();
  final String _deviceId = '';
  final _locationBloc = LocationBloc();

  void _onItemTapped(int index) {
    if (index == 0) {
      // Show a message for the first tab
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This page is in progress'),
        ),
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // List of pages or widgets that you want to display for each navigation item
    _pages = [
      const SizedBox(), // Placeholder for the first tab
      const HomeScreen(),
      const CallScreen(),
    ];
    _locationBloc.add(GetCurrentLocationET());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGrey,
      bottomNavigationBar: CustomBottomNavbar(
        currentIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
      body: Stack(
        children: [
          // Background Image within App Boundary
          SafeArea(
            bottom: false,
            child: Positioned.fill(
              child: Image.asset(
                'assets/png/chatgpt.png', // Replace with your image path
                fit: BoxFit.cover, // Ensures the image covers the full screen
              ),
            ),
          ),

          // Current Page Content
          SafeArea(
            bottom: false,
            child: _selectedIndex == 0
                ? const Center(
                    child: Text(
                      'This page is in progress',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : _pages[_selectedIndex],
          ),
        ],
      ),
    );
  }
}
