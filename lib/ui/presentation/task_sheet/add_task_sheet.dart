import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/task_sheet/task_sheet_screen.dart';
import 'package:el_race/ui/presentation/todo_list/services/team_members_api_service.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:el_race/resources/app_colors.dart';

import '../../widgets/header_widget.dart';

class AddTaskSheet extends StatefulWidget {
  const AddTaskSheet({super.key});

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final TextEditingController noteController = TextEditingController();
  List<Map<String, dynamic>> employees = [];
  bool isLoading = true;

  // Multi-select employees
  List<Map<String, dynamic>> _selectedEmployees = [];
  final ValueNotifier<List<String>> _selectedEmployeeIdsNotifier =
      ValueNotifier<List<String>>([]);
  bool _isDropdownOpen = false;

  bool isLeaveSelected = false;

  DateTime? startDateTime;
  DateTime? endDateTime;
  Duration breakDuration = const Duration(hours: 1);

  String getWorkingHours() {
    if (startDateTime == null || endDateTime == null) return '00:00';

    final total = endDateTime!.difference(startDateTime!) - breakDuration;
    if (total.isNegative) return '00:00';

    final hours = total.inHours;
    final minutes = total.inMinutes % 60;
    final hh = hours.toString().padLeft(2, '0');
    final mm = minutes.toString().padLeft(2, '0');
    return "$hh:$mm";
  }

  final List<String> leaveTypes = [
    'Pilgrimage/Umrah Leave',
    'Bereavement Leave',
    'Education Leave',
    'Absent',
  ];

  String? selectedLeaveType;

  int _getLeaveTypeId(String leaveType) {
    switch (leaveType) {
      case 'Absent':
        return 15;
      case 'Pilgrimage/Umrah Leave':
        return 12;
      case 'Education Leave':
        return 14;
      case 'Bereavement Leave':
        return 13;
      default:
        return 0; // You can return 0 or handle differently
    }
  }

// Sample employees
  @override
  void initState() {
    super.initState();
    _fetchEmployees();

    final selected = DateTime.now();
    //  final selected = widget.selectedDate;
    final now = DateTime.now();

    // Take selectedDate's year, month, day but apply time
    startDateTime = DateTime(
      selected.year,
      selected.month,
      selected.day,
      now.hour,
      now.minute,
    ).subtract(const Duration(hours: 9)); // minus 9 hours

    endDateTime = DateTime(
      selected.year,
      selected.month,
      selected.day,
      now.hour,
      now.minute,
    ); // current time
  }

  @override
  void dispose() {
    noteController.dispose();
    _selectedEmployeeIdsNotifier.dispose();
    super.dispose();
  }

