import 'dart:io';

import 'package:el_race/report_module/core/constants/colors.dart';
import 'package:el_race/report_module/core/constants/text_styles.dart';
import 'package:el_race/report_module/data/models/report_item_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class ReportItem extends StatelessWidget {
  final ReportItemModel item;
  final VoidCallback onMoreClicked;
  final VoidCallback onTap;
  final int index;
  const ReportItem(
      {super.key,
      required this.item,
      required this.onMoreClicked,
      required this.onTap,
      required this.index});

  @override
  Widget build(BuildContext context) {
    final bool isTextItem = item.type == "text";
    final String day = DateFormat.d().format(item.createdAt);
    final String month = DateFormat.MMMM().format(item.createdAt);
    final String year = DateFormat.y().format(item.createdAt);
    final String formattedDate =
        DateFormat("dd MMM yyyy, HH:mma").format(item.createdAt);

    Widget thumbnail = Container(
      width: 110.w,
      height: 110.w,
      decoration: BoxDecoration(
        color: CustomColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isTextItem
          ? Center(
              child: Image.asset(
              "assets/png/text.png",
              height: 28,
              width: 28,
            ))
          : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(item.image),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: CustomColors.black.withOpacity(0.4),
                  ),
                ),
              ),
            ),
    );

    return GestureDetector(
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 210.h,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/png/background.png"),
                  fit: BoxFit.fill,
                ),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(24.w, 16.h, 16.w, 16.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 12.h),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            thumbnail,
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Image.asset(
                                        "assets/png/icons/tag.png",
                                        height: 12.h,
                                        width: 12.w,
                                        color: CustomColors.black,
                                      ),
                                      SizedBox(width: 8.w),
                                      Text(
                                        isTextItem ? "TEXT ENTRY" : "PHOTO",
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                          color: CustomColors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (item.description.isNotEmpty)
                                    Padding(
                                      padding: EdgeInsets.only(
                                        top: 8.h,
                                        right: 12.w,
                                      ),
                                      child: Text(
                                        item.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.visible,
                                        style: CustomTextStyle.reportHeader
                                            .copyWith(
                                          fontWeight: FontWeight.normal,
                                          color: CustomColors.black,
                                        ),
                                      ),
                                    ),
                                  SizedBox(height: 10.h),
                                  Text(
                                    formattedDate,
                                    style: CustomTextStyle.smallGrey.copyWith(
                                      color: CustomColors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Padding(
                              padding: EdgeInsets.only(top: 6.h),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    width: 58.w,
                                    height: 92.h,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(10.97),
                                        topRight: Radius.circular(10.97),
                                        bottomLeft: Radius.circular(10.97),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 42.w,
                                          height: 42.h,
                                          alignment: Alignment.center,
                                          padding: EdgeInsets.only(top: 6.h),
                                          decoration: const BoxDecoration(
                                            image: DecorationImage(
                                              image: AssetImage(
                                                  "assets/png/date_box_bg.png"),
                                              fit: BoxFit.fill,
                                            ),
                                          ),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              day,
                                              maxLines: null,
                                              softWrap: false,
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.poppins(
                                                fontSize: 14.16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          month,
                                          maxLines: null,
                                          overflow: TextOverflow.visible,
                                          style: GoogleFonts.poppins(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xff1A1A53),
                                          ),
                                        ),
                                        Text(
                                          year,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xff1A1A53),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 8.w,
                    top: 8.h,
                    child: Row(
                      children: [
                        InkWell(
                            onTap: onMoreClicked,
                            child: const Icon(
                              Icons.more_vert_rounded,
                              color: Colors.black,
                            )),
                        SizedBox(width: 6.w),
                        ReorderableDragStartListener(
                          index: index,
                          child: const Icon(
                            Icons.drag_handle_rounded,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
