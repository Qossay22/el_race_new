import 'dart:convert';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/task_sheet/TaskDetailsPage.dart';
import 'package:el_race/ui/presentation/task_sheet/add_task_sheet.dart';
import 'package:el_race/ui/presentation/todo_list/services/team_members_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../widgets/header_widget.dart';

class TaskSheetPage extends StatefulWidget {
  const TaskSheetPage({
    super.key,
  });

  @override
  State<TaskSheetPage> createState() => _TaskSheetPageState();
}

class _TaskSheetPageState extends State<TaskSheetPage> {
  List<dynamic> tasks = [];
  List<String> _dropdownEmployees = [];
  bool isLoading = true;
  String? errorMessage;
  String? _selectedEmployee;

  @override
  void initState() {
    super.initState();
    fetchTasks();
    _fetchDropdownEmployees();
  }

  Future<void> _fetchDropdownEmployees() async {
    try {
      final members = await TeamMembersApiService.instance
          .getLaborListMembers(forceRefresh: true);
      if (!mounted) return;
      final names = members
          .map((m) => m.name.replaceFirst(RegExp(r'^\d+\s+'), '').trim())
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      debugPrint('👥 Dropdown employees from /employee/list: ${names.length}');
      setState(() => _dropdownEmployees = names);
    } catch (e) {
      debugPrint('❌ Failed to load dropdown employees: $e');
    }
  }

  Future<void> fetchTasks() async {
    final loginData = SharedPref.getLoginData();

    // Debug: Print ALL available user ID fields
    print('\n🔍 ===== TIME SHEET DEBUG =====');
    print('LoginData exists: ${loginData != null}');
    print('Result exists: ${loginData.result != null}');
    print('Data exists: ${loginData.result?.data != null}');
    print('\n📋 All User ID Fields:');
    print('  uid: ${loginData.result?.data?.uid}');
    print('  emp_id: ${loginData.result?.data?.emp_id}');
    print('  emp_profile_id: ${loginData.result?.data?.emp_profile_id}');
    print('  odoo_user_id: ${loginData.result?.data?.odoo_user_id}');
    print('  employee_id: ${loginData.result?.data?.employee_id}');
    print('  partnerId: ${loginData.result?.data?.partnerId}');
    print(
        '\n🔑 Token: ${loginData.result?.token != null ? 'exists (${loginData.result?.token?.length} chars)' : 'null'}');
    print('================================\n');

    // Try multiple user ID fields in order of preference
    final userId = loginData.result?.data?.odoo_user_id ??
        loginData.result?.data?.uid ??
        loginData.result?.data?.employee_id ??
        loginData.result?.data?.emp_id ??
        loginData.result?.data?.uid;
    final token = loginData.result?.token;

    if (userId == null || token == null) {
      setState(() {
        isLoading = false;
        errorMessage = "User ID or token is missing.\n"
            "UID: ${loginData.result?.data?.uid}\n"
            "odoo_user_id: ${loginData.result?.data?.odoo_user_id}\n"
            "employee_id: ${loginData.result?.data?.employee_id}\n"
            "Token: ${token != null ? 'exists' : 'null'}";
      });
      return;
    }

    final url = Uri.parse("https://erp.elrace.com/api/tasks/list");
    final headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };

    print('🎯 Task list user_id used: $userId');

    final body = jsonEncode({
      "jsonrpc": "2.0",
      "params": {
        "user_id": userId,
      }
    });

    debugPrint('\n📡 ===== TASK LIST API =====');
    debugPrint('URL: $url');
    debugPrint('METHOD: POST');
    debugPrint('HEADERS: {Content-Type: ${headers["Content-Type"]}, Authorization: Bearer ***}');
    debugPrint('BODY: $body');

