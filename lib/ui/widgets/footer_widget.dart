import 'package:flutter/material.dart';

import '../../utils/color_utils.dart';

class FooterWidget extends StatelessWidget {
  const FooterWidget({super.key});

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
