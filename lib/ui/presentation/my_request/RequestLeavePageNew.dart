import 'dart:convert';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_screenutil/flutter_screenutil.dart';

class RequestLeavePageNew extends StatefulWidget {
  final dynamic loginResponseModel;
  final String leaveType; // 'SICK', 'SHORT', or 'ANNUAL'

  const RequestLeavePageNew({
    super.key,
    required this.loginResponseModel,
    required this.leaveType,
  });

  @override
  State<RequestLeavePageNew> createState() => _RequestLeavePageNewState();
}

class _RequestLeavePageNewState extends State<RequestLeavePageNew> {
  static const Color _primary = Color(0xFF151544);
  static const Color _accentGrey = Color(0xFF5E5E5E);
  DateTime? startDate;
  DateTime? endDate;
  DateTime displayedMonth = DateTime.now();
  String duration = '5';
  String? leaveBalance;
  String certificateNo = '';
  String description = '';
  bool isLoading = false;
  final Set<DateTime> holidays = {};
  final Set<DateTime> officialHolidays = {};
  bool isLoadingHolidays = false;

  // SHORT leave restrictions
  static const int maxShortLeaveDays = 7; // Maximum 7 days for SHORT leave

  // Text formatting states
  bool isBold = false;
  bool isItalic = false;
  bool isBulletList = false;
  bool isNumberedList = false;
  final TextEditingController _descController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initAsync();
  }

  Future<void> _initAsync() async {
    await _fetchLeaveBalance();
  }

  Future<void> _fetchLeaveBalance() async {
    try {
      setState(() {
        leaveBalance = SharedPref.getCachedLeaveBalance();
      });
      debugPrint('✅ Leave Balance fetched: $leaveBalance');
    } catch (e) {
      debugPrint('❌ Error fetching leave balance: $e');
      setState(() {
        leaveBalance = '0';
      });
    }
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      if (startDate == null || (endDate != null)) {
        startDate = date;
        endDate = null;
      } else if (date.isBefore(startDate!)) {
        startDate = date;
        endDate = null;
      } else {
        endDate = date;
        // Calculate duration excluding holidays
        duration = _calculateWorkingDays(startDate!, endDate!).toString();
      }
    });
  }

  bool _isHoliday(DateTime date) {
    return holidays.any((holiday) => _isSameDay(holiday, date));
  }

  int _calculateWorkingDays(DateTime start, DateTime end) {
    // Sick leave duration should count all consecutive days from certificate.
    if (widget.leaveType == 'SICK') {
      return end.difference(start).inDays + 1;
    }

    int workingDays = 0;
    DateTime current = start;

    while (current.isBefore(end) || _isSameDay(current, end)) {
      if (!_isHoliday(current)) {
        workingDays++;
      }
      current = current.add(const Duration(days: 1));
    }

    return workingDays;
  }

  Future<void> _submitRequest() async {
    // If only a start date is selected (1-day leave), treat end date as the same day.
    if (startDate != null && endDate == null) {
      setState(() {
        endDate = startDate;
        duration = '1';
      });
    }

    if (startDate == null || endDate == null || description.trim().isEmpty) {
      _showErrorDialog('Please fill in all required fields.');
      return;
    }

    if (widget.leaveType == 'SICK' && certificateNo.trim().isEmpty) {
      _showErrorDialog('Please enter certificate number for sick leave.');
      return;
    }

    // SHORT leave specific validations
    if (widget.leaveType == 'SHORT') {
      final durationInt = int.tryParse(duration) ?? 0;

      // Check maximum 7 days
      if (durationInt > maxShortLeaveDays) {
        _showErrorDialog('Short leave cannot exceed $maxShortLeaveDays days.');
        return;
      }

      // TODO: Check 30 days gap from last SHORT leave
      // This needs API call to get employee's last SHORT leave date
      // For now, we'll send it to backend and let it validate
    }

    setState(() => isLoading = true);

    try {
      final token = SharedPref.getLoginData().result?.token;
      final url = Uri.parse('https://erp.elrace.com/api/submit_request');

      final body = jsonEncode({
        'jsonrpc': '2.0',
        'params': {
          'request_type': 'leave',
          'leave_type': widget.leaveType.toLowerCase(),
          'start_date': DateFormat('yyyy-MM-dd').format(startDate!),
          'duration': duration,
          'end_date': DateFormat('yyyy-MM-dd').format(endDate!),
          'description': description,
          'note': description,
          'certificate_no': widget.leaveType == 'SICK' ? certificateNo : null,
          'duration_type': 'days',
        }
      });

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token'
      };

      debugPrint('[LeaveRequest][${widget.leaveType}][RequestBody] $body');
      final response = await http.post(url, body: body, headers: headers);
      debugPrint(
          '[LeaveRequest][${widget.leaveType}][ResponseStatus] ${response.statusCode}');
      debugPrint(
          '[LeaveRequest][${widget.leaveType}][ResponseBody] ${response.body}');

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 &&
          data['result']?['status'] == 'success') {
        debugPrint('[LeaveRequest][${widget.leaveType}][Result] SUCCESS');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request submitted successfully!')),
        );
        Navigator.pop(context, true);
      } else {
        final backendErrorMessage = _extractBackendErrorMessage(data);
        debugPrint(
            '[LeaveRequest][${widget.leaveType}][Result] FAILURE: $backendErrorMessage');
        _showErrorDialog(backendErrorMessage);
      }
    } catch (e) {
      debugPrint('[LeaveRequest][${widget.leaveType}][Exception] $e');
      if (mounted) {
        _showErrorDialog('An error occurred. Please try again.');
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showErrorDialog(String msg) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _extractBackendErrorMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      final result = data['result'];
      if (result is Map<String, dynamic>) {
        final resultMessage = result['message'];
        if (resultMessage is String && resultMessage.trim().isNotEmpty) {
          return resultMessage;
        }
      }

      final error = data['error'];
      if (error is Map<String, dynamic>) {
        final errorMessage = error['message'];
        if (errorMessage is String && errorMessage.trim().isNotEmpty) {
          final details = error['data'];
          if (details is Map<String, dynamic>) {
            final detailsMessage = details['message'];
            if (detailsMessage is String && detailsMessage.trim().isNotEmpty) {
              return '$errorMessage: $detailsMessage';
            }
            final name = details['name'];
            if (name is String && name.trim().isNotEmpty) {
              return '$errorMessage ($name)';
            }
            final debug = details['debug'];
            if (debug is String && debug.trim().isNotEmpty) {
              return '$errorMessage\n$debug';
            }
          }
          return errorMessage;
        }
      }
    }

    return 'Request failed';
  }

  String _getPageTitle() {
    switch (widget.leaveType) {
      case 'SICK':
        return 'SICK LEAVE';
      case 'SHORT':
        return 'SHORT LEAVE';
      case 'ANNUAL':
        return 'ANNUAL LEAVE';
      default:
        return 'LEAVE REQUEST';
    }
  }

  String _getNoticeText() {
    switch (widget.leaveType) {
      case 'SICK':
        return 'Sick leave requires a certificate number.';
      case 'SHORT':
        return 'Please be aware that you are eligible for 4 leaves per year';
      case 'ANNUAL':
        return 'Please select your leave dates and submit your request.';
      default:
        return 'Please be aware that you have to submit your request 15 days prior your leave start date.';
    }
  }

  bool get _isSickLayout => widget.leaveType == 'SICK';
  bool get _isShortLayout => widget.leaveType == 'SHORT';
  bool get _isAnnualLayout => widget.leaveType == 'ANNUAL';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: const HeaderWidget(),
      body: SafeArea(
        child: _isSickLayout
            ? _buildSickLeaveLayout()
            : _isShortLayout
                ? _buildShortLeaveLayout()
                : _isAnnualLayout
                    ? _buildAnnualLeaveLayout()
                    : _buildDefaultLeaveLayout(),
      ),
    );
  }

  Widget _buildShortLeaveLayout() {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(
        left: 18.w,
        right: 18.w,
        top: 4.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18.h,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              _getPageTitle(),
              style: GoogleFonts.poppins(
                fontSize: 24.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: const Color(0xFF1D2032),
              ),
            ),
          ),
          SizedBox(height: 10.h),
          _buildSickCalendar(),
          SizedBox(height: 12.h),
          _buildSickInfoRow('Duration', '$duration days'),
          SizedBox(height: 7.h),
          _buildSickInfoRow('Leave Balance', '${leaveBalance ?? 0} days'),
          SizedBox(height: 12.h),
          _buildDescriptionEditor(),
          SizedBox(height: 10.h),
          _buildNoticeRow(),
          SizedBox(height: 12.h),
          Center(child: _buildSubmitButton(width: 235.w)),
        ],
      ),
    );
  }

  Widget _buildAnnualLeaveLayout() {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(
        left: 18.w,
        right: 18.w,
        top: 4.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18.h,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              _getPageTitle(),
              style: GoogleFonts.poppins(
                fontSize: 24.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: const Color(0xFF1D2032),
              ),
            ),
          ),
          SizedBox(height: 10.h),
          _buildSickCalendar(),
          SizedBox(height: 12.h),
          _buildSickInfoRow('Duration', '$duration days'),
          SizedBox(height: 7.h),
          _buildSickInfoRow('Leave Balance', '${leaveBalance ?? 0} days'),
          SizedBox(height: 12.h),
          _buildDescriptionEditor(),
          SizedBox(height: 10.h),
          _buildNoticeRow(),
          SizedBox(height: 12.h),
          Center(child: _buildSubmitButton(width: 235.w)),
        ],
      ),
    );
  }

  Widget _buildDefaultLeaveLayout() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          child: Text(
            _getPageTitle(),
            style: GoogleFonts.poppins(
              fontSize: 18.sp,
              fontWeight: FontWeight.w400,
              letterSpacing: 1.5,
              color: _primary,
            ),
          ),
        ),
        Expanded(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 20.w),
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCalendar(),
                  SizedBox(height: 20.h),
                  _buildInfoRow('Duration', '$duration days'),
                  SizedBox(height: 12.h),
                  if (leaveBalance != null)
                    _buildInfoRow('Leave Balance', '$leaveBalance days'),
                  SizedBox(height: 12.h),
                  if (widget.leaveType == 'SICK') ...[
                    _buildInfoRow('Certificate No', ''),
                    SizedBox(height: 20.h),
                  ],
                  Text(
                    'Description',
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  _buildDescriptionEditor(),
                  SizedBox(height: 16.h),
                  _buildNoticeRow(),
                  SizedBox(height: 24.h),
                  _buildSubmitButton(width: double.infinity),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: 20.h),
      ],
    );
  }

  Widget _buildSickLeaveLayout() {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(
        left: 18.w,
        right: 18.w,
        top: 4.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18.h,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              _getPageTitle(),
              style: GoogleFonts.poppins(
                fontSize: 24.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.1,
                color: const Color(0xFF1D2032),
              ),
            ),
          ),
          SizedBox(height: 10.h),
          _buildSickCalendar(),
          SizedBox(height: 12.h),
          _buildSickInfoRow('Duration', '$duration days'),
          SizedBox(height: 7.h),
          _buildSickInfoRow('Leave Balance', '${leaveBalance ?? 0} days'),
          SizedBox(height: 8.h),
          _buildCertificateRow(),
          SizedBox(height: 12.h),
          _buildDescriptionEditor(),
          SizedBox(height: 10.h),
          _buildNoticeRow(),
          SizedBox(height: 12.h),
          Center(child: _buildSubmitButton(width: 235.w)),
        ],
      ),
    );
  }

  Widget _buildSickCalendar() {
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 9.h, 12.w, 9.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFD0D0D0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    displayedMonth =
                        DateTime(displayedMonth.year, displayedMonth.month - 1);
                  });
                },
                icon: const Icon(Icons.chevron_left),
                color: const Color(0xFF272A35),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 34.h,
                        padding: EdgeInsets.symmetric(horizontal: 10.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFEFEF),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: const Color(0xFFCBCBCB)),
                        ),
                        child: DropdownButton<int>(
                          value: displayedMonth.month,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          items: List.generate(12, (i) => i + 1)
                              .map((m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(
                                      DateFormat('MMM')
                                          .format(DateTime(2000, m)),
                                      style: GoogleFonts.poppins(
                                        fontSize: 13.sp,
                                        color: const Color(0xFF2C2C2C),
                                      ),
                                    ),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val == null) return;
                            setState(() {
                              displayedMonth =
                                  DateTime(displayedMonth.year, val);
                            });
                          },
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Container(
                        height: 34.h,
                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFEFEF),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: const Color(0xFFCBCBCB)),
                        ),
                        child: DropdownButton<int>(
                          value: displayedMonth.year,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          items: List.generate(
                                  12, (i) => DateTime.now().year - 6 + i)
                              .map((y) => DropdownMenuItem(
                                    value: y,
                                    child: Text(
                                      '$y',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13.sp,
                                        color: const Color(0xFF2C2C2C),
                                      ),
                                    ),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val == null) return;
                            setState(() {
                              displayedMonth =
                                  DateTime(val, displayedMonth.month);
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    displayedMonth =
                        DateTime(displayedMonth.year, displayedMonth.month + 1);
                  });
                },
                icon: const Icon(Icons.chevron_right),
                color: const Color(0xFF272A35),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']
                .map((day) => SizedBox(
                      width: 40.w,
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 11.sp,
                          color: const Color(0xFF7C7C7C),
                        ),
                      ),
                    ))
                .toList(growable: false),
          ),
          SizedBox(height: 8.h),
          ..._buildSickCalendarRows(),
        ],
      ),
    );
  }

  List<Widget> _buildSickCalendarRows() {
    final firstDay = DateTime(displayedMonth.year, displayedMonth.month, 1);
    final startOffset = firstDay.weekday % 7;
    final gridStart = firstDay.subtract(Duration(days: startOffset));

    final rows = <Widget>[];
    for (int week = 0; week < 6; week++) {
      rows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (dayIndex) {
            final date = gridStart.add(Duration(days: (week * 7) + dayIndex));
            final isCurrentMonth = date.month == displayedMonth.month;
            final isSelected =
                (startDate != null && _isSameDay(date, startDate!)) ||
                    (endDate != null && _isSameDay(date, endDate!));
            final isInRange = startDate != null &&
                endDate != null &&
                date.isAfter(startDate!) &&
                date.isBefore(endDate!);

            final bg = isSelected
                ? const Color(0xFF696C74)
                : isInRange
                    ? const Color(0xFFEAEAEA)
                    : Colors.transparent;

            return GestureDetector(
              onTap: isCurrentMonth ? () => _onDateSelected(date) : null,
              child: Container(
                width: 40.w,
                height: 38.h,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  '${date.day}',
                  style: GoogleFonts.poppins(
                    fontSize: 13.sp,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: !isCurrentMonth
                        ? const Color(0xFFC4C4C4)
                        : (isSelected ? Colors.white : const Color(0xFF2A2A2A)),
                  ),
                ),
              ),
            );
          }),
        ),
      );
      rows.add(SizedBox(height: 4.h));
    }
    return rows;
  }

  Widget _buildSickInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Row(
        children: [
          SizedBox(
            width: 120.w,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF151528),
                letterSpacing: 0.6,
              ),
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            '|',
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFA4A4A4),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A35),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificateRow() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Row(
        children: [
          Text(
            'Certificate No',
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF151528),
              letterSpacing: 0.6,
            ),
          ),
          const Spacer(),
          Container(
            width: 200.w,
            height: 38.h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30.r),
              border: Border.all(color: const Color(0xFFC9C9C9)),
            ),
            alignment: Alignment.center,
            child: TextField(
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '',
              ),
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                color: const Color(0xFF2B2B2B),
                fontWeight: FontWeight.w500,
              ),
              onChanged: (val) => setState(() => certificateNo = val),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionEditor() {
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFC7C7C7)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Description',
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF686A73),
                ),
              ),
              const Spacer(),
              _buildEditorIcon(Icons.qr_code_scanner_rounded, false, () {}),
              SizedBox(width: 6.w),
              _buildEditorIcon(
                  Icons.format_list_numbered_rounded, isNumberedList, () {
                setState(() {
                  isNumberedList = !isNumberedList;
                  isBulletList = false;
                  _insertNumberedList();
                });
              }),
              SizedBox(width: 6.w),
              _buildEditorIcon(Icons.format_list_bulleted_rounded, isBulletList,
                  () {
                setState(() {
                  isBulletList = !isBulletList;
                  isNumberedList = false;
                  _insertListPrefix('• ');
                });
              }),
            ],
          ),
          SizedBox(height: 6.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFFD0D0D0)),
            ),
            child: TextField(
              controller: _descController,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Write your description...',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 11.sp,
                  color: const Color(0xFF858585),
                ),
              ),
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                color: const Color(0xFF232323),
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
              ),
              onChanged: (val) => setState(() => description = val),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorIcon(IconData icon, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        width: 30.w,
        height: 24.h,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFD7D7D7) : const Color(0xFFE4E4E4),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Icon(
          icon,
          size: 16.sp,
          color: const Color(0xFF3E3F47),
        ),
      ),
    );
  }

  Widget _buildNoticeRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info, size: 21.w, color: const Color(0xFF62646B)),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            _getNoticeText(),
            style: GoogleFonts.poppins(
              fontSize: 9.8.sp,
              color: const Color(0xFF141414),
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton({required double width}) {
    return SizedBox(
      width: width,
      height: 48.h,
      child: ElevatedButton(
        onPressed: isLoading ? null : _submitRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentGrey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26.r),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Text(
                'SUBMIT',
                style: GoogleFonts.poppins(
                  fontSize: 15.sp,
                  letterSpacing: 1.0,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          // Month/Year selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    displayedMonth =
                        DateTime(displayedMonth.year, displayedMonth.month - 1);
                  });
                },
              ),
              Row(
                children: [
                  DropdownButton<int>(
                    value: displayedMonth.month,
                    underline: const SizedBox(),
                    items: List.generate(12, (i) => i + 1)
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(
                                  DateFormat('MMM').format(DateTime(2000, m))),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          displayedMonth = DateTime(displayedMonth.year, val);
                        });
                      }
                    },
                  ),
                  SizedBox(width: 8.w),
                  DropdownButton<int>(
                    value: displayedMonth.year,
                    underline: const SizedBox(),
                    items: List.generate(10, (i) => DateTime.now().year - 5 + i)
                        .map((y) =>
                            DropdownMenuItem(value: y, child: Text('$y')))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          displayedMonth = DateTime(val, displayedMonth.month);
                        });
                      }
                    },
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    displayedMonth =
                        DateTime(displayedMonth.year, displayedMonth.month + 1);
                  });
                },
              ),
            ],
          ),
          SizedBox(height: 8.h),

          // Weekday headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']
                .map((day) => SizedBox(
                      width: 32.w,
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                      ),
                    ))
                .toList(),
          ),
          SizedBox(height: 8.h),

          // Calendar grid
          ..._buildCalendarRows(),
        ],
      ),
    );
  }

  List<Widget> _buildCalendarRows() {
    final firstDay = DateTime(displayedMonth.year, displayedMonth.month, 1);
    final lastDay = DateTime(displayedMonth.year, displayedMonth.month + 1, 0);
    final startWeekday = firstDay.weekday % 7;

    final days = <Widget>[];
    for (int i = 0; i < startWeekday; i++) {
      days.add(SizedBox(width: 32.w, height: 32.w));
    }

    for (int day = 1; day <= lastDay.day; day++) {
      final date = DateTime(displayedMonth.year, displayedMonth.month, day);
      final isSelected = (startDate != null && _isSameDay(date, startDate!)) ||
          (endDate != null && _isSameDay(date, endDate!));
      final isInRange = startDate != null &&
          endDate != null &&
          date.isAfter(startDate!) &&
          date.isBefore(endDate!);

      days.add(
        GestureDetector(
          onTap: () => _onDateSelected(date),
          child: Container(
            width: 32.w,
            height: 32.w,
            margin: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: isSelected
                  ? _accentGrey
                  : isInRange
                      ? _accentGrey.withAlpha(64)
                      : Colors.transparent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 12.sp,
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      );
    }

    final rows = <Widget>[];
    for (int i = 0; i < days.length; i += 7) {
      rows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children:
              days.sublist(i, (i + 7 > days.length) ? days.length : i + 7),
        ),
      );
      rows.add(SizedBox(height: 4.h));
    }
    return rows;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: _primary,
            ),
          ),
          if (label == 'Certificate No')
            Expanded(
              child: TextField(
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Enter number',
                  isDense: true,
                ),
                style: TextStyle(fontSize: 12.sp, color: Colors.black54),
                onChanged: (val) => setState(() => certificateNo = val),
              ),
            )
          else
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
        ],
      ),
    );
  }

  void _applyFormatting() {
    final text = _descController.text;
    _descController.value = _descController.value.copyWith(
      text: text,
    );
  }

  void _insertListPrefix(String prefix) {
    final text = _descController.text;
    final selection = _descController.selection;

    if (text.isEmpty || selection.start == 0) {
      _descController.text = '$prefix$text';
      _descController.selection =
          TextSelection.collapsed(offset: prefix.length);
    } else {
      final newText =
          '${text.substring(0, selection.start)}\n$prefix${text.substring(selection.start)}';
      _descController.text = newText;
      _descController.selection =
          TextSelection.collapsed(offset: selection.start + prefix.length + 1);
    }
    description = _descController.text;
  }

  void _insertNumberedList() {
    final text = _descController.text;
    final lines = text.split('\n');
    final newLines = <String>[];

    for (int i = 0; i < lines.length; i++) {
      if (lines[i].trim().isNotEmpty) {
        newLines
            .add('${i + 1}. ${lines[i].replaceAll(RegExp(r'^\d+\.\s*'), '')}');
      } else {
        newLines.add(lines[i]);
      }
    }

    _descController.text = newLines.join('\n');
    description = _descController.text;
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }
}
