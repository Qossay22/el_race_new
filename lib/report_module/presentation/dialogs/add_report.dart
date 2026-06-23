import 'package:el_race/report_module/data/provider/reports_provider.dart';
import 'package:el_race/report_module/data/repositories/company_repository.dart';
import 'package:el_race/report_module/presentation/screens/report_photos/report_photos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/app_globals.dart' show navKey;

Future<bool> showAddNewReport(BuildContext context,
    {required int type, String? folderID}) async {
  TextEditingController nameController = TextEditingController();

  bool cancel = true;

  await showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (ctx) {
      return Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 10.w),
        backgroundColor: Colors.transparent,
        child: Container(
          width: 1.sw,
          padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 16.h),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(22.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    width: 30.w,
                    height: 30.w,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE81E25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, color: Colors.white, size: 18.w),
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              _ReportNameSection(
                controller: nameController,
              ),
              SizedBox(height: 16.h),
              SizedBox(
                height: 47.h,
                child: ElevatedButton(
                  onPressed: () {
                    if (nameController.text.trim().isNotEmpty) {
                      cancel = false;
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFF27304E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.r),
                    ),
                  ),
                  child: Text(
                    'Start',
                    style: GoogleFonts.poppins(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (cancel || nameController.text.trim().isEmpty) return false;

  ReportProvider provider =
      Provider.of<ReportProvider>(navKey.currentContext!, listen: false);
  final reportName = nameController.text.trim();
  if (type == 2) {
    final previousFolderIds = provider.folders.map((f) => f.id).toSet();
    await provider.createFolder(
      title: reportName,
      description: CompanyRepository.company?.companyName ?? '',
    );
    final createdFolderIndex = provider.folders.indexWhere(
      (folder) => !previousFolderIds.contains(folder.id),
    );
    if (createdFolderIndex == -1) return false;

    if (context.mounted) {
      final createdFolder = provider.folders[createdFolderIndex];
      final createdReportIndex = provider.reports.indexWhere(
        (report) => report.folderId == createdFolder.id,
      );
      final createdReport = createdReportIndex != -1
          ? provider.reports[createdReportIndex]
          : await provider.getOrCreateSingleReportForFolder(createdFolder);
      if (createdReport != null && context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReportPhotosScreen(
              report: createdReport,
              folderName: createdFolder.name,
              folderId: createdFolder.id,
            ),
          ),
        );
      }
    }
    return true;
  } else {
    await provider.createReport(title: reportName, folderID: folderID!);
    return true;
  }
}

class _ReportNameSection extends StatelessWidget {
  final TextEditingController controller;

  const _ReportNameSection({
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFB9BBC3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Report',
            style: GoogleFonts.poppins(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6A6D78),
            ),
          ),
          Text(
            'Name',
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF151A36),
            ),
          ),
          SizedBox(height: 8.h),
          Container(
            height: 40.h,
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            decoration: BoxDecoration(
              color: const Color(0xFFEFEFEF),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: const Color(0xFFCFCFCF), width: 1),
            ),
            child: TextField(
              controller: controller,
              style: GoogleFonts.poppins(
                fontSize: 11.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF272A36),
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Enter report name',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFA2A4AA),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 10.h),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
