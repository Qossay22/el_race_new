import 'package:el_race/ui/presentation/my_actions/data/my_actions_models.dart';
import 'package:el_race/ui/presentation/my_actions/widgets/my_actions_pagination_mixin.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class TimesheetScreen extends StatefulWidget {
  const TimesheetScreen({super.key});

  @override
  State<TimesheetScreen> createState() => _TimesheetScreenState();
}

class _TimesheetScreenState extends State<TimesheetScreen>
    with MyActionsPaginationMixin<TimesheetScreen> {
  @override
  MyActionsType get actionsType => MyActionsType.timesheet;

  @override
  void initState() {
    super.initState();
    initActionsPagination();
  }

  @override
  void dispose() {
    disposeActionsPagination();
    super.dispose();
  }

  String _statusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'approved':
        return 'APPROVED';
      case 'rejected':
        return 'REJECTED';
      default:
        return 'PENDING';
    }
  }

  String _statusRibbonAsset(String status) {
    switch (_statusLabel(status)) {
      case 'APPROVED':
        return 'assets/newapp/newicon/green_rebon_my_action.svg';
      case 'REJECTED':
        return 'assets/newapp/newicon/red_rebon_my_action.svg';
      default:
        return 'assets/newapp/newicon/orange_rebon_my_action.svg';
    }
  }

  String _formatDate(String? dateRaw) {
    if (dateRaw == null || dateRaw.trim().isEmpty) return '--/--/----';
    final parsed = DateTime.tryParse(dateRaw);
    if (parsed == null) return dateRaw;
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const HeaderWidget(),
      body: SafeArea(
        top: false,
        child: Builder(
          builder: (context) {
            if (actionsInitialLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (actionsError != null && actionItems.isEmpty) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(20.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off,
                          size: 60.w, color: const Color(0xFFB5B7C1)),
                      SizedBox(height: 16.h),
                      Text(
                        'Service not available',
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF5A5A5A),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'This feature is currently unavailable.\nPlease try again later.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 13.sp,
                          color: const Color(0xFF9AA0A6),
                        ),
                      ),
                      SizedBox(height: 14.h),
                      TextButton(
                        onPressed: retryInitialActionsLoad,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final items = List<MyActionItem>.from(actionItems);

            return RefreshIndicator(
              onRefresh: refreshActions,
              child: ListView(
                controller: actionsScrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(top: 10.h, bottom: 80.h),
                children: [
                  const _ActionsHeader(
                    iconAsset: 'assets/png/my-req-frame.png',
                    title: 'TIMESHEETS',
                  ),
                  SizedBox(height: 12.h),
                  if (items.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 30.h),
                        child: Text(
                          'No timesheets found.',
                          style: GoogleFonts.poppins(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF5A5A5A),
                          ),
                        ),
                      ),
                    )
                  else
                    ...items.map(
                      (item) => Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 12.w, vertical: 7.h),
                        child: _TimesheetCard(
                          clientName: item.project?.trim().isNotEmpty == true
                              ? item.project!
                              : 'Client Name',
                          projectName: item.name.trim().isEmpty
                              ? 'PROJECT NAME'
                              : item.name,
                          formanName: item.employeeName.trim().isEmpty
                              ? 'Forman Name'
                              : item.employeeName,
                          dateText: _formatDate(item.date),
                          statusBadgeAsset: _statusRibbonAsset(item.status),
                          statusLabel: _statusLabel(item.status),
                        ),
                      ),
                    ),
                  buildActionsPaginationFooter(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ActionsHeader extends StatelessWidget {
  final String iconAsset;
  final String title;

  const _ActionsHeader({
    required this.iconAsset,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            iconAsset,
            width: 30.w,
            height: 30.w,
            fit: BoxFit.contain,
            color: const Color(0xFFD21B2E),
            colorBlendMode: BlendMode.srcIn,
          ),
          SizedBox(width: 8.w),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF171A2E),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimesheetCard extends StatelessWidget {
  final String clientName;
  final String projectName;
  final String formanName;
  final String dateText;
  final String statusBadgeAsset;
  final String statusLabel;

  const _TimesheetCard({
    required this.clientName,
    required this.projectName,
    required this.formanName,
    required this.dateText,
    required this.statusBadgeAsset,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: 132.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(color: const Color(0xFF8E8E8E), width: 1),
      ),
      child: Stack(
        children: [
          _StatusRibbon(assetPath: statusBadgeAsset, label: statusLabel),
          Padding(
            padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 14.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Text(
                    clientName,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lexendDeca(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF0D3E7F),
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  projectName.toUpperCase(),
                  maxLines: null,
                  overflow: TextOverflow.visible,
                  style: GoogleFonts.poppins(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  formanName,
                  maxLines: null,
                  overflow: TextOverflow.visible,
                  style: GoogleFonts.lexendDeca(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xB8484848),
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    SvgPicture.asset(
                      'assets/newapp/newicon/calendar-03.svg',
                      width: 26.w,
                      height: 26.w,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      dateText,
                      style: GoogleFonts.sora(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF0D3E7F),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRibbon extends StatelessWidget {
  final String assetPath;
  final String label;

  const _StatusRibbon({
    required this.assetPath,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      child: SizedBox(
        width: 84.w,
        height: 48.h,
        child: Stack(
          alignment: Alignment.topLeft,
          children: [
            SvgPicture.asset(
              assetPath,
              width: 73.w,
              height: 41.h,
              fit: BoxFit.contain,
            ),
            Positioned(
              top: 3.h,
              left: 8.w,
              width: 58.w,
              height: 22.h,
              child: Transform.rotate(
                angle: -0.50,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
