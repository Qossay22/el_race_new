import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class TimeStatusWidget extends StatelessWidget {
  const TimeStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final checkInTime = SharedPref().getPreferenceString('checkInDisplayTime');
    final checkOutTime =
        SharedPref().getPreferenceString('checkOutDisplayTime');

    // If empty or null, use default
    final displayCheckIn = (checkInTime.isEmpty) ? '00:00:00' : checkInTime;
    final displayCheckOut = (checkOutTime.isEmpty) ? '00:00:00' : checkOutTime;

    return Container(
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          // First Row - Check-in Time
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/png/icons/Ellipse_green.png',
                width: 16.w,
                height: 16.w,
              ),
              const SizedBox(width: 8),
              Text(
                displayCheckIn,
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1A1A53),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Second Row - Check-out Time
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/png/icons/Ellipse_red.png',
                width: 16.w,
                height: 16.w,
              ),
              const SizedBox(width: 8),
              Text(
                displayCheckOut,
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1A1A53),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
