import 'dart:convert';
import 'package:el_race/core/services/approval_viewed_service.dart';
import 'package:el_race/core/services/approval_count_service.dart';
import 'package:el_race/ui/presentation/Email%20Approval/Approval_confirmation.dart';
import 'package:el_race/ui/presentation/Email%20Approval/screens/invoice_details_screen.dart';
import 'package:el_race/ui/presentation/Email%20Approval/screens/rfq_details_screen.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class InvoiceAndRfqCard extends StatelessWidget {
  final List<dynamic> approvalItems;
  final VoidCallback? onRefresh;
  final String categoryType;
  const InvoiceAndRfqCard(
      {super.key,
      required this.approvalItems,
      this.onRefresh,
      this.categoryType = ''});

  String _formatAmountForCard(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.\-]'), '');
    final value = double.tryParse(cleaned);
    if (value == null) return raw;
    if (value % 1 == 0) {
      return NumberFormat('#,##0', 'en_US').format(value);
    }
    return NumberFormat('#,##0.##', 'en_US').format(value);
  }

  String _extractDisplayValue(dynamic value, {String fallback = 'N/A'}) {
    if (value == null || value == false || value == true) return fallback;

    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      return _pickFromKeys(map, const [
        'name',
        'display_name',
        'title',
        'value',
        'label',
      ], fallback: fallback);
    }

    if (value is List) {
      if (value.length >= 2) {
        final second = value[1]?.toString().trim() ?? '';
        if (second.isNotEmpty && second.toLowerCase() != 'null') {
          return second;
        }
      }
      for (final item in value) {
        final parsed = _extractDisplayValue(item, fallback: '');
        if (parsed.isNotEmpty) return parsed;
      }
      return fallback;
    }

    final text = value.toString().trim();
    if (text.isEmpty ||
        text.toLowerCase() == 'false' ||
        text.toLowerCase() == 'true' ||
        text.toLowerCase() == 'null') {
      return fallback;
    }
    return text;
  }

  String _pickFromKeys(
    Map<String, dynamic> item,
    List<String> keys, {
    String fallback = 'N/A',
  }) {
    for (final key in keys) {
      final value = _extractDisplayValue(item[key], fallback: '');
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  // Helper method to check if image_emp is a URL or base64 data
  bool _isImageUrl(String imageData) {
    return imageData.startsWith('http://') || imageData.startsWith('https://');
  }

  // Helper widget to display employee image (URL or base64)
  Widget _buildEmployeeImage(dynamic imageEmp, double size) {
    if (imageEmp != null &&
        imageEmp is String &&
        imageEmp.isNotEmpty &&
        imageEmp.toLowerCase() != "false") {
      if (_isImageUrl(imageEmp)) {
        // It's a URL, use Image.network
        return Image.network(
          imageEmp,
          fit: BoxFit.cover,
          height: size,
          width: size,
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(
              'assets/png/police.png',
              fit: BoxFit.cover,
              height: size,
              width: size,
            );
          },
        );
      } else {
        // It's base64 data, decode it
        try {
          return Image.memory(
            base64Decode(imageEmp),
            fit: BoxFit.cover,
            height: size,
            width: size,
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                'assets/png/police.png',
                fit: BoxFit.cover,
                height: size,
                width: size,
              );
            },
          );
        } catch (e) {
          return Image.asset(
            'assets/png/police.png',
            fit: BoxFit.cover,
            height: size,
            width: size,
          );
        }
      }
    }
    // Fallback to default image
    return Image.asset(
      'assets/png/police.png',
      fit: BoxFit.cover,
      height: size,
      width: size,
    );
  }

  Widget _buildRfqCard({
    required dynamic item,
    required String refNo,
    required String title,
    required String subtitle,
    required String date,
    required String amount,
  }) {
    final amountText = _formatAmountForCard(amount);

    return Container(
      constraints: BoxConstraints(minHeight: 150.w),
      width: 350.w,
      margin: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.w),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.w),
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
                          item["requester_image"] ??
                              item["employee_image"] ??
                              item["emp_image"] ??
                              item["image_emp"],
                          38.w),
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
            title.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F1114),
              height: 1.1,
            ),
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
          ),
          SizedBox(height: 10.w),
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
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    amountText,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(
                      fontSize: 28.63,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0B387A),
                      letterSpacing: 0.2,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard({
    required dynamic item,
    required String refNo,
    required String title,
    required String client,
    required String date,
    required String amount,
  }) {
    final amountText = _formatAmountForCard(amount);

    return Container(
      constraints: BoxConstraints(minHeight: 150.w),
      width: 350.w,
      margin: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.w),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.w),
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
                          item["requester_image"] ??
                              item["employee_image"] ??
                              item["emp_image"] ??
                              item["image_emp"],
                          38.w),
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
            title.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F1114),
              height: 1.1,
            ),
          ),
          SizedBox(height: 4.w),
          Text(
            client,
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF737A83),
              letterSpacing: 0.2,
              height: 1.0,
            ),
          ),
          SizedBox(height: 10.w),
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
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    amountText,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(
                      fontSize: 28.63,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0B387A),
                      letterSpacing: 0.2,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (approvalItems.isEmpty) {
      return const Expanded(
        child: Center(
          child: Text('No items found'),
        ),
      );
    }

    // Calculate safe bottom padding for devices with navigation bars
    final totalBottomPadding =
        kBottomNavigationBarHeight + context.systemBottomInset + 100.h;

    return Expanded(
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 5) +
            EdgeInsets.only(bottom: totalBottomPadding, top: 120.w),
        itemCount: approvalItems.length,
        separatorBuilder: (context, index) => const SizedBox(height: 1),
        itemBuilder: (context, index) {
          final item = approvalItems[index];
          String type = (item["type"]?.toString().isNotEmpty == true)
              ? item["type"].toString()
              : categoryType;
          String id = item["id"]?.toString() ?? "";
          final isRfq = type.toString().toUpperCase() == 'RFQ';

          // For Invoice: name might be ID, For RFQ: name has ref number
          String refNo = _pickFromKeys(item, const [
            'request_no',
            'ref_no',
            'reference_no',
            'invoice_no',
            'invoice_no_code',
            'name',
            'title',
          ]);

          // Check multiple amount fields
          String amount = _pickFromKeys(item, const [
            'total_amount',
            'amount_total',
            'invoice_amount',
            'amount',
            'total',
          ], fallback: '0');

          final rfqTitle = _pickFromKeys(item, const [
            'project_title',
            'project_name',
            'project',
            'title',
            'name',
          ]);

          final rfqSubtitle = _pickFromKeys(item, const [
            'client_name',
            'client',
            'vendor_name',
            'vendor',
            'partner_name',
            'supplier',
          ]);

          final rfqDate = _pickFromKeys(item, const [
            'date',
            'request_date',
            'create_date',
            'created_date',
            'invoice_date',
          ]);

          final invoiceTitle = _pickFromKeys(item, const [
            'project_title',
            'project_name',
            'project',
            'title',
            'name',
          ]);

          final invoiceClient = _pickFromKeys(item, const [
            'vendor_name',
            'client_name',
            'client',
            'vendor',
            'partner_name',
            'supplier',
            'beneficiary_name',
          ]);

          final invoiceDate = _pickFromKeys(item, const [
            'date',
            'invoice_date',
            'request_date',
            'create_date',
            'created_date',
          ]);

          return GestureDetector(
            onTap: () async {
              debugPrint(
                  '👆 [MyApproval][Invoice/RFQ] Tap -> type=$type, id=$id');
              // Mark item as viewed
              print('🔵 Marking as viewed - Type: $type, ID: $id');
              await ApprovalViewedService.markAsViewed(
                type,
                id,
              );

              if (context.mounted) {
                final upperType = type.toString().toUpperCase();
                final result = upperType == 'INVOICE'
                    ? await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => InvoiceDetailsScreen(
                            requestId: id,
                            type: type,
                            initialData: Map<String, dynamic>.from(item as Map),
                          ),
                        ),
                      )
                    : upperType == 'RFQ'
                        ? await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RfqDetailsScreen(
                                requestId: id,
                                type: type,
                                initialData:
                                    Map<String, dynamic>.from(item as Map),
                              ),
                            ),
                          )
                        : await showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return ApprovalConfirmationScreen(
                                requestId: id,
                                type: type,
                              );
                            },
                          );
                // Trigger a rebuild to update the list after dialog closes
                debugPrint(
                  '↩️ [MyApproval][Invoice/RFQ] Back from details -> type=$type, id=$id, result=$result',
                );
                if (result == true) {
                  // Invalidate cache so header re-fetches fresh count from API
                  ApprovalCountService.invalidateCache();
                  // Update approval count badge
                  ApprovalCountService.onCountChanged?.call();
                  // Refresh the list
                  debugPrint(
                      '🔁 [MyApproval][Invoice/RFQ] Triggering onRefresh callback');
                  onRefresh?.call();
                }
              }
            },
            child: isRfq
                ? _buildRfqCard(
                    item: item,
                    refNo: refNo,
                    title: rfqTitle,
                    subtitle: rfqSubtitle,
                    date: rfqDate,
                    amount: amount,
                  )
                : _buildInvoiceCard(
                    item: item,
                    refNo: refNo,
                    title: invoiceTitle,
                    client: invoiceClient,
                    date: invoiceDate,
                    amount: amount,
                  ),
          );
        },
      ),
    );
  }
}

// final item = approvalItems[index];
// List<String> statuses = ['approved', 'pending', 'rejected'];
// String sampleStatus = statuses[index % statuses.length];
// final itemData = {
//   "id": "${item["id"] ?? ""}",
//   "name": "${item["name"] ?? ""}",
//   "type": "${item["type"] ?? ""}",
//   "requester": "${item["requester_name"] ?? ""}",
//   "approver": "${item["emp_name"] ?? ""}",
//   "location": "${item["location"] ?? ""}",
//   "date": "${item["date"] ?? ""}",
//   "image_emp": "${item["image_emp"] ?? ""}",
//   "req_no":
//   "REQ-${(item["id"] ?? "").toString().padLeft(6, '0')}",
//   "title": "${item["name"] ?? ""}",
//   "status": item["status"] ?? sampleStatus,
// };

// return ApprovalCardTypeTwo(
//   item: itemData,
//   isExpanded: false,
//   onTap: () {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return ApprovalConfirmationScreen(
//           requestId: itemData["id"],
//           type: itemData["type"],
//         );
//       },
//     );
//   },
// );
