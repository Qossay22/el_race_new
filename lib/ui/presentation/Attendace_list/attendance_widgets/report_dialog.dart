import 'package:el_race/ui/presentation/Attendace_list/attendance_widgets/report_item.dart';
import 'package:el_race/ui/presentation/Attendace_list/repository/attendance_repository.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AttendanceDialogs {
  static showAttendancePopup(BuildContext context, DateTime selectedStartDate,
      DateTime selectedEndDate) async {
    final startDateStr = DateFormat('yyyy-MM-dd').format(selectedStartDate);
    final endDateStr = DateFormat('yyyy-MM-dd').format(selectedEndDate);

    try {
      final summaryData = await AttendanceRepo().getAttendanceSummary(
        startDate: startDateStr,
        endDate: endDateStr,
      );

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: const Color(0xFFD9D9D9),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 26, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "ATTENDANCE REPORT",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 1.5, // Adjust as needed
                      color: appFontColor,
                    ),
                  ),
                  Text(
                    DateFormat('MMM yyyy').format(selectedEndDate),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                      color: appFontColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  AttendanceReportItem(
                      title: "Working Days",
                      value: "${summaryData['working_days']} Days",
                      dotColor: Colors.green),
                  const Divider(color: Colors.grey, thickness: 0.5),
                  AttendanceReportItem(
                      title: "Late Hours",
                      value: "${summaryData['late_hours']} min",
                      dotColor: Colors.red),
                  const Divider(color: Colors.grey, thickness: 0.5),
                  AttendanceReportItem(
                      title: "Absent",
                      value: "${summaryData['absent_days']} Days",
                      dotColor: Colors.black),
                  const Divider(color: Colors.grey, thickness: 0.5),
                  AttendanceReportItem(
                      title: "Sick Leave",
                      value: "${summaryData['sick_leaves']} Days",
                      dotColor: Colors.orange),
                  const Divider(color: Colors.grey, thickness: 0.5),
                  AttendanceReportItem(
                      title: "Annual Leave",
                      value: "${summaryData['annual_leaves']} Days",
                      dotColor: Colors.blue),
                  const Divider(color: Colors.grey, thickness: 0.5),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close",
                          style: TextStyle(color: appFontColor, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      debugPrint("Failed to fetch summary: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Failed to load report")));
    }
  }
}
