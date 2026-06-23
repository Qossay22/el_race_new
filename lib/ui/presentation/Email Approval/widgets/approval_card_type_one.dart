import 'package:el_race/resources/app_colors.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ApprovalCardTypeOne extends StatelessWidget {
  final Map<dynamic, dynamic> item;
  final bool isExpanded;
  final VoidCallback onTap;

  const ApprovalCardTypeOne({
    super.key,
    required this.item,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String id = item["id"] ?? '';
    String name = item["name"] ?? '';
    String type = item["type"] ?? 'ALL';
    String empName = item["requester"] ?? '';
    String date = item["date"] ?? '2024-08-09';
    String reqNo = item["req_no"] ?? 'REQ-${id.substring(0, 6)}';
    String title = item["title"] ?? name;
    String status = item["status"] ?? 'pending';

    List<String> requesterParts = empName.split(" - ");
    String requesterName = requesterParts.isNotEmpty ? requesterParts[0] : '';

    DateTime parsedDate = DateTime.tryParse(date) ?? DateTime.now();

    Color bgColorStart = Colors.blue.shade100;
    Color bgColorEnd = Colors.blue.shade300;
    Color textColor = Colors.blue.shade800;
    String backgroundImage = "assets/png/background.png";

    Color getStatusColor() {
      switch (status.toLowerCase()) {
        case 'approved':
          return const Color(0xff009859);
        case 'rejected':
          return red;
        case 'pending':
        default:
          return AppColors.statusPending;
      }
    }

    return InkWell(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          isExpanded
              ? Container(
                  key: const ValueKey("expanded"),
                  height: 70.w,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A53),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 11),
                      const Spacer(),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: getStatusColor(),
                          fontWeight: FontWeight.bold,
                          fontSize: 20.sp,
                          letterSpacing: 1,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                )
              : Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    if (backgroundImage.isNotEmpty && !isExpanded)
                      Container(
                        width: 60.w,
                        height: 70.w,
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        margin: const EdgeInsets.only(top: 3),
                        decoration: BoxDecoration(
                          color: getStatusColor(),
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                    Container(
                      height: 70.w,
                      alignment: Alignment.center,
                      key: const ValueKey("collapsed"),
                      padding: EdgeInsets.symmetric(horizontal: 10.w),
                      margin: EdgeInsets.only(left: 4.w, top: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 1),
                          Text(
                            DateFormat('dd MMM yy').format(parsedDate),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: appFontColor,
                            ),
                          ),
                          const SizedBox(
                            height: 39.5,
                            child: VerticalDivider(
                                color: Colors.grey, thickness: 1),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                translate('home.REQ_NO'),
                                style: GoogleFonts.poppins(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.bold,
                                  color: appFontColor,
                                ),
                              ),
                              Text(
                                reqNo,
                                style: GoogleFonts.poppins(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 39.5,
                            child: VerticalDivider(
                                color: Colors.grey, thickness: 1),
                          ),
                          SizedBox(
                            width: 90.w,
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                              maxLines: null,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
          // AnimatedAlign(
          //   alignment: isExpanded ? Alignment.centerLeft : Alignment.centerRight,
          //   duration: const Duration(milliseconds: 900),
          //   curve: Curves.easeInOut,
          //   child: Container(
          //     margin: EdgeInsets.symmetric(horizontal: 10.w),
          //     key: ValueKey(isExpanded),
          //     width: 50.w,
          //     height: 50.w,
          //     decoration: BoxDecoration(
          //       shape: BoxShape.circle,
          //       border: Border.all(color: Colors.white, width: 2),
          //     ),
          //     child: ClipOval(
          //       child: (item["image_emp"] != null &&
          //               item["image_emp"] is String &&
          //               (item["image_emp"] as String).isNotEmpty &&
          //               (item["image_emp"] as String).toLowerCase() != "false")
          //           ? Image.memory(
          //               base64Decode(item["image_emp"] as String),
          //               fit: BoxFit.cover,
          //               width: double.infinity,
          //               height: double.infinity,
          //             )
          //           : Image.asset(
          //               'assets/png/profile_1.png',
          //               fit: BoxFit.cover,
          //               width: double.infinity,
          //               height: double.infinity,
          //             ),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }
}
