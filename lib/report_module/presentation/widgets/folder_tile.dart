import 'package:el_race/report_module/data/models/folder_model.dart';
import 'package:el_race/report_module/presentation/screens/report_listing/project_reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class FolderTile extends StatelessWidget {
  final FolderModel folder;
  final ValueChanged<String> onMenuSelected;
  final VoidCallback? onTap;
  final VoidCallback? onShareTap;
  final VoidCallback? onDragTap;

  const FolderTile({
    super.key,
    required this.folder,
    required this.onMenuSelected,
    this.onTap,
    this.onShareTap,
    this.onDragTap,
  });

  String _updatedDateOnly() {
    return DateFormat('dd/MM/yyyy').format(folder.updatedAt);
  }

  Widget _buildLatestImagesRow() {
    if (folder.latestItemImages.isEmpty) {
      return Text(
        'No images',
        style: GoogleFonts.poppins(
          fontSize: 12.sp,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF9AA0A6),
        ),
      );
    }

    final displayCount =
        folder.latestItemImages.length > 5 ? 5 : folder.latestItemImages.length;
    final totalItems =
        folder.latestItemsTotalCount > folder.latestItemImages.length
            ? folder.latestItemsTotalCount
            : folder.latestItemImages.length;
    final remaining = totalItems > 5 ? totalItems - 5 : 0;

    return Row(
      children: [
        ...List.generate(displayCount, (index) {
          return Align(
            widthFactor: 1,
            child: Container(
              width: 38.w,
              height: 38.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.6),
              ),
              child: ClipOval(
                child: Image.network(
                  folder.latestItemImages[index],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFE5E7EB),
                    child: Icon(
                      Icons.image,
                      size: 14.w,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
        if (remaining > 0)
          Padding(
            padding: EdgeInsets.only(left: 8.w),
            child: Text(
              '+$remaining',
              style: GoogleFonts.poppins(
                fontSize: 10.146.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF27304E),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ??
          () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        ProjectReportsScreen(folder: folder)));
          },
      child: Container(
        margin: EdgeInsets.fromLTRB(14.w, 0, 14.w, 12.h),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: const Color(0xFFE8E8E8),
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(color: const Color(0xFF9A9A9A), width: 1),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: 0.42,
                  heightFactor: 1,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.78,
                      child: Transform.scale(
                        scale: 1.0,
                        alignment: Alignment.topRight,
                        child: SvgPicture.asset(
                          'assets/newapp/Vector 103.svg',
                          fit: BoxFit.contain,
                          alignment: Alignment.topRight,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 12.w, 8.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              folder.name.isEmpty ? 'Report Name' : folder.name,
                              style: GoogleFonts.poppins(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF27304E),
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.visible,
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              _updatedDateOnly(),
                              style: GoogleFonts.poppins(
                                fontSize: 12.741.sp,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF27304E),
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 6.w),
                      SizedBox(
                        height: 24.h,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Theme(
                              data: Theme.of(context).copyWith(
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: const VisualDensity(
                                  horizontal: -4,
                                  vertical: -4,
                                ),
                              ),
                              child: PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                splashRadius: 16,
                                color: const Color(0xFFF1F1F1),
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                  side: const BorderSide(
                                    color: Color(0xFFD8D8D8),
                                    width: 1,
                                  ),
                                ),
                                icon: Icon(
                                  Icons.more_vert,
                                  size: 22.w,
                                  color: const Color(0xFF27304E),
                                ),
                                onSelected: onMenuSelected,
                                itemBuilder: (context) => [
                                  PopupMenuItem<String>(
                                    value: 'rename',
                                    height: 42.h,
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 12.w),
                                    child: Row(
                                      children: [
                                        SvgPicture.asset(
                                          'assets/newapp/newicon/rename_svgrepo.com.svg',
                                          width: 13.w,
                                          height: 13.w,
                                          colorFilter: const ColorFilter.mode(
                                            Color(0xFF9A9A9A),
                                            BlendMode.srcIn,
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Text(
                                          'Rename',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF9A9A9A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuDivider(height: 1),
                                  PopupMenuItem<String>(
                                    value: 'delete',
                                    height: 42.h,
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 12.w),
                                    child: Row(
                                      children: [
                                        SvgPicture.asset(
                                          'assets/newapp/newicon/delete-folder_svgrepo.com.svg',
                                          width: 13.w,
                                          height: 13.w,
                                          colorFilter: const ColorFilter.mode(
                                            Color(0xFF9A9A9A),
                                            BlendMode.srcIn,
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Text(
                                          'Delete',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF9A9A9A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: onDragTap,
                              borderRadius: BorderRadius.circular(20.r),
                              child: Padding(
                                padding: EdgeInsets.only(left: 4.w, right: 2.w),
                                child: Icon(
                                  Icons.menu_rounded,
                                  size: 22.w,
                                  color: const Color(0xFF27304E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: _buildLatestImagesRow()),
                      InkWell(
                        onTap: onShareTap,
                        borderRadius: BorderRadius.circular(99.r),
                        child: Container(
                          width: 36.w,
                          height: 36.w,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF27304E),
                          ),
                          child: Icon(
                            Icons.share,
                            size: 18.w,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
