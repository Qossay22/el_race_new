import 'dart:convert';

import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:el_race/resources/app_colors.dart';

import '../../widgets/header_widget.dart';
import 'EmployeeShiftRequestPage.dart';
import 'EmptyShiftPage.dart';
import 'add_task_sheet.dart';

class TaskDetailsPage extends StatefulWidget {
  final LoginResponseModel loginResponseModel;
  final int taskId; // <-- Task ID to send in API
  final int project_id;

  const TaskDetailsPage(
      {super.key,
      required this.loginResponseModel,
      required this.taskId,
      required this.project_id});

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> {
  DateTime selectedStartDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime selectedEndDate = DateTime.now();
  List<Map<String, dynamic>> timesheetData = [];

  @override
  void initState() {
    super.initState();
    _fetchTimesheetData();
  }

  Future<void> _fetchTimesheetData() async {
    final url =
        Uri.parse("https://erp.elrace.com/api/count/timesheets/by/days");

    final body = {
      "jsonrpc": "2.0",
      "params": {
        "task_id": widget.taskId,
        "date_list": List.generate(
          selectedEndDate.difference(selectedStartDate).inDays + 1,
          (i) => DateFormat('yyyy-MM-dd')
              .format(selectedStartDate.add(Duration(days: i))),
        ),
      }
    };

    try {
      final response = await http.post(url, body: jsonEncode(body), headers: {
        'Content-Type': 'application/json',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          timesheetData =
              List<Map<String, dynamic>>.from(data['result']['timesheets']);
        });
      } else {
        print("API Error: ${response.statusCode}");
      }
    } catch (e) {
      print("Fetch error: $e");
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final picked = await _showStyledDatePicker(
      isStartDate ? selectedStartDate : selectedEndDate,
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          selectedStartDate = picked;
        } else {
          selectedEndDate = picked;
        }
      });
      _fetchTimesheetData();
    }
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
            final daysInMonth = DateUtils.getDaysInMonth(visibleMonth.year, visibleMonth.month);
            final leading = firstDay.weekday % 7;
            final prevMonth = DateTime(visibleMonth.year, visibleMonth.month - 1, 1);
            final daysInPrevMonth = DateUtils.getDaysInMonth(prevMonth.year, prevMonth.month);

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 22),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                          icon: const Icon(Icons.chevron_left, color: Colors.black, size: 22),
                          onPressed: () {
                            setModalState(() {
                              visibleMonth = DateTime(visibleMonth.year, visibleMonth.month - 1, 1);
                            });
                          },
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 36,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(11),
                                    border: Border.all(color: const Color(0xFFD7D7D7)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: visibleMonth.month,
                                      isExpanded: true,
                                      items: List.generate(12, (index) {
                                        final m = index + 1;
                                        return DropdownMenuItem<int>(
                                          value: m,
                                          child: Text(months[index], style: const TextStyle(fontSize: 16)),
                                        );
                                      }),
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setModalState(() {
                                          visibleMonth = DateTime(visibleMonth.year, value, 1);
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
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(11),
                                    border: Border.all(color: const Color(0xFFD7D7D7)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: visibleMonth.year,
                                      isExpanded: true,
                                      items: List.generate(31, (index) {
                                        final y = DateTime.now().year - 10 + index;
                                        return DropdownMenuItem<int>(
                                          value: y,
                                          child: Text('$y', style: const TextStyle(fontSize: 16)),
                                        );
                                      }),
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setModalState(() {
                                          visibleMonth = DateTime(value, visibleMonth.month, 1);
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
                          icon: const Icon(Icons.chevron_right, color: Colors.black, size: 22),
                          onPressed: () {
                            setModalState(() {
                              visibleMonth = DateTime(visibleMonth.year, visibleMonth.month + 1, 1);
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
                                    fontSize: 11,
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
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemBuilder: (context, index) {
                          final dayNumber = index - leading + 1;
                          final isCurrentMonth = dayNumber > 0 && dayNumber <= daysInMonth;

                          DateTime cellDate;
                          if (isCurrentMonth) {
                            cellDate = DateTime(visibleMonth.year, visibleMonth.month, dayNumber);
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

                          final selected = DateUtils.isSameDay(cellDate, selectedDate);

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
                                      border: Border.all(color: const Color(0xFF8DB6A6)),
                                    )
                                  : null,
                              alignment: Alignment.center,
                              child: Text(
                                '${cellDate.day}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isCurrentMonth ? Colors.black : const Color(0xFFBEBEBE),
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
                              style: TextStyle(color: Colors.white, fontSize: 12),
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
                            onPressed: () => Navigator.pop(dialogContext, selectedDate),
                            child: const Text(
                              'Done',
                              style: TextStyle(color: Colors.white, fontSize: 12),
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

  @override
  Widget build(BuildContext context) {
    final displayDate = DateFormat('dd MMM yyyy').format(selectedEndDate);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const HeaderWidget(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Text(
              translate('home.time_sheet'),
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w400,
                color: Colors.black,
                letterSpacing: 2.0,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () => _selectDate(context, false),
                child: _buildSingleDateChip(displayDate),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildAddNewRequestButton(context),
          ),
          const SizedBox(height: 8),
          _buildOverallHoursHeader(),

          // Task list
          Expanded(
            child: timesheetData.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: timesheetData.length,
                    itemBuilder: (context, index) {
                      final item = timesheetData[index];

                      // ✅ Try parsing the date safely
                      DateTime? date;
                      try {
                        date = DateTime.parse(item['date']);
                      } catch (_) {
                        return const SizedBox(); // Skip rendering invalid entries
                      }
                      final weekday = DateFormat('E').format(date);
                      final day = DateFormat('dd').format(date);

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8.0, horizontal: 16.0),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EmptyShiftPage(
                                  loginResponseModel: widget.loginResponseModel,
                                  selectedDate: date!,
                                  taskId: widget.taskId,
                                  project_id: widget
                                      .project_id, // 👈 Ensure 'date' is parsed correctly earlier in your loop
                                ),
                              ),
                            );
                          },
                          child: _buildTimesheetStatusCard(
                            date: date,
                            inProgress: item['inprogress'],
                            submitted: item['submitted'],
                            approved: item['approved'],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleDateChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8D8D8D), width: 1),
        gradient: const LinearGradient(
          colors: [Color(0xFFF1F7F4), Color(0xFFD8EEE4)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 2.5),
            child: Image.asset(
              'assets/png/tscalendericon.png',
              width: 19,
              height: 20,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: appFontColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddNewRequestButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFF8D8D8D),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Positioned.fill(
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFF2FBF6),
                      Color(0xFFBFEBD6),
                      Color(0xFFFFFFFF),
                    ],
                    stops: [0.0, 0.58, 1.0],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddTaskSheet(),
                      ),
                    );
                  },
                  child: Center(
                    child: Text(
                      'Add a new request',
                      style: GoogleFonts.poppins(
                        fontSize: 30 / 2,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
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

  Widget _buildOverallHoursHeader() {
    return Row(
      children: [
        const Expanded(
          child: Divider(
            color: Color(0xFFCDCDCD),
            thickness: 0.9,
            indent: 0,
            endIndent: 10,
          ),
        ),
        Text(
          translate('home.OVERALL_HOURS'),
          style: GoogleFonts.poppins(
            fontSize: 26 / 1.6,
            fontWeight: FontWeight.w300,
            color: const Color(0xFF9A9A9A),
            letterSpacing: 1.1,
          ),
        ),
        const Expanded(
          child: Divider(
            color: Color(0xFFCDCDCD),
            thickness: 0.9,
            indent: 10,
            endIndent: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildTimesheetStatusCard({
    required DateTime date,
    required dynamic inProgress,
    required dynamic submitted,
    required dynamic approved,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 134),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF8D8D8D), width: 1),
        image: const DecorationImage(
          image: AssetImage('assets/newapp/tsbackground.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: 6,
              top: 0,
              bottom: 0,
              child: Opacity(
                opacity: 0.22,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    'assets/png/tsIcon.png',
                    width: 150,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusRow(
                    label: 'In Progress',
                    value: inProgress,
                    dotColor: const Color(0xFFFF9800),
                  ),
                  const SizedBox(height: 4),
                  _buildStatusRow(
                    label: 'Submitted',
                    value: submitted,
                    dotColor: const Color(0xFF1F2466),
                  ),
                  const SizedBox(height: 4),
                  _buildStatusRow(
                    label: 'Approved',
                    value: approved,
                    dotColor: const Color(0xFF20C78C),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2, left: 2.5),
                          child: Image.asset(
                            'assets/png/tscalendericon.png',
                            width: 19,
                            height: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd MMM yyyy').format(date),
                          style: GoogleFonts.poppins(
                            fontSize: 30 / 2,
                            fontWeight: FontWeight.w500,
                            color: appFontColor,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow({
    required String label,
    required dynamic value,
    required Color dotColor,
  }) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 32 / 2,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${value ?? 0}',
          style: GoogleFonts.poppins(
            fontSize: 32 / 2,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}
