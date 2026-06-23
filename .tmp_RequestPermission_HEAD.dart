import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class RequestPermission extends StatefulWidget {
  final dynamic loginResponseModel;

  const RequestPermission({super.key, required this.loginResponseModel});

  @override
  State<RequestPermission> createState() => _RequestPermissionState();
}

class _RequestPermissionState extends State<RequestPermission> {
  static const Color _primary = Color(0xFF151544);
  static const Color _bg = Color(0xFFF5F5F5);
  static const Color _accentGrey = Color(0xFF5E5E5E);

  String selectedReason = "New hire";
  DateTime selectedStartDate = DateTime.now();
  DateTime selectedEndDate = DateTime.now();
  DateTime joinedDate = DateTime.now();
  DateTime leaveEndDate = DateTime.now();
  String description = '';
  String selectedDay = 'Today';

  bool isSubmitting = false;

  // Description formatting states
  bool isBold = false;
  bool isItalic = false;
  bool isBulletList = false;
  bool isNumberedList = false;
  final TextEditingController _descController = TextEditingController();

  // Add missing time variables
  String startTimeFormatted = 'Select Time';
  String endTimeFormatted = 'Select Time';

  // New variables for the updated design
  int selectedHour = 8;
  String selectedPeriod = 'AM'; // AM or PM
  String selectedDuration = '2H'; // 1H, 2H, or 3H

