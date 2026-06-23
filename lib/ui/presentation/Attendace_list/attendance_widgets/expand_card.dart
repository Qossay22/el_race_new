import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ExpandCard extends StatelessWidget {
  final String status;
  final Color textColor;
  final Color bgColorStart;
  final Color bgColorEnd;
  const ExpandCard(
      {super.key,
      required this.status,
      required this.textColor,
      required this.bgColorStart,
      required this.bgColorEnd});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey("expanded"),
      height: 54.h,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [bgColorStart, bgColorEnd]),
        borderRadius: BorderRadius.circular(30),
        // boxShadow: [
        //   BoxShadow(
        //     color: bgColorEnd
        //         .withAlpha((0.3 * 255).toInt()),
        //     blurRadius: 6,
        //     spreadRadius: 1,
        //     offset: const Offset(0, 4),
        //   )
        // ],
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 11,
          ),
          const Spacer(),
          Text(
            status,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
