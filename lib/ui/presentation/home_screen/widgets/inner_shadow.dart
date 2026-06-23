import 'package:flutter/material.dart';

class InnerShadowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double blur = 6;
    final Rect rect = Offset.zero & size;

    final Paint shadowPaint = Paint()
      ..color = Colors.black.withAlpha((0.1 * 255).toInt())
      ..maskFilter = const MaskFilter.blur(BlurStyle.inner, blur);

    final RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(40));
    canvas.drawRRect(rrect, shadowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
