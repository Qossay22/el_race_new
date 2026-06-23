import 'package:el_race/ui/presentation/my_actions/data/my_actions_models.dart';
import 'package:el_race/ui/presentation/my_actions/widgets/my_actions_pagination_mixin.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class HrScreen extends StatefulWidget {
  const HrScreen({super.key});

  @override
  State<HrScreen> createState() => _HrScreenState();
}

class _HrScreenState extends State<HrScreen>
    with MyActionsPaginationMixin<HrScreen> {
  @override
  MyActionsType get actionsType => MyActionsType.hr;

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
                child: TextButton(
                  onPressed: retryInitialActionsLoad,
                  child: const Text('Retry'),
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
                    title: 'HR',
                  ),
                  SizedBox(height: 12.h),
                  if (items.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 30.h),
                        child: Text(
                          'No actions available.',
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
                        child: _HrRequestCard(
                          requestNo: item.reference?.trim().isNotEmpty == true
                              ? item.reference!
                              : item.name,
                          title: item.requestType?.trim().isNotEmpty == true
                              ? item.requestType!
                              : 'REQUEST',
                          employeeName: item.employeeName.trim().isEmpty
                              ? '-'
                              : item.employeeName,
                          requestId: '${item.id}',
                          updatedAt: _formatDate(item.date),
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

class _HrRequestCard extends StatelessWidget {
  final String requestNo;
  final String title;
  final String employeeName;
  final String requestId;
  final String updatedAt;
  final String statusBadgeAsset;
  final String statusLabel;

  const _HrRequestCard({
    required this.requestNo,
    required this.title,
    required this.employeeName,
    required this.requestId,
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
          _StatusRibbon(assetPath: statusBadgeAsset, label: statusLabel),
          MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.noScaling,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(18.w, 10.h, 18.w, 15.h),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Text(
                              requestNo.trim().isEmpty ? 'REQ/-' : requestNo,
                              maxLines: null,
                              overflow: TextOverflow.visible,
                              style: GoogleFonts.poppins(
                                fontSize: 17.sp,
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
                            employeeName,
                            maxLines: null,
                            overflow: TextOverflow.visible,
                            style: GoogleFonts.poppins(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xB8484848),
                            ),
                          ),
                          SizedBox(height: 1.h),
                          Text(
                            requestId,
                            style: GoogleFonts.poppins(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
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
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFB1B1B1),
                                  ),
                                ),
                                Text(
                                  updatedAt,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.sp,
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
                  );
                },
              ),
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
