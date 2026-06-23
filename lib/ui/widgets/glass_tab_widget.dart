import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Professional glassmorphism tab widget with advanced frosted glass effect
class GlassTabWidget extends StatelessWidget {
  final String icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? selectedColor;
  final Color? unselectedColor;

  const GlassTabWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.selectedColor,
    this.unselectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        alignment: Alignment.center,
        margin: const EdgeInsets.only(top: 6, bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          // Professional layered shadows for depth
          boxShadow: [
            // Main shadow
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
            // Secondary shadow for more depth
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
              spreadRadius: -1,
            ),
            // Top highlight
            BoxShadow(
              color: Colors.white.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(-2, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                // Advanced glass effect with gradient overlay
                gradient: isSelected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.25),
                          (selectedColor ?? const Color(0xFF2D2F81))
                              .withOpacity(0.35),
                          (selectedColor ?? const Color(0xFF2D2F81))
                              .withOpacity(0.25),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.5),
                          Colors.white.withOpacity(0.3),
                          (unselectedColor ?? Colors.grey.shade300)
                              .withOpacity(0.2),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                // Glass border
                border: Border.all(
                  color: Colors.white.withOpacity(isSelected ? 0.5 : 0.7),
                  width: 1.5,
                ),
                // Inner shadow effect
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? Colors.black.withOpacity(0.1)
                        : Colors.transparent,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                    spreadRadius: -2,
                    blurStyle: BlurStyle.inner,
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    icon,
                    height: 25.w,
                    color: isSelected ? Colors.white : const Color(0xFF1A237E),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    title.toUpperCase(),
                    style: GoogleFonts.poppins(
                      color:
                          isSelected ? Colors.white : const Color(0xFF1A237E),
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.7,
                      shadows: isSelected
                          ? [
                              Shadow(
                                color: Colors.black.withOpacity(0.4),
                                offset: const Offset(0, 2),
                                blurRadius: 4,
                              ),
                              Shadow(
                                color: Colors.black.withOpacity(0.2),
                                offset: const Offset(0, 1),
                                blurRadius: 2,
                              ),
                            ]
                          : [
                              Shadow(
                                color: Colors.white.withOpacity(0.8),
                                offset: const Offset(0, 1),
                                blurRadius: 2,
                              ),
                            ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
