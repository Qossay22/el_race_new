import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/widgets/horizontal_slider_widget.dart';
import 'package:flutter/material.dart';

class HomCheckIn extends StatelessWidget {
  final Function(double val) value;
  const HomCheckIn({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Slide to check in'.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF1A1A53),
            fontFamily: 'Poppins',
            letterSpacing: 0,
            fontWeight: FontWeight.w700,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: GradientSliderWidget(
            onValueChanged: (currentVal) {
              value(currentVal);
            },
            loginResponseModel: SharedPref.getLoginData(), // ✅ Pass it here
          ),
        ),
      ],
    );
  }
}
