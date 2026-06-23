import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomBulletPoint extends StatelessWidget {
  final Color? bulletColor;
  final String text;
  final Color textColor;
  final String count;
  final Color countColor;
  final Color containerColor;
  final String? days;
  final bool isAttendance;
  final bool showCount;

  const CustomBulletPoint({
    super.key,
    this.bulletColor,
    required this.text,
    required this.textColor,
    required this.count,
    required this.countColor,
    this.days = 'Days',
    this.isAttendance = false,
    required this.containerColor,
    this.showCount = true,
  });

  @override
  Widget build(BuildContext context) {
    // Inherit the style from DefaultTextStyle
    final defaultTextStyle = DefaultTextStyle.of(context).style;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Custom bullet design
          // Container(
          //   width: 10,
          //   height: 10,
          //   decoration: BoxDecoration(
          //     color: bulletColor, // Bullet color
          //     borderRadius: BorderRadius.circular(2),
          //   ),
          // ),
          // const SizedBox(width: 4), // Spacing between bullet and text
          SizedBox(
            width: 120.w,
            child: Text(
              text,
              maxLines: 2,
              style: GoogleFonts.poppins(
                color: Colors.black,
                fontSize: 14.sp,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w600, // ✅ Bold applied
              ),
            ),
          ),
          if (showCount)
            CountWidget(
              count: count,
              countColor: countColor,
              containerColor: containerColor,
            ),

          // const SizedBox(width: 8),
          // isAttendance
          //     ? Text(days ?? '',
          //         style: GoogleFonts.poppins(
          //           fontSize: 14.sp,
          //           fontWeight: FontWeight.w500,
          //         ))
          //     : const Text(''),
        ],
      ),
    );
  }
}

class CountWidget extends StatelessWidget {
  final String count;
  final Color countColor;
  final double? width;
  final Color containerColor;
  const CountWidget(
      {super.key,
      required this.count,
      required this.countColor,
      this.width,
      required this.containerColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? 30.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: containerColor,
        // borderRadius: BorderRadius.circular(3),
        shape: BoxShape.circle,
        // border: Border.all(width: 1, ),
      ),
      child: Text(
        count.toUpperCase(),
        style: GoogleFonts.poppins(
            color: countColor,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500, // ✅ Bold applied
            letterSpacing: 0.09),
      ),
    );
  }
}
