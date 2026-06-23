import 'package:flutter/material.dart';

/// Draggable corner handle widget for crop adjustment.
///
/// Shows a visible handle that users can drag to adjust document corners.
class CornerHandle extends StatelessWidget {
  /// Size of the handle
  final double size;

  /// Color of the handle
  final Color color;

  /// Border color
  final Color borderColor;

  const CornerHandle({
    super.key,
    this.size = 40,
    this.color = Colors.white,
    this.borderColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: borderColor,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: size * 0.4,
          height: size * 0.4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: borderColor,
          ),
        ),
      ),
    );
  }
}

/// A magnifier widget that shows zoomed content around a corner.
///
/// Useful for precise corner adjustment.
class CornerMagnifier extends StatelessWidget {
  /// The image to magnify
  final Widget image;

  /// Position of the corner
  final Offset cornerPosition;

  /// Size of the magnifier
  final double size;

  /// Magnification factor
  final double magnification;

  const CornerMagnifier({
    super.key,
    required this.image,
    required this.cornerPosition,
    this.size = 100,
    this.magnification = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: Transform.scale(
          scale: magnification,
          child: Transform.translate(
            offset: Offset(
              -cornerPosition.dx + size / (2 * magnification),
              -cornerPosition.dy + size / (2 * magnification),
            ),
            child: image,
          ),
        ),
      ),
    );
  }
}

/// Grid lines overlay for crop adjustment.
class CropGridOverlay extends StatelessWidget {
  /// Number of horizontal divisions
  final int horizontalDivisions;

  /// Number of vertical divisions
  final int verticalDivisions;

  /// Line color
  final Color lineColor;

  /// Line width
  final double lineWidth;

  const CropGridOverlay({
    super.key,
    this.horizontalDivisions = 3,
    this.verticalDivisions = 3,
    this.lineColor = const Color(0x40FFFFFF),
    this.lineWidth = 1,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: GridPainter(
            horizontalDivisions: horizontalDivisions,
            verticalDivisions: verticalDivisions,
            lineColor: lineColor,
            lineWidth: lineWidth,
          ),
        );
      },
    );
  }
}

class GridPainter extends CustomPainter {
  final int horizontalDivisions;
  final int verticalDivisions;
  final Color lineColor;
  final double lineWidth;

  GridPainter({
    required this.horizontalDivisions,
    required this.verticalDivisions,
    required this.lineColor,
    required this.lineWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke;

    // Draw vertical lines
    final verticalSpacing = size.width / verticalDivisions;
    for (int i = 1; i < verticalDivisions; i++) {
      final x = verticalSpacing * i;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Draw horizontal lines
    final horizontalSpacing = size.height / horizontalDivisions;
    for (int i = 1; i < horizontalDivisions; i++) {
      final y = horizontalSpacing * i;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) {
    return horizontalDivisions != oldDelegate.horizontalDivisions ||
        verticalDivisions != oldDelegate.verticalDivisions ||
        lineColor != oldDelegate.lineColor ||
        lineWidth != oldDelegate.lineWidth;
  }
}