    try {
      final response = await http.post(url, headers: headers, body: body);
      debugPrint('STATUS: ${response.statusCode}');
      debugPrint('RESPONSE: ${response.body}');
      debugPrint('===================================\n');
      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 && decoded["result"] != null) {
        final rawTasks = (decoded["result"]["tasks"] as List?) ?? [];
        final sortedTasks = _sortTasksNewestFirst(rawTasks);
        setState(() {
          tasks = sortedTasks;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = "Failed to load tasks.";
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Error: $e";
      });
    }
  }

  List<dynamic> _sortTasksNewestFirst(List<dynamic> items) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      final text = value.toString().trim();
      if (text.isEmpty) return null;
      return DateTime.tryParse(text.replaceFirst(' ', 'T'));
    }

    final sorted = List<dynamic>.from(items);
    sorted.sort((a, b) {
      if (a is! Map || b is! Map) return 0;

      final aDate = parseDate(a['date_time']) ??
          parseDate(a['create_date']) ??
          parseDate(a['write_date']) ??
          parseDate(a['created_at']) ??
          parseDate(a['date']);
      final bDate = parseDate(b['date_time']) ??
          parseDate(b['create_date']) ??
          parseDate(b['write_date']) ??
          parseDate(b['created_at']) ??
          parseDate(b['date']);

      if (aDate != null && bDate != null) {
        return bDate.compareTo(aDate);
      }

      final aId = int.tryParse((a['id'] ?? '').toString()) ?? 0;
      final bId = int.tryParse((b['id'] ?? '').toString()) ?? 0;
      return bId.compareTo(aId);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await fetchTasks();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: const HeaderWidget(),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 10.h),
                child: Column(
                  children: [
                    Center(
                      child: Text(
                        'TIME SHEET',
                        style: GoogleFonts.poppins(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    SizedBox(height: 18.h),
                    SizedBox(
                      width: double.infinity,
                      height: 40.h,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28.r),
                          border: Border.all(
                            color: const Color(0xFF9AA0A6),
                            width: 0.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28.r),
                          child: Stack(
                            children: [
                              // Base gradient
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
                              // Soft splash highlight (no sharp edge): top-right light green -> white fade
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(
                                        center: Alignment.topRight,
                                        radius: 1.25,
                                        colors: [
                                          Colors.white.withOpacity(0.92),
                                          Colors.white.withOpacity(0.65),
                                          Colors.white.withOpacity(0.0),
                                        ],
                                        stops: const [0.0, 0.42, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Tap area + label
                              Positioned.fill(
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () async {
                                      final createdResult =
                                          await Navigator.push<dynamic>(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const AddTaskSheet(),
                                        ),
                                      );

                                      final created = createdResult == true ||
                                          (createdResult is Map &&
                                              createdResult['created'] == true);

                                      if (createdResult is Map &&
                                          createdResult['task'] is Map &&
                                          mounted) {
                                        final optimisticTask =
                                            Map<String, dynamic>.from(
                                                createdResult['task'] as Map);
                                        setState(() {
                                          tasks = _sortTasksNewestFirst([
                                            optimisticTask,
                                            ...tasks,
                                          ]);
                                        });
                                      }

                                      if (created && mounted) {
                                        await fetchTasks();
                                        Future.delayed(
                                            const Duration(seconds: 2),
                                            () async {
                                          if (!mounted) return;
                                          await fetchTasks();
                                        });
                                      }
                                    },
                                    child: Center(
                                      child: Text(
                                        'Add a new request',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16.sp,
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
                      ),
                    ),
                    SizedBox(height: 12.h),
                    _EmployeeDropdown(
                      value: _selectedEmployee,
                      employees: _dropdownEmployees,
                      onChanged: (value) {
                        debugPrint('👤 Employee dropdown selected: $value');
                        setState(() {
                          _selectedEmployee = value;
                        });
                      },
                    ),
                    SizedBox(height: 8.h),
                  ],
                ),
              ),
            ),
            if (isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (errorMessage != null)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final filteredTasks =
                        _filterTasks(tasks, _selectedEmployee);
                    final task = filteredTasks[index];
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 8.h,
                        horizontal: 20.w,
                      ),
                      child: GestureDetector(
                        onTap: () {
                          final taskId = task['id'];
                          final isOptimistic = task['is_optimistic'] == true;
                          if (taskId == null || isOptimistic) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TaskDetailsPage(
                                loginResponseModel: SharedPref.getLoginData(),
                                taskId: task['id'],
                                project_id: task['project_id'],
                              ),
                            ),
                          );
                        },
                        child: _GreenTimesheetCard(task: task),
                      ),
                    );
                  },
                  childCount: _filterTasks(tasks, _selectedEmployee).length,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static List<dynamic> _filterTasks(List<dynamic> allTasks, String? employee) {
    if (employee == null || employee.trim().isEmpty) return allTasks;
    return allTasks.where((t) {
      final name = (t is Map ? (t['name'] ?? '') : '').toString();
      final employeeName =
          (t is Map ? (t['employee_name'] ?? '') : '').toString();
      final label = employeeName.isNotEmpty ? employeeName : name;
      return label.trim() == employee.trim();
    }).toList();
  }
}

class _EmployeeDropdown extends StatelessWidget {
  final String? value;
  final List<String> employees;
  final ValueChanged<String?> onChanged;

  const _EmployeeDropdown({
    required this.value,
    required this.employees,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = employees;
    return Container(
      width: double.infinity,
      height: 40.h,
      padding: EdgeInsets.symmetric(horizontal: 18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(
          color: const Color(0xFFBDBDBD),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton2<String>(
          isExpanded: true,
          value: options.contains(value) ? value : null,
          hint: Text(
            'Select an Employee',
            style: GoogleFonts.poppins(
              fontSize: 15.sp,
              fontWeight: FontWeight.w400,
              color: const Color(0xFFB0B0B0),
            ),
          ),
          items: options
              .map(
                (e) => DropdownMenuItem<String>(
                  value: e,
                  child: Text(
                    e,
                    style: GoogleFonts.poppins(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                    ),
                    maxLines: null,
                    overflow: TextOverflow.visible,
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          iconStyleData: IconStyleData(
            icon: Icon(
              Icons.keyboard_arrow_down,
              color: const Color(0xFFB0B0B0),
              size: 26.w,
            ),
          ),
          buttonStyleData: ButtonStyleData(
            height: 40.h,
            padding: EdgeInsets.zero,
            decoration: const BoxDecoration(color: Colors.transparent),
          ),
          dropdownStyleData: DropdownStyleData(
            elevation: 2,
            offset: Offset(0, 4.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: const Color(0xFFEEEEEE),
                width: 1,
              ),
            ),
          ),
          menuItemStyleData: MenuItemStyleData(
            height: 44.h,
            padding: EdgeInsets.symmetric(horizontal: 12.w),
          ),
        ),
      ),
    );
  }
}

class _GreenTimesheetCard extends StatelessWidget {
  final Map task;

  const _GreenTimesheetCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final employeeName =
        (task['employee_name'] ?? task['name'] ?? '').toString();
    final projectName = (task['project_name'] ?? '').toString();
    final clientName = (task['customer_name'] ?? '').toString();
    final imageUrl = (task['emp_image_url'] ??
            task['employee_image'] ??
            task['employee_image_url'] ??
            task['image'] ??
            '')
        .toString();

    return Container(
      constraints: BoxConstraints(minHeight: 120.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: const Color(0xFF8D8D8D),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        image: const DecorationImage(
          image: AssetImage('assets/newapp/tsbackground.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22.r),
        child: Stack(
          children: [
            Positioned(
              right: 10.w,
              top: 0,
              bottom: 0,
              child: Opacity(
                opacity: 0.28,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    'assets/png/tsIcon.png',
                    width: 150.w,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              child: Row(
                children: [
                  _Avatar(imageUrl: imageUrl),
                  SizedBox(width: 14.w),
                  Container(
                    width: 1,
                    height: 52.h,
                    color: const Color(0xFF7F7F7F),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          employeeName,
                          style: GoogleFonts.poppins(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                            height: 1.15,
                          ),
                          maxLines: null,
                          overflow: TextOverflow.visible,
                        ),
                        SizedBox(height: 8.h),
                        _LabelValue(
                          label: 'Project Name : ',
                          value: projectName,
                        ),
                        SizedBox(height: 4.h),
                        _LabelValue(
                          label: 'Client : ',
                          value: clientName,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabelValue extends StatelessWidget {
  final String label;
  final String value;

  const _LabelValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return RichText(
      maxLines: null,
      overflow: TextOverflow.visible,
      text: TextSpan(
        style: GoogleFonts.poppins(
          fontSize: 13.sp,
          color: const Color(0xFF6F6F6F),
          height: 1.2,
        ),
        children: [
          TextSpan(
            text: label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String imageUrl;

  const _Avatar({required this.imageUrl});

  String? _resolvedUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/')) {
      return 'https://erp.elrace.com$value';
    }
    return 'https://erp.elrace.com/$value';
  }

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = _resolvedUrl(imageUrl);
    final hasNetwork = resolvedUrl != null;
    return Container(
      width: 56.w,
      height: 56.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.black,
          width: 1.2,
        ),
        color: Colors.white,
      ),
      child: ClipOval(
        child: hasNetwork
            ? Image.network(
                resolvedUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, error, __) {
                  print(
                      '❌ TaskSheet avatar load failed: $resolvedUrl | error: $error');
                  return Icon(
                    Icons.person,
                    size: 28.w,
                    color: const Color(0xFF9E9E9E),
                  );
                },
              )
            : Icon(
                Icons.person,
                size: 28.w,
                color: const Color(0xFF9E9E9E),
              ),
      ),
    );
  }
}
