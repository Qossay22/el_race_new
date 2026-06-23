import 'dart:async';
import 'dart:developer';

import 'package:el_race/ui/presentation/Attendace_list/attendance_widgets/colleasped_card.dart';
import 'package:el_race/ui/presentation/Attendace_list/model/attendance_model.dart';
import 'package:el_race/ui/presentation/Attendace_list/repository/attendance_repository.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/utils/di.dart';
import '../../widgets/header_widget.dart';
import 'bloc/attendance_bloc.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({
    super.key,
  });

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  late AttendanceBloc _attendanceBloc;
  final AttendanceRepo _attendanceRepo = sl.get<AttendanceRepo>();
  Set<String> expandedRecords = {};
  final Set<String> _selectedActionCards = {};
  final Map<String, List<AttendanceRecord>> _managerEmployeeRecords = {};
  final Set<String> _managerEmployeeLoading = {};
  final Map<String, String> _managerEmployeeErrors = {};
  int? selectedMonth;
  int selectedYear = DateTime.now().year;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  int _requestSeq = 0;

  // Pagination state
  int _displayedItemsCount = 10;
  final int _itemsPerLoad = 10;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      if (!mounted) return;
      setState(() {});

      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 400), () {
        if (mounted) {
          _onSearch();
        }
      });
    });

    _scrollController.addListener(_onScroll);

    selectedMonth = DateTime.now().month;

    _attendanceBloc = AttendanceBloc();

    // Initial load - the API response determines the user role.
    _fetchAttendance(keyword: null);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreItems();
    }
  }

  void _loadMoreItems() {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _displayedItemsCount += _itemsPerLoad;
          _isLoadingMore = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _attendanceBloc.close();
    super.dispose();
  }

  void _onSearch() {
    final keyword = _searchController.text.trim();
    log('AttendancePage search keyword -> $keyword');
    setState(() {
      _displayedItemsCount = 10;
      expandedRecords.clear();
      _selectedActionCards.clear();
      _managerEmployeeLoading.clear();
      _managerEmployeeErrors.clear();
    });
  }

  void _fetchAttendance({String? keyword}) {
    _requestSeq += 1;
    final monthToUse = selectedMonth ?? DateTime.now().month;

    log(
      'AttendancePage fetch -> requestId=$_requestSeq, keyword=$keyword, month=$monthToUse, year=$selectedYear',
    );

    // Always call GetAttendanceListET — the API returns user_type so we decide
    // which view to show from the response, not from SharedPref.
    _attendanceBloc.add(GetAttendanceListET(
      keyword: keyword,
      month: monthToUse,
      year: selectedYear,
      requestId: _requestSeq,
    ));

    setState(() {
      expandedRecords.clear();
      _selectedActionCards.clear();
      _managerEmployeeRecords.clear();
      _managerEmployeeLoading.clear();
      _managerEmployeeErrors.clear();
    });
  }

  void _toggleActionCard(String cardKey) {
    setState(() {
      if (_selectedActionCards.contains(cardKey)) {
        _selectedActionCards.remove(cardKey);
      } else {
        _selectedActionCards.add(cardKey);
      }
    });
  }

  String _normalizeBackendStatus(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return '';
    return raw.replaceAll('_', ' ').toUpperCase();
  }

  int _daysInMonth(int year, int month) {
    if (month < 1 || month > 12) return 0;
    return DateTime(year, month + 1, 0).day;
  }

  String _actionTitleForRecord(AttendanceRecord record) {
    // Always show x_attendance_type if available
    if (record.attendanceType != null &&
        record.attendanceType!.trim().isNotEmpty) {
      return record.attendanceType!.trim().toUpperCase().replaceAll('_', ' ');
    }

    final inStatus = _normalizeBackendStatus(record.checkInStatus);
    final outStatus = _normalizeBackendStatus(record.checkOutStatus);
    final overallStatus = _normalizeBackendStatus(record.status);

    if (inStatus.isNotEmpty && outStatus.isNotEmpty) {
      return '$inStatus • $outStatus';
    }
    if (overallStatus.isNotEmpty) {
      return overallStatus;
    }
    if (inStatus.isNotEmpty) {
      return inStatus;
    }
    if (outStatus.isNotEmpty) {
      return outStatus;
    }

    final hasCheckOut = record.checkOut != null &&
        record.checkOut != false &&
        record.checkOut.toString().trim().isNotEmpty;
    return hasCheckOut ? 'CHECK IN • CHECK OUT' : 'CHECK IN';
  }

  /// Returns the display color for an [AttendanceRecord] based on its
  /// attendance type or computed check-in status.
  Color _colorForRecord(AttendanceRecord record,
      {required String computedStatus}) {
    final type = (record.attendanceType?.trim() ?? '').toLowerCase();
    const normalTypes = {'normal', 'attendance', ''};
    if (normalTypes.contains(type)) {
      // Server marked as normal — respect late/absent only when NO type is set
      if (type.isEmpty) {
        if (computedStatus == 'ABSENT' || computedStatus.contains('LATE')) {
          return const Color(0xFFBA1719); // red
        }
      }
      return Colors.transparent;
    }
    return const Color(0xFF660FF2); // leave / special type — purple
    if (computedStatus == 'ABSENT' || computedStatus.contains('LATE')) {
      return const Color(0xFFBA1719); // red
    }
    return Colors.transparent; // on time – no accent bar
  }

  Widget _buildActionCard({required String title, required Color color}) {
    return Container(
      key: ValueKey('action_$title'),
      height: 54,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF04031A), Color(0xFF0B0A2E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(23),
      ),
      alignment: Alignment.center,
      child: Text(
        title,
        style: GoogleFonts.koulen(
          fontSize: 19,
          color: color == Colors.transparent ? Colors.white : color,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildInteractiveAttendanceRecordCard({
    required String cardKey,
    required String status,
    required Color textColor,
    required DateTime checkInTime,
    required DateTime? checkOutTime,
    required String actionTitle,
  }) {
    final isSelected = _selectedActionCards.contains(cardKey);
    return InkWell(
      borderRadius: BorderRadius.circular(23),
      onTap: () => _toggleActionCard(cardKey),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: isSelected
            ? _buildActionCard(title: actionTitle, color: textColor)
            : ColleaspedCard(
                key: ValueKey('normal_$cardKey'),
                status: status,
                textColor: textColor,
                bgColorStart: const Color(0xFF0F0C29),
                bgColorEnd: const Color(0xFF302B63),
                isExpanded: false,
                checkInTime: checkInTime,
                checkOutTime: checkOutTime,
              ),
      ),
    );
  }

  Future<void> _toggleManagerEmployee(FlatAttendanceData employee) async {
    final empKey = employee.empId.trim();
    if (empKey.isEmpty) return;

    final wasExpanded = expandedRecords.contains(empKey);
    setState(() {
      if (wasExpanded) {
        expandedRecords.remove(empKey);
      } else {
        expandedRecords.add(empKey);
      }
    });

    if (wasExpanded) return;
    if (_managerEmployeeRecords.containsKey(empKey) ||
        _managerEmployeeLoading.contains(empKey)) {
      return;
    }

    setState(() {
      _managerEmployeeLoading.add(empKey);
      _managerEmployeeErrors.remove(empKey);
    });

    try {
      final response = await _attendanceRepo.getAttendanceDetail(
        empId: int.tryParse(empKey) ?? 0,
        month: selectedMonth ?? DateTime.now().month,
        year: selectedYear,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load records (${response.statusCode})');
      }

      final parsed = attendanceModelFromJson(response.body);
      final result = parsed.result;

      if (result.status.toLowerCase() != 'success') {
        throw Exception('Failed to load employee records');
      }

      final records = result.records ?? <AttendanceRecord>[];
      final Map<String, AttendanceRecord> uniqueRecords = {};
      for (final record in records) {
        final key = '${record.date}_${record.checkIn}';
        if (!uniqueRecords.containsKey(key)) {
          uniqueRecords[key] = record;
        }
      }

      if (!mounted) return;
      setState(() {
        _managerEmployeeRecords[empKey] = uniqueRecords.values.toList();
        _managerEmployeeLoading.remove(empKey);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _managerEmployeeLoading.remove(empKey);
        _managerEmployeeErrors[empKey] = e.toString();
      });
    }
  }

  Future<void> _selectMonth(BuildContext context) async {
    final int? picked = await showDialog<int>(
      context: context,
      builder: (context) => _MonthPickerDialog(
        selectedMonth: selectedMonth,
        currentYear: selectedYear,
      ),
    );

    if (picked != null) {
      setState(() {
        selectedMonth = picked;
        _displayedItemsCount = 10; // Reset to initial count on month change
      });
      _fetchAttendance(keyword: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const HeaderWidget(),
      body: BlocBuilder<AttendanceBloc, AttendanceState>(
        bloc: _attendanceBloc,
        builder: (context, state) {
          // Determine role from the API response user_type field.
          // "manager" and "management" → manager view; "user" → employee view.
          // Fall back to SharedPref while state is loading.
          bool isManagerRole =
              SharedPref.getLoginDataOrNull()?.result?.data?.isAttendanceManager ==
                  true;
          if (state is AttendanceDataLoaded) {
            isManagerRole = state.attendanceData.isManagerRole;
          }

          if (isManagerRole) {
            return _buildManagerView(context, state);
          } else {
            return _buildEmployeeView(context, state);
          }
        },
      ),
    );
  }

  Widget _buildManagerView(BuildContext context, AttendanceState state) {
    final isLoading = state is AttendanceLoadingState && state.isLoading;
    final errorMessage = state is AttendanceErrorState ? state.message : null;
    Result? attendanceData;
    if (state is AttendanceDataLoaded) {
      attendanceData = state.attendanceData;
    }

    final hasFlatData = attendanceData?.data?.isNotEmpty ?? false;
    final hasMonthlyData = attendanceData?.monthlyEmployees?.isNotEmpty ?? false;
    final hasGroupedData = attendanceData?.mode == "grouped" &&
        (attendanceData?.records?.isNotEmpty ?? false);

    final monthName = selectedMonth != null
        ? DateFormat('MMMM').format(DateTime(2020, selectedMonth!))
        : 'Select Month';
    final year = DateTime.now().year.toString();

    return ListView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      children: [
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(width: 48),
            Text(
              'ATTENDANCE',
              style: GoogleFonts.koulen(
                fontSize: 20,
                fontWeight: FontWeight.w400,
                color: appFontColor,
                letterSpacing: 1.9,
              ),
            ),
            _MonthChip(
              label: monthName,
              onTap: () => _selectMonth(context),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _SearchBox(
          controller: _searchController,
          hintText: 'Search employee name or ID',
          onSearch: _onSearch,
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            '$monthName, $year',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF9AA0A6),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          )
        else if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Center(
              child: Text(
                errorMessage,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF5A5A5A),
                ),
              ),
            ),
          )
        else if (attendanceData == null)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Center(
              child: Text(
                'Loading attendance data...',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF5A5A5A),
                ),
              ),
            ),
          )
        else if (attendanceData.status == "error" &&
            !hasFlatData &&
            !hasMonthlyData &&
            !hasGroupedData)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Center(
              child: Text(
                'No data found.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF5A5A5A),
                ),
              ),
            ),
          )
        else if (hasMonthlyData)
          _buildMonthlyEmployeeList(_filterMonthlyEmployeesLocally(attendanceData.monthlyEmployees!))
        else if (hasFlatData)
          _buildFlatEmployeeList(_filterEmployeesLocally(attendanceData.data!))
        else if (attendanceData.mode == "grouped" &&
            attendanceData.records != null)
          _buildEmployeeAttendanceWithCount(attendanceData)
        else
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Center(
              child: Text(
                'No data found.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF5A5A5A),
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildFlatEmployeeList(List<FlatAttendanceData> employees) {
    if (employees.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Center(
          child: Text(
            'No employees found.',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF5A5A5A),
            ),
          ),
        ),
      );
    }

    // Calculate how many items to display
    final displayCount = _displayedItemsCount.clamp(0, employees.length);
    final displayedEmployees = employees.sublist(0, displayCount);
    final hasMore = displayCount < employees.length;

    return Column(
      children: [
        // Employee list
        ...displayedEmployees.map((employee) {
          final empKey = employee.empId.trim();
          final isExpanded = expandedRecords.contains(empKey);
          final isLoadingRecords = _managerEmployeeLoading.contains(empKey);
          final recordsError = _managerEmployeeErrors[empKey];
          final records =
              _managerEmployeeRecords[empKey] ?? const <AttendanceRecord>[];

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () => _toggleManagerEmployee(employee),
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6E6E6),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Row(
                      children: [
                        _EmployeeAvatar(
                          size: 38,
                          imageUrl: employee.employeeImageUrl,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                employee.employeeName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: const Color(0xFF5A5A5A),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isExpanded) ...[
                  const SizedBox(height: 8),
                  if (isLoadingRecords)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (recordsError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        recordsError,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF5A5A5A),
                        ),
                      ),
                    )
                  else if (records.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'No attendance records found.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF5A5A5A),
                        ),
                      ),
                    )
                  else
                    ...records.map((record) {
                      // Weekend/holiday records — render special card
                      final recordStatus =
                          record.status?.toLowerCase().trim() ?? '';
                      final recordAttendanceType =
                          record.attendanceType?.toLowerCase().trim() ?? '';
                      if (recordStatus == 'weekend' ||
                          recordAttendanceType == 'weekend') {
                        final DateTime? recordDate =
                            DateTime.tryParse(record.date);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildWeekendCard(recordDate),
                        );
                      }

                      DateTime? checkInTime;
                      try {
                        checkInTime = DateTime.parse(record.checkIn);
                      } catch (_) {}

                      DateTime? checkOutTime;
                      if (record.checkOut != null && record.checkOut != false) {
                        try {
                          checkOutTime =
                              DateTime.parse(record.checkOut.toString());
                        } catch (_) {}
                      }

                      if (checkInTime == null) {
                        return const SizedBox.shrink();
                      }

                      String status = 'ONTIME';

                      if (checkOutTime == null) {
                        status = 'ABSENT';
                      } else if (checkInTime.isAfter(DateTime(checkInTime.year,
                          checkInTime.month, checkInTime.day, 8, 15))) {
                        final lateMinutes = checkInTime
                            .difference(DateTime(checkInTime.year,
                                checkInTime.month, checkInTime.day, 8, 15))
                            .inMinutes;
                        status = '$lateMinutes MINS LATE';
                      }

                      final textColor =
                          _colorForRecord(record, computedStatus: status);
                      final cardKey =
                          'mgr_${empKey}_${record.date}_${record.checkIn}';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildInteractiveAttendanceRecordCard(
                          cardKey: cardKey,
                          status: status,
                          textColor: textColor,
                          checkInTime: checkInTime,
                          checkOutTime: checkOutTime,
                          actionTitle: _actionTitleForRecord(record),
                        ),
                      );
                    }),
                ],
              ],
            ),
          );
        }),

        // Loading indicator when loading more
        if (_isLoadingMore && hasMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),

        // Total count
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Text(
            'Showing $displayCount of ${employees.length} employees',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF9AA0A6),
            ),
          ),
        ),
      ],
    );
  }

  List<FlatAttendanceData> _filterEmployeesLocally(
      List<FlatAttendanceData> employees) {
    final keyword = _searchController.text.trim().toLowerCase();
    if (keyword.isEmpty) return employees;

    return employees.where((employee) {
      final name = employee.employeeName.toLowerCase();
      final empId = employee.empId.toLowerCase();
      return name.contains(keyword) || empId.contains(keyword);
    }).toList();
  }

  List<EmployeeMonthlyAttendance> _filterMonthlyEmployeesLocally(
      List<EmployeeMonthlyAttendance> employees) {
    final keyword = _searchController.text.trim().toLowerCase();
    if (keyword.isEmpty) return employees;

    return employees.where((e) {
      return e.employeeName.toLowerCase().contains(keyword) ||
          e.employeeId.toString().contains(keyword);
    }).toList();
  }

  Future<void> _toggleMonthlyEmployee(EmployeeMonthlyAttendance employee) async {
    final empKey = employee.employeeId.toString();
    final wasExpanded = expandedRecords.contains(empKey);
    setState(() {
      if (wasExpanded) {
        expandedRecords.remove(empKey);
      } else {
        expandedRecords.add(empKey);
      }
    });

    if (wasExpanded) return;
    if (_managerEmployeeRecords.containsKey(empKey) ||
        _managerEmployeeLoading.contains(empKey)) return;

    setState(() {
      _managerEmployeeLoading.add(empKey);
      _managerEmployeeErrors.remove(empKey);
    });

    try {
      final response = await _attendanceRepo.getAttendanceDetail(
        empId: employee.employeeId,
        month: selectedMonth ?? DateTime.now().month,
        year: selectedYear,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load records (${response.statusCode})');
      }

      final parsed = attendanceModelFromJson(response.body);
      final result = parsed.result;

      if (result.status.toLowerCase() != 'success') {
        throw Exception('Failed to load employee records');
      }

      final records = result.records ?? <AttendanceRecord>[];
      final Map<String, AttendanceRecord> uniqueRecords = {};
      for (final record in records) {
        final key = '${record.date}_${record.checkIn}';
        if (!uniqueRecords.containsKey(key)) {
          uniqueRecords[key] = record;
        }
      }

      if (!mounted) return;
      setState(() {
        _managerEmployeeRecords[empKey] = uniqueRecords.values.toList();
        _managerEmployeeLoading.remove(empKey);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _managerEmployeeErrors[empKey] = e.toString();
        _managerEmployeeLoading.remove(empKey);
      });
    }
  }

  Widget _buildMonthlyEmployeeList(List<EmployeeMonthlyAttendance> employees) {
    if (employees.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No employees found.',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF5A5A5A),
            ),
          ),
        ),
      );
    }

    final displayCount = _displayedItemsCount.clamp(0, employees.length);
    final displayed = employees.sublist(0, displayCount);
    final hasMore = displayCount < employees.length;

    return Column(
      children: [
        ...displayed.map((employee) {
          final empKey = employee.employeeId.toString();
          final isExpanded = expandedRecords.contains(empKey);
          final isLoadingRecords = _managerEmployeeLoading.contains(empKey);
          final recordsError = _managerEmployeeErrors[empKey];
          final records =
              _managerEmployeeRecords[empKey] ?? const <AttendanceRecord>[];

            final monthDays = _daysInMonth(
            employee.year > 0 ? employee.year : selectedYear,
            employee.month > 0
              ? employee.month
              : selectedMonth ?? DateTime.now().month,
            );
            final absentDays =
              (monthDays - employee.totalPresentDays).clamp(0, monthDays);
            final attendanceRatio = monthDays > 0
              ? employee.totalPresentDays / monthDays
              : 0.0;
          final ratioColor = attendanceRatio >= 0.8
              ? const Color(0xFF009859)
              : attendanceRatio >= 0.6
                  ? const Color(0xFFF5A623)
                  : const Color(0xFFE74C3C);

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () => _toggleMonthlyEmployee(employee),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6E6E6),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Row(
                      children: [
                        _EmployeeAvatar(
                          size: 38,
                          imageUrl: employee.employeeImageUrl ?? '',
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            employee.employeeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        Text(
                          '${employee.totalPresentDays}/$monthDays',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: ratioColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: const Color(0xFF5A5A5A),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isExpanded) ...[
                  const SizedBox(height: 8),
                  if (isLoadingRecords)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (recordsError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        recordsError,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF5A5A5A),
                        ),
                      ),
                    )
                  else if (records.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'No attendance records found.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF5A5A5A),
                        ),
                      ),
                    )
                  else
                    ...records.map((record) {
                      final recordStatus =
                          record.status?.toLowerCase().trim() ?? '';
                      final recordAttendanceType =
                          record.attendanceType?.toLowerCase().trim() ?? '';
                      if (recordStatus == 'weekend' ||
                          recordAttendanceType == 'weekend') {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildWeekendCard(
                              DateTime.tryParse(record.date)),
                        );
                      }

                      DateTime? checkInTime;
                      try {
                        checkInTime = DateTime.parse(record.checkIn);
                      } catch (_) {}

                      DateTime? checkOutTime;
                      if (record.checkOut != null &&
                          record.checkOut != false) {
                        try {
                          checkOutTime =
                              DateTime.parse(record.checkOut.toString());
                        } catch (_) {}
                      }

                      if (checkInTime == null) return const SizedBox.shrink();

                      String status = 'ONTIME';
                      if (checkOutTime == null) {
                        status = 'ABSENT';
                      } else if (checkInTime.isAfter(DateTime(
                          checkInTime.year,
                          checkInTime.month,
                          checkInTime.day,
                          8,
                          15))) {
                        final lateMinutes = checkInTime
                            .difference(DateTime(checkInTime.year,
                                checkInTime.month, checkInTime.day, 8, 15))
                            .inMinutes;
                        status = '$lateMinutes MINS LATE';
                      }

                      final textColor =
                          _colorForRecord(record, computedStatus: status);
                      final cardKey =
                          'monthly_${empKey}_${record.date}_${record.checkIn}';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildInteractiveAttendanceRecordCard(
                          cardKey: cardKey,
                          status: status,
                          textColor: textColor,
                          checkInTime: checkInTime,
                          checkOutTime: checkOutTime,
                          actionTitle: _actionTitleForRecord(record),
                        ),
                      );
                    }),
                ],
              ],
            ),
          );
        }),

        if (_isLoadingMore && hasMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),

        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Text(
            'Showing $displayCount of ${employees.length} employees',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF9AA0A6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeView(BuildContext context, AttendanceState state) {
    final isLoading = state is AttendanceLoadingState && state.isLoading;
    final errorMessage = state is AttendanceErrorState ? state.message : null;
    Result? attendanceData;
    if (state is AttendanceDataLoaded) {
      attendanceData = state.attendanceData;
    }

    final monthName = selectedMonth != null
        ? DateFormat('MMMM').format(DateTime(2020, selectedMonth!))
        : 'Select Month';
    final year = DateTime.now().year.toString();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      children: [
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(width: 48),
            Text(
              'ATTENDANCE',
              style: GoogleFonts.koulen(
                fontSize: 20,
                fontWeight: FontWeight.w400,
                color: appFontColor,
                letterSpacing: 1.9,
              ),
            ),
            _MonthChip(
              label: monthName,
              onTap: () => _selectMonth(context),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            '$monthName, $year',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF9AA0A6),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          )
        else if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Center(
              child: Text(
                errorMessage,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF5A5A5A),
                ),
              ),
            ),
          )
        else if (attendanceData == null)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(
              child: Text('No data available'),
            ),
          )
        else if (attendanceData.mode == "grouped" &&
            attendanceData.records != null)
          _buildEmployeeAttendanceWithCount(attendanceData)
        else
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(
              child: Text('No data available'),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildEmployeeAttendanceWithCount(Result data) {
    final records = data.records ?? [];

    // Remove duplicate records
    final Map<String, AttendanceRecord> uniqueRecords = {};
    for (var record in records) {
      final key = '${record.date}_${record.checkIn}';
      if (!uniqueRecords.containsKey(key)) {
        uniqueRecords[key] = record;
      }
    }

    final uniqueRecordsList = uniqueRecords.values.toList();

    return Column(
      children: [
        // Employee header with count
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFE6E6E6),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              _EmployeeAvatar(
                size: 38,
                imageUrl: data.employeeImageUrl ?? "",
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  data.employeeName ?? "",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              Text(
                '${data.totalPresentDays ?? 0}/${data.totalWorkingDays ?? 0}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Attendance records
        ...uniqueRecordsList.map((record) {
          // Weekend records — render special card
          if (record.status?.toLowerCase() == 'weekend') {
            final DateTime? recordDate = DateTime.tryParse(record.date);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildWeekendCard(recordDate),
            );
          }

          final DateTime? checkInTime = DateTime.tryParse(record.checkIn);
          if (checkInTime == null) return const SizedBox.shrink();
          DateTime? checkOutTime;
          if (record.checkOut != null && record.checkOut != false) {
            checkOutTime = DateTime.tryParse(record.checkOut!);
          }

          String status = 'ONTIME';

          if (checkOutTime == null) {
            status = 'ABSENT';
          } else if (checkInTime.isAfter(DateTime(
              checkInTime.year, checkInTime.month, checkInTime.day, 8, 15))) {
            final lateMinutes = checkInTime
                .difference(DateTime(checkInTime.year, checkInTime.month,
                    checkInTime.day, 8, 15))
                .inMinutes;
            status = '$lateMinutes MINS LATE';
          }

          final textColor = _colorForRecord(record, computedStatus: status);
          final cardKey = 'emp_${record.date}_${record.checkIn}';

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildInteractiveAttendanceRecordCard(
              cardKey: cardKey,
              status: status,
              textColor: textColor,
              checkInTime: checkInTime,
              checkOutTime: checkOutTime,
              actionTitle: _actionTitleForRecord(record),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildWeekendCard(DateTime? date) {
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        // Green left accent bar
        Container(
          width: 50,
          height: 55,
          margin: const EdgeInsets.only(top: 2, left: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF009859),
            borderRadius: BorderRadius.circular(23),
          ),
        ),
        // Main card
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          margin: const EdgeInsets.only(left: 7, top: 2),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFD6D6D6), Color(0xFFADB2BD)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(23),
          ),
          child: Row(
            children: [
              // Date
              SizedBox(
                width: 80,
                child: Text(
                  date != null
                      ? DateFormat('dd MMM yy').format(date).toUpperCase()
                      : '--',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: appFontColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const SizedBox(
                height: 40,
                child: VerticalDivider(color: Colors.grey, thickness: 1),
              ),
              // Weekend label
              Expanded(
                child: Center(
                  child: Text(
                    'W e e k e n d',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      color: appFontColor,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonthPickerDialog extends StatefulWidget {
  final int? selectedMonth;
  final int currentYear;

  const _MonthPickerDialog({
    required this.selectedMonth,
    required this.currentYear,
  });

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int? _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.selectedMonth;
  }

  @override
  Widget build(BuildContext context) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sept',
      'Oct',
      'Nov',
      'Dec'
    ];

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      backgroundColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Yearly Calendar ${widget.currentYear}',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF9AA0A6),
              ),
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final monthNumber = index + 1;
                final isSelected = _selectedMonth == monthNumber;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedMonth = monthNumber;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          isSelected ? const Color(0xFF757575) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE0E0E0),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      months[index],
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(_selectedMonth);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF757575),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  'Done',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _MonthChip({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.15 * 255).toInt()),
              blurRadius: 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: appFontColor,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down, size: 16),
          ],
        ),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final VoidCallback? onSearch;

  const _SearchBox({
    required this.controller,
    required this.hintText,
    this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onSubmitted: (_) => onSearch?.call(),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search, size: 20),
        hintText: hintText,
        hintStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF5A5A5A),
        ),
        filled: true,
        fillColor: const Color(0xFFF3F3F3),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _EmployeeAvatar extends StatelessWidget {
  final double size;
  final String imageUrl;
  final bool withShadow;

  const _EmployeeAvatar({
    required this.size,
    required this.imageUrl,
    this.withShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFFBDBDBD), width: 1),
      boxShadow: withShadow
          ? [
              BoxShadow(
                color: Colors.black.withAlpha((0.12 * 255).toInt()),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ]
          : null,
    );

    Widget image;
    if (imageUrl.trim().isNotEmpty) {
      image = Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset('assets/png/profile_1.png', fit: BoxFit.cover);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(color: const Color(0xFFE6E6E6));
        },
      );
    } else {
      image = Image.asset('assets/png/profile_1.png', fit: BoxFit.cover);
    }

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: decoration,
      child: ClipOval(child: image),
    );
  }
}
