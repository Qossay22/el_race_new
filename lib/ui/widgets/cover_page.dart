import 'package:el_race/core/constants/colors.dart';
import 'package:el_race/core/constants/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CoverPageTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onMoreClicked;
  const CoverPageTile(
      {super.key, required this.data, required this.onMoreClicked});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigator.push(
        //     context,
        //     MaterialPageRoute(
        //         builder: (context) => ReportDetailScreen(report: report)));
      },
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: CustomColors.containerColor),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        data['title'],
                        style: CustomTextStyle.heading
                            .copyWith(color: CustomColors.black),
                      ),
                    ),
                    const SizedBox(
                      width: 20,
                    )
                  ],
                ),
                Text(
                  DateFormat("dd MMM yyyy HH:mma").format(data['created_at']),
                  style: CustomTextStyle.smallGrey,
                ),
                // Text(
                //   "Updated At : ${DateFormat("MMM yyyy HH:mma").format(report.createdAt)}",
                //   style: CustomTextStyle.smallGrey,
                // ),
                if (data['description'] != null && data['description'] != "")
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      data['description'],
                      style: CustomTextStyle.reportHeader
                          .copyWith(color: CustomColors.black),
                    ),
                  ),

                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: CustomColors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
                  child: Text(
                    "Cover Page",
                    style: CustomTextStyle.smallWhite,
                  ),
                )
              ],
            ),
            Positioned(
                right: 0,
                top: 0,
                child: InkWell(
                    onTap: onMoreClicked, child: const Icon(Icons.more_vert_rounded)))
          ],
        ),
      ),
    );
  }
}
