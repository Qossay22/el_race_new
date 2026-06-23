import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomSliderButton extends StatefulWidget {
  final Future<void> Function() onSlideComplete;
  final dynamic loginResponseModel;
  final bool enableProgressColor;
  final LinearGradient? idleGradient;
  final LinearGradient? completedGradient;
  final Color? idleBorderColor;
  final Color? completedBorderColor;
  final Color? idleLabelColor;
  final Color? completedLabelColor;
  final Color? idleHandleColor;
  final Color? completedHandleColor;

  const CustomSliderButton({
    super.key,
    required this.onSlideComplete,
    required this.loginResponseModel,
    this.enableProgressColor = true,
    this.idleGradient,
    this.completedGradient,
    this.idleBorderColor,
    this.completedBorderColor,
    this.idleLabelColor,
    this.completedLabelColor,
    this.idleHandleColor,
    this.completedHandleColor,
  });

  @override
  CustomSliderButtonState createState() => CustomSliderButtonState();
}

class CustomSliderButtonState extends State<CustomSliderButton> {
  double _position = 5.0;
  bool _isCompleted = false;

  void resetSlider() {
    setState(() {
      _position = 5.0;
      _isCompleted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // progress 0..1
    double progress;
    if (widget.enableProgressColor) {
      progress = (_position - 5) / (230 - 5);
    } else {
      progress = 0.0;
    }
    progress = progress.clamp(0.0, 1.0);

    Color dynamicColor = Color.lerp(Colors.white, Colors.green, progress)!;
    if (_isCompleted) dynamicColor = Colors.green;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 280,
            height: 45.h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                width: _isCompleted ? 3 : 2,
                color: _isCompleted
                    ? (widget.completedBorderColor ?? Colors.green.shade900)
                    : (widget.idleBorderColor ?? Colors.grey.withOpacity(0.25)),
              ),
              gradient: _isCompleted
                  ? (widget.completedGradient ??
                      LinearGradient(
                        colors: [Colors.green.shade600, Colors.green.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ))
                  : (widget.idleGradient ??
                      LinearGradient(
                        colors: [
                          dynamicColor.withOpacity(0.95),
                          dynamicColor.withOpacity(0.8)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )),
              boxShadow: [
                BoxShadow(
                  color: _isCompleted
                      ? Colors.green.withOpacity(0.25)
                      : Colors.grey.withAlpha((0.5 * 255).toInt()),
                  blurRadius: _isCompleted ? 8 : 0,
                  offset:
                      _isCompleted ? const Offset(0, 3) : const Offset(0, 0),
                ),
              ],
            ),
          ),

          // Handle
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            left: _isCompleted ? 244 : _position,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                if (_isCompleted) return;
                setState(() {
                  _position = (details.localPosition.dx + 5).clamp(5, 230);
                });
              },
              onHorizontalDragEnd: (details) {
                if (_isCompleted) return;
                if (_position > 168) {
                  setState(() {
                    _position = 230;
                    _isCompleted = true;
                  });

                  Future.delayed(const Duration(milliseconds: 50), () async {
                    await widget.onSlideComplete();
                  });
                } else {
                  setState(() => _position = 5);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _isCompleted
                      ? (widget.completedHandleColor ?? Colors.white)
                      : (widget.idleHandleColor ?? Colors.indigo.shade900),
                  shape: BoxShape.circle,
                  border: _isCompleted
                      ? Border.all(color: Colors.green.shade900, width: 4)
                      : null,
                  boxShadow: [
                    if (_isCompleted)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                  ],
                ),
                alignment: Alignment.center,
                child: AnimatedRotation(
                  turns: _isCompleted ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: Icon(
                    Icons.arrow_forward_ios,
                    key: const ValueKey('handle'),
                    color: _isCompleted
                        ? (widget.completedLabelColor ?? Colors.indigo.shade900)
                        : Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),

          // Label
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: Text(
                "SUBMIT",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: _isCompleted
                      ? (widget.completedLabelColor ?? Colors.indigo.shade900)
                      : (widget.idleLabelColor ?? appFontColor),
                  letterSpacing: 2.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
