import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LabelWidget extends StatelessWidget {
  final String name;
  final String time;
  final Color? textColor;
  const LabelWidget({
    super.key,
    required this.name,
    required this.time,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final isGold = textColor?.value == const Color(0xFFFFD700).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(name,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: isGold ? FontWeight.w600 : FontWeight.w400,
              color: textColor ?? Colors.white,
              shadows: isGold
                  ? [
                      const Shadow(
                        color: Colors.black,
                        blurRadius: 4,
                        offset: Offset(0, 0),
                      ),
                    ]
                  : null,
            )),
        Text(time,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: isGold ? FontWeight.w600 : FontWeight.w400,
              color: textColor ?? Colors.white,
              shadows: isGold
                  ? [
                      const Shadow(
                        color: Colors.black,
                        blurRadius: 4,
                        offset: Offset(0, 0),
                      ),
                    ]
                  : null,
            )),
      ],
    );
  }
}
