import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class RequestJobMissionPage extends StatefulWidget {
  final dynamic loginResponseModel;

  const RequestJobMissionPage({super.key, required this.loginResponseModel});

  @override
  State<RequestJobMissionPage> createState() => _RequestJobMissionPageState();
}

class _RequestJobMissionPageState extends State<RequestJobMissionPage> {
  static const Color _primary = Color(0xFF151544);
  static const Color _bg = Color(0xFFF5F5F5);
  static const Color _accentGrey = Color(0xFF5E5E5E);

  String description = '';
  String clientDetails = '';
  String projectDetails = '';
  DateTime selectedDate = DateTime.now();
  DateTime displayedMonth = DateTime.now();
  String selectedMissionType = 'job mission type';
  String selectedDuration = "Morning";
  String selectedDay = 'Today'; // or 'Tomorrow'

  bool isSubmitting = false;

  // Description formatting states
  bool isBold = false;
  bool isItalic = false;
  bool isBulletList = false;
  bool isNumberedList = false;
  final TextEditingController _descController = TextEditingController();

  final List<String> options = [
    "Client Visit",
    "Media",
    "Support",
  ];
  bool dropdownOpen = false;

  @override
  void initState() {
    super.initState();
    displayedMonth = DateTime(selectedDate.year, selectedDate.month);
    if (_shouldDisableMorning) {
      selectedDuration = 'Afternoon';
    }
  }

  bool get _isCurrentTimeAfternoonOrLater => DateTime.now().hour >= 12;

  bool get _shouldDisableMorning =>
      selectedDay == 'Today' && _isCurrentTimeAfternoonOrLater;

  String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _formatApiDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  void _onSelectedDateChanged(DateTime newDate) {
    setState(() {
      selectedDate = newDate;
      displayedMonth = DateTime(newDate.year, newDate.month);
    });
  }

  String _mapMissionTypeToApiValue(String label) {
    final normalized = label.trim().toLowerCase();
    if (normalized == 'client visit') return 'client_meeting';
    return normalized.replaceAll(' ', '_');
  }

