import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A reusable vertical status strip that attaches to the right edge of a card.
///
/// Requirements:
/// - Fixed width (default ~46px)
/// - Full parent height
/// - Solid red background
/// - Rounded ONLY on top-right & bottom-right corners
/// - Text rotated 90° counter-clockwise using RotatedBox
/// - Text perfectly centered
class StatusStrip extends StatelessWidget {
  final String text;
  final double? width;
  final double? radius;
  final Color color;

  const StatusStrip({
    super.key,
    required this.text,
    this.width,
    this.radius,
    this.color = const Color(0xFFC62828),
  });

  @override
  Widget build(BuildContext context) {
    final stripWidth = width ?? 46.w;
    final r = radius ?? 22.r;

    return SizedBox(
      width: stripWidth,
      height: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(r),
          bottomRight: Radius.circular(r),
          topLeft: Radius.zero,
          bottomLeft: Radius.zero,
        ),
        child: ColoredBox(
          color: color,
          child: Center(
            child: RotatedBox(
              quarterTurns: 3, // 90° counter-clockwise (bottom -> top)
              child: Text(
                text,
                textAlign: TextAlign.center,
                maxLines: null,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.sp,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
