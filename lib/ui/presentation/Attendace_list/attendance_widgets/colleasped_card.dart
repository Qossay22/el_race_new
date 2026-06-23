import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ColleaspedCard extends StatelessWidget {
  final String status;
  final Color textColor;
  final Color bgColorStart;
  final Color bgColorEnd;
  final bool isExpanded;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  const ColleaspedCard(
      {super.key,
      required this.status,
      required this.textColor,
      required this.bgColorStart,
      required this.bgColorEnd,
      required this.isExpanded,
      required this.checkInTime,
      required this.checkOutTime});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        if (!isExpanded)
          Container(
            width: 50.w,
            height: 55.h,
            margin: EdgeInsets.only(top: 2.h, left: 3.w),
            decoration: BoxDecoration(
              color: textColor,
              borderRadius: BorderRadius.circular(23),
            ),
          ),
        Container(
          height: 54.h,
          key: const ValueKey("collapsed"),
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          margin: EdgeInsets.only(left: 7.w, top: 2.w),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFD6D6D6), Color(0xFFADB2BD)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(23),
          ),
          child: Row(
            children: [
              // Date
              SizedBox(
                width: 80,
                child: Text(
                  DateFormat('dd MMM yy').format(checkInTime).toUpperCase(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: appFontColor,
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              SizedBox(
                height: 40.h,
                child: const VerticalDivider(color: Colors.grey, thickness: 1),
              ),

              // Check-in
              SizedBox(
                width: 80.w,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Check-in',
                      style: GoogleFonts.poppins(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: appFontColor,
                      ),
                    ),
                    Text(
                      DateFormat('hh:mm a').format(checkInTime),
                      style: GoogleFonts.poppins(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),

              // Check-out
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Check-out',
                      style: GoogleFonts.poppins(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: appFontColor,
                      ),
                    ),
                    Text(
                      checkOutTime != null
                          ? DateFormat('hh:mm a').format(checkOutTime!)
                          : '--:--',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 50.w),
            ],
          ),
        ),
      ],
    );
  }
}
