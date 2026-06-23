import 'package:el_race/ui/presentation/my_projects/data/datasources/project_remote_datasource.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_document_item_model.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/screens/cloud_documents_screen.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_list_bloc.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_list_event.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/screens/attachment_list.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Document type enum for the popup options
enum ProjectDocumentType {
  workOrder,
  estimations,
  cloud,
}

/// Shows the Project Documents popup dialog
class ProjectDocumentsDialog extends StatelessWidget {
  final int projectId;
  final ProjectListBloc bloc;

  const ProjectDocumentsDialog({
    super.key,
    required this.projectId,
    required this.bloc,
  });

  static Future<void> show(
    BuildContext context, {
    required int projectId,
    required ProjectListBloc bloc,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => ProjectDocumentsDialog(
        projectId: projectId,
        bloc: bloc,
      ),
    );
  }

  void _onOptionTap(BuildContext context, ProjectDocumentType type) {
    Navigator.pop(context); // Close dialog

    switch (type) {
      case ProjectDocumentType.workOrder:
        debugPrint("=====================================");
        debugPrint("🔵 WORK ORDER CLICKED");
        debugPrint("API: https://erp.elrace.com/api/get_project_attachments");
        debugPrint("Method: POST");
        debugPrint('Body: {"jsonrpc":"2.0","params":{"project_id":$projectId,"folder_type":"wo"}}');
        debugPrint("=====================================");
        // Go directly to attachments screen with folder_type: "wo"
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AttachmentListScreen(
              bloc: bloc,
              projectId: projectId,
              folderType: 'wo',
            ),
          ),
        );
        break;
      case ProjectDocumentType.estimations:
        debugPrint("=====================================");
        debugPrint("💰 ESTIMATIONS CLICKED");
        debugPrint("API: https://erp.elrace.com/api/get_project_attachments");
        debugPrint("Method: POST");
        debugPrint('Body: {"jsonrpc":"2.0","params":{"project_id":$projectId,"folder_type":"estimation"}}');
        debugPrint("=====================================");
        // Go directly to attachments screen with folder_type: "estimation"
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AttachmentListScreen(
              bloc: bloc,
              projectId: projectId,
              folderType: 'estimation',
            ),
          ),
        );
        break;
      case ProjectDocumentType.cloud:
        debugPrint("=====================================");
        debugPrint("☁️  CLOUD CLICKED");
        debugPrint("API: https://erp.elrace.com/api/projects/documents");
        debugPrint("Method: GET (with body)");
        debugPrint('Body: {"jsonrpc":"2.0","params":{"project_id":$projectId}}');
        debugPrint("=====================================");
        // Go to cloud folders screen using projects/documents API
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CloudDocumentsScreen(
              projectId: projectId,
            ),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 40.w),
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close button
            Stack(
              children: [
                // Centered title with icon
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 24.w,
                        color: const Color(0xFF151544),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Project Documents',
                        style: GoogleFonts.poppins(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF151544),
                        ),
                      ),
                    ],
                  ),
                ),
                // Close button on the right
                Positioned(
                  right: 0,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 24.w,
                      height: 24.w,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE74C3C),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 16.w,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),

            // Work Order Option
            _buildOptionButton(
              context: context,
              icon: 'assets/png/work-order.png',
              fallbackIcon: Icons.description,
              label: 'Work order',
              type: ProjectDocumentType.workOrder,
            ),
            SizedBox(height: 12.h),

            // Estimations Option
            _buildOptionButton(
              context: context,
              icon: 'assets/png/coins.png',
              fallbackIcon: Icons.monetization_on,
              label: 'Estimations',
              type: ProjectDocumentType.estimations,
            ),
            SizedBox(height: 12.h),

            // Cloud Option
            _buildOptionButton(
              context: context,
              icon: 'assets/png/cloud.png',
              fallbackIcon: Icons.cloud,
              label: 'Cloud',
              type: ProjectDocumentType.cloud,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required BuildContext context,
    required String icon,
    required IconData fallbackIcon,
    required String label,
    required ProjectDocumentType type,
  }) {
    return GestureDetector(
      onTap: () => _onOptionTap(context, type),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 230.w),
          child: SizedBox(
            height: 52.h,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15.r),
                border: Border.all(
                  color: const Color(0xFF151544),
                  width: 1.3,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 34.w,
                    height: 34.w,
                    child: _buildIcon(icon, fallbackIcon),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF151544),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(String assetPath, IconData fallbackIcon) {
    return Image.asset(
      assetPath,
      width: 24.w,
      height: 24.w,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          fallbackIcon,
          size: 24.w,
          color: const Color(0xFF151544),
        );
      },
    );
  }
}