  Future<void> _selectDate(BuildContext context, bool isJoinedDate) async {
    DateTime initialDate = isJoinedDate ? joinedDate : leaveEndDate;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isJoinedDate) {
          joinedDate = picked;
        } else {
          leaveEndDate = picked;
        }
      });
    }
  }

  int calculateLateDays() {
    return leaveEndDate.difference(joinedDate).inDays;
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          startTimeFormatted = picked.format(context);
        } else {
          endTimeFormatted = picked.format(context);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: const HeaderWidget(),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Text(
                'TEMPORARY PERMISSION',
                style: GoogleFonts.koulen(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          'Select Day',
                          style: GoogleFonts.koulen(
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
                                    _updateDateBasedOnRadio();
                                  });
                                },
                              ),
                              Text(
                                'Today',
                                style: GoogleFonts.inter(
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
                                    _updateDateBasedOnRadio();
                                  });
                                },
                              ),
                              Text(
                                'Tomorrow',
                                style: GoogleFonts.inter(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 18.h),
                      Center(
                        child: Text(
                          'Select Hour',
                          style: GoogleFonts.koulen(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.5,
                            color: _primary,
                          ),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.w),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 6.w, vertical: 5.h),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(20.r),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          if (selectedHour > 1) selectedHour--;
                                        });
                                      },
                                      child: Padding(
                                        padding: EdgeInsets.all(4.w),
                                        child: Icon(Icons.remove, size: 16.w),
                                      ),
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      '${selectedHour.toString().padLeft(2, '0')}:00',
                                      style: GoogleFonts.inter(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(width: 4.w),
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          if (selectedHour < 12) selectedHour++;
                                        });
                                      },
                                      child: Padding(
                                        padding: EdgeInsets.all(4.w),
                                        child: Icon(Icons.add, size: 16.w),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 6.w),
                              _buildPeriodChip('AM'),
                              SizedBox(width: 5.w),
                              _buildPeriodChip('PM'),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 18.h),
                      Center(
                        child: Text(
                          'Duration type',
                          style: GoogleFonts.koulen(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.5,
                            color: _primary,
                          ),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildDurationChoice('1H'),
                          SizedBox(width: 14.w),
                          _buildDurationChoice('2H'),
                          SizedBox(width: 14.w),
                          _buildDurationChoice('3H'),
                        ],
                      ),
                      SizedBox(height: 18.h),
                      _buildReasonCard(),
                      SizedBox(height: 16.h),
                      _buildNotice(),
                      SizedBox(height: 24.h),
                      SizedBox(
                        width: double.infinity,
                        height: 48.h,
                        child: ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : _submitTempPermissionRequest,
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
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : Text(
                                  'SUBMIT',
                                  style: GoogleFonts.koulen(
                                    fontSize: 16.sp,
                                    letterSpacing: 1.5,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
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

  Widget _buildPeriodChip(String period) {
    final bool isSelected = selectedPeriod == period;
    return GestureDetector(
      onTap: () => setState(() => selectedPeriod = period),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? _accentGrey : Colors.white,
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(
          period,
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildDurationChoice(String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: selectedDuration == value,
          activeColor: _accentGrey,
          checkColor: Colors.white,
          onChanged: (_) => setState(() => selectedDuration = value),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildReasonCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.95.r),
        border: Border.all(
          width: 1.13,
          color: const Color(0xFFB0B0B0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 36.16,
            offset: Offset(0, 4.52.h),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(11.30.w, 11.30.h, 11.30.w, 10.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Reason',
                    style: GoogleFonts.lexendDeca(
                      color: const Color(0xFF6E6A7C),
                      fontSize: 14.69.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 15.82.w,
                  children: [
                    _buildMiniFormatButton(
                      icon: Icons.format_bold,
                      isActive: isBold,
                      onTap: () {
                        setState(() {
                          isBold = !isBold;
                          _applyFormatting();
                        });
                      },
                    ),
                    _buildMiniFormatButton(
                      icon: Icons.format_list_numbered,
                      isActive: isNumberedList,
                      onTap: () {
                        setState(() {
                          isNumberedList = !isNumberedList;
                          isBulletList = false;
                          _insertNumberedList();
                        });
                      },
                    ),
                    _buildMiniFormatButton(
                      icon: Icons.format_list_bulleted,
                      isActive: isBulletList,
                      onTap: () {
                        setState(() {
                          isBulletList = !isBulletList;
                          isNumberedList = false;
                          _insertListPrefix('GÇó ');
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11.30.r),
                border: Border.all(
                  width: 1.13,
                  color: const Color(0xFFD9D9D9),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
                child: TextField(
                  controller: _descController,
                  minLines: 4,
                  maxLines: 4,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: 'Write your description...',
                    hintStyle: GoogleFonts.lexendDeca(
                      color: const Color(0xFF24252C).withAlpha(120),
                      fontSize: 12.43.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  style: GoogleFonts.lexendDeca(
                    color: const Color(0xFF24252C),
                    fontSize: 12.43.sp,
                    fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
                    fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                  ),
                  onChanged: (val) => setState(() => description = val),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniFormatButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 29.70.w,
      height: 24.91.h,
      child: Material(
        color: const Color(0xFFD9D9D9),
        borderRadius: BorderRadius.circular(4.95.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(4.95.r),
          onTap: onTap,
          child: Center(
            child: Icon(
              icon,
              size: 16.w,
              color: isActive ? _primary : const Color(0xFF24252C),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotice() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.info_outline, size: 20.w, color: Colors.grey),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            'Maximum Hours per month is 6 Hours',
            style: GoogleFonts.inter(
              fontSize: 9.sp,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submitTempPermissionRequest() async {
    if (isSubmitting) return;
    try {
      final token = SharedPref.getLoginData().result?.token;

      // Convert hour to 24-hour format
      int get24Hour() {
        if (selectedPeriod == 'AM') {
          return selectedHour == 12 ? 0 : selectedHour;
        } else {
          return selectedHour == 12 ? 12 : selectedHour + 12;
        }
      }

      // Get duration in hours
      int getDurationHours() {
        return int.parse(selectedDuration.replaceAll('H', ''));
      }

      int startHour = get24Hour();
      int endHour = startHour + getDurationHours();

      // Validation conditions
      int tempHoursValue =
          selectedHour; // from 1 to 10 (12-hour format, but API expects 1-10)
      int tempSelectionValue = getDurationHours(); // from 1 to 3

      // Validate temp_hours (1 to 10)
      if (tempHoursValue < 1 || tempHoursValue > 10) {
        _showErrorDialog("Start hour must be between 1 and 10.");
        return;
      }

      // Validate temp_selection (1 to 3)
      if (tempSelectionValue < 1 || tempSelectionValue > 3) {
        _showErrorDialog("Duration selection must be between 1H and 3H.");
        return;
      }

      // Validate description is not empty
      if (description.trim().isEmpty) {
        _showErrorDialog("Please provide a reason for your request.");
        return;
      }

      if (mounted) setState(() => isSubmitting = true);

      final response = await http.post(
        Uri.parse('https://erp.elrace.com/api/submit_request'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "jsonrpc": "2.0",
          "params": {
            "request_type": "temp_permission",
            "leave_type": null,
            "joined_date": null,
            "start_date": DateFormat('yyyy-MM-dd').format(joinedDate),
            "duration": null,
            "end_date": null,
            "description": description,
            "note": description,
            "job_type": null,
            "job_time": null,
            "job_date": null,
            "e_reason": null,
            "join_date": null,
            "late_days": null,
            "attachment": null,
            "client_details": null,
            "project_details": null,
            "duration_type": "custom_hours",
            "hour_from": startHour.toString(),
            "hour_to": endHour.toString(),
            "jm_start": selectedDay.toLowerCase(),
            "temp_hours": tempHoursValue.toString(),
            "temp_selection": tempSelectionValue.toString(),
          }
        }),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 &&
          data["result"]?['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(translate('request.request_submitted'))),
        );
        Navigator.pop(
            context, true); // G£à Go back to MyRequestsPage with refresh flag
      } else {
        _showErrorDialog(
            data["result"]?['message'] ?? translate('request.request_failed'));
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(translate('request.error_occurred'));
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(128),
      builder: (ctx) => AlertDialog(
        title: Text(translate('common.error')),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(translate('common.ok')),
          )
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _updateDateBasedOnRadio(); // initialize selected date
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

  void _updateDateBasedOnRadio() {
    setState(() {
      joinedDate = selectedDay == 'Today'
          ? DateTime.now()
          : DateTime.now().add(const Duration(days: 1));
    });
  }
}
