import 'package:el_race/core/constants/colors.dart';
import 'package:el_race/core/constants/text_styles.dart';
import 'package:el_race/data/models/report_model.dart';
import 'package:el_race/data/repositories/company_repository.dart';
import 'package:flutter/material.dart';

PreferredSize getBottomAppBar(context,
    {ReportModel? report, bool edit = false, VoidCallback? onClick}) {
  return PreferredSize(
      preferredSize: Size(double.infinity, (report != null) ? 58 : 38),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: 33,
            color: CustomColors.maroon,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
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
          if (report != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              height: 20,
              color: CustomColors.blue,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    report.name,
                    style: CustomTextStyle.reportHeader,
                  ),
                ],
              ),
            ),
        ],
      ));
}
