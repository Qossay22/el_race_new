import 'dart:convert';
import 'package:el_race/core/constants/app_images.dart';
import 'package:el_race/core/services/approval_count_service.dart';
import 'package:el_race/core/services/approval_viewed_service.dart';
import 'package:el_race/ui/presentation/Email%20Approval/Approval_confirmation.dart';
import 'package:el_race/ui/presentation/Email%20Approval/screens/hr_details_screen.dart';
import 'package:el_race/ui/presentation/Email%20Approval/screens/pettycash_details_screen.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class HrAndPettycashCard extends StatelessWidget {
  final List<dynamic> approvalItems;
  final VoidCallback? onRefresh;

  const HrAndPettycashCard({
    super.key,
    required this.approvalItems,
    this.onRefresh,
  });

  String _formatAmountForCard(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.\-]'), '');
    final value = double.tryParse(cleaned);
    if (value == null) return raw;
    if (value % 1 == 0) {
      return NumberFormat('#,##0', 'en_US').format(value);
    }
    return NumberFormat('#,##0.##', 'en_US').format(value);
  }

  Widget _buildHrCard({
    required dynamic item,
    required String reqNo,
    required String requestType,
    required String employeeName,
    required String empCode,
    required String date,
  }) {
    return Container(
      constraints: BoxConstraints(minHeight: 150.w),
      width: 350.w,
      margin: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFDDE1E6),
            Color(0xFFBDC4CD),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFF8F969F), width: 0.8),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 34.w,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 34.w,
                      height: 34.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.95),
                          width: 1.5,
                        ),
                      ),
                      child: ClipOval(
                        child: _buildEmployeeImage(
                          item['requester_image'] ??
                              item['employee_image'] ??
                              item['emp_image'] ??
                              item['image_emp'],
                          34.w,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 38.w),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          reqNo.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 13.2.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0B2D5E),
                            letterSpacing: 0.25,
                            height: 1.0,
                          ),
                          maxLines: null,
                          overflow: TextOverflow.visible,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    requestType.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12.4.sp,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0E0E10),
                    ),
                    maxLines: null,
                    overflow: TextOverflow.visible,
                  ),
                ),
                SizedBox(height: 6.w),
                Text(
                  employeeName,
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF4A5564),
                    letterSpacing: 0.1,
                  ),
                  maxLines: null,
                  overflow: TextOverflow.visible,
                ),
                SizedBox(height: 1.8.w),
                Text(
                  empCode,
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6B717B),
                  ),
                  maxLines: null,
                  overflow: TextOverflow.visible,
                ),
                SizedBox(height: 10.w),
                Text(
                  date,
                  style: GoogleFonts.poppins(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8C939C),
                    letterSpacing: 0.1,
                  ),
                  maxLines: null,
                  overflow: TextOverflow.visible,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPettyCashCard({
    required dynamic item,
    required String refNo,
    required String employeeName,
    required String subtitle,
    required String date,
    required String amount,
  }) {
    final amountText = _formatAmountForCard(amount);

    return Container(
      height: 150.w,
      width: 350.w,
      margin: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE1E4E8),
            Color(0xFFB9C0CB),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFF8F969F), width: 0.8),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 34.w,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 38.w,
                      height: 38.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: ClipOval(
                        child: _buildEmployeeImage(
                          item['requester_image'] ??
                              item['employee_image'] ??
                              item['emp_image'] ??
                              item['image_emp'],
                          38.w,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 38.w),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          refNo.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0B2D5E),
                            letterSpacing: 0.25,
                            height: 1.0,
                          ),
                          maxLines: null,
                          overflow: TextOverflow.visible,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 10.w),
            Text(
              employeeName.toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F1114),
                height: 1.1,
              ),
              maxLines: null,
              overflow: TextOverflow.visible,
            ),
            SizedBox(height: 4.w),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF737A83),
                letterSpacing: 0.2,
                height: 1.0,
              ),
              maxLines: null,
              overflow: TextOverflow.visible,
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    date,
                    style: GoogleFonts.poppins(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF8C939C),
                      letterSpacing: 0.1,
                    ),
                    maxLines: null,
                    overflow: TextOverflow.visible,
                  ),
                ),
                Text(
                  amountText,
                  style: GoogleFonts.poppins(
                    fontSize: 28.63,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0B387A),
                    letterSpacing: 0.2,
                    height: 1.0,
                  ),
                  maxLines: null,
                  overflow: TextOverflow.visible,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getSafeString(dynamic value, String fallback) {
    if (value == null || value == false || value == true) {
      return fallback;
    }

    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      for (final key in const ['name', 'display_name', 'title', 'value']) {
        final resolved = _getSafeString(map[key], '');
        if (resolved.isNotEmpty) return resolved;
      }
      return fallback;
    }

    if (value is List) {
      if (value.length >= 2) {
        final second = _getSafeString(value[1], '');
        if (second.isNotEmpty) return second;
      }
      for (final item in value) {
        final resolved = _getSafeString(item, '');
        if (resolved.isNotEmpty) return resolved;
      }
      return fallback;
    }

    final strValue = value.toString().trim();
    if (strValue.isEmpty ||
        strValue.toLowerCase() == 'false' ||
        strValue.toLowerCase() == 'true' ||
        strValue.toLowerCase() == 'null') {
      return fallback;
    }

    return strValue;
  }

  String _limitToFirstThreeNames(String value) {
    final raw = value.trim();
    if (raw.isEmpty || raw == 'N/A') return value;

    final normalized = raw.replaceAll(';', ',').replaceAll('\n', ',');
    final names = normalized
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (names.length <= 3) return raw;
    return names.take(3).join(', ');
  }

  bool _isImageUrl(String imageData) {
    return imageData.startsWith('http://') || imageData.startsWith('https://');
  }

  Widget _buildEmployeeImage(dynamic imageEmp, double size) {
    if (imageEmp != null &&
        imageEmp is String &&
        imageEmp.isNotEmpty &&
        imageEmp.toLowerCase() != 'false') {
      if (_isImageUrl(imageEmp)) {
        return Image.network(
          imageEmp,
          fit: BoxFit.cover,
          height: size,
          width: size,
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(
              AppImages.personImage,
              fit: BoxFit.cover,
              height: size,
              width: size,
            );
          },
        );
      }

      try {
        return Image.memory(
          base64Decode(imageEmp),
          fit: BoxFit.cover,
          height: size,
          width: size,
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(
              AppImages.personImage,
              fit: BoxFit.cover,
              height: size,
              width: size,
            );
          },
        );
      } catch (_) {
        return Image.asset(
          AppImages.personImage,
          fit: BoxFit.cover,
          height: size,
          width: size,
        );
      }
    }

    return Image.asset(
      AppImages.personImage,
      fit: BoxFit.cover,
      height: size,
      width: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayItems = List<dynamic>.from(approvalItems);

    if (displayItems.isEmpty) {
      return const Expanded(
        child: Center(
          child: Text('No items found'),
        ),
      );
    }

    final totalBottomPadding =
        kBottomNavigationBarHeight + context.systemBottomInset + 100.h;

    return Expanded(
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 5) +
            EdgeInsets.only(bottom: totalBottomPadding, top: 120.w),
        itemCount: displayItems.length,
        separatorBuilder: (context, index) => const SizedBox(height: 1),
        itemBuilder: (context, index) {
          final item = displayItems[index];
          final category = item['category'] ?? item['type'] ?? '';
          final id = item['id']?.toString() ?? '';
          final isHr = category.toString().toUpperCase() == 'HR';

          if (kDebugMode && isHr && index == 0) {
            debugPrint('🔍 HR Item Fields: ${item.keys.toList()}');
            debugPrint('📋 HR Item Data: $item');
          }

          final employeeName = _getSafeString(
            item['employee_name'] ??
                item['requester_name'] ??
                item['emp_name'] ??
                item['requester'] ??
                item['employee'] ??
                item['holder_name'],
            'N/A',
          );

          final hrEmployeeName = _limitToFirstThreeNames(employeeName);

          final empCode = _getSafeString(
            item['emp_code'] ??
                item['employee_code'] ??
                item['requester_code'] ??
                item['emp_id']?.toString() ??
                item['employee_id']?.toString() ??
                item['requester_id']?.toString() ??
                item['requester_emp_id']?.toString() ??
                item['code'],
            '',
          );

          final reqNo = _getSafeString(
            item['name'] ??
                item['request_no'] ??
                item['ref_no'] ??
                item['reference_no'] ??
                item['req_no'] ??
                item['pettycash_no'] ??
                item['petty_cash_no'],
            'N/A',
          );

          final amount = _getSafeString(
            item['amount_total'] ??
                item['amount'] ??
                item['total_amount'] ??
                item['total'] ??
                item['invoice_amount'] ??
                item['pettycash_limit'] ??
                item['limit_amount'],
            '0',
          );

          final requestType = _getSafeString(
            item['type'] ??
                item['request_type'] ??
                item['holiday_status_name'] ??
                item['request_type_name'] ??
                item['holiday_status_id'] ??
                item['leave_type'] ??
                item['subject'] ??
                item['title'] ??
                item['category'],
            'HR Request',
          );

          final date = _getSafeString(
            item['date'] ??
                item['request_date'] ??
                item['created_date'] ??
                item['submission_date'] ??
                item['create_date'] ??
                item['invoice_date'],
            '',
          );

          final pettySubtitle = _getSafeString(
            item['emp_id']?.toString() ??
                item['emp_code'] ??
                item['employee_code'] ??
                item['requester_code'] ??
                item['employee_id']?.toString() ??
                item['requester_id']?.toString() ??
                item['requester_emp_id']?.toString() ??
                item['client_name'] ??
                item['client'] ??
                item['vendor'] ??
                item['partner_name'] ??
                item['beneficiary_name'] ??
                item['holder_name'] ??
                item['requester_name'] ??
                item['employee_name'],
            'N/A',
          );

          return GestureDetector(
            onTap: () async {
              debugPrint(
                '👆 [MyApproval][HR/PettyCash] Tap -> category=$category, id=$id',
              );

              await ApprovalViewedService.markAsViewed(category, id);
              if (!context.mounted) return;

              final upperCategory = category.toString().toUpperCase();
              final result = upperCategory == 'HR'
                  ? await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HrDetailsScreen(
                          requestId: id,
                          type: category,
                        ),
                      ),
                    )
                  : upperCategory == 'PETTY CASH'
                      ? await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PettyCashDetailsScreen(
                              requestId: id,
                              type: category,
                            ),
                          ),
                        )
                      : await showDialog(
                          context: context,
                          builder: (dialogContext) {
                            return ApprovalConfirmationScreen(
                              requestId: id,
                              type: category,
                            );
                          },
                        );

              debugPrint(
                '↩️ [MyApproval][HR/PettyCash] Back -> category=$category, id=$id, result=$result',
              );

              if (result == true) {
                ApprovalCountService.invalidateCache();
                ApprovalCountService.onCountChanged?.call();
                onRefresh?.call();
              }
            },
            child: isHr
                ? _buildHrCard(
                    item: item,
                    reqNo: reqNo,
                    requestType: requestType,
                    employeeName: hrEmployeeName,
                    empCode: empCode,
                    date: date,
                  )
                : _buildPettyCashCard(
                    item: item,
                    refNo: reqNo,
                    employeeName: employeeName,
                    subtitle: pettySubtitle,
                    date: date.isNotEmpty ? date : 'N/A',
                    amount: amount,
                  ),
          );
        },
      ),
    );
  }
}