  Future<bool> _submitTimesheetWithFeedback() async {
    if (_selectedEmployees.isEmpty) {
      _showDialogMessage("Please select at least one employee.");
      return false;
    }

    final loginData = SharedPref.getLoginData();
    final token = loginData.result?.token;
    if (token == null || token.isEmpty) {
      _showDialogMessage("Authentication token is missing.");
      return false;
    }

    final employeeIds = _selectedEmployees.map((e) => e['id']).toList();
    final employeeNames =
        _selectedEmployees.map((e) => e['name'].toString()).join(', ');

    final body = {
      "jsonrpc": "2.0",
      "params": {
        "project_id": " widget.project_id",
        // "project_id": widget.project_id,
        "task_id": "widget.taskId",
        //"task_id": widget.taskId,
        "name": employeeNames,
        "break_time":
            breakDuration.inHours, // Sending break in hours (example: 1)
        "leave_type_id": selectedLeaveType != null
            ? _getLeaveTypeId(selectedLeaveType!)
            : false,
        "employee_ids": employeeIds,
        "date": DateFormat('yyyy-MM-dd').format(startDateTime!), // Picked date
        "date_time": DateFormat('yyyy-MM-dd HH:mm:ss')
            .format(startDateTime!), // Start datetime
        "date_time_end": DateFormat('yyyy-MM-dd HH:mm:ss')
            .format(endDateTime!), // End datetime
      }
    };

    try {
      final response = await http.post(
        Uri.parse("https://erp.elrace.com/api/timesheet/submit"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(body),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['result']['success'] == true) {
        return true;
      } else {
        _showDialogMessage(result['result']['message'] ?? "Submission failed.");
        return false;
      }
    } catch (e) {
      _showDialogMessage("Error submitting timesheet: $e");
      return false;
    }
  }

  void _showDialogMessage(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text("Error"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            )
          ],
        );
      },
    );
  }

  Future<void> _fetchEmployees() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final members = await TeamMembersApiService.instance
          .getLaborListMembers(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        employees = members.map((m) {
          final cleanName = m.name.replaceFirst(RegExp(r'^\d+\s+'), '');
          return <String, dynamic>{'id': m.id, 'name': cleanName};
        }).toList();
        isLoading = false;
      });
      print('[AddTaskSheet] Loaded ${employees.length} employees');
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      print('[AddTaskSheet] Error fetching employees: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // ✅ Prevents keyboard overlap
      appBar: const HeaderWidget(),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding:
                const EdgeInsets.only(bottom: 20), // Extra space at the bottom
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    child: Text(
                      'TIME SHEET',
                      style: GoogleFonts.poppins(
                        fontSize: 19,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 1.0,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // ✅ Employee picker — inline multi-select dropdown
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Label + selected chips
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Employee",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: _selectedEmployees
                                  .map(
                                    (emp) => Chip(
                                      label: Text(
                                        emp['name'],
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      deleteIcon:
                                          const Icon(Icons.close, size: 14),
                                      onDeleted: () {
                                        setState(() {
                                          _selectedEmployees.removeWhere(
                                              (e) => e['id'] == emp['id']);
                                          _selectedEmployeeIdsNotifier.value =
                                              _selectedEmployees
                                                  .map(
                                                      (e) => e['id'].toString())
                                                  .toList();
                                        });
                                      },
                                      backgroundColor: const Color(0xFFE8F5E9),
                                      side: const BorderSide(
                                          color: Color(0xFFB2DFDB)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 0),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Dropdown toggle button
                      GestureDetector(
                        onTap: () async {
                          if (isLoading) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Loading employees, please wait...')),
                            );
                            return;
                          }
                          if (employees.isEmpty) {
                            await _fetchEmployees();
                            if (employees.isEmpty && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'No employees found. Please try again.')),
                              );
                              return;
                            }
                          }
                          setState(() {
                            _isDropdownOpen = !_isDropdownOpen;
                          });
                        },
                        child: Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  isLoading
                                      ? 'Loading employees...'
                                      : 'Select an Employee',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade500,
                                  ),
                                  overflow: TextOverflow.visible,
                                ),
                              ),
                              Icon(
                                _isDropdownOpen
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Inline dropdown list
                      AnimatedCrossFade(
                        firstChild: const SizedBox.shrink(),
                        secondChild: Container(
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFEEEEEE)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Employee list
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxHeight: 220),
                                child: Builder(
                                  builder: (context) {
                                    if (employees.isEmpty) {
                                      return Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                          'No employees found',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade500),
                                        ),
                                      );
                                    }

                                    return ListView.separated(
                                      shrinkWrap: true,
                                      padding: EdgeInsets.zero,
                                      itemCount: employees.length,
                                      separatorBuilder: (_, __) => Divider(
                                          height: 1,
                                          color: Colors.grey.shade200),
                                      itemBuilder: (context, index) {
                                        final employee = employees[index];
                                        final isSelected =
                                            _selectedEmployees.any((e) =>
                                                e['id'] == employee['id']);
                                        return InkWell(
                                          onTap: () {
                                            setState(() {
                                              if (isSelected) {
                                                _selectedEmployees.removeWhere(
                                                    (e) =>
                                                        e['id'] ==
                                                        employee['id']);
                                              } else {
                                                _selectedEmployees
                                                    .add(employee);
                                              }
                                              _selectedEmployeeIdsNotifier
                                                      .value =
                                                  _selectedEmployees
                                                      .map((e) =>
                                                          e['id'].toString())
                                                      .toList();
                                            });
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 6),
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: Checkbox(
                                                    value: isSelected,
                                                    onChanged: null,
                                                    activeColor:
                                                        const Color(0xFF27AE60),
                                                    materialTapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    employee['name'],
                                                    style: const TextStyle(
                                                        fontSize: 13),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        crossFadeState: _isDropdownOpen
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 200),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                const SizedBox(height: 15),

                // ✅ Action Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0), // 👈 padding added here
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => isLeaveSelected = false),
                        child: _buildActionButton(
                          "Add shift",
                          isSelected: !isLeaveSelected,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => isLeaveSelected = true),
                        child: _buildActionButton(
                          "Add leave",
                          isSelected: isLeaveSelected,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (!isLeaveSelected) ...[
                  _buildTimeRow("Starts", startDateTime,
                      (picked) => setState(() => startDateTime = picked)),
                  _buildTimeRow("Ends", endDateTime,
                      (picked) => setState(() => endDateTime = picked)),
                  _buildBreakRow("Break Time", breakDuration),
                  _buildInfoRow("Working Hours", "", getWorkingHours(),
                      highlight: true),
                ],

                const SizedBox(height: 20),

                // ✅ Leave Type Dropdown
                if (isLeaveSelected)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 10.0),
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedLeaveType,
                      decoration: InputDecoration(
                        labelText: 'Choose leave type',
                        labelStyle:
                            const TextStyle(fontSize: 13, color: Colors.black),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      icon: const Icon(Icons.arrow_drop_down),
                      dropdownColor: Colors.white,
                      isExpanded: true,
                      items: leaveTypes.map((type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child:
                              Text(type, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedLeaveType = value;
                        });
                      },
                    ),
                  ),

                const SizedBox(height: 20),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildDescriptionBox(),
                ),

                const SizedBox(height: 20),

                const Center(
                  child: Text(
                    "All requests will be sent for a manager’s approval",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 20),

                // ✅ Submit Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildBottomButton("Cancel", red, Colors.white, () {
                        Navigator.pop(context);
                      }),
                      _buildBottomButton(
                          "Send for approval", AppColors.green, Colors.white,
                          () {
                        _showApprovalPopup(context);
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeRow(
      String label, DateTime? dateTime, Function(DateTime) onDateTimePicked) {
    return Column(
      children: [
        Divider(color: Colors.grey.shade300, height: 1, thickness: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15),
          child: InkWell(
            onTap: () async {
              DateTime initialDate = dateTime ?? DateTime.now();
              DateTime? pickedDate = await _showStyledDatePicker(initialDate);

              if (pickedDate != null) {
                TimeOfDay? pickedTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(initialDate),
                );
                if (pickedTime != null) {
                  final combined = DateTime(
                    pickedDate.year,
                    pickedDate.month,
                    pickedDate.day,
                    pickedTime.hour,
                    pickedTime.minute,
                  );
                  onDateTimePicked(combined);
                }
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black)),
                _buildDateTimeValue(dateTime),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<DateTime?> _showStyledDatePicker(DateTime initialDate) async {
    final start = DateUtils.dateOnly(initialDate);
    const weekDays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        DateTime visibleMonth = DateTime(start.year, start.month, 1);
        DateTime selectedDate = start;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final firstDay = DateTime(visibleMonth.year, visibleMonth.month, 1);
            final daysInMonth =
                DateUtils.getDaysInMonth(visibleMonth.year, visibleMonth.month);
            final leading = firstDay.weekday % 7;
            final prevMonth =
                DateTime(visibleMonth.year, visibleMonth.month - 1, 1);
            final daysInPrevMonth =
                DateUtils.getDaysInMonth(prevMonth.year, prevMonth.month);

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 22),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left,
                              color: Colors.black, size: 22),
                          onPressed: () {
                            setModalState(() {
                              visibleMonth = DateTime(
                                  visibleMonth.year, visibleMonth.month - 1, 1);
                            });
                          },
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 36,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(11),
                                    border: Border.all(
                                        color: const Color(0xFFD7D7D7)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: visibleMonth.month,
                                      isExpanded: true,
                                      items: List.generate(12, (index) {
                                        final m = index + 1;
                                        return DropdownMenuItem<int>(
                                          value: m,
                                          child: Text(months[index],
                                              style: const TextStyle(
                                                  fontSize: 16)),
                                        );
                                      }),
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setModalState(() {
                                          visibleMonth = DateTime(
                                              visibleMonth.year, value, 1);
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  height: 36,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(11),
                                    border: Border.all(
                                        color: const Color(0xFFD7D7D7)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: visibleMonth.year,
                                      isExpanded: true,
                                      items: List.generate(31, (index) {
                                        final y =
                                            DateTime.now().year - 10 + index;
                                        return DropdownMenuItem<int>(
                                          value: y,
                                          child: Text('$y',
                                              style: const TextStyle(
                                                  fontSize: 16)),
                                        );
                                      }),
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setModalState(() {
                                          visibleMonth = DateTime(
                                              value, visibleMonth.month, 1);
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right,
                              color: Colors.black, size: 22),
                          onPressed: () {
                            setModalState(() {
                              visibleMonth = DateTime(
                                  visibleMonth.year, visibleMonth.month + 1, 1);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: weekDays
                          .map(
                            (day) => Expanded(
                              child: Center(
                                child: Text(
                                  day,
                                  style: const TextStyle(
                                    color: Color(0xFF8E8E8E),
                                    fontSize: 22 / 2,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 250,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 42,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemBuilder: (context, index) {
                          final dayNumber = index - leading + 1;
                          final isCurrentMonth =
                              dayNumber > 0 && dayNumber <= daysInMonth;

                          DateTime cellDate;
                          if (isCurrentMonth) {
                            cellDate = DateTime(visibleMonth.year,
                                visibleMonth.month, dayNumber);
                          } else if (dayNumber <= 0) {
                            cellDate = DateTime(
                              prevMonth.year,
                              prevMonth.month,
                              daysInPrevMonth + dayNumber,
                            );
                          } else {
                            cellDate = DateTime(
                              visibleMonth.year,
                              visibleMonth.month + 1,
                              dayNumber - daysInMonth,
                            );
                          }

                          final selected =
                              DateUtils.isSameDay(cellDate, selectedDate);

                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: isCurrentMonth
                                ? () {
                                    setModalState(() {
                                      selectedDate = cellDate;
                                    });
                                  }
                                : null,
                            child: Container(
                              decoration: selected
                                  ? BoxDecoration(
                                      color: const Color(0xFFBFEBD6),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: const Color(0xFF8DB6A6)),
                                    )
                                  : null,
                              alignment: Alignment.center,
                              child: Text(
                                '${cellDate.day}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isCurrentMonth
                                      ? Colors.black
                                      : const Color(0xFFBEBEBE),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 36,
                          width: 110,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: red,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 24 / 2),
                            ),
                          ),
                        ),
                        const SizedBox(width: 22),
                        SizedBox(
                          height: 36,
                          width: 110,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.green,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                            onPressed: () =>
                                Navigator.pop(dialogContext, selectedDate),
                            child: const Text(
                              'Done',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 24 / 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDateTimeValue(DateTime? dateTime) {
    final dateText = dateTime == null ? '--' : _formatDateOnly(dateTime);
    final timeText =
        dateTime == null ? '--:--' : DateFormat('HH:mm').format(dateTime);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          dateText,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 10),
        Container(width: 1, height: 16, color: Colors.grey),
        const SizedBox(width: 10),
        Text(
          timeText,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _formatDateOnly(DateTime dateTime) {
    final month = _getMonthShortName(dateTime.month);
    final daySuffix = _getDaySuffix(dateTime.day);
    final yy = (dateTime.year % 100).toString().padLeft(2, '0');
    return "$month ${dateTime.day}$daySuffix $yy";
  }

  String _getMonthShortName(int month) {
    const monthNames = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];
    return monthNames[month - 1];
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return "th";
    switch (day % 10) {
      case 1:
        return "st";
      case 2:
        return "nd";
      case 3:
        return "rd";
      default:
        return "th";
    }
  }

  Widget _buildBreakRow(String label, Duration breakDuration) {
    return Column(
      children: [
        Divider(color: Colors.grey.shade300, height: 1, thickness: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
              Text(
                "${breakDuration.inHours.toString().padLeft(2, '0')}:00",
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ Build Action Buttons (Add Shift / Add Leave)
  Widget _buildActionButton(String text, {required bool isSelected}) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? greyText2 : greyText3,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          color: Colors.black,
        ),
      ),
    );
  }

  // ✅ Build Time Detail Rows
  Widget _buildInfoRow(String label, String time, String hours,
      {bool highlight = false}) {
    return Container(
      decoration: highlight
          ? BoxDecoration(
              color: const Color(0xFFE6E6E6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.15 * 255).toInt()),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            )
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          Text(
            hours,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionBox() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Description',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const Spacer(),
              _buildMiniImageButton('assets/png/paragraphIcon.png',
                  tooltip: 'Paragraph', onPressed: _insertParagraph),
              const SizedBox(width: 6),
              _buildMiniIconButton(Icons.format_list_numbered,
                  tooltip: 'Numbered list', onPressed: _insertNumberedList),
              const SizedBox(width: 6),
              _buildMiniIconButton(Icons.format_list_bulleted,
                  tooltip: 'Bulleted list', onPressed: _insertBulletList),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: TextField(
              controller: noteController,
              minLines: 3,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(
                  fontSize: 12, color: Colors.black87, height: 1.3),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _insertAtCursor(String insertion) {
    final text = noteController.text;
    final sel = noteController.selection;
    final pos = sel.isValid ? sel.baseOffset : text.length;
    final before = text.substring(0, pos);
    final after = text.substring(pos);
    final needsNewline = before.isNotEmpty && !before.endsWith('\n');
    final prefix = needsNewline ? '\n$insertion' : insertion;
    noteController.text = '$before$prefix$after';
    final newPos = before.length + prefix.length;
    noteController.selection = TextSelection.collapsed(offset: newPos);
  }

  void _insertParagraph() {
    _insertAtCursor('\n');
  }

  void _insertNumberedList() {
    final text = noteController.text;
    // Count existing numbered lines to auto-increment
    final lines = text.split('\n');
    int count = 0;
    for (final line in lines) {
      if (RegExp(r'^\d+\.\s').hasMatch(line)) count++;
    }
    _insertAtCursor('${count + 1}. ');
  }

  void _insertBulletList() {
    _insertAtCursor('• ');
  }

  Widget _buildMiniImageButton(String assetPath,
      {String? tooltip, VoidCallback? onPressed}) {
    return SizedBox(
      width: 34,
      height: 28,
      child: Tooltip(
        message: tooltip ?? '',
        child: Material(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Image.asset(assetPath, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniIconButton(IconData icon,
      {String? tooltip, VoidCallback? onPressed}) {
    return SizedBox(
      width: 34,
      height: 28,
      child: Tooltip(
        message: tooltip ?? '',
        child: Material(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(6),
            child: Icon(icon, size: 16, color: Colors.black87),
          ),
        ),
      ),
    );
  }

  Future<void> _openEmployeePicker() async {
    if (isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading employees, please wait...')),
      );
      return;
    }
    if (employees.isEmpty) {
      // Retry fetching
      await _fetchEmployees();
      if (employees.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('No employees found. Please try again.')),
          );
        }
        return;
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = employees.where((emp) {
              final name = (emp['name'] ?? '').toString().toLowerCase();
              return name.contains(query.toLowerCase());
            }).toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      autofocus: true,
                      onChanged: (v) => setModalState(() => query = v),
                      decoration: InputDecoration(
                        hintText: 'Search employee...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 340),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (context, index) {
                          final employee = filtered[index];
                          final isSelected = _selectedEmployees
                              .any((e) => e['id'] == employee['id']);
                          return ListTile(
                            dense: true,
                            leading: Checkbox(
                              value: isSelected,
                              onChanged: null,
                              activeColor: const Color(0xFF27AE60),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            title: Text(
                              '${employee['id']} ${(employee['name'] ?? '').toString()}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            trailing: null,
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedEmployees.removeWhere(
                                      (e) => e['id'] == employee['id']);
                                } else {
                                  _selectedEmployees.add(employee);
                                }
                                _selectedEmployeeIdsNotifier.value =
                                    _selectedEmployees
                                        .map((e) => e['id'].toString())
                                        .toList();
                              });
                              setModalState(() {});
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF27AE60),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Done (${_selectedEmployees.length} selected)',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ✅ Build Bottom Buttons (Cancel / Send for Approval)
  Widget _buildBottomButton(
      String text, Color bgColor, Color textColor, VoidCallback onPressed) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: bgColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: onPressed, // Calls the function when clicked
          child: Text(
            text,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
          ),
        ),
      ),
    );
  }

  void _showApprovalPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 26),
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFF2FBF6),
                  Color(0xFFBFEBD6),
                  Color(0xFFFFFFFF),
                ],
                stops: [0.0, 0.62, 1.0],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Are you sure you want to send your request",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildPopupActionButton(
                        label: 'Cancel',
                        color: red,
                        icon: Icons.close,
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildPopupActionButton(
                        label: 'Send',
                        color: AppColors.green,
                        icon: Icons.send_outlined,
                        onTap: () async {
                          Navigator.pop(context);
                          final success = await _submitTimesheetWithFeedback();
                          if (success) {
                            await Future.delayed(const Duration(seconds: 1));
                            if (!mounted) return;
                            Navigator.pushAndRemoveUntil(
                              this.context,
                              MaterialPageRoute(
                                builder: (context) => const TaskSheetPage(),
                              ),
                              (route) => route.isFirst,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPopupActionButton({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 38,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          elevation: 0,
        ),
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 14),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24 / 2,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
