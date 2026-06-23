import 'dart:convert';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ApprovalCardTypeTwo extends StatelessWidget {
  final Map<dynamic, dynamic> item;
  final bool isExpanded;
  final VoidCallback onTap;

  const ApprovalCardTypeTwo({
    super.key,
    required this.item,
    required this.isExpanded,
    required this.onTap,
  });

  // Helper method to check if image_emp is a URL or base64 data
  bool _isImageUrl(String imageData) {
    return imageData.startsWith('http://') || imageData.startsWith('https://');
  }

  // Helper widget to display employee image (URL or base64)
  Widget _buildEmployeeImage(dynamic imageEmp) {
    if (imageEmp != null &&
        imageEmp is String &&
        imageEmp.isNotEmpty &&
        imageEmp.toLowerCase() != "false") {
      if (_isImageUrl(imageEmp)) {
        // It's a URL, use Image.network
        return Image.network(
          imageEmp,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(
              'assets/png/profile_1.png',
              fit: BoxFit.cover,
            );
          },
        );
      } else {
        // It's base64 data, decode it
        try {
          return Image.memory(
            base64Decode(imageEmp),
            fit: BoxFit.cover,
          );
        } catch (e) {
          return Image.asset(
            'assets/png/profile_1.png',
            fit: BoxFit.cover,
          );
        }
      }
    }
    // Fallback to default image
    return Image.asset(
      'assets/png/profile_1.png',
      fit: BoxFit.cover,
    );
  }

  @override
  Widget build(BuildContext context) {
    String name = item["name"] ?? '';
    String type = item["type"] ?? 'ALL';
    String empName = item["approver"] ?? '';
    String location = item["location"] ?? 'N/A';
    String status = item["status"] ?? 'pending';
    String date = item["date"] ?? '';

    List<String> nameParts = name.split(' ');
    List<String> requesterParts = empName.split(" - ");
    String requesterName = requesterParts.isNotEmpty ? requesterParts[0] : '';
    String requesterRole = requesterParts.length > 1 ? requesterParts[1] : '';

    Color getStatusColor(String status) {
      switch (status.toLowerCase()) {
        case 'approved':
          return Colors.green;
        case 'rejected':
          return Colors.red;
        case 'pending':
        default:
          return Colors.orange;
      }
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 105.w,
        width: 350.w,
        margin: EdgeInsets.symmetric(horizontal: 10.w),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                height: 73.w,
                width: 73.w,
                padding: EdgeInsets.all(6.w),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: _buildEmployeeImage(item["image_emp"]),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 130.w,
                      child: Text(
                        requesterName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.visible,
                        maxLines: null,
                      ),
                    ),
                    SizedBox(height: 5.w),
                    Text(
                      name,
                      style: TextStyle(color: greyText, fontSize: 13.sp),
                      overflow: TextOverflow.visible,
                      maxLines: null,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 6.w, horizontal: 8.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const InfoContainer(text: 'Job Mission'),
                      SizedBox(height: 6.w),
                      InfoContainer(text: name),
                      SizedBox(height: 6.w),
                      InfoContainer(
                        text: date,
                        icon: Image.asset('assets/newapp/calendar.png',
                            width: 14.w, height: 14.w),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InfoContainer extends StatelessWidget {
  final String text;
  final Widget? icon;
  final double? fontSize;
  final double? width;

  const InfoContainer({
    super.key,
    required this.text,
    this.icon,
    this.fontSize,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      height: 27.w,
      width: width ?? 120.w,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF1A1A53), width: 1),
        borderRadius: BorderRadius.circular(13.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            icon!,
            SizedBox(width: 2.w),
          ],
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: fontSize ?? 11.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1A53),
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.visible,
          ),
        ],
      ),
    );
  }
}
