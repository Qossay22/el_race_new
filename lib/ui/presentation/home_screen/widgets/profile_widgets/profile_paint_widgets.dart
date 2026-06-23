// Keep the original painter for reference (can be removed if not needed)
import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'dart:ui' as ui;

class QRBackgroundPainter extends CustomPainter {
  static var textStyle = TextStyle(
    color: HexColor("#009859"),
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );

  static const spacing = 50.0;
  static const text = '920';

  // Pre-compute text painter once to avoid recreation
  static final _textPainter = TextPainter(
    text: TextSpan(text: text, style: textStyle),
    textDirection: ui.TextDirection.ltr,
  );

  static bool _isInitialized = false;

  @override
  void paint(Canvas canvas, Size size) {
    // Initialize text painter only once
    if (!_isInitialized) {
      _textPainter.layout();
      _isInitialized = true;
    }

    // Use cached text painter and reduce iterations
    final maxX = size.width;
    final maxY = size.height;

    for (double x = 0; x < maxX; x += spacing) {
      for (double y = 0; y < maxY; y += spacing) {
        _textPainter.paint(canvas, Offset(x, y));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom painter for decorative strips
class DecorativeStripPainter extends CustomPainter {
  // Cache the shader to avoid recreation
  static Shader? _cachedShader;
  static Size? _cachedSize;

  @override
  void paint(Canvas canvas, Size size) {
    // Only recreate shader if size changed
    if (_cachedShader == null || _cachedSize != size) {
      _cachedShader = LinearGradient(
        begin: const Alignment(0.0, 1.0), // Bottom
        end: const Alignment(0.0, -1.0), // Top
        colors: [
          Colors.white.withOpacity(0.49),
          const Color(0xFF999999).withOpacity(0.49),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      _cachedSize = size;
    }

    final paint = Paint()..shader = _cachedShader;

    // Create the triangular strip path based on new SVG (36/233 ratio)
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width * 0.154, 0); // 36/233 ≈ 0.154 (15.4% of width)
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom painter for QR background with animated moving numbers
class AnimatedQRBackgroundPainter extends CustomPainter {
  final double animationValue;
  final String empId;

  static var textStyle = TextStyle(
    color: HexColor("#009859"),
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  static const spacing = 40;

  AnimatedQRBackgroundPainter(this.animationValue, this.empId);

  @override
  void paint(Canvas canvas, Size size) {
    // Create text painter with dynamic emp_id
    final textPainter = TextPainter(
      text: TextSpan(text: empId, style: textStyle),
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();

    // Clip to container bounds to keep numbers only inside the white square
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Calculate movement offset - numbers move from bottom-right to top-left
    final moveX = animationValue * spacing;
    final moveY = animationValue * spacing;

    // Create grid and animate it by a small offset. Using a single layer
    // prevents duplicate numbers overlapping in corners.
    final gridWidth = (size.width / spacing).ceil() + 1;
    final gridHeight = (size.height / spacing).ceil() + 1;

    for (int i = -1; i <= gridWidth; i++) {
      for (int j = -1; j <= gridHeight; j++) {
        final baseX = i * spacing;
        final baseY = j * spacing;

        final animatedX = baseX - moveX;
        final animatedY = baseY - moveY;

        // Paint numbers - clipping will automatically constrain to square bounds
        textPainter.paint(canvas, Offset(animatedX, animatedY));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is AnimatedQRBackgroundPainter &&
        (oldDelegate.animationValue != animationValue ||
            oldDelegate.empId != empId);
  }
}
