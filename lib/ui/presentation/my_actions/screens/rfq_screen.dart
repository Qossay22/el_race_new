import 'package:el_race/ui/presentation/my_actions/data/my_actions_models.dart';
import 'package:el_race/ui/presentation/my_actions/widgets/my_actions_pagination_mixin.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class RfqScreen extends StatefulWidget {
  const RfqScreen({super.key});

  @override
  State<RfqScreen> createState() => _RfqScreenState();
}

class _RfqScreenState extends State<RfqScreen>
    with MyActionsPaginationMixin<RfqScreen> {
  final DateFormat _sectionDateFormat = DateFormat('dd/MM/yyyy');
  final DateFormat _updatedDateFormat = DateFormat('dd/MM/yyyy');

  @override
  MyActionsType get actionsType => MyActionsType.rfq;

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

  String _formatAmount(double? amount) {
    if (amount == null) return '';
    return '${NumberFormat.decimalPattern().format(amount)} AED';
  }

  DateTime? _parseDate(String? rawDate) {
    if (rawDate == null || rawDate.trim().isEmpty) {
      return null;
    }
    final normalized = rawDate.trim().replaceFirst(' ', 'T');
    return DateTime.tryParse(normalized) ?? DateTime.tryParse(rawDate.trim());
  }

  String _sectionTitle(DateTime? dateTime) {
    if (dateTime == null) return 'today';
    final now = DateTime.now();
    final isToday = now.year == dateTime.year &&
        now.month == dateTime.month &&
        now.day == dateTime.day;
    return isToday ? 'today' : _sectionDateFormat.format(dateTime);
  }

  String _formatUpdatedDate(DateTime? dateTime) {
    if (dateTime == null) return '--/--/----';
    return _updatedDateFormat.format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
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
            final sectionItems = items.map((item) {
              final updatedDate = _parseDate(item.date);
              return _RfqRequestItem(
                requestNo: (item.reference?.trim().isNotEmpty == true)
                    ? item.reference!.trim()
                    : item.name,
                title: item.project ?? '',
                workOrder: item.vendor ?? '',
                employeeName: item.employeeName,
                amount: _formatAmount(item.amountTotal),
                statusBadgeAsset: _statusRibbonAsset(item.status),
                statusLabel: _statusLabel(item.status),
                lastUpdated: _formatUpdatedDate(updatedDate),
                updatedDate: updatedDate,
              );
            }).toList();

            final grouped = <String, List<_RfqRequestItem>>{};
            final orderedTitles = <String>[];
            for (final item in sectionItems) {
              final title = _sectionTitle(item.updatedDate);
              if (!grouped.containsKey(title)) {
                grouped[title] = <_RfqRequestItem>[];
                orderedTitles.add(title);
              }
              grouped[title]!.add(item);
            }

            final sections = orderedTitles
                .map((title) =>
                    _RfqSection(title: title, items: grouped[title]!))
                .toList();

            return RefreshIndicator(
              onRefresh: refreshActions,
              child: ListView(
                controller: actionsScrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(top: 8.h, bottom: 80.h),
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/newapp/newicon/rfq_header.png',
                            width: 26.w,
                            height: 26.w,
                            fit: BoxFit.contain,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'RFQ',
                            style: GoogleFonts.poppins(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF101C36),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (sectionItems.isEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 24.h),
                      child: Center(
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
                    ...sections.expand((section) {
                      return [
                        _SectionHeader(title: section.title),
                        SizedBox(height: 10.h),
                        ...section.items.map(
                          (item) => Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16.w, vertical: 7.h),
                            child: _RfqRequestCard(item: item),
                          ),
                        ),
                        SizedBox(height: 14.h),
                      ];
                    }),
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

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 18.w, top: 6.h),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16.sp,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF767676),
        ),
      ),
    );
  }
}

class _RfqRequestCard extends StatelessWidget {
  final _RfqRequestItem item;

  const _RfqRequestCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 152.h,
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(30.r),
        border: Border.all(color: const Color(0xFF9F9F9F), width: 1),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.only(topLeft: Radius.circular(30.r)),
              child: _StatusBadge(
                assetPath: item.statusBadgeAsset,
                label: item.statusLabel,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    item.requestNo,
                    maxLines: null,
                    overflow: TextOverflow.visible,
                    style: GoogleFonts.poppins(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0A3887),
                    ),
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  item.title.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  style: GoogleFonts.poppins(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111111),
                    height: 1.15,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  item.workOrder,
                  maxLines: null,
                  overflow: TextOverflow.visible,
                  style: GoogleFonts.poppins(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF777777),
                  ),
                ),
                Text(
                  item.employeeName,
                  maxLines: null,
                  overflow: TextOverflow.visible,
                  style: GoogleFonts.poppins(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF777777),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    SizedBox(width: 86.w),
                    Expanded(
                      child: Center(
                        child: Text(
                          item.amount,
                          style: GoogleFonts.poppins(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF073A85),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 92.w,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Last Updated',
                            style: GoogleFonts.poppins(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFB8B8B8),
                            ),
                          ),
                          Text(
                            item.lastUpdated,
                            style: GoogleFonts.poppins(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFB8B8B8),
                            ),
                          ),
                        ],
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

class _StatusBadge extends StatelessWidget {
  final String assetPath;
  final String label;

  const _StatusBadge({required this.assetPath, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 73.w,
      height: 41.h,
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
    );
  }
}

class _RfqSection {
  final String title;
  final List<_RfqRequestItem> items;

  const _RfqSection({required this.title, required this.items});
}

class _RfqRequestItem {
  final String requestNo;
  final String title;
  final String workOrder;
  final String employeeName;
  final String amount;
  final String statusBadgeAsset;
  final String statusLabel;
  final String lastUpdated;
  final DateTime? updatedDate;

  const _RfqRequestItem({
    required this.requestNo,
    required this.title,
    required this.workOrder,
    required this.employeeName,
    required this.amount,
    required this.statusBadgeAsset,
    required this.statusLabel,
    required this.lastUpdated,
    required this.updatedDate,
  });
}
