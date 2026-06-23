import 'package:el_race/report_module/core/constants/colors.dart';
import 'package:el_race/report_module/core/constants/text_styles.dart';
import 'package:el_race/report_module/data/models/report_detail_model.dart';
import 'package:el_race/report_module/data/repositories/company_repository.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';

PreferredSize getBottomAppBar(context,
    {ReportDetailModel? report,
    String? folderName,
    bool edit = false,
    VoidCallback? onClick}) {
  return PreferredSize(
      preferredSize: Size(
          double.infinity,
          (report != null)
              ? 78
              : folderName != null
                  ? 58
                  : 38),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: 33,
            color: const Color(0xFFD1002C),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (CompanyRepository.company != null)
                  Text(
                    CompanyRepository.company!.companyName,
                    style: CustomTextStyle.heading,
                  ),
                if (edit)
                  InkWell(
                    // padding: EdgeInsets.zero,
                    onTap: onClick!,
                    child: Icon(
                      Icons.edit_note_rounded,
                      color: CustomColors.white,
                    ),
                  )
              ],
            ),
          ),
          if (folderName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              height: 20,
              color: CustomColors.blue,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Image.asset(
                    "assets/png/icons/arrow_turn.png",
                    color: white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Project : $folderName",
                    style: CustomTextStyle.reportHeader,
                  ),
                ],
              ),
            ),
          if (report != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              height: 20,
              color: CustomColors.black,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Image.asset(
                    "assets/png/icons/report_arrow.png",
                    color: white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Report : ${report.report.name}",
                    style: CustomTextStyle.reportHeader,
                  ),
                ],
              ),
            ),
        ],
      ));
}