  Future<void> _submitJobMissionRequest() async {
    if (selectedMissionType.trim().toLowerCase() == 'job mission type' ||
        selectedMissionType.trim().toLowerCase() == 'job mission type') {
      _showErrorDialog('Please select job mission type.');
      return;
    }

    if (description.trim().isEmpty) {
      _showErrorDialog('Please enter a reason.');
      return;
    }

    if (selectedMissionType == 'Client Visit') {
      if (clientDetails.trim().isEmpty || projectDetails.trim().isEmpty) {
        _showErrorDialog('Please fill client & project details.');
        return;
      }
    }

    if (mounted) setState(() => isSubmitting = true);

    try {
      final token = SharedPref.getLoginData().result?.token;
      final selectedMissionTypeApiValue =
          _mapMissionTypeToApiValue(selectedMissionType);

      final url = Uri.parse("https://erp.elrace.com/api/submit_request");

      final body = jsonEncode({
        "jsonrpc": "2.0",
        "params": {
          "request_type": "job_mission",
          "leave_type": selectedMissionTypeApiValue,
          "joined_date": _formatApiDate(selectedDate),
          "start_date": DateFormat('yyyy-MM-dd 00:00:00').format(selectedDate),
          "duration": null,
          "end_date": DateFormat('yyyy-MM-dd 00:00:00').format(selectedDate),
          "description": description,
          "note": description,
          "job_type": selectedMissionTypeApiValue,
          "job_time": selectedDuration.toLowerCase(),
          "job_date": null,
          "e_reason": null,
          "join_date": null,
          "late_days": null,
          "attachment": null,
          "client_details":
              selectedMissionType == 'Client Visit' ? clientDetails : null,
          "project_details":
              selectedMissionType == 'Client Visit' ? projectDetails : null,
          "duration_type": null,
          "hour_from": null,
          "hour_to": null,
          "jm_start": selectedDay.toLowerCase(),
        }
      });

      final headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token"
      };

      debugPrint('[JobMission][RequestBody] $body');
      final response = await http.post(url, body: body, headers: headers);
      debugPrint('[JobMission][ResponseStatus] ${response.statusCode}');
      debugPrint('[JobMission][ResponseBody] ${response.body}');

      final data = jsonDecode(response.body);
      final rpcError = data is Map<String, dynamic>
          ? data['error'] as Map<String, dynamic>?
          : null;
      final rpcResult = data is Map<String, dynamic>
          ? data['result'] as Map<String, dynamic>?
          : null;

      if (!mounted) return;

      if (response.statusCode == 200 && rpcResult?['status'] == 'success') {
        debugPrint('[JobMission][Result] SUCCESS');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(translate('request.job_mission_success'))),
        );
        Navigator.pop(
            context, true); // ✅ Go back to MyRequestsPage with refresh flag
      } else {
        final backendErrorMessage = _extractBackendErrorMessage(data);
        debugPrint('[JobMission][Result] FAILURE: $backendErrorMessage');
        _showErrorDialog(backendErrorMessage);
      }
    } catch (e) {
      debugPrint('[JobMission][Exception] $e');
      if (mounted) {
        _showErrorDialog(translate('request.error_occurred'));
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  void _showErrorDialog(String msg) {
    if (!mounted) return;
    final cleanedMessage = _sanitizeErrorMessage(msg);
    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(128),
      builder: (context) => AlertDialog(
        title: Text(translate('request.submission_failed')),
        content: Text(cleanedMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(translate('common.ok')),
          ),
        ],
      ),
    );
  }

  String _sanitizeErrorMessage(String message) {
    var cleaned = message.trim();
    cleaned = cleaned.replaceFirst(
      RegExp(r'^validation\s*error\s*[:\-]?\s*', caseSensitive: false),
      '',
    );
    return cleaned.isEmpty ? message.trim() : cleaned;
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
          }
          return errorMessage;
        }
      }
    }

    return translate('request.request_failed');
  }

  Widget _buildDropdownHeader() {
    return GestureDetector(
      onTap: () => setState(() => dropdownOpen = !dropdownOpen),
      child: Container(
        width: 260.w,
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 24.w),
        decoration: BoxDecoration(
          color: _accentGrey,
          borderRadius: BorderRadius.circular(22.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(64),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              selectedMissionType,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 15.sp,
                letterSpacing: 2,
              ),
            ),
            Icon(
              dropdownOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownList() {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(22.r),
      child: Container(
        width: 260.w,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(options.length, (i) {
            return Column(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedMissionType = options[i];
                      dropdownOpen = false;
                    });
                  },
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(vertical: 14.h, horizontal: 20.w),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      options[i],
                      style: GoogleFonts.poppins(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                if (i != options.length - 1)
                  Divider(height: 1, color: Colors.grey.shade300),
              ],
            );
          }),
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
      final isSelected = _isSameDay(date, selectedDate);

      days.add(
        GestureDetector(
          onTap: null,
          child: Container(
            width: 32.w,
            height: 32.w,
            margin: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: isSelected ? _accentGrey : Colors.transparent,
              borderRadius: BorderRadius.circular(8.r),
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

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

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

  Widget _buildNotice() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 20.w, color: Colors.grey),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            translate('notification.job_mission_notice'),
            style: GoogleFonts.poppins(
              fontSize: 9.sp,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      appBar: const HeaderWidget(),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Text(
                'JOB MISSION',
                style: GoogleFonts.poppins(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                  color: const Color(0xFF1D2032),
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
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(child: _buildDropdownHeader()),
                          SizedBox(height: 18.h),
                          Center(
                            child: Text(
                              translate('request.select_day'),
                              style: GoogleFonts.poppins(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 1.5,
                                color: _primary,
                              ),
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Radio<String>(
                                    value: 'Today',
                                    groupValue: selectedDay,
                                    activeColor: _accentGrey,
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() {
                                        selectedDay = value;
                                        if (_shouldDisableMorning &&
                                            selectedDuration == 'Morning') {
                                          selectedDuration = 'Afternoon';
                                        }
                                        _onSelectedDateChanged(DateTime.now());
                                      });
                                    },
                                  ),
                                  Text(
                                    translate('request.today'),
                                    style: GoogleFonts.poppins(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(width: 20.w),
                              Row(
                                children: [
                                  Radio<String>(
                                    value: 'Tomorrow',
                                    groupValue: selectedDay,
                                    activeColor: _accentGrey,
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() {
                                        selectedDay = value;
                                        selectedDuration = 'Morning';
                                        _onSelectedDateChanged(
                                          DateTime.now()
                                              .add(const Duration(days: 1)),
                                        );
                                      });
                                    },
                                  ),
                                  Text(
                                    translate('request.tomorrow'),
                                    style: GoogleFonts.poppins(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 10.h),
                          Center(
                            child: Text(
                              translate('request.duration_type'),
                              style: GoogleFonts.poppins(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 1.5,
                                color: _primary,
                              ),
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Radio<String>(
                                    value: 'Morning',
                                    groupValue: selectedDuration,
                                    activeColor: _accentGrey,
                                    onChanged: _shouldDisableMorning
                                        ? null
                                        : (value) {
                                            if (value == null) return;
                                            setState(
                                                () => selectedDuration = value);
                                          },
                                  ),
                                  Text(
                                    translate('request.morning'),
                                    style: GoogleFonts.poppins(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                      color: _shouldDisableMorning
                                          ? Colors.grey
                                          : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(width: 20.w),
                              Row(
                                children: [
                                  Radio<String>(
                                    value: 'Afternoon',
                                    groupValue: selectedDuration,
                                    activeColor: _accentGrey,
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() => selectedDuration = value);
                                    },
                                  ),
                                  Text(
                                    translate('request.afternoon'),
                                    style: GoogleFonts.poppins(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (selectedMissionType == 'Client Visit') ...[
                            SizedBox(height: 14.h),
                            TextField(
                              onChanged: (value) =>
                                  setState(() => clientDetails = value),
                              decoration: InputDecoration(
                                labelText: translate('request.client_details'),
                                labelStyle: GoogleFonts.poppins(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: _primary,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 10.h, horizontal: 12.w),
                                isDense: true,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            TextField(
                              onChanged: (value) =>
                                  setState(() => projectDetails = value),
                              decoration: InputDecoration(
                                labelText: translate('request.project_details'),
                                labelStyle: GoogleFonts.poppins(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: _primary,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 10.h, horizontal: 12.w),
                                isDense: true,
                              ),
                            ),
                          ],
                          SizedBox(height: 16.h),
                          _buildCalendar(),
                          SizedBox(height: 12.h),
                          _buildDescriptionField(),
                          SizedBox(height: 16.h),
                          _buildNotice(),
                          SizedBox(height: 24.h),
                          SizedBox(
                            width: double.infinity,
                            height: 48.h,
                            child: ElevatedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : _submitJobMissionRequest,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accentGrey,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24.r),
                                ),
                                elevation: 2,
                              ),
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                            Colors.white),
                                      ),
                                    )
                                  : Text(
                                      'SUBMIT',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16.sp,
                                        letterSpacing: 1.5,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      if (dropdownOpen)
                        Positioned(
                          top: 48.h,
                          left: 0,
                          right: 0,
                          child: Center(child: _buildDropdownList()),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }
}
