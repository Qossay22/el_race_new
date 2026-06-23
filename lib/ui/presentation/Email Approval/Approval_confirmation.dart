import 'dart:convert';
import 'dart:math' as math;
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/resources/app_colors.dart';
import 'package:el_race/ui/presentation/Email%20Approval/widgets/approval_card_type_two.dart';
import 'package:el_race/ui/presentation/Email%20Approval/widgets/file_binary.dart';
import 'package:el_race/utils/Util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:el_race/utils/color_utils.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'widgets/approval_action_buttons.dart';

class ApprovalConfirmationScreen extends StatefulWidget {
  final String requestId;
  final String type;

  const ApprovalConfirmationScreen({
    super.key,
    required this.requestId,
    required this.type,
  });

  @override
  State<ApprovalConfirmationScreen> createState() =>
      _ApprovalConfirmationScreenState();
}

class _ApprovalConfirmationScreenState
    extends State<ApprovalConfirmationScreen> {
  bool isLoading = true;
  String error = '';
  int _currentPage = 0;
  late PageController _pageController;
  int _pettyCashCurrentPage = 0;
  late PageController _pettyCashPageController;
  Map<String, dynamic>? formData;
  List<dynamic> tableView = [];
  List<dynamic> attachmentIds = [];
  List<dynamic> approvals = [];

  bool get isCurrentUserInApprovals {
    final userId = SharedPref.getLoginData().result?.data?.uid;
    if (userId == null) return false;
    return approvals.any((a) => a['id'] == userId);
  }

  // Helper method to check if image_emp is a URL or base64 data
  bool _isImageUrl(String imageData) {
    return imageData.startsWith('http://') || imageData.startsWith('https://');
  }

  // Helper widget to display employee image (URL or base64)
  Widget _buildEmployeeImage(dynamic imageEmp, double radius) {
    if (imageEmp != null &&
        imageEmp is String &&
        imageEmp.isNotEmpty &&
        imageEmp.toLowerCase() != "false") {
      if (_isImageUrl(imageEmp)) {
        // It's a URL, use Image.network inside CircleAvatar
        return CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey[300],
          child: ClipOval(
            child: Image.network(
              imageEmp,
              fit: BoxFit.cover,
              width: radius * 2,
              height: radius * 2,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.person, size: radius);
              },
            ),
          ),
        );
      } else {
        // It's base64 data, decode it
        try {
          return CircleAvatar(
            radius: radius,
            backgroundImage: MemoryImage(base64Decode(imageEmp)),
          );
        } catch (e) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: Colors.grey[300],
            child: Icon(Icons.person, size: radius),
          );
        }
      }
    }
    // Fallback to placeholder
    return SizedBox(width: radius * 2, height: radius * 2);
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pettyCashPageController = PageController(viewportFraction: 0.92);
    _fetchRequestDetails();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pettyCashPageController.dispose();
    super.dispose();
  }

  Future<void> _fetchRequestDetails() async {
    final token = SharedPref.getLoginData().result?.token;
    final userId = SharedPref.getLoginData().result?.data?.uid;
    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };
    String getApiUrl(String type) {
      switch (type.toUpperCase().replaceAll(' ', '')) {
        case 'HR':
          return "https://erp.elrace.com/api/get_hr_request_details";
        case 'RFQ':
          return "https://erp.elrace.com/api/get_rfq_details";
        case 'INVOICE':
          return "https://erp.elrace.com/api/get_invoice_details";
        case 'PETTYCASH':
          return "https://erp.elrace.com/api/get_petty_cash_details";
        default:
          throw Exception("Invalid request type: ${widget.type}");
      }
    }

    String getParamKey(String type) {
      switch (type.toUpperCase().replaceAll(' ', '')) {
        case 'HR':
          return "request_id";
        case 'RFQ':
          return "rfq_id";
        case 'INVOICE':
          return "invoice_id";
        case 'PETTYCASH':
          return "petty_cash_id";
        default:
          throw Exception("Invalid request type: ${widget.type}");
      }
    }

    final url = Uri.parse(getApiUrl(widget.type));
    final paramKey = getParamKey(widget.type);
    final body = jsonEncode({
      "jsonrpc": "2.0",
      "params": {
        paramKey: int.tryParse(widget.requestId),
      },
    });
    final request = http.Request('GET', url)
      ..headers.addAll(headers)
      ..body = body;
    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final normalizedType = widget.type.toUpperCase().replaceAll(' ', '');
      final isInvoice = normalizedType == 'INVOICE';

      void debugPrintLong(String text) {
        const chunkSize = 900;
        if (text.isEmpty) {
          debugPrint('');
          return;
        }
        for (var i = 0; i < text.length; i += chunkSize) {
          final end = math.min(i + chunkSize, text.length);
          debugPrint(text.substring(i, end));
        }
      }

      if (kDebugMode && isInvoice) {
        debugPrint('=========== INVOICE API RESPONSE START ===========');
        debugPrint('Status: ${response.statusCode}');
        try {
          final pretty = const JsonEncoder.withIndent('  ')
              .convert(jsonDecode(response.body));
          debugPrintLong(pretty);
        } catch (_) {
          debugPrintLong(response.body);
        }
        debugPrint('=========== INVOICE API RESPONSE END ===========');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['result']['data'];

        if (kDebugMode && isInvoice) {
          debugPrint('=========== INVOICE RESULT DATA START ===========');
          debugPrint('Result Keys: ${result?.keys?.toList()}');
          debugPrint('Result Data: $result');
          debugPrint('=========== INVOICE RESULT DATA END ===========');
        }

        setState(() {
          formData = result['form_view'] ?? {};
          approvals = result['approvals'] ?? [];
          tableView = result['table_view'] ?? [];
          attachmentIds = result['attachment_ids'] ?? [];
        });

        if (kDebugMode && isInvoice) {
          debugPrint('=========== INVOICE FORM DATA START ===========');
          debugPrint('🔍 Form Data Keys: ${formData?.keys.toList()}');
          debugPrint('🔍 Full Form Data: $formData');
          debugPrint('=========== INVOICE FORM DATA END ===========');
        }

        await Future.delayed(const Duration(seconds: 1));
        setState(() {
          isLoading = false;
        });
      } else {
        throw Exception(
            "Failed to load request details: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  List<Map<String, String>> get projects {
    // Handle different table structures for different request types
    if (widget.type.toUpperCase().replaceAll(' ', '') == 'PETTYCASH') {
      return tableView
          .map<Map<String, String>>((item) => {
                "product": item["project"]?.toString() ?? "",
                "qty": item["qty"]?.toString() ?? "",
                "uom": "", // Not provided in petty cash
                "unit_price": item["unit_price"]?.toString() ?? "",
                "total": item["unit_price"]?.toString() ?? "",
                "remarks": item["remarks"]?.toString() ?? "",
                "sequence": item["sequence"]?.toString() ?? "",
                "date": item["date"]?.toString() ??
                    item["invoice_date"]?.toString() ??
                    formData?["date"]?.toString() ??
                    "",
                "petty_cash_type": item["petty_cash_type"]?.toString() ??
                    item["type"]?.toString() ??
                    "",
              })
          .toList();
    }

    return tableView
        .map<Map<String, String>>((item) => {
              "product": item["product"]?.toString() ?? "",
              "qty": item["qty"]?.toString() ?? "",
              "uom": item["uom"]?.toString() ?? "",
              "unit_price": item["unit_price"]?.toString() ?? "",
              "total": item["total"]?.toString() ?? "",
              "date": item["date"]?.toString() ??
                  item["invoice_date"]?.toString() ??
                  formData?["date"]?.toString() ??
                  formData?["invoice_date"]?.toString() ??
                  "",
            })
        .toList();
  }

  void _showEmployeeDetailsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Employee Details',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.0,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                isLoading
                    ? Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          shape: BoxShape.circle,
                        ),
                      )
                    : _buildEmployeeImage(formData?["image_emp"], 28),
                const SizedBox(height: 8),
                Center(
                  child: Text(formData?["employee_name"] ?? "",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Center(
                  child: Text(formData?["emp_code"]?.toString() ?? "",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey)),
                ),
                const SizedBox(height: 12),
                _buildIconText(Icons.work_outline,
                    formData?["job_id"] ?? formData?["job_title"]),
                _buildIconText(Icons.phone_android, formData?["phone"]),
                _buildIconText(Icons.business,
                    formData?["department_id"] ?? formData?["department"]),
                _buildIconText(Icons.email, formData?["email"]),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  ScrollController scrollController = ScrollController();
  @override
  Widget build(BuildContext context) {
    if (widget.type.toUpperCase() == 'HR') {
      return _buildHrDialog(context);
    }
    if (widget.type.toUpperCase() == 'RFQ') {
      return _buildRfqDialog(context);
    }
    if (widget.type.toUpperCase().replaceAll(' ', '') == 'INVOICE') {
      return _buildInvoiceDialog(context);
    }
    if (widget.type.toUpperCase().replaceAll(' ', '') == 'PETTYCASH') {
      return _buildPettyCashDialog(context);
    }
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        padding: EdgeInsets.all(10.w),
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 10),
                if (widget.type.toUpperCase() == 'HR') ...[
                  InkWell(
                    onTap: _showEmployeeDetailsDialog,
                    child: Container(
                        width: 280.w,
                        padding: EdgeInsets.symmetric(
                            horizontal: 13.w, vertical: 5.w),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD6D6D6), Color(0xFFADB2BD)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Row(
                          children: [
                            isLoading
                                ? Container(
                                    width: 50.w,
                                    height: 50.w,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                : _buildEmployeeImage(
                                    formData?["image_emp"], 25.w),
                            const SizedBox(width: 8),
                            Text(
                              'Employee Details',
                              style: GoogleFonts.poppins(
                                fontSize: 19.sp,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Image.asset(
                              'assets/png/tap.png',
                              width: 40.w,
                              height: 40.w,
                            ),
                          ],
                        )),
                  ),
                ] else ...[
                  const SizedBox.shrink(),
                ],
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    margin: EdgeInsets.only(
                        bottom: widget.type.toUpperCase() == 'HR' ? 60.w : 0),
                    padding: EdgeInsets.all(3.w),
                    decoration: const BoxDecoration(
                      color: red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ],
            ),
            Text(
              'Request Details',
              style: GoogleFonts.poppins(
                fontSize: 23.sp,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: greyText),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  if (widget.type.toUpperCase() == 'HR') ...[
                                    _buildDetailRow("REQ NO",
                                        formData?["request_no"] ?? ""),
                                    _buildDetailRow("REQ TYPE",
                                        formData?["request_type"] ?? ""),
                                    _buildDetailRow("STATUS",
                                        formData?["status"]?.toString() ?? ""),
                                    _buildDetailRow("REQ DATE",
                                        formData?["request_date"] ?? ""),
                                    _buildDetailRow(
                                        "START DATE",
                                        formData?["start_date"]?.toString() ??
                                            ""),
                                    _buildDetailRow(
                                        "DURATION",
                                        formData?["duration"]?.toString() ??
                                            ""),
                                    _buildDetailRow(
                                        "BALANCE LEAVE",
                                        formData?["balance_leave"]
                                                ?.toString() ??
                                            ""),
                                  ],
                                  if (widget.type.toUpperCase() == 'RFQ') ...[
                                    _buildDetailRow("Request Type",
                                        formData?["request_type"] ?? "RFQ"),
                                    _buildDetailRow(
                                        "Ref No", formData?["title"] ?? ""),
                                    _buildDetailRow(
                                        "Vendor", formData?["vendor"] ?? ""),
                                    // _buildDetailRow("Client", formData?["client"] ?? ""),
                                    // _buildDetailRow("WO", formData?["wo"] ?? ""),
                                    _buildDetailRow("Material Type",
                                        formData?["material_type"] ?? ""),
                                    _buildDetailRow(
                                        "Total Amount",
                                        formData?["amount_total"] != null
                                            ? double.parse(
                                                    formData!["amount_total"]
                                                        .toString())
                                                .toStringAsFixed(2)
                                            : "0.00"),
                                  ],
                                  if (widget.type.toUpperCase() ==
                                      'INVOICE') ...[
                                    _buildDetailRow(
                                        "REQ NO", formData?["title"] ?? ""),
                                    _buildDetailRow("REQ TYPE", "Invoice"),
                                    _buildDetailRow("STATUS", "Pending"),
                                    _buildDetailRow(
                                        "REQ DATE", formData?["date"] ?? ""),
                                    _buildDetailRow(
                                        "START DATE", formData?["date"] ?? ""),
                                  ],
                                  if (widget.type
                                          .toUpperCase()
                                          .replaceAll(' ', '') ==
                                      'PETTYCASH') ...[
                                    _buildDetailRow("REQ NO",
                                        formData?["petty_cash_no"] ?? ""),
                                    _buildDetailRow(
                                        "REQ TYPE",
                                        formData?["request_type"] ??
                                            "Petty Cash"),
                                    _buildDetailRow("STATUS",
                                        formData?["status"] ?? "Pending"),
                                    _buildDetailRow(
                                        "REQ DATE", formData?["date"] ?? ""),
                                    _buildDetailRow(
                                        "START DATE", formData?["date"] ?? ""),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (widget.type.toUpperCase() != 'HR') ...[
                              Column(
                                children: [
                                  // Row(
                                  //   mainAxisAlignment: MainAxisAlignment.center,
                                  //   children: [
                                  //     IconButton(
                                  //       icon: const Icon(Icons.arrow_back_ios, size: 16),
                                  //       onPressed: () {
                                  //         if (_currentPage > 0) {
                                  //           _pageController.previousPage(
                                  //             duration: const Duration(milliseconds: 300),
                                  //             curve: Curves.easeInOut,
                                  //           );
                                  //         }
                                  //       },
                                  //     ),
                                  //     Text(
                                  //       "${_currentPage + 1}/${projects.length}",
                                  //       style: const TextStyle(fontWeight: FontWeight.bold),
                                  //     ),
                                  //     IconButton(
                                  //       icon: const Icon(Icons.arrow_forward_ios, size: 16),
                                  //       onPressed: () {
                                  //         if (_currentPage < projects.length - 1) {
                                  //           _pageController.nextPage(
                                  //             duration: const Duration(milliseconds: 300),
                                  //             curve: Curves.easeInOut,
                                  //           );
                                  //         }
                                  //       },
                                  //     ),
                                  //   ],
                                  // ),
                                  const SizedBox(height: 8),
                                  _buildPagedSummaryTable(
                                    context,
                                    borderColor: const Color(0xFF1A1A53),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 10),
                            Center(
                              child: ElevatedButton.icon(
                                
                                onPressed: () async {
                                  if (attachmentIds.isEmpty) {
                                    Fluttertoast.showToast(
                                      msg: 'No attachment found.',
                                      toastLength: Toast.LENGTH_SHORT,
                                      gravity: ToastGravity.CENTER,
                                      backgroundColor: Colors.black,
                                      textColor: Colors.white,
                                    );
                                    return;
                                  }
                                  await _viewAttachement();
                                },
                                icon: Image.asset(
                                  'assets/png/attachment.png',
                                  width: 20.w,
                                  height: 20.w,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  "VIEW ATTACHMENT",
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A1A53),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                GestureDetector(
                                  onTap: () {},
                                  child: AbsorbPointer(
                                    absorbing: isCurrentUserInApprovals,
                                    child: ApprovalActionButtons(
                                      requestId: widget.requestId,
                                      type: widget.type,
                                      // Don't refresh data inside the dialog since it will close anyway
                                      onResult: null,
                                      disabled: isCurrentUserInApprovals,
                                      // Send only current user's ID for approval
                                      userIds: [
                                        SharedPref.getLoginData()
                                                .result
                                                ?.data
                                                ?.uid
                                                .toString() ??
                                            ''
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPettyCashDialog(BuildContext context) {
    String safeValue(dynamic v) {
      if (v == null) return '';
      final s = v.toString();
      if (s.toLowerCase() == 'false') return '';
      return s;
    }

    String formatAmount(dynamic v) {
      final raw = safeValue(v).trim();
      if (raw.isEmpty) return '';
      final parsed = double.tryParse(raw.replaceAll(',', ''));
      if (parsed == null) return raw;
      return NumberFormat('#,##0').format(parsed);
    }

    const borderColor = Color(0xFF1A1A53);

    final holderName = safeValue(
      formData?['holder'] ??
          formData?['petty_cash_holder'] ??
          formData?['employee_name'] ??
          formData?['holder_name'] ??
          formData?['requester_name'] ??
          formData?['requested_by'],
    );
    final requestNo = safeValue(
      formData?['petty_cash_no'] ??
          formData?['request_no'] ??
          formData?['title'] ??
          formData?['name'],
    );
    final submissionDate = safeValue(
      formData?['submission_date'] ??
          formData?['request_date'] ??
          formData?['date'],
    );
    final dateOfInvoice = safeValue(
      formData?['date_of_invoice'] ??
          formData?['invoice_date'] ??
          formData?['date'],
    );
    final totalRaw = safeValue(
      formData?['amount_total'] ??
          formData?['total_amount'] ??
          formData?['total'] ??
          formData?['unit_price'],
    );
    final totalAmount = totalRaw.isEmpty ? '' : '${formatAmount(totalRaw)} AED';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            child: Container(
              width: MediaQuery.of(context).size.width,
              padding: EdgeInsets.fromLTRB(18.w, 18.w, 18.w, 18.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24.r),
              ),
              child: Column(
                children: [
                  SizedBox(height: 6.w),
                  Text(
                    'REQUEST DETAILS',
                    style: GoogleFonts.poppins(
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 14.w),
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(16.w),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: borderColor, width: 2),
                                    borderRadius: BorderRadius.circular(18.r),
                                  ),
                                  child: Column(
                                    children: [
                                      _buildPettyCashHolderRow(
                                        label: 'PETTY CASH HOLDER',
                                        name: holderName,
                                      ),
                                      _buildPettyCashPillRow(
                                        label: 'REQUEST NO',
                                        value: requestNo,
                                      ),
                                      _buildPettyCashPillRow(
                                        label: 'SUBMITION DATE',
                                        value: submissionDate,
                                      ),
                                      _buildPettyCashPillRow(
                                        label: 'DATE OF INVOICE',
                                        value: dateOfInvoice,
                                      ),
                                      _buildPettyCashPillRow(
                                        label: 'TOTAL AMOUNT',
                                        value: totalAmount,
                                      ),
                                      _buildPettyCashAttachmentRow(
                                        enabled: attachmentIds.isNotEmpty,
                                        buttonColor: borderColor,
                                        onPressed: () async {
                                          print('🟢 VIEW button pressed!');
                                          print('🟢 attachmentIds: $attachmentIds');
                                          if (attachmentIds.isEmpty) {
                                            Fluttertoast.showToast(
                                              msg: 'No attachment found.',
                                              toastLength: Toast.LENGTH_SHORT,
                                              gravity: ToastGravity.CENTER,
                                              backgroundColor: Colors.black,
                                              textColor: Colors.white,
                                            );
                                            return;
                                          }
                                          await _viewAttachement();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 14.w),
                                _buildPettyCashPagedTable(
                                  context,
                                  borderColor: borderColor,
                                ),
                                SizedBox(height: 22.w),
                                AbsorbPointer(
                                  absorbing: isCurrentUserInApprovals,
                                  child: ApprovalActionButtons(
                                    requestId: widget.requestId,
                                    type: widget.type,
                                    onResult: null,
                                    disabled: isCurrentUserInApprovals,
                                    userIds: [
                                      SharedPref.getLoginData()
                                              .result
                                              ?.data
                                              ?.uid
                                              .toString() ??
                                          ''
                                    ],
                                    variant:
                                        ApprovalActionButtonsVariant.rectangle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: -10.w,
            right: -10.w,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: EdgeInsets.all(5.w),
                decoration: const BoxDecoration(
                  color: red,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, color: Colors.white, size: 22.w),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPettyCashHolderRow({
    required String label,
    required String name,
  }) {
    const bullet = '●';
    final displayName = name.isEmpty ? '' : name;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.w),
      child: Row(
        children: [
          Text(
            bullet,
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(width: 8.w),
          SizedBox(
            width: 135.w,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          if (isLoading)
            Container(
              width: 34.w,
              height: 34.w,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
            )
          else
            Container(
              width: 34.w,
              height: 34.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade400, width: 1),
              ),
              child: ClipOval(
                child: Center(
                  child: _buildEmployeeImage(formData?['image_emp'], 17.w),
                ),
              ),
            ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              displayName,
              maxLines: null,
              overflow: TextOverflow.visible,
              style: GoogleFonts.poppins(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPettyCashPillRow({required String label, required String value}) {
    const bullet = '●';
    final display = value.isEmpty ? '' : value;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.w),
      child: Row(
        children: [
          Text(
            bullet,
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(width: 8.w),
          SizedBox(
            width: 135.w,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.w),
              decoration: BoxDecoration(
                color: const Color(0xFFE1E1E1),
                borderRadius: BorderRadius.circular(22.r),
                border: Border.all(color: const Color(0xFF4A4A4A), width: 1),
              ),
              child: Text(
                display,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPettyCashAttachmentRow({
    required bool enabled,
    required Color buttonColor,
    required Future<void> Function() onPressed,
  }) {
    const bullet = '●';

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.w),
      child: Row(
        children: [
          Text(
            bullet,
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(width: 8.w),
          SizedBox(
            width: 135.w,
            child: Text(
              'ATTACHMENT',
              style: GoogleFonts.poppins(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                if (enabled) {
                  await onPressed();
                }
              },
              child: Container(
                height: 36.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: enabled ? const Color(0xFF1A1A53) : Colors.grey,
                  borderRadius: BorderRadius.circular(22.r),
                ),
                child: Text(
                  'VIEW',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPettyCashPagedTable(
    BuildContext context, {
    required Color borderColor,
  }) {
    final rows = projects;

    String safeValue(dynamic v) {
      if (v == null) return '';
      final s = v.toString();
      if (s.toLowerCase() == 'false') return '';
      return s;
    }

    String resolveInvoiceDate(Map<String, String> item) {
      final candidates = <String?>[
        item['date'],
        item['invoice_date'],
        safeValue(formData?['date']),
        safeValue(formData?['invoice_date']),
        safeValue(formData?['request_date']),
      ];
      return candidates.firstWhere(
            (e) => (e ?? '').trim().isNotEmpty,
            orElse: () => '',
          ) ??
          '';
    }

    String resolvePettyCashType(Map<String, String> item) {
      final candidates = <String?>[
        item['petty_cash_type'],
        item['type'],
        safeValue(formData?['petty_cash_type']),
        safeValue(formData?['request_type']),
      ];
      return candidates.firstWhere(
            (e) => (e ?? '').trim().isNotEmpty,
            orElse: () => '',
          ) ??
          '';
    }

    String resolveTotalAmount(Map<String, String> item) {
      final candidates = <String?>[
        item['total'],
        item['unit_price'],
        safeValue(formData?['amount_total']),
      ];
      final raw = candidates.firstWhere(
            (e) => (e ?? '').trim().isNotEmpty,
            orElse: () => '',
          ) ??
          '';
      if (raw.trim().isEmpty) return '';
      final parsed = double.tryParse(raw.replaceAll(',', ''));
      final formatted =
          parsed == null ? raw : NumberFormat('#,##0').format(parsed);
      return '$formatted AED';
    }

    const rowsPerPage = 2;
    final pageCount = (rows.length / rowsPerPage).ceil();
    final safePageCount = math.max(pageCount, 1);

    List<Map<String, String>> pageRows(int pageIndex) {
      final start = pageIndex * rowsPerPage;
      if (start >= rows.length) return const [];
      final end = math.min(start + rowsPerPage, rows.length);
      return rows.sublist(start, end);
    }

    final tableHeight = 290.w;

    return SizedBox(
      height: tableHeight,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pettyCashPageController,
              itemCount: safePageCount,
              onPageChanged: (i) {
                setState(() => _pettyCashCurrentPage = i);
              },
              itemBuilder: (context, pageIndex) {
                final chunk = pageRows(pageIndex);
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18.r),
                    child: Container(
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: Colors.grey.shade400, width: 1),
                        borderRadius: BorderRadius.circular(18.r),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final cellWidth = constraints.maxWidth / 4;
                          return Column(
                            children: [
                              _buildTableHeader(
                                borderColor: borderColor,
                                cellWidth: cellWidth,
                              ),
                              Expanded(
                                child: rows.isEmpty
                                    ? Container(
                                        color: const Color(0xFFE6E6E6),
                                        alignment: Alignment.center,
                                        child: Text(
                                          'No items',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14.sp,
                                            letterSpacing: 1.0,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color: const Color(0xFFE6E6E6),
                                        child: SingleChildScrollView(
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: List.generate(
                                                chunk.length, (i) {
                                              final item = chunk[i];
                                              return _buildTableRow(
                                                invoiceDate:
                                                    resolveInvoiceDate(item),
                                                projectName:
                                                    item['product'] ?? '',
                                                pettyCashType:
                                                    resolvePettyCashType(item),
                                                totalAmount:
                                                    resolveTotalAmount(item),
                                                isLast: i == chunk.length - 1,
                                                cellWidth: cellWidth,
                                              );
                                            }),
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 14.w),
          if (rows.isNotEmpty && pageCount > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: () {
                    if (_pettyCashCurrentPage <= 0) return;
                    _pettyCashPageController.previousPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    size: 28.w,
                    color: Colors.grey.shade700,
                  ),
                ),
                SizedBox(width: 18.w),
                Row(
                  children: List.generate(pageCount, (i) {
                    final active = i == _pettyCashCurrentPage;
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10.w),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 16.w,
                            height: 16.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey.shade300,
                              border: Border.all(
                                color: active
                                    ? borderColor
                                    : Colors.transparent,
                                width: active ? 2 : 0,
                              ),
                            ),
                          ),
                          SizedBox(height: 6.w),
                          Text(
                            '${i + 1}',
                            style: GoogleFonts.poppins(
                              fontSize: 12.sp,
                              fontWeight:
                                  active ? FontWeight.w700 : FontWeight.w600,
                              letterSpacing: 1.0,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
                SizedBox(width: 18.w),
                InkWell(
                  onTap: () {
                    if (_pettyCashCurrentPage >= pageCount - 1) return;
                    _pettyCashPageController.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 28.w,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInvoiceDialog(BuildContext context) {
    String safeValue(dynamic v) {
      if (v == null) return '';
      final s = v.toString();
      if (s.toLowerCase() == 'false') return '';
      return s;
    }

    String formatTotal(dynamic v) {
      if (v == null) return '';
      final raw = safeValue(v);
      if (raw.trim().isEmpty) return '';
      return raw;
    }

    const borderColor = Color(0xFF1A1A53);

    final projectName = safeValue(
      formData?['project_name'] ??
          formData?['project'] ??
          formData?['project_name_id'] ??
          formData?['project_id'],
    );
    final vendorName = safeValue(
      formData?['vendor_name'] ??
          formData?['vendor'] ??
          formData?['partner_name'] ??
          formData?['supplier'],
    );
    final invoiceNoCode = safeValue(
      formData?['invoice_no_code'] ??
          formData?['invoice_no'] ??
          formData?['title'] ??
          formData?['name'] ??
          formData?['ref_no'],
    );
    final dateOfInvoice = safeValue(
      formData?['date_of_invoice'] ??
          formData?['invoice_date'] ??
          formData?['date'],
    );
    final totalAmountRaw =
        formatTotal(formData?['amount_total'] ?? formData?['total_amount']);
    final totalAmount = totalAmountRaw.isEmpty ? '' : '$totalAmountRaw AED';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Container(
              width: MediaQuery.of(context).size.width,
              padding: EdgeInsets.fromLTRB(18.w, 18.w, 18.w, 18.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24.r),
              ),
              child: Column(
                children: [
                  SizedBox(height: 6.w),
                  Text(
                    'REQUEST DETAILS',
                    style: GoogleFonts.poppins(
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 14.w),
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(16.w),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: borderColor, width: 2),
                                    borderRadius:
                                        BorderRadius.circular(18.r),
                                  ),
                                  child: Column(
                                    children: [
                                      _buildInvoicePillRow(
                                        label: 'PROJECT NAME',
                                        value: projectName,
                                      ),
                                      _buildInvoicePillRow(
                                        label: 'VENDRO NAME',
                                        value: vendorName,
                                      ),
                                      _buildInvoicePillRow(
                                        label: 'INVOICE NO CODE',
                                        value: invoiceNoCode,
                                      ),
                                      _buildInvoicePillRow(
                                        label: 'DATE OF INVOICE',
                                        value: dateOfInvoice,
                                      ),
                                      _buildInvoicePillRow(
                                        label: 'TOTAL AMOUNT',
                                        value: totalAmount,
                                      ),
                                      _buildInvoiceAttachmentRow(
                                        enabled: attachmentIds.isNotEmpty,
                                        buttonColor: borderColor,
                                        onPressed: () async {
                                          if (attachmentIds.isEmpty) {
                                            Fluttertoast.showToast(
                                              msg: 'No attachment found.',
                                              toastLength: Toast.LENGTH_SHORT,
                                              gravity: ToastGravity.CENTER,
                                              backgroundColor: Colors.black,
                                              textColor: Colors.white,
                                            );
                                            return;
                                          }
                                          await _viewAttachement();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 12.w),
                                _buildInvoicePagedTable(
                                  context,
                                  borderColor: borderColor,
                                ),
                                SizedBox(height: 20.w),
                                AbsorbPointer(
                                  absorbing: isCurrentUserInApprovals,
                                  child: ApprovalActionButtons(
                                    requestId: widget.requestId,
                                    type: widget.type,
                                    onResult: null,
                                    disabled: isCurrentUserInApprovals,
                                    userIds: [
                                      SharedPref.getLoginData()
                                              .result
                                              ?.data
                                              ?.uid
                                              .toString() ??
                                          ''
                                    ],
                                    variant: ApprovalActionButtonsVariant
                                        .rectangle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: -10.w,
            right: -10.w,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: EdgeInsets.all(5.w),
                decoration: const BoxDecoration(
                  color: red,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, color: Colors.white, size: 22.w),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicePillRow({required String label, required String value}) {
    const bullet = '●';
    final display = value.isEmpty ? '' : value;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.w),
      child: Row(
        children: [
          Text(
            bullet,
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(width: 8.w),
          SizedBox(
            width: 135.w,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.w),
              decoration: BoxDecoration(
                color: const Color(0xFFE1E1E1),
                borderRadius: BorderRadius.circular(22.r),
                border: Border.all(color: const Color(0xFFB0B0B0), width: 1),
              ),
              child: Text(
                display,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceAttachmentRow({
    required bool enabled,
    required Color buttonColor,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.w),
      child: Row(
        children: [
          Text(
            '●',
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(width: 8.w),
          SizedBox(
            width: 135.w,
            child: Text(
              'ATTACHMENT',
              style: GoogleFonts.poppins(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: InkWell(
              onTap: enabled ? onPressed : null,
              borderRadius: BorderRadius.circular(22.r),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.w),
                decoration: BoxDecoration(
                  color: enabled ? const Color(0xFF1A1A53) : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(22.r),
                ),
                child: Text(
                  'View',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicePagedTable(
    BuildContext context, {
    required Color borderColor,
  }) {
    String safeValue(dynamic v) {
      if (v == null) return '';
      final s = v.toString();
      if (s.toLowerCase() == 'false') return '';
      return s;
    }

    final rows = tableView
        .where((e) => e is Map)
        .map<Map<String, String>>((dynamic e) {
      final m = e as Map;
      String pick(List<dynamic> candidates) {
        for (final c in candidates) {
          final s = safeValue(c);
          if (s.trim().isNotEmpty) return s;
        }
        return '';
      }

      final invoiceDate = pick([
        m['invoice_date'],
        m['date'],
        formData?['invoice_date'],
        formData?['date'],
      ]);

      final vendorName = pick([
        m['vendor_name'],
        m['vendor'],
        m['partner_name'],
        formData?['vendor_name'],
        formData?['vendor'],
      ]);

      final lpoNo = pick([
        m['lpo_no'],
        m['lpo'],
        m['lpo_number'],
        m['lpo_no_code'],
      ]);

      final woName = pick([
        m['wo_name'],
        m['wo'],
        m['work_order'],
        m['wo_no'],
        formData?['wo_name'],
        formData?['wo'],
      ]);

      final totalAmount = pick([
        m['total_amount'],
        m['amount_total'],
        m['total'],
        formData?['amount_total'],
        formData?['total_amount'],
      ]);

      String totalDisplay(String raw) {
        if (raw.trim().isEmpty) return '';
        final cleaned = raw.replaceAll(',', '').trim();
        final parsed = double.tryParse(cleaned);
        if (parsed == null) return '$raw AED';
        final formatted = NumberFormat('#,##0', 'en_US').format(parsed);
        return '$formatted AED';
      }

      return {
        'invoice_date': invoiceDate,
        'vendor_name': vendorName,
        'lpo_no': lpoNo,
        'wo_name': woName,
        'total_amount': totalDisplay(totalAmount),
      };
    }).toList();

    const rowsPerPage = 2;
    final pageCount = (rows.length / rowsPerPage).ceil();
    final safePageCount = math.max(pageCount, 1);

    List<Map<String, String>> pageRows(int pageIndex) {
      final start = pageIndex * rowsPerPage;
      if (start >= rows.length) return const [];
      final end = math.min(start + rowsPerPage, rows.length);
      return rows.sublist(start, end);
    }

    final tableHeight = 220.w;
    final cellWidth = 82.w;
    final tableWidth = cellWidth * 5;

    Widget headerCell(String text, {bool isLast = false}) {
      return Container(
        width: cellWidth,
        padding: EdgeInsets.symmetric(vertical: 10.w, horizontal: 8.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            right: isLast
                ? BorderSide.none
                : const BorderSide(color: Colors.white, width: 1),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: Colors.white,
          ),
        ),
      );
    }

    Widget bodyCell(String text, {bool isLast = false}) {
      return Container(
        width: cellWidth,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(vertical: 16.w, horizontal: 10.w),
        decoration: BoxDecoration(
          border: Border(
            right: isLast
                ? BorderSide.none
                : const BorderSide(color: Colors.white, width: 1),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: Colors.black,
          ),
          maxLines: 3,
          overflow: TextOverflow.visible,
        ),
      );
    }

    // حساب الارتفاع المناسب بناءً على عدد الصفوف
    final dynamicTableHeight = rows.isEmpty 
        ? 120.w // ارتفاع صغير للجدول الفارغ
        : (rows.length == 1 
            ? 140.w // ارتفاع أصغر لصف واحد
            : tableHeight); // الارتفاع الكامل للصفوف المتعددة

    return SizedBox(
      height: dynamicTableHeight,
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18.r),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400, width: 1),
                  borderRadius: BorderRadius.circular(18.r),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF8A8A8A),
                            border: const Border(
                              bottom:
                                  BorderSide(color: Colors.white, width: 1),
                            ),
                          ),
                          child: Row(
                            children: [
                              headerCell('INVOICE\nDATE'),
                              headerCell('VENDOR\nNAME'),
                              headerCell('LPO\nNO'),
                              headerCell('WO\nNAME'),
                              headerCell('TOTAL\nAMOUNT', isLast: true),
                            ],
                          ),
                        ),
                        Expanded(
                          child: rows.isEmpty
                              ? Container(
                                  color: const Color(0xFFE6E6E6),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'No items',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14.sp,
                                      letterSpacing: 1.0,
                                      color: Colors.black54,
                                    ),
                                  ),
                                )
                              : PageView.builder(
                                  controller: _pageController,
                                  itemCount: safePageCount,
                                  onPageChanged: (i) {
                                    setState(() => _currentPage = i);
                                  },
                                  itemBuilder: (context, pageIndex) {
                                    final chunk = pageRows(pageIndex);
                                    return Container(
                                      color: const Color(0xFFE6E6E6),
                                      child: Column(
                                        children:
                                            List.generate(chunk.length, (i) {
                                          final item = chunk[i];
                                          final isLastRow =
                                              i == chunk.length - 1;
                                          return Container(
                                            decoration: BoxDecoration(
                                              border: Border(
                                                bottom: BorderSide(
                                                  color: isLastRow
                                                      ? Colors.transparent
                                                      : Colors.white,
                                                  width: 1,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                bodyCell(item['invoice_date'] ??
                                                    ''),
                                                bodyCell(item['vendor_name'] ??
                                                    ''),
                                                bodyCell(item['lpo_no'] ?? ''),
                                                bodyCell(item['wo_name'] ?? ''),
                                                bodyCell(
                                                  item['total_amount'] ?? '',
                                                  isLast: true,
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 10.w),
          if (rows.isNotEmpty && pageCount > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: () {
                    if (_currentPage <= 0) return;
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Icon(Icons.arrow_back_ios,
                      size: 18.w, color: Colors.grey.shade700),
                ),
                SizedBox(width: 10.w),
                Row(
                  children: List.generate(pageCount, (i) {
                    final active = i == _currentPage;
                    return Container(
                      margin: EdgeInsets.symmetric(horizontal: 6.w),
                      width: 12.w,
                      height: 12.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            active ? borderColor : const Color(0xFFCFCFCF),
                      ),
                    );
                  }),
                ),
                SizedBox(width: 10.w),
                InkWell(
                  onTap: () {
                    if (_currentPage >= pageCount - 1) return;
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Icon(Icons.arrow_forward_ios,
                      size: 18.w, color: Colors.grey.shade700),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRfqDialog(BuildContext context) {
    String safeValue(dynamic v) {
      if (v == null) return '';
      final s = v.toString();
      if (s.toLowerCase() == 'false') return '';
      return s;
    }

    String formatAmount(dynamic v) {
      if (v == null) return '';
      final parsed = double.tryParse(v.toString());
      if (parsed == null) return safeValue(v);
      return parsed.toStringAsFixed(4);
    }

    final borderColor = const Color(0xFF1A1A53);

    final projectName = safeValue(
      formData?['project_name'] ??
          formData?['project'] ??
          formData?['project_name_id'],
    );
    final vendorName = safeValue(formData?['vendor']);
    final rfqNoCode = safeValue(formData?['title'] ?? formData?['ref_no']);
    final dateOfInvoice = safeValue(
      formData?['date_of_invoice'] ??
          formData?['invoice_date'] ??
          formData?['date'],
    );
    final totalAmount = formatAmount(formData?['amount_total']);
    final materialType = safeValue(formData?['material_type']);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Container(
              width: MediaQuery.of(context).size.width,
              padding: EdgeInsets.fromLTRB(18.w, 18.w, 18.w, 18.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24.r),
              ),
              child: Column(
                children: [
                  SizedBox(height: 6.w),
                  Text(
                    'REQUEST DETAILS',
                    style: GoogleFonts.poppins(
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: borderColor,
                    ),
                  ),
                  SizedBox(height: 14.w),
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(16.w),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: borderColor, width: 2),
                                    borderRadius:
                                        BorderRadius.circular(18.r),
                                  ),
                                  child: Column(
                                    children: [
                                      _buildRfqPillRow(
                                          label: 'PROJECT NAME',
                                          value: projectName),
                                      _buildRfqPillRow(
                                          label: 'VENDRO NAME',
                                          value: vendorName),
                                      _buildRfqPillRow(
                                          label: 'RFQ NO CODE',
                                          value: rfqNoCode),
                                      _buildRfqPillRow(
                                          label: 'DATE OF INVOICE',
                                          value: dateOfInvoice),
                                      _buildRfqPillRow(
                                        label: 'TOTAL AMOUNT',
                                        value: totalAmount.isEmpty
                                            ? ''
                                            : '$totalAmount AED',
                                      ),
                                      _buildRfqPillRow(
                                          label: 'MATERIAL TYPE',
                                          value: materialType),
                                      _buildRfqAttachmentPillRow(
                                        enabled: attachmentIds.isNotEmpty,
                                        onPressed: () async {
                                          if (attachmentIds.isEmpty) {
                                            Fluttertoast.showToast(
                                              msg: 'No attachment found.',
                                              toastLength: Toast.LENGTH_SHORT,
                                              gravity: ToastGravity.CENTER,
                                              backgroundColor: Colors.black,
                                              textColor: Colors.white,
                                            );
                                            return;
                                          }
                                          await _viewAttachement();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 12.w),
                                _buildPagedSummaryTable(
                                  context,
                                  borderColor: borderColor,
                                ),
                                SizedBox(height: 20.w),
                                AbsorbPointer(
                                  absorbing: isCurrentUserInApprovals,
                                  child: ApprovalActionButtons(
                                    requestId: widget.requestId,
                                    type: widget.type,
                                    onResult: null,
                                    disabled: isCurrentUserInApprovals,
                                    userIds: [
                                      SharedPref.getLoginData()
                                              .result
                                              ?.data
                                              ?.uid
                                              .toString() ??
                                          ''
                                    ],
                                    variant:
                                        ApprovalActionButtonsVariant.pill,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: -10.w,
            right: -10.w,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: EdgeInsets.all(5.w),
                decoration: const BoxDecoration(
                  color: red,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, color: Colors.white, size: 22.w),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagedSummaryTable(
    BuildContext context, {
    required Color borderColor,
  }) {
    final rows = projects;

    String safeValue(dynamic v) {
      if (v == null) return '';
      final s = v.toString();
      if (s.toLowerCase() == 'false') return '';
      return s;
    }

    String resolveInvoiceDate(Map<String, String> item) {
      final candidates = <String?>[
        item['date'],
        item['invoice_date'],
        safeValue(formData?['date']),
        safeValue(formData?['invoice_date']),
        safeValue(formData?['request_date']),
      ];
      return candidates.firstWhere(
        (e) => (e ?? '').trim().isNotEmpty,
        orElse: () => '',
      ) ?? '';
    }

    String resolvePettyCashType(Map<String, String> item) {
      final candidates = <String?>[
        item['petty_cash_type'],
        item['type'],
        safeValue(formData?['petty_cash_type']),
        safeValue(formData?['request_type']),
      ];
      return candidates.firstWhere(
        (e) => (e ?? '').trim().isNotEmpty,
        orElse: () => '',
      ) ?? '';
    }

    String resolveTotalAmount(Map<String, String> item) {
      final candidates = <String?>[
        item['total'],
        item['unit_price'],
        safeValue(formData?['amount_total']),
      ];
      final value = candidates.firstWhere(
        (e) => (e ?? '').trim().isNotEmpty,
        orElse: () => '',
      ) ?? '';
      if (value.isEmpty) return '';
      return '$value AED';
    }

    const rowsPerPage = 2;
    final pageCount = (rows.length / rowsPerPage).ceil();
    final safePageCount = math.max(pageCount, 1);

    List<Map<String, String>> pageRows(int pageIndex) {
      final start = pageIndex * rowsPerPage;
      if (start >= rows.length) return const [];
      final end = math.min(start + rowsPerPage, rows.length);
      return rows.sublist(start, end);
    }

    final tableHeight = 220.w;
    final cellWidth = 100.w;
    final tableWidth = cellWidth * 4;

    return SizedBox(
      height: tableHeight,
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18.r),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400, width: 1),
                  borderRadius: BorderRadius.circular(18.r),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      children: [
                        _buildTableHeader(
                            borderColor: borderColor, cellWidth: cellWidth),
                        Expanded(
                          child: rows.isEmpty
                              ? Container(
                                  color: const Color(0xFFE6E6E6),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'No items',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14.sp,
                                      letterSpacing: 1.0,
                                      color: Colors.black54,
                                    ),
                                  ),
                                )
                              : PageView.builder(
                                  controller: _pageController,
                                  itemCount: safePageCount,
                                  onPageChanged: (i) {
                                    setState(() => _currentPage = i);
                                  },
                                  itemBuilder: (context, pageIndex) {
                                    final chunk = pageRows(pageIndex);
                                    return Container(
                                      color: const Color(0xFFE6E6E6),
                                      child: Column(
                                        children:
                                            List.generate(chunk.length, (i) {
                                          final item = chunk[i];
                                          return _buildTableRow(
                                            invoiceDate:
                                                resolveInvoiceDate(item),
                                            projectName:
                                                item['product'] ?? '',
                                            pettyCashType:
                                                resolvePettyCashType(item),
                                            totalAmount:
                                                resolveTotalAmount(item),
                                            isLast: i == chunk.length - 1,
                                            cellWidth: cellWidth,
                                          );
                                        }),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 10.w),
          if (rows.isNotEmpty && pageCount > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: () {
                    if (_currentPage <= 0) return;
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Icon(Icons.arrow_back_ios,
                      size: 18.w, color: Colors.grey.shade700),
                ),
                SizedBox(width: 10.w),
                Row(
                  children: List.generate(pageCount, (i) {
                    final active = i == _currentPage;
                    return Container(
                      margin: EdgeInsets.symmetric(horizontal: 6.w),
                      width: active ? 14.w : 12.w,
                      height: active ? 14.w : 12.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.shade300,
                        border: Border.all(
                          color: active ? borderColor : Colors.grey.shade400,
                          width: active ? 2 : 1,
                        ),
                      ),
                    );
                  }),
                ),
                SizedBox(width: 10.w),
                InkWell(
                  onTap: () {
                    if (_currentPage >= pageCount - 1) return;
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Icon(Icons.arrow_forward_ios,
                      size: 18.w, color: Colors.grey.shade700),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(
      {required Color borderColor, required double cellWidth}) {
    Widget cell(String text, {bool isLast = false}) {
      return Container(
        width: cellWidth,
        padding: EdgeInsets.symmetric(vertical: 10.w, horizontal: 8.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            right: isLast
                ? BorderSide.none
                : const BorderSide(color: Colors.white, width: 1),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: Colors.white,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF8A8A8A),
        border: const Border(
          bottom: BorderSide(color: Colors.white, width: 1),
        ),
      ),
      child: Row(
        children: [
          cell('INVOICE\nDATE'),
          cell('PROJECTS\nNAME'),
          cell('PETTY CASH\nTYPE'),
          cell('TOTAL\nAMOUNT', isLast: true),
        ],
      ),
    );
  }

  Widget _buildTableRow({
    required String invoiceDate,
    required String projectName,
    required String pettyCashType,
    required String totalAmount,
    required bool isLast,
    required double cellWidth,
  }) {
    Widget cell(String text, {bool isLastCell = false}) {
      return Container(
        width: cellWidth,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(vertical: 16.w, horizontal: 10.w),
        decoration: BoxDecoration(
          border: Border(
            right: isLastCell
                ? BorderSide.none
                : const BorderSide(color: Colors.white, width: 1),
          ),
        ),
        child: Text(
          text.isEmpty ? '' : text,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: Colors.black,
          ),
          maxLines: 3,
          overflow: TextOverflow.visible,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : Colors.white,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          cell(invoiceDate),
          cell(projectName),
          cell(pettyCashType),
          cell(totalAmount, isLastCell: true),
        ],
      ),
    );
  }

  Widget _buildRfqPillRow({required String label, required String value}) {
    const bullet = '●';
    final display = value.isEmpty ? '-' : value;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.w),
      child: Row(
        children: [
          Text(
            bullet,
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(width: 8.w),
          SizedBox(
            width: 135.w,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.w),
              decoration: BoxDecoration(
                color: const Color(0xFFE1E1E1),
                borderRadius: BorderRadius.circular(22.r),
                border: Border.all(color: const Color(0xFF4A4A4A), width: 1),
              ),
              child: Text(
                display,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRfqAttachmentPillRow({
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.w),
      child: Row(
        children: [
          Text(
            '●',
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(width: 8.w),
          SizedBox(
            width: 135.w,
            child: Text(
              'ATTACHMENT',
              style: GoogleFonts.poppins(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: InkWell(
              onTap: enabled ? onPressed : null,
              borderRadius: BorderRadius.circular(22.r),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.w),
                decoration: BoxDecoration(
                  color: enabled ? const Color(0xFFE1E1E1) : Colors.grey[300],
                  borderRadius: BorderRadius.circular(22.r),
                  border:
                      Border.all(color: const Color(0xFF4A4A4A), width: 1),
                ),
                child: Text(
                  'View',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHrDialog(BuildContext context) {
    final employeeName =
        (formData?['employee_name'] ?? formData?['requester'] ?? '')
            .toString();

    String safeValue(dynamic v) {
      if (v == null) return '';
      final s = v.toString();
      if (s.toLowerCase() == 'false') return '';
      return s;
    }

    final reqNo = safeValue(formData?['request_no']);
    final reqType = safeValue(formData?['request_type']);
    final reqDate = safeValue(formData?['request_date']);
    final startDate = safeValue(formData?['start_date']);
    final duration = safeValue(formData?['duration']);
    final balanceLeave = safeValue(formData?['balance_leave']);

    const borderColor = Color(0xFF0B2D5E);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Container(
              padding: EdgeInsets.fromLTRB(18.w, 18.w, 18.w, 18.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(color: borderColor, width: 2),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: _showEmployeeDetailsDialog,
                      borderRadius: BorderRadius.circular(22.r),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 14.w, vertical: 10.w),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22.r),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4A4A4A), Color(0xFF101010)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44.w,
                              height: 44.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 2),
                              ),
                              child: ClipOval(
                                child: isLoading
                                    ? Container(color: Colors.grey.shade400)
                                    : _buildEmployeeImage(
                                        formData?['image_emp'],
                                        22.w,
                                      ),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Text(
                                employeeName.toUpperCase(),
                                maxLines: null,
                                overflow: TextOverflow.visible,
                                style: GoogleFonts.poppins(
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.0,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Image.asset(
                              'assets/png/tap.png',
                              width: 26.w,
                              height: 26.w,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 18.w),
                    Text(
                      'REQUEST DETAILS',
                      style: GoogleFonts.poppins(
                        fontSize: 26.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: borderColor,
                      ),
                    ),
                    SizedBox(height: 14.w),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        border: Border.all(color: borderColor, width: 2),
                        borderRadius: BorderRadius.circular(18.r),
                      ),
                      child: Column(
                        children: [
                          _buildHrPillRow(
                              label: 'REQ NO', value: reqNo),
                          _buildHrPillRow(
                              label: 'REQ TYPE', value: reqType),
                          _buildHrPillRow(
                              label: 'REQ DATE', value: reqDate),
                          _buildHrPillRow(
                              label: 'START DATE', value: startDate),
                          _buildHrPillRow(
                              label: 'DURATION', value: duration),
                          _buildHrPillRow(
                              label: 'BALANCE LEAVE', value: balanceLeave),
                          _buildHrAttachmentRow(
                            onPressed: () async {
                              if (attachmentIds.isEmpty) {
                                Fluttertoast.showToast(
                                  msg: 'No attachment found.',
                                  toastLength: Toast.LENGTH_SHORT,
                                  gravity: ToastGravity.CENTER,
                                  backgroundColor: Colors.black,
                                  textColor: Colors.white,
                                );
                                return;
                              }
                              await _viewAttachement();
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 22.w),
                    AbsorbPointer(
                      absorbing: isCurrentUserInApprovals,
                      child: ApprovalActionButtons(
                        requestId: widget.requestId,
                        type: widget.type,
                        onResult: null,
                        disabled: isCurrentUserInApprovals,
                        userIds: [
                          SharedPref.getLoginData()
                                  .result
                                  ?.data
                                  ?.uid
                                  .toString() ??
                              ''
                        ],
                        variant: ApprovalActionButtonsVariant.pill,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -10.w,
            right: -10.w,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: EdgeInsets.all(5.w),
                decoration: const BoxDecoration(
                  color: red,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, color: Colors.white, size: 22.w),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHrPillRow({required String label, required String value}) {
    const bullet = '●';
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.w),
      child: Row(
        children: [
          Text(
            bullet,
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(width: 8.w),
          SizedBox(
            width: 120.w,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.w),
              decoration: BoxDecoration(
                color: const Color(0xFFE1E1E1),
                borderRadius: BorderRadius.circular(22.r),
                border: Border.all(color: const Color(0xFFB0B0B0), width: 1),
              ),
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHrAttachmentRow({
    required VoidCallback onPressed,
  }) {
    const navy = Color(0xFF1A1A53);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.w),
      child: Row(
        children: [
          Text(
            '●',
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(width: 8.w),
          SizedBox(
            width: 120.w,
            child: Text(
              'ATTACHMENT',
              style: GoogleFonts.poppins(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: SizedBox(
              height: 38.w,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: navy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22.r),
                  ),
                ),
                child: Text(
                  'View',
                  style: GoogleFonts.poppins(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.0),
        child: Row(
          children: [
            Text(
              "●",
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.0),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Container(
                width: 150.w,
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.w),
                decoration: BoxDecoration(
                  color: AppColors.separatorColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          ],
        ));
  }

  Widget _buildStatusBar() {
    if (approvals.isEmpty) {
      return const SizedBox();
    }

    final approvedCount =
        approvals.where((a) => a['validation_status'] == true).length;
    final totalCount = approvals.length;
    final progress = approvedCount / totalCount;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: progress,
        backgroundColor: Colors.grey.shade300,
        valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
        minHeight: 8,
      ),
    );
  }

  Widget _buildApproverRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: approvals.map((approver) {
        final approved = approver['validation_status'] == true;

        return Column(
          children: [
            Icon(
              approved ? Icons.check_circle : Icons.cancel,
              color: approved ? Colors.green : Colors.red,
              size: 18,
            ),
            const SizedBox(height: 4),
            const CircleAvatar(
              radius: 16,
              backgroundImage: AssetImage('assets/png/profile_1.png'),
            ),
            SizedBox(
              width: 40.w,
              child: Text(
                approver['name'] ?? '',
                style: TextStyle(fontSize: 10.sp),
                overflow: TextOverflow.visible,
              ),
            )
          ],
        );
      }).toList(),
    );
  }

  Widget _buildIconText(IconData icon, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.black87),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value ?? "N/A",
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHrRequestDetail() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D1540), Color(0xFF1E2A78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHrField("Request no :", formData?["request_no"]),
          _buildHrField("Request type :", formData?["request_type"]),
          _buildHrField("Status :", formData?["status"]?.toString()),
          _buildHrField("Request date :", formData?["request_date"]),
          _buildHrField("Start Date :", formData?["start_date"]?.toString()),
          _buildHrField("Duration :", formData?["duration"]?.toString()),
          _buildHrField(
              "Balance Leave :", formData?["balance_leave"]?.toString()),
        ],
      ),
    );
  }

  Widget _buildHrField(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(
        "$label ${value ?? ''}",
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w300,
          color: Colors.white,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  _viewAttachement() async {
    print('🔵 _viewAttachement called');
    print('🔵 attachmentIds: $attachmentIds');
    
    if (attachmentIds.isEmpty) {
      print('🔴 No attachments found');
      Fluttertoast.showToast(
        msg: 'No attachment found.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.black,
        textColor: Colors.white,
      );
      return;
    }
    
    final attachmentId =
        attachmentIds.first['attachment_id'] ?? attachmentIds.first;
    print('🔵 attachmentId: $attachmentId');
    
    final token = SharedPref.getLoginData().result?.token;
    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };
    print('id: $attachmentId');
    final data = {
      "jsonrpc": "2.0",
      "params": {
        "attachment_id": attachmentId,
      }
    };
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final response = await Dio().fetch(
        RequestOptions(
          method: 'GET',
          path: 'https://erp.elrace.com/api/get_attachment_details',
          headers: headers,
          data: data,
          responseType: ResponseType.json,
        ),
      );
      Navigator.of(context).pop();
      final resData = response.data;
      final binaryBase64 =
          resData['result']['data']['attachment_binary_data'] ?? '';
      final fileName = resData['result']['data']['attachment_name'] ?? '';
      if (binaryBase64 == null) {
        Fluttertoast.showToast(
          msg: 'No binary data found.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          backgroundColor: Colors.black,
          textColor: Colors.white,
        );
        return;
      }
      final pdfBytes = base64Decode(binaryBase64);
      Util.pushPage(
          AttachmentPdfViewer(
            pdfBytes: pdfBytes,
            attchmentName: fileName,
          ),
          context);
    } catch (e) {
      Navigator.of(context).pop();
      Fluttertoast.showToast(
        msg: 'Error: $e',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.black,
        textColor: Colors.white,
      );
    }
  }
}
