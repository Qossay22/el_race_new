import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class EffectiveDatePage extends StatefulWidget {
  final dynamic loginResponseModel;

  const EffectiveDatePage({super.key, required this.loginResponseModel});

  @override
  State<EffectiveDatePage> createState() => _EffectiveDatePageState();
}

class _EffectiveDatePageState extends State<EffectiveDatePage> {
  static const String _fixedReasonLabel = 'Work resumption';
  static const String _fixedReasonApiValue = 'work_resumption';

  DateTime joinedDate = DateTime.now();
  DateTime leaveEndDate = DateTime.now();
  DateTime displayedMonth = DateTime.now();
  String description = '';

  bool isBold = false;
  bool isItalic = false;
  bool isBulletList = false;
  bool isNumberedList = false;
  final TextEditingController _descController = TextEditingController();

  bool isSubmitting = false;

  bool get _isWorkResumption => true;

  void _onCalendarDateSelected(DateTime date) {
    setState(() {
      joinedDate = date;
    });
  }

  int calculateLateDays() {
    return joinedDate.difference(leaveEndDate).inDays.abs();
  }

  String _formatDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);
  String _formatDateTime(DateTime date) =>
      DateFormat('yyyy-MM-dd HH:mm:ss').format(date);

  Future<void> _submitEffectiveDateRequest() async {
    if (description.trim().isEmpty) {
      _showErrorDialog('Please enter a description.');
      return;
    }

    if (mounted) setState(() => isSubmitting = true);

    final token = SharedPref.getLoginData().result?.token;
    final url = Uri.parse('https://erp.elrace.com/api/submit_request');

    final body = jsonEncode({
      'jsonrpc': '2.0',
      'params': {
        'request_type': 'effective_date',
        'leave_type': null,
        'joined_date': DateFormat('yyyy-MM-dd').format(joinedDate),
        'start_date': _formatDateTime(joinedDate),
        'end_date': _isWorkResumption ? _formatDateTime(leaveEndDate) : null,
        'description': description,
        'note': description,
        'job_type': null,
        'job_time': null,
        'job_date': null,
        'e_reason': _fixedReasonApiValue,
        'join_date': null,
        'late_days': _isWorkResumption ? calculateLateDays() : null,
        'attachment': null,
        'client_details': null,
        'project_details': null,
        'duration_type': null,
        'hour_from': null,
        'hour_to': null,
      }
    });

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      final response = await http.post(url, headers: headers, body: body);
      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 &&
          data['result']?['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request submitted successfully!')),
        );
        Navigator.pop(context, true);
      } else {
        _showErrorDialog(data['result']?['message'] ?? 'Request failed');
      }
    } catch (_) {
      if (mounted) {
        _showErrorDialog('Something went wrong. Please try again later.');
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      resizeToAvoidBottomInset: true,
      appBar: const HeaderWidget(),
      body: SafeArea(
        child: SingleChildScrollView(
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
                  'EFFECTIVE DATE',
                  style: GoogleFonts.poppins(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                    color: const Color(0xFF1D2032),
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              Center(child: _buildReasonHeader()),
              SizedBox(height: 12.h),
              _buildCalendar(),
              SizedBox(height: 12.h),
              _buildInfoRowPillValue('Joining Date', _formatDate(joinedDate)),
              if (_isWorkResumption) ...[
                SizedBox(height: 7.h),
                _buildInfoRowPipe('Late Days', '${calculateLateDays()} days'),
                SizedBox(height: 7.h),
                _buildInfoRowPipe('Leave End Date', _formatDate(leaveEndDate)),
              ],
              SizedBox(height: 12.h),
              _buildDescriptionField(),
              SizedBox(height: 10.h),
              if (_isWorkResumption) _buildNotice(),
              SizedBox(height: 12.h),
              Center(child: _buildSubmitButton(width: 235.w)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReasonHeader() {
    return Container(
      width: 285.w,
      height: 44.h,
      decoration: BoxDecoration(
        color: const Color(0xFF5E5E5E),
        borderRadius: BorderRadius.circular(22.r),
      ),
      alignment: Alignment.center,
      child: Text(
        _fixedReasonLabel,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 14.sp,
          letterSpacing: 0.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCalendar() {
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
          ..._buildCalendarRows(),
        ],
      ),
    );
  }

  List<Widget> _buildCalendarRows() {
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
            final isSelected = _isSameDay(date, joinedDate);

            return GestureDetector(
              onTap:
                  isCurrentMonth ? () => _onCalendarDateSelected(date) : null,
              child: Container(
                width: 40.w,
                height: 38.h,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:
                      isSelected ? const Color(0xFF696C74) : Colors.transparent,
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildInfoRowPillValue(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: Row(
        children: [
          SizedBox(
            width: 140.w,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF151528),
                letterSpacing: 0.6,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 38.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30.r),
                border: Border.all(color: const Color(0xFFC9C9C9)),
              ),
              alignment: Alignment.center,
              child: Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A35),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRowPipe(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: Row(
        children: [
          SizedBox(
            width: 140.w,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
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
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFA4A4A4),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A35),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionField() {
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

  Widget _buildNotice() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info, size: 21.w, color: const Color(0xFF62646B)),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            'Please be aware that any late days will be deducted from your salary.',
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
        onPressed: isSubmitting ? null : _submitEffectiveDateRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF5E5E5E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26.r),
          ),
          elevation: 0,
        ),
        child: isSubmitting
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

  void _applyFormatting() {
    final text = _descController.text;
    _descController.value = _descController.value.copyWith(text: text);
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
