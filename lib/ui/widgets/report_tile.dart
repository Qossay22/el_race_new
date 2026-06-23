import 'package:el_race/core/constants/colors.dart';
import 'package:el_race/core/constants/text_styles.dart';
import 'package:el_race/ui/presentation/My_task/screens/report_detail/report_detail.dart';
import 'package:el_race/ui/presentation/My_task/screens/report_listing/folder_reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/report_model.dart';

class ReportTile extends StatelessWidget {
  final ReportModel report;
  final ValueChanged<String> onMenuSelected;
  const ReportTile(
      {super.key, required this.report, required this.onMenuSelected});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (report.report == 2) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => FolderReportScreen(folder: report)));
        } else {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => ReportDetailScreen(report: report)));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
                        report.name,
                        style: CustomTextStyle.reportTitle,
                      ),
                    ),
                    const SizedBox(
                      width: 20,
                    )
                  ],
                ),
                Text(
                  DateFormat("dd MMM yyyy HH:mma").format(report.createdAt),
                  style: CustomTextStyle.smallGrey,
                ),
                // Text(
                //   "Updated At : ${DateFormat("MMM yyyy HH:mma").format(report.createdAt)}",
                //   style: CustomTextStyle.smallGrey,
                // ),
                if (report.description != null && report.description != "")
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      report.description!,
                      style: CustomTextStyle.smallGrey,
                    ),
                  ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: CustomColors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
                  child: Text(
                    report.report == 1 ? "Report" : "Project",
                    style: CustomTextStyle.smallWhite,
                  ),
                )
              ],
            ),
            Positioned(
                right: 0,
                top: 0,
                child: PopupMenuButton<String>(
                  tooltip: 'More options',
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: onMenuSelected,
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'rename',
                      child: Text('Rename'),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ))
          ],
        ),
      ),
    );
  }
}
