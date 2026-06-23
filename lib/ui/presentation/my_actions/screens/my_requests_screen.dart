import 'package:el_race/ui/presentation/my_actions/data/my_actions_models.dart';
import 'package:el_race/ui/presentation/my_actions/data/my_actions_repository.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  final MyActionsRepository _repo = MyActionsRepository();
  late final Future<List<MyActionItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.fetchMyRequests();
  }

  String _statusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'approve':
      case 'approved':
      case 'validate':
      case 'validate2':
      case 'done':
        return 'APPROVED';
      case 'refuse':
      case 'refused':
      case 'rejected':
      case 'cancel':
      case 'cancelled':
      case 'canceled':
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

  String _formatDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '--/--/----';
    final normalized = raw.trim().replaceFirst(' ', 'T');
    final dt = DateTime.tryParse(normalized) ?? DateTime.tryParse(raw.trim());
    if (dt == null) return raw;
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const HeaderWidget(),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<MyActionItem>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Failed to load requests',
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF5A5A5A),
                  ),
                ),
              );
            }

            final items = snapshot.data ?? const <MyActionItem>[];

            return ListView(
              padding: EdgeInsets.only(top: 10.h, bottom: 80.h),
              children: [
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/newapp/newicon/my_action_my_request.png',
                        width: 30.w,
                        height: 30.w,
                        fit: BoxFit.contain,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'MY REQUESTS',
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF171A2E),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),
                if (items.isEmpty)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 30.h),
                      child: Text(
                        'No requests available.',
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
                      padding:
                          EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
                      child: _MyRequestCard(
                        requestNo: (item.reference?.trim().isNotEmpty == true)
                            ? item.reference!.trim()
                            : item.name,
                        title: (item.requestType?.trim().isNotEmpty == true)
                            ? item.requestType!.trim()
                            : item.name,
                        employeeName: item.employeeName,
                        employeeFileId: item.fileId ?? '',
                        updatedAt: _formatDate(item.date),
                        statusBadgeAsset: _statusRibbonAsset(item.status),
                        statusLabel: _statusLabel(item.status),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MyRequestCard extends StatelessWidget {
  final String requestNo;
  final String title;
  final String employeeName;
  final String employeeFileId;
  final String updatedAt;
  final String statusBadgeAsset;
  final String statusLabel;

  const _MyRequestCard({
    required this.requestNo,
    required this.title,
    required this.employeeName,
    required this.employeeFileId,
    required this.updatedAt,
    required this.statusBadgeAsset,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150.h,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(color: const Color(0xFF8E8E8E), width: 1),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: SizedBox(
              width: 84.w,
              height: 48.h,
              child: Stack(
                alignment: Alignment.topLeft,
                children: [
                  SvgPicture.asset(
                    statusBadgeAsset,
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
                            statusLabel,
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
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(18.w, 10.h, 18.w, 15.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    requestNo.trim().isEmpty ? 'REQ/-' : requestNo,
                    maxLines: null,
                    overflow: TextOverflow.visible,
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0D3E7F),
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  title.toUpperCase(),
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
                  employeeName.trim().isEmpty ? '-' : employeeName,
                  maxLines: null,
                  overflow: TextOverflow.visible,
                  style: GoogleFonts.poppins(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF484848).withAlpha(184),
                  ),
                ),
                if (employeeFileId.trim().isNotEmpty)
                  Text(
                    'File ID: $employeeFileId',
                    maxLines: null,
                    overflow: TextOverflow.visible,
                    style: GoogleFonts.poppins(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF686868),
                    ),
                  ),
                const Spacer(),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Last Updated',
                        style: GoogleFonts.poppins(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFB1B1B1),
                        ),
                      ),
                      Text(
                        updatedAt,
                        style: GoogleFonts.poppins(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFB1B1B1),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
