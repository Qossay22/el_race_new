import 'package:el_race/resources/app_colors.dart';
import 'package:el_race/ui/presentation/my_projects/domain/entities/project_entity.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_list_event.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_dialog.dart';
import 'package:el_race/utils/Util.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../bloc/project_list_bloc.dart';

class ProjectCardWidget extends StatelessWidget {
  final ProjectEntity item;
  final ProjectListBloc bloc;

  const ProjectCardWidget({super.key, required this.item, required this.bloc});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Show dialog with 3 options: Work Order, Estimations, Cloud
        ProjectDocumentsDialog.show(
          context,
          projectId: item.projectId,
          bloc: bloc,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Stack(
          //   alignment: Alignment.centerLeft,
          //   children: [
          //     // Container(
          //     //   width: 20.w,
          //     //   height: 28.w,
          //     //   margin: EdgeInsets.only(
          //     //     left: 20.w,
          //     //   ),
          //     //   decoration: BoxDecoration(
          //     //     color: red,
          //     //     boxShadow: [
          //     //       BoxShadow(
          //     //         color: red.withValues(alpha: 0.3),
          //     //         blurRadius: 4,
          //     //         spreadRadius: 1,
          //     //       ),
          //     //     ],
          //     //   ),
          //     // ),
          //     // Container(
          //     //   height: 37.w,
          //     //   width: 210.w,
          //     //   alignment: Alignment.centerLeft,
          //     //   margin: EdgeInsets.only(left: 30.w),
          //     //   padding: const EdgeInsets.symmetric(horizontal: 10),
          //     //   decoration: const BoxDecoration(
          //     //       image: DecorationImage(
          //     //           image:
          //     //               AssetImage('assets/newapp/back_ground_card.png'))),
          //     //   child: SizedBox(
          //     //     width: 190.w,
          //     //     child: Text(
          //     //       item.name,
          //     //       style: GoogleFonts.poppins(
          //     //         fontSize: 12.sp,
          //     //         fontWeight: FontWeight.w500,
          //     //         color: Colors.white,
          //     //         letterSpacing: 1.2,
          //     //       ),
          //     //       overflow: TextOverflow.visible,
          //     //     ),
          //     //   ),
          //     // ),
          //   ],
          // ),
          Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
            width: 357.65.w,
            height: 210.h,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/png/background.png"),
                fit: BoxFit.fill,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(36, 16, 16, 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Image.asset(
                              "assets/newapp/my_projects.png",
                              height: 24.h,
                              width: 24.w,
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 225.w,
                              child: Text(
                                item.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 19.26,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.black,
                                  letterSpacing: 1.2,
                                ),
                                overflow: TextOverflow.visible,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // const Icon(Icons.more_horiz,
                      //     size: 20, color: Colors.black),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 60.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                "assets/png/icons/tag.png",
                                height: 10.h,
                                width: 10.w,
                                color: Colors.black,
                              ),
                              SizedBox(width: 10.w),
                              SizedBox(
                                width: 100,
                                child: Text(
                                  "WORK ORDER",
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    color: black,
                                    //letterSpacing: 1.0,
                                  ),
                                  overflow: TextOverflow.visible,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Image.asset(
                                "assets/png/icons/hand.png",
                                height: 11.14.h,
                                width: 18.03.w,
                                color: black,
                              ),
                              SizedBox(width: 2.w),
                              SizedBox(
                                width: 170.w,
                                child: Text(
                                  item.agreementId,
                                  maxLines: null,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.06,
                                    fontWeight: FontWeight.w400,
                                    color: black,
                                    // letterSpacing: 1.0,
                                  ),
                                  overflow: TextOverflow.visible,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 35.w,
                            height: 35.h,
                            // padding: const EdgeInsets.all(6),
                            margin: EdgeInsets.only(bottom: 4.h),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(color: black, width: 1),
                            ),
                            child: Center(
                              child: Text(
                                '+12',
                                style: GoogleFonts.poppins(
                                  fontSize: 16.76.sp,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.green,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 54.w,
                            height: 90.h,
                            margin: EdgeInsets.only(
                              right: 10.w,
                            ),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(10.97),
                                topRight: Radius.circular(10.97),
                                bottomLeft: Radius.circular(10.97),
                              ),
                              // image: DecorationImage(
                              //   image: AssetImage("assets/png/date_box_bg.png"),
                              //   fit: BoxFit.contain,
                              // ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 36.w,
                                  height: 40.h,
                                  alignment: Alignment.center,
                                  padding: EdgeInsets.symmetric(
                                        horizontal: 8.h,
                                      ) +
                                      EdgeInsets.only(top: 4.h),
                                  decoration: const BoxDecoration(
                                    image: DecorationImage(
                                      image: AssetImage(
                                          "assets/png/date_box_bg.png"),
                                      fit: BoxFit.fill,
                                    ),
                                  ),
                                  child: Text(
                                    Util.isValidDateTime(item.date)
                                        ? DateTime.parse(item.date)
                                            .day
                                            .toString()
                                        : '',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14.16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  Util.isValidDateTime(item.date)
                                      ? DateFormat.MMMM()
                                          .format(DateTime.parse(item.date))
                                      : '',
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xff1A1A53),
                                  ),
                                  maxLines: null,
                                  overflow: TextOverflow.visible,
                                ),
                                Text(
                                  Util.isValidDateTime(item.date)
                                      ? DateTime.parse(item.date)
                                          .year
                                          .toString()
                                      : '',
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
                    ],
                  ),
                  // Transform.translate(
                  //   offset: Offset(0, -15.w),
                  //   child: Row(
                  //     children: [
                  //       // SizedBox(
                  //       //   width: 200,
                  //       //   child: Text(
                  //       //     item.partnerId,
                  //       //     style: GoogleFonts.poppins(
                  //       //       fontSize: 12,
                  //       //       color: Colors.black,
                  //       //       letterSpacing: 1.0,
                  //       //     ),
                  //       //     overflow: TextOverflow.visible,
                  //       //     maxLines: 2,
                  //       //     softWrap: false,
                  //       //   ),
                  //       // ),
                  //       // Container(
                  //       //   width: 50.w,
                  //       //   height: 50.w,
                  //       //   decoration: BoxDecoration(
                  //       //     shape: BoxShape.circle,
                  //       //     border: Border.all(color: Colors.white, width: 2),
                  //       //   ),
                  //       //   child: ClipOval(
                  //       //     child: Image.asset(
                  //       //       'assets/png/profile_1.png',
                  //       //       fit: BoxFit.cover,
                  //       //       width: double.infinity,
                  //       //       height: double.infinity,
                  //       //     ),
                  //       //   ),
                  //       // ),
                  //       // const Spacer(),
                  //     ],
                  //   ),
                  // ),
                  SizedBox(height: 14.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
