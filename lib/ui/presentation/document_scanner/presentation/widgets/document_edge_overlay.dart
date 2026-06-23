import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Overlay widget that displays detected document edges on camera preview.
///
/// Shows:
/// - Semi-transparent overlay outside document area
/// - Border around detected document
/// - Corner indicators
class DocumentEdgeOverlay extends StatelessWidget {
  /// Detected corner points (top-left, top-right, bottom-right, bottom-left)
  final List<ui.Offset>? corners;

  /// Size of the camera preview
  final Size previewSize;

  /// Color of the border when document is detected
  final Color detectedColor;

  /// Color of the overlay outside the document
  final Color overlayColor;

  /// Border width
  final double borderWidth;

  const DocumentEdgeOverlay({
    super.key,
    this.corners,
    required this.previewSize,
    this.detectedColor = Colors.blue,
    this.overlayColor = const Color(0x80000000),
    this.borderWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: EdgeOverlayPainter(
            corners: corners,
            previewSize: previewSize,
            detectedColor: detectedColor,
            overlayColor: overlayColor,
            borderWidth: borderWidth,
          ),
        );
      },
    );
  }
}

class EdgeOverlayPainter extends CustomPainter {
  final List<ui.Offset>? corners;
  final Size previewSize;
  final Color detectedColor;
  final Color overlayColor;
  final double borderWidth;

  EdgeOverlayPainter({
    this.corners,
    required this.previewSize,
    required this.detectedColor,
    required this.overlayColor,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (corners == null || corners!.length != 4) {
      // No document detected - just show guidance
      _drawGuidanceOverlay(canvas, size);
      return;
    }

    // Scale corners from preview size to canvas size
    final scaledCorners = _scaleCorners(corners!, size);

    // Draw overlay outside document area
    _drawOverlay(canvas, size, scaledCorners);

    // Draw document border
    _drawBorder(canvas, scaledCorners);

    // Draw corner handles
    _drawCornerHandles(canvas, scaledCorners);
  }

  List<Offset> _scaleCorners(List<ui.Offset> corners, Size canvasSize) {
    // Calculate scale factors
    // The preview might be rotated, so we need to handle both orientations
    final scaleX = canvasSize.width / previewSize.height;
    final scaleY = canvasSize.height / previewSize.width;

    return corners.map((corner) {
      return Offset(
        corner.dx * scaleX,
        corner.dy * scaleY,
      );
    }).toList();
  }

  void _drawGuidanceOverlay(Canvas canvas, Size size) {
    // Draw subtle guidance frame
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const margin = 40.0;
    final rect = Rect.fromLTWH(
      margin,
      margin,
      size.width - margin * 2,
      size.height - margin * 2,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      paint,
    );

    // Draw corner marks
    const cornerLength = 30.0;
    final cornerPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(
      Offset(rect.left, rect.top + cornerLength),
      Offset(rect.left, rect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left + cornerLength, rect.top),
      cornerPaint,
    );

    // Top-right
    canvas.drawLine(
      Offset(rect.right - cornerLength, rect.top),
      Offset(rect.right, rect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.top + cornerLength),
      cornerPaint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(rect.right, rect.bottom - cornerLength),
      Offset(rect.right, rect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.bottom),
      Offset(rect.right - cornerLength, rect.bottom),
      cornerPaint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(rect.left + cornerLength, rect.bottom),
      Offset(rect.left, rect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left, rect.bottom - cornerLength),
      cornerPaint,
    );
  }

  void _drawOverlay(Canvas canvas, Size size, List<Offset> corners) {
    // Create path for the document area
    final documentPath = Path()
      ..moveTo(corners[0].dx, corners[0].dy)
      ..lineTo(corners[1].dx, corners[1].dy)
      ..lineTo(corners[2].dx, corners[2].dy)
      ..lineTo(corners[3].dx, corners[3].dy)
      ..close();

    // Create path for the entire canvas
    final canvasPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Combine paths to create overlay outside document
    final overlayPath = Path.combine(
      PathOperation.difference,
      canvasPath,
      documentPath,
    );

    final overlayPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(overlayPath, overlayPaint);
  }

  void _drawBorder(Canvas canvas, List<Offset> corners) {
    final borderPaint = Paint()
      ..color = detectedColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(corners[0].dx, corners[0].dy)
      ..lineTo(corners[1].dx, corners[1].dy)
      ..lineTo(corners[2].dx, corners[2].dy)
      ..lineTo(corners[3].dx, corners[3].dy)
      ..close();

    canvas.drawPath(path, borderPaint);
  }

  void _drawCornerHandles(Canvas canvas, List<Offset> corners) {
    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final handleBorderPaint = Paint()
      ..color = detectedColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    const handleRadius = 8.0;

    for (final corner in corners) {
      // White fill
      canvas.drawCircle(corner, handleRadius, handlePaint);
      // Colored border
      canvas.drawCircle(corner, handleRadius, handleBorderPaint);
    }
  }

  @override
  bool shouldRepaint(EdgeOverlayPainter oldDelegate) {
    return corners != oldDelegate.corners ||
        previewSize != oldDelegate.previewSize;
  }
}
