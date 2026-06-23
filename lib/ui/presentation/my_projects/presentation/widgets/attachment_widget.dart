import 'package:el_race/ui/presentation/my_projects/domain/entities/attachment_entity.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/project_file_opening.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AttachmentWidget extends StatelessWidget {
  final AttachmentEntity item;

  const AttachmentWidget({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    String fileIcon = 'assets/png/file-icon.png';

    if (item.type.contains('pdf') || item.name.toLowerCase().endsWith('.pdf')) {
      fileIcon = 'assets/png/pdf-icon.png';
    } else if (item.type.contains('spreadsheet') ||
        item.type.contains('excel') ||
        item.name.toLowerCase().endsWith('.xlsx') ||
        item.name.toLowerCase().endsWith('.xls')) {
      fileIcon = 'assets/png/excel-icon.png';
    }

    return GestureDetector(
      onTap: () => openProjectFileInApp(
        context,
        rawUrl: item.url,
        fileName: item.name,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(width: 1, color: Colors.black26),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              fileIcon,
              height: 60.w,
              width: 60.w,
            ),
            const SizedBox(height: 12),
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
