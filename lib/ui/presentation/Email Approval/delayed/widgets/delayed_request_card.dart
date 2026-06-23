import 'package:el_race/core/constants/app_images.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// A card widget for displaying a delayed request item
/// Matches the design from the screenshot with employee image, request info, and days delayed badge
class DelayedRequestCard extends StatelessWidget {
  final String reqNo;
  final String requestType;
  final String employeeName;
  final String empCode;
  final String requestDate;
  final String employeeImageUrl;
  final int daysDelayed;
  final VoidCallback? onTap;

  const DelayedRequestCard({
    super.key,
    required this.reqNo,
    required this.requestType,
    required this.employeeName,
    required this.empCode,
    required this.requestDate,
    required this.employeeImageUrl,
    required this.daysDelayed,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const double stripWidth = 34;

    return Container(
      height: 165.w,
      margin: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.w),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18.r),
          child: Stack(
            children: [
              Positioned.fill(
                child: Ink(
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8DCE1),
                    borderRadius: BorderRadius.circular(18.r),
                    border:
                        Border.all(color: const Color(0xFF80858C), width: 1),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 8.w,
                    right: 8.w + stripWidth,
                    top: 9.w,
                    bottom: 8.w,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 36.w,
                              child: Stack(
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      width: 36.w,
                                      height: 36.w,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFFE7EBEF),
                                          width: 1.3,
                                        ),
                                      ),
                                      child: ClipOval(
                                        child: _buildEmployeeImage(36.w),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 40.w),
                                    child: Center(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          reqNo,
                                          style: GoogleFonts.poppins(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w900,
                                            color: const Color(0xFF0B2D5E),
                                            letterSpacing: 0.2,
                                          ),
                                          maxLines: null,
                                          overflow: TextOverflow.visible,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.w),
                      Padding(
                        padding: EdgeInsets.only(left: 2.w),
                        child: Text(
                          requestType,
                          style: GoogleFonts.poppins(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF121212),
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                      SizedBox(height: 2.w),
                      Padding(
                        padding: EdgeInsets.only(left: 2.w),
                        child: Text(
                          employeeName,
                          style: GoogleFonts.poppins(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6C7075),
                          ),
                          maxLines: null,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                      SizedBox(height: 1.5.w),
                      Padding(
                        padding: EdgeInsets.only(left: 2.w),
                        child: Text(
                          empCode,
                          style: GoogleFonts.poppins(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF565B61),
                          ),
                          maxLines: null,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: EdgeInsets.only(left: 2.w),
                        child: Text(
                          requestDate,
                          style: GoogleFonts.poppins(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF70757C),
                          ),
                          maxLines: null,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 20.w,
                bottom: 0,
                child: SizedBox(
                  width: stripWidth,
                  height: double.infinity,
                  child: ColoredBox(
                    color: const Color(0xFFC62828),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$daysDelayed',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 20.sp,
                                height: 1.0,
                              ),
                            ),
                            SizedBox(height: 6.w),
                            RotatedBox(
                              quarterTurns: 3,
                              child: Text(
                                'Days Delayed',
                                textAlign: TextAlign.center,
                                maxLines: null,
                                overflow: TextOverflow.visible,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 8.sp,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeImage(double size) {
    final url = employeeImageUrl.trim();
    if (url.isNotEmpty &&
        (url.startsWith('http://') || url.startsWith('https://'))) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        height: size,
        width: size,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            AppImages.personImage,
            fit: BoxFit.cover,
            height: size,
            width: size,
          );
        },
      );
    }

    return Image.asset(
      AppImages.personImage,
      fit: BoxFit.cover,
      height: size,
      width: size,
    );
  }
}
