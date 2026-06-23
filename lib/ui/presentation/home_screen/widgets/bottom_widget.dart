import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';

class BottomWidget extends StatelessWidget {
  final Function() onTapped;
  const BottomWidget({super.key, required this.onTapped});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..scale(-1.0, 1.0), // Flip horizontally
          child: Image.asset('assets/png/bottom.png'),
        ),
        const SizedBox.shrink(),
      ],
    );
  }
}
