import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:el_race/ui/presentation/tasks_dashboard/services/task_options_api_service.dart';
import 'package:el_race/ui/presentation/tasks_dashboard/services/teams_api_service.dart';
import 'package:el_race/ui/presentation/tasks_dashboard/models/team_model.dart';
import 'package:el_race/ui/presentation/todo_list/services/team_members_api_service.dart';
import 'package:el_race/ui/presentation/todo_list/data/todo_model.dart';
import 'package:el_race/ui/presentation/todo_list/data/task_member_model.dart';
import 'package:el_race/ui/presentation/todo_list/services/todo_firebase_service.dart';
import 'package:el_race/data/services/task_notification_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:el_race/report_module/data/provider/reports_provider.dart';
import 'package:el_race/report_module/data/models/folder_model.dart';
import 'package:el_race/report_module/data/models/report_model.dart';
import 'package:el_race/core/utils/shared_pref.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({Key? key}) : super(key: key);

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  double _daysValue = 5;
  late TextEditingController _daysController;
  late TextEditingController _descriptionController;
  late TextEditingController _titleController;

  // Dates
  DateTime _startDate = DateTime.now();

  DateTime get _endDate => _startDate.add(Duration(days: _daysValue.toInt()));

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date).toUpperCase();
  }

  // Projects from backend
  List<ProjectOption> _projects = [];
  ProjectOption? _selectedProject;
  bool _isLoadingProjects = true;

  // Departments from backend (teams API)
  List<String> _departments = [];
  String? _selectedDepartment;
  bool _isLoadingDepartments = true;

  // Team members from backend
  List<TeamMember> _allMembers = [];
  List<TeamMember> _selectedMembers = [];
  List<TeamMember> _selectedFollowers = [];
  bool _isLoadingMembers = true;

  // Attachments
  List<File> _attachments = [];
  final ImagePicker _imagePicker = ImagePicker();

  // Linked Report (optional)
  List<FolderModel> _folders = [];
  List<ReportModel> _reportsForSelectedFolder = [];
  FolderModel? _selectedFolder;
  ReportModel? _selectedReport;
  bool _isLoadingFolders = true;
  bool _isLoadingReports = false;

  // Submit state
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _daysController =
        TextEditingController(text: _daysValue.toInt().toString());
    _descriptionController = TextEditingController();
    _titleController = TextEditingController();
    _loadData();
  }

  Future<void> _loadData() async {
    // Load projects, departments, and members in parallel
    final results = await Future.wait([
      TaskOptionsApiService.getProjects(),
      TeamsApiService.getUniqueDepartments(),
      TeamMembersApiService.instance.getTeamMembers(forceRefresh: true),
    ]);

    if (mounted) {
      setState(() {
        _projects = results[0] as List<ProjectOption>;
        _departments = results[1] as List<String>;
        _allMembers = results[2] as List<TeamMember>;
        _isLoadingProjects = false;
        _isLoadingDepartments = false;
        _isLoadingMembers = false;

        // Don't set default selections - let user choose
      });
    }

    // Load folders for report linking
    await _loadFolders();
  }

  Future<void> _loadFolders() async {
    try {
      final reportsProvider =
          Provider.of<ReportProvider>(context, listen: false);

      // Initialize provider if not already initialized
      final loginData = SharedPref.getLoginDataOrNull();
      if (loginData != null) {
        final baseUrl =
            loginData.result?.data?.webBaseUrl ?? 'https://erp.elrace.com';
        await reportsProvider.init(base: baseUrl);
      }

      await reportsProvider.fetchAllFolders();

      if (mounted) {
        setState(() {
          _folders = reportsProvider.folders;
          _isLoadingFolders = false;
        });
      }
    } catch (e) {
      print('❌ Error loading folders: $e');
      if (mounted) {
        setState(() {
          _isLoadingFolders = false;
        });
      }
    }
  }

  Future<void> _loadReportsForFolder(String folderId) async {
    setState(() {
      _isLoadingReports = true;
      _selectedReport = null;
      _reportsForSelectedFolder = [];
    });

    try {
      final reportsProvider =
          Provider.of<ReportProvider>(context, listen: false);
      await reportsProvider.fetchAllReports(folderID: folderId);

      if (mounted) {
        setState(() {
          _reportsForSelectedFolder = reportsProvider.reports;
          _isLoadingReports = false;
        });
      }
    } catch (e) {
      print('❌ Error loading reports: $e');
      if (mounted) {
        setState(() {
          _isLoadingReports = false;
        });
      }
    }
  }

  Future<void> _submitTask() async {
    // Validate title
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a task title',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Get assigned member names (for backward compatibility)
      String? assignedToName;
      if (_selectedMembers.isNotEmpty) {
        assignedToName = _selectedMembers.map((m) => m.name).join(', ');
      }

      // Convert to TaskMember list for progress tracking
      List<TaskMember>? assignedMembers;
      if (_selectedMembers.isNotEmpty) {
        assignedMembers = _selectedMembers
            .map((m) {
              // Prefer explicit employee_id; fallback to id
              final empId = (m.employeeId != null && m.employeeId! > 0)
                  ? m.employeeId.toString()
                  : m.id.toString();
              // odooUserId = res.users ID; used to build "odoo_{id}" firebase_uid format
              final oUserId = (m.odooUserId != null && m.odooUserId! > 0)
                  ? m.odooUserId.toString()
                  : null;
              print('📋 [TaskAssign] Assigning to: ${m.name} | employeeId=$empId | odooUserId=$oUserId');
              return TaskMember(
                name: m.name,
                odooId: empId,
                userId: oUserId,
                isCompleted: false,
              );
            })
            .toList();
      }

      // Get follower names (for backward compatibility)
      List<String>? followers;
      if (_selectedFollowers.isNotEmpty) {
        followers = _selectedFollowers.map((m) => m.name).toList();
      }

      // Convert followers to TaskMember list
      List<TaskMember>? followedUpBy;
      if (_selectedFollowers.isNotEmpty) {
        followedUpBy = _selectedFollowers
            .map((m) => TaskMember(
                  name: m.name,
                  odooId: (m.employeeId != null && m.employeeId! > 0)
                      ? m.employeeId.toString()
                      : m.id.toString(),
                  userId: (m.odooUserId != null && m.odooUserId! > 0)
                      ? m.odooUserId.toString()
                      : null,
                  isCompleted: false,
                ))
            .toList();
      }

      // Get linked report ID if selected
      String? linkedReportId;
      if (_selectedReport != null) {
        linkedReportId = _selectedReport!.id;
      }

      // Create the todo model
      final todo = TodoModel(
        title: title,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        department: _selectedDepartment,
        startDate: _startDate,
        dueDate: _endDate,
        assignedToName: assignedToName,
        assignedMembers: assignedMembers,
        followers: followers,
        followedUpBy: followedUpBy,
        reportId: linkedReportId,
        isCompleted: false,
        isImportant: false,
        isMyDay: false,
        sortOrder: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save to Firebase
      final docId = await TodoFirebaseService.instance.insertTodo(todo);

      if (_attachments.isNotEmpty) {
        await TodoFirebaseService.instance.uploadTaskAttachments(
          todoId: docId,
          todo: todo.copyWith(firebaseId: docId),
          files: List<File>.from(_attachments),
        );
      }

      // ── Fire task notifications ──
      try {
        final notifService = TaskNotificationService();
        final currentUserName =
            SharedPref.getLoginData().result?.data?.name ?? '';

        // Notify each assigned member
        if (assignedMembers != null) {
          for (final member in assignedMembers) {
            // Skip self-assignment notification
            if (member.name.toLowerCase() ==
                currentUserName.toLowerCase()) {
              continue;
            }
            await notifService.showNewTaskNotification(
              taskId: docId,
              taskTitle: title,
              assignedBy: currentUserName,
            );
          }
        }

        // Schedule deadline reminders if due date is set
        if (_endDate != null) {
          await notifService.scheduleDeadlineReminders(
            taskId: docId,
            taskTitle: title,
            dueDate: _endDate!,
          );
        }
      } catch (e) {
        debugPrint('⚠️ Task notification error (non-blocking): $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Task created successfully!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to previous screen
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      print('❌ Error submitting task: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to create task: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _daysController.dispose();
    _descriptionController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const HeaderWidget(),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(20.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      "assets/png/Tasks.svg",
                      height: 24.w,
                      width: 24.w,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'ADD TASK',
                      style: GoogleFonts.poppins(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w500,
                        color: appFontColor,
                      ),
                      overflow: TextOverflow.visible,
                    ),
                  ],
                ),
                const SizedBox(height: 5),

                // Task Title
                _buildBorderedFieldWithLabel(
                  label: 'Task\nTitle',
                  child: _buildTextField(
                      hint: 'Enter task title', controller: _titleController),
                ),
                const SizedBox(height: 20),

                // Project Name
                _buildBorderedFieldWithLabel(
                  label: 'Project\nName',
                  child: _isLoadingProjects
                      ? _buildDropdownShimmer()
                      : _buildProjectDropdown(),
                ),
                const SizedBox(height: 20),

                // Task Department
                _buildBorderedFieldWithLabel(
                  label: 'Task\nDepartment',
                  child: _isLoadingDepartments
                      ? _buildDropdownShimmer()
                      : _buildDepartmentDropdown(),
                ),
                const SizedBox(height: 20),

                // Add Member
                _buildSectionLabel('Add Member'),
                const SizedBox(height: 12),
                _buildMembersSection(
                  selectedMembers: _selectedMembers,
                  onAdd: () => _showMemberPicker(isFollower: false),
                  onRemove: (member) {
                    setState(() => _selectedMembers.remove(member));
                  },
                ),
                const SizedBox(height: 20),

                // Linked Report (Optional)
                _buildBorderedFieldWithLabel(
                  label: 'Linked Report\n(Optional)',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Folder Selection
                      _isLoadingFolders
                          ? _buildDropdownShimmer()
                          : _buildFolderDropdown(),
                      if (_selectedFolder != null) ...[
                        const SizedBox(height: 12),
                        // Report Selection
                        _isLoadingReports
                            ? _buildDropdownShimmer()
                            : _buildReportDropdown(),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Description
                _buildDescriptionSection(),
                const SizedBox(height: 20),

                // Days Section with Dates
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Days TextField
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Days',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 120,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Color(0xFFD0D0D0), width: 1.5),
                          ),
                          child: Center(
                            child: TextField(
                              controller: _daysController,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(2),
                              ],
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.only(bottom: 4),
                              ),
                              onChanged: (value) {
                                if (value.isNotEmpty) {
                                  setState(() {
                                    _daysValue = double.tryParse(value) ?? 5;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Start Date
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => _startDate = picked);
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'START DATE',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(_startDate),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Divider
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey[300],
                    ),

                    // End Date
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'END DATE',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(_endDate),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Following By
                _buildSectionLabel('Following By'),
                const SizedBox(height: 12),
                _buildMembersSection(
                  selectedMembers: _selectedFollowers,
                  onAdd: () => _showMemberPicker(isFollower: true),
                  onRemove: (member) {
                    setState(() => _selectedFollowers.remove(member));
                  },
                ),
                const SizedBox(height: 20),

                // Attachments
                _buildSectionLabel('Attachments'),
                const SizedBox(height: 12),
                _buildAttachmentsSection(),
                const SizedBox(height: 50),

                // Submit Button
                Center(
                  child: Container(
                    width: 220,
                    height: 55,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8BC6EC), Color(0xFF9599E2)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8BC6EC).withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitTask,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'SUBMIT TASK',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    final parts = label.split('\n');

    if (parts.length > 1) {
      // Two-line label (first line gray, second line black bold)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            parts[0],
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          Text(
            parts[1],
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      );
    } else {
      // Single-line label (black bold)
      return Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      );
    }
  }

  Widget _buildBorderedFieldWithLabel(
      {required String label, required Widget child}) {
    final parts = label.split('\n');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (parts.length > 1) ...[
            Text(
              parts[0],
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[500],
              ),
            ),
            Text(
              parts[1],
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ] else ...[
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField(
      {String hint = '', int maxLines = 1, TextEditingController? controller}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[400],
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        style: GoogleFonts.poppins(fontSize: 14),
      ),
    );
  }

  Widget _buildLabeledInputField({required String label, String hint = ''}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: TextField(
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[400],
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectDropdown() {
    if (_projects.isEmpty) {
      return Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Center(
          child: Text(
            'No projects available',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[400]),
          ),
        ),
      );
    }

    return DropdownButtonHideUnderline(
      child: DropdownButton2<ProjectOption>(
        value: _selectedProject,
        hint: Text(
          'Choose a project...',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[400],
          ),
        ),
        isExpanded: true,
        items: _projects.map((ProjectOption project) {
          return DropdownMenuItem<ProjectOption>(
            value: project,
            child: Text(
              project.name,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              overflow: TextOverflow.visible,
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedProject = value;
          });
        },
        buttonStyleData: ButtonStyleData(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
        ),
        iconStyleData: const IconStyleData(
          icon: Icon(Icons.keyboard_arrow_down),
          iconSize: 24,
          iconEnabledColor: Colors.black54,
        ),
        dropdownStyleData: DropdownStyleData(
          maxHeight: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          offset: const Offset(0, -5),
          scrollbarTheme: ScrollbarThemeData(
            radius: const Radius.circular(40),
            thickness: WidgetStateProperty.all(6),
            thumbVisibility: WidgetStateProperty.all(true),
          ),
        ),
        menuItemStyleData: const MenuItemStyleData(
          height: 48,
          padding: EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildDepartmentDropdown() {
    if (_departments.isEmpty) {
      return Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Center(
          child: Text(
            'No departments available',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[400]),
          ),
        ),
      );
    }

    return DropdownButtonHideUnderline(
      child: DropdownButton2<String>(
        value: _selectedDepartment,
        hint: Text(
          'Choose a department...',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[400],
          ),
        ),
        isExpanded: true,
        items: _departments.map((String dept) {
          return DropdownMenuItem<String>(
            value: dept,
            child: Text(
              dept,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              overflow: TextOverflow.visible,
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedDepartment = value;
          });
        },
        buttonStyleData: ButtonStyleData(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
        ),
        iconStyleData: const IconStyleData(
          icon: Icon(Icons.keyboard_arrow_down),
          iconSize: 24,
          iconEnabledColor: Colors.black54,
        ),
        dropdownStyleData: DropdownStyleData(
          maxHeight: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          offset: const Offset(0, -5),
          scrollbarTheme: ScrollbarThemeData(
            radius: const Radius.circular(40),
            thickness: WidgetStateProperty.all(6),
            thumbVisibility: WidgetStateProperty.all(true),
          ),
        ),
        menuItemStyleData: const MenuItemStyleData(
          height: 48,
          padding: EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildFolderDropdown() {
    if (_folders.isEmpty) {
      return Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Center(
          child: Text(
            'No projects available',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[400]),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Project',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonHideUnderline(
          child: DropdownButton2<FolderModel>(
            value: _selectedFolder,
            hint: Text(
              'Choose a project...',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[400]),
            ),
            isExpanded: true,
            items: _folders.map((FolderModel folder) {
              return DropdownMenuItem<FolderModel>(
                value: folder,
                child: Text(
                  folder.name,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.visible,
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedFolder = value;
                _selectedReport = null;
                _reportsForSelectedFolder = [];
              });
              if (value != null) {
                _loadReportsForFolder(value.id);
              }
            },
            buttonStyleData: ButtonStyleData(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
            ),
            iconStyleData: const IconStyleData(
              icon: Icon(Icons.keyboard_arrow_down),
              iconSize: 24,
              iconEnabledColor: Colors.black54,
            ),
            dropdownStyleData: DropdownStyleData(
              maxHeight: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              offset: const Offset(0, -5),
              scrollbarTheme: ScrollbarThemeData(
                radius: const Radius.circular(40),
                thickness: WidgetStateProperty.all(6),
                thumbVisibility: WidgetStateProperty.all(true),
              ),
            ),
            menuItemStyleData: const MenuItemStyleData(
              height: 48,
              padding: EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportDropdown() {
    if (_reportsForSelectedFolder.isEmpty) {
      return Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Center(
          child: Text(
            'No reports in this project',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[400]),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Report',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonHideUnderline(
          child: DropdownButton2<ReportModel>(
            value: _selectedReport,
            hint: Text(
              'Choose a report...',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[400]),
            ),
            isExpanded: true,
            items: _reportsForSelectedFolder.map((ReportModel report) {
              return DropdownMenuItem<ReportModel>(
                value: report,
                child: Row(
                  children: [
                    Icon(Icons.description_outlined,
                        size: 18, color: Colors.grey[500]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        report.name,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedReport = value;
              });
            },
            buttonStyleData: ButtonStyleData(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
            ),
            iconStyleData: const IconStyleData(
              icon: Icon(Icons.keyboard_arrow_down),
              iconSize: 24,
              iconEnabledColor: Colors.black54,
            ),
            dropdownStyleData: DropdownStyleData(
              maxHeight: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              offset: const Offset(0, -5),
              scrollbarTheme: ScrollbarThemeData(
                radius: const Radius.circular(40),
                thickness: WidgetStateProperty.all(6),
                thumbVisibility: WidgetStateProperty.all(true),
              ),
            ),
            menuItemStyleData: const MenuItemStyleData(
              height: 48,
              padding: EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
        if (_selectedReport != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.link, size: 16, color: Colors.green[600]),
                const SizedBox(width: 4),
                Text(
                  'Task will be linked to this report',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.green[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonHideUnderline(
      child: DropdownButton2<String>(
        value: value,
        isExpanded: true,
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(
              item,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          );
        }).toList(),
        onChanged: onChanged,
        buttonStyleData: ButtonStyleData(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
        ),
        iconStyleData: const IconStyleData(
          icon: Icon(Icons.keyboard_arrow_down),
          iconSize: 24,
          iconEnabledColor: Colors.black54,
        ),
        dropdownStyleData: DropdownStyleData(
          maxHeight: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          offset: const Offset(0, -5),
          scrollbarTheme: ScrollbarThemeData(
            radius: const Radius.circular(40),
            thickness: WidgetStateProperty.all(6),
            thumbVisibility: WidgetStateProperty.all(true),
          ),
        ),
        menuItemStyleData: MenuItemStyleData(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return Column(
      children: [
        DottedBorder(
          borderType: BorderType.Circle,
          color: Colors.black,
          strokeWidth: 2,
          dashPattern: [6, 4],
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Icon(Icons.add, size: 25, color: Colors.black),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Add',
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  /*   Text(
              'Add',
              style: GoogleFonts.poppins(
                fontSize: 8,
                color: Colors.black
              ),
            ),*/

  Widget _buildMemberAvatar(String name, String imagePath) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey[300]!, width: 2),
            image: DecorationImage(
              image: AssetImage(imagePath),
              fit: BoxFit.cover,
              onError: (exception, stackTrace) {},
            ),
            color: Colors.grey[200],
          ),
          child: imagePath.isEmpty
              ? Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  /// Build members section with add button and selected members
  Widget _buildMembersSection({
    required List<TeamMember> selectedMembers,
    required VoidCallback onAdd,
    required Function(TeamMember) onRemove,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Add button
          if (_isLoadingMembers)
            Row(
              children: List.generate(
                3,
                (index) => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      _ShimmerWidget(
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _ShimmerWidget(
                        child: Container(
                          width: 30,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            GestureDetector(
              onTap: onAdd,
              child: Column(
                children: [
                  DottedBorder(
                    borderType: BorderType.Circle,
                    color: Colors.black,
                    strokeWidth: 2,
                    dashPattern: const [6, 4],
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child:
                          const Icon(Icons.add, size: 25, color: Colors.black),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Selected members
            ...selectedMembers.map((member) => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildSelectedMemberAvatar(member, onRemove),
                )),
          ],
        ],
      ),
    );
  }

  /// Build avatar for a selected member with remove option
  Widget _buildSelectedMemberAvatar(
      TeamMember member, Function(TeamMember) onRemove) {
    final imageProvider = _memberImageProvider(member.image);
    final displayName = _memberDisplayName(member.name);

    return GestureDetector(
      onLongPress: () => onRemove(member),
      child: Stack(
        children: [
          // Avatar with image or initials
          imageProvider != null
              ? Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[300]!, width: 2),
                    image: DecorationImage(
                      image: imageProvider,
                      fit: BoxFit.cover,
                      onError: (_, __) {},
                    ),
                  ),
                )
              : Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[300]!, width: 2),
                    color: const Color(0xFF1A1A53).withOpacity(0.1),
                  ),
                  child: Center(
                    child: Text(
                      displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1A53),
                      ),
                    ),
                  ),
                ),
          Positioned(
            right: 0,
            top: 0,
            child: GestureDetector(
              onTap: () => onRemove(member),
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                ),
                child: const Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _memberDisplayName(String rawName) {
    final cleaned = rawName
        .replaceFirst(RegExp(r'^\s*\d+\s*[-:|#]*\s*'), '')
        .trim();
    final parts = cleaned.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return rawName.trim();
    if (parts.length == 1) return parts.first;
    return '${parts[0]} ${parts[1]}';
  }

  ImageProvider? _memberImageProvider(String? rawImage) {
    if (rawImage == null) return null;
    final value = rawImage.trim();
    if (value.isEmpty) return null;

    if (value.startsWith('data:image')) {
      final commaIndex = value.indexOf(',');
      if (commaIndex == -1) return null;
      final base64Part = value.substring(commaIndex + 1).trim();
      final bytes = _decodeBase64Safe(base64Part);
      if (bytes != null) return MemoryImage(bytes);
      return null;
    }

    if (_looksLikeBase64(value)) {
      final bytes = _decodeBase64Safe(value);
      if (bytes != null) return MemoryImage(bytes);
      return null;
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return NetworkImage(value);
    }

    if (value.startsWith('//')) {
      return NetworkImage('https:$value');
    }

    if (value.startsWith('/')) {
      return NetworkImage('https://erp.elrace.com$value');
    }

    return NetworkImage('https://erp.elrace.com/$value');
  }

  Uint8List? _decodeBase64Safe(String value) {
    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
  }

  bool _looksLikeBase64(String value) {
    if (value.length < 64) return false;
    if (value.contains(' ')) return false;
    final normalized = value.replaceAll('\n', '').replaceAll('\r', '');
    return RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(normalized);
  }

  /// Show member picker bottom sheet
  void _showMemberPicker({required bool isFollower}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MemberPickerSheet(
        members: _allMembers,
        selectedMembers: isFollower ? _selectedFollowers : _selectedMembers,
        onMemberSelected: (member) {
          setState(() {
            if (isFollower) {
              if (!_selectedFollowers.any((m) => m.id == member.id)) {
                _selectedFollowers.add(member);
              }
            } else {
              if (!_selectedMembers.any((m) => m.id == member.id)) {
                _selectedMembers.add(member);
              }
            }
          });
        },
      ),
    );
  }

  /// Build attachments section
  Widget _buildAttachmentsSection() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Add button
          GestureDetector(
            onTap: _pickAttachment,
            child: Column(
              children: [
                DottedBorder(
                  borderType: BorderType.Circle,
                  color: Colors.black,
                  strokeWidth: 2,
                  dashPattern: const [6, 4],
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: const Icon(Icons.add, size: 25, color: Colors.black),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Attachments
          ..._attachments.asMap().entries.map((entry) {
            final index = entry.key;
            final file = entry.value;
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _buildAttachmentPreview(file, index),
            );
          }),
        ],
      ),
    );
  }

  /// Build attachment preview
  Widget _buildAttachmentPreview(File file, int index) {
    final extension = file.path.split('.').last.toLowerCase();
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension);
    final isPdf = extension == 'pdf';

    return Stack(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
            color: isPdf ? Colors.red.withOpacity(0.1) : Colors.grey[100],
          ),
          child: isImage
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(file, fit: BoxFit.cover),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file,
                      color: isPdf ? Colors.red : Colors.grey[600],
                      size: 24,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      extension.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: isPdf ? Colors.red : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: GestureDetector(
            onTap: () {
              setState(() => _attachments.removeAt(index));
            },
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
              ),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  /// Pick attachment (image or file)
  Future<void> _pickAttachment() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Add Attachment',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library, color: Colors.blue),
              ),
              title: Text('Pick from Gallery', style: GoogleFonts.poppins()),
              subtitle: Text('Select images from your gallery',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _imagePicker.pickImage(
                  source: ImageSource.gallery,
                );
                if (image != null) {
                  setState(() => _attachments.add(File(image.path)));
                }
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.green),
              ),
              title: Text('Take Photo', style: GoogleFonts.poppins()),
              subtitle: Text('Capture a new photo',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _imagePicker.pickImage(
                  source: ImageSource.camera,
                );
                if (image != null) {
                  setState(() => _attachments.add(File(image.path)));
                }
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.picture_as_pdf, color: Colors.red),
              ),
              title: Text('Pick PDF File', style: GoogleFonts.poppins()),
              subtitle: Text('Select a PDF document',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
              onTap: () async {
                Navigator.pop(context);
                final result = await FilePicker.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf'],
                );
                if (result != null && result.files.single.path != null) {
                  setState(
                      () => _attachments.add(File(result.files.single.path!)));
                }
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.folder_open, color: Colors.orange),
              ),
              title: Text('Pick Any File', style: GoogleFonts.poppins()),
              subtitle: Text('Select any document',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
              onTap: () async {
                Navigator.pop(context);
                final result = await FilePicker.pickFiles();
                if (result != null && result.files.single.path != null) {
                  setState(
                      () => _attachments.add(File(result.files.single.path!)));
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDateLabel(String label, String date, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          date,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with label and icons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Description',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              Row(
                children: [
                  _buildParagraphIconButton(_formatAlignLeft),
                  const SizedBox(width: 8),
                  _buildIconButton(
                      Icons.format_list_bulleted, _formatBulletList),
                  const SizedBox(width: 8),
                  _buildIconButton(
                      Icons.format_list_numbered, _formatNumberedList),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Text field
          TextField(
            controller: _descriptionController,
            maxLines: 5,
            onChanged: _handleDescriptionChange,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'Write your description...',
              hintStyle: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[400],
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Icon(
          icon,
          size: 18,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildParagraphIconButton(VoidCallback onTap) {
    return SizedBox(
      width: 34,
      height: 28,
      child: Material(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Image.asset('assets/png/paragraphIcon.png',
                fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  void _formatAlignLeft() {
    // Format text alignment - for now just showing the action
    setState(() {});
  }

  void _handleDescriptionChange(String value) {
    // Auto-add bullet point when pressing Enter after a bulleted line
    if (value.endsWith('\n')) {
      final lines = value.split('\n');
      if (lines.length >= 2) {
        final previousLine = lines[lines.length - 2].trim();

        // Check if previous line starts with bullet point
        if (previousLine.startsWith('• ')) {
          final newText = value + '• ';
          _descriptionController.value = TextEditingValue(
            text: newText,
            selection: TextSelection.fromPosition(
              TextPosition(offset: newText.length),
            ),
          );
          return;
        }

        // Check if previous line starts with number
        final numberMatch = RegExp(r'^(\d+)\.\s').firstMatch(previousLine);
        if (numberMatch != null) {
          final nextNumber = int.parse(numberMatch.group(1)!) + 1;
          final newText = value + '$nextNumber. ';
          _descriptionController.value = TextEditingValue(
            text: newText,
            selection: TextSelection.fromPosition(
              TextPosition(offset: newText.length),
            ),
          );
          return;
        }
      }
    }
  }

  /// Shimmer effect for dropdown loading
  Widget _buildDropdownShimmer() {
    return _ShimmerWidget(
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Simple shimmer box with animation
  Widget _buildShimmerBox({
    double? width,
    double height = 14,
    double borderRadius = 4,
  }) {
    return _ShimmerWidget(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  /// Shimmer for member avatar loading
  Widget _buildMemberAvatarShimmer() {
    return Row(
      children: List.generate(
        3,
        (index) => Padding(
          padding: EdgeInsets.only(right: 8.w),
          child: _ShimmerWidget(
            child: Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _formatBulletList() {
    final text = _descriptionController.text;
    if (text.isEmpty) return;

    final lines = text.split('\n');
    final formattedLines =
        lines.where((line) => line.trim().isNotEmpty).map((line) {
      final trimmed = line.trim();
      if (trimmed.startsWith('• ')) return trimmed;
      if (RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
        return '• ${trimmed.replaceFirst(RegExp(r'^\d+\.\s'), '')}';
      }
      return '• $trimmed';
    }).join('\n');

    _descriptionController.text = formattedLines;
    _descriptionController.selection = TextSelection.fromPosition(
      TextPosition(offset: formattedLines.length),
    );
  }

  void _formatNumberedList() {
    final text = _descriptionController.text;
    if (text.isEmpty) return;

    final lines = text.split('\n');
    int number = 1;
    final formattedLines =
        lines.where((line) => line.trim().isNotEmpty).map((line) {
      final trimmed = line.trim();
      if (trimmed.startsWith('• ')) {
        return '${number++}. ${trimmed.substring(2)}';
      }
      if (RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
        return '${number++}. ${trimmed.replaceFirst(RegExp(r'^\d+\.\s'), '')}';
      }
      return '${number++}. $trimmed';
    }).join('\n');

    _descriptionController.text = formattedLines;
    _descriptionController.selection = TextSelection.fromPosition(
      TextPosition(offset: formattedLines.length),
    );
  }
}

/// Bottom sheet for picking team members
class _MemberPickerSheet extends StatefulWidget {
  final List<TeamMember> members;
  final List<TeamMember> selectedMembers;
  final Function(TeamMember) onMemberSelected;

  const _MemberPickerSheet({
    required this.members,
    required this.selectedMembers,
    required this.onMemberSelected,
  });

  @override
  State<_MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _MemberPickerSheetState extends State<_MemberPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<TeamMember> _filteredMembers = [];

  @override
  void initState() {
    super.initState();
    _filteredMembers = widget.members;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterMembers(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredMembers = widget.members;
      } else {
        _filteredMembers = widget.members
            .where((m) {
              final displayName = _memberDisplayName(m.name).toLowerCase();
              final fullName = m.name.toLowerCase();
              final department = (m.department ?? '').toLowerCase();
              return displayName.contains(q) ||
                  fullName.contains(q) ||
                  department.contains(q);
            })
            .toList();
      }
    });
  }

  String _memberDisplayName(String rawName) {
    final cleaned = rawName
        .replaceFirst(RegExp(r'^\s*\d+\s*[-:|#]*\s*'), '')
        .trim();
    final parts = cleaned.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return rawName.trim();
    if (parts.length == 1) return parts.first;
    return '${parts[0]} ${parts[1]}';
  }

  ImageProvider? _memberImageProvider(String? rawImage) {
    if (rawImage == null) return null;
    final value = rawImage.trim();
    if (value.isEmpty) return null;

    if (value.startsWith('data:image')) {
      final commaIndex = value.indexOf(',');
      if (commaIndex == -1) return null;
      final base64Part = value.substring(commaIndex + 1).trim();
      final bytes = _decodeBase64Safe(base64Part);
      if (bytes != null) return MemoryImage(bytes);
      return null;
    }

    if (_looksLikeBase64(value)) {
      final bytes = _decodeBase64Safe(value);
      if (bytes != null) return MemoryImage(bytes);
      return null;
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return NetworkImage(value);
    }

    if (value.startsWith('//')) {
      return NetworkImage('https:$value');
    }

    if (value.startsWith('/')) {
      return NetworkImage('https://erp.elrace.com$value');
    }

    return NetworkImage('https://erp.elrace.com/$value');
  }

  Uint8List? _decodeBase64Safe(String value) {
    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
  }

  bool _looksLikeBase64(String value) {
    if (value.length < 64) return false;
    if (value.contains(' ')) return false;
    final normalized = value.replaceAll('\n', '').replaceAll('\r', '');
    return RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: 12.h),
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 16.h),
          // Title
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Team Member',
                  style: GoogleFonts.poppins(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A53),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Done',
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      color: const Color(0xFF1A1A53),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          // Search
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: TextField(
              controller: _searchController,
              onChanged: _filterMembers,
              decoration: InputDecoration(
                hintText: 'Search for member...',
                hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
                prefixIcon:
                    Icon(Icons.search, color: Colors.grey.shade400, size: 22.w),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF1A1A53),
                    width: 2,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 12.h),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          // Members list
          Expanded(
            child: _filteredMembers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 60.w,
                          color: Colors.grey.shade300,
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'No members found',
                          style: GoogleFonts.poppins(
                            fontSize: 16.sp,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    itemCount: _filteredMembers.length,
                    itemBuilder: (context, index) {
                      final member = _filteredMembers[index];
                      final isSelected =
                          widget.selectedMembers.any((m) => m.id == member.id);
                      final displayName = _memberDisplayName(member.name);
                      final imageProvider = _memberImageProvider(member.image);

                      return ListTile(
                        onTap: () {
                          widget.onMemberSelected(member);
                          setState(() {}); // Refresh to show selection
                        },
                        leading: imageProvider != null
                            ? CircleAvatar(
                                radius: 20.w,
                                backgroundColor:
                                    const Color(0xFF1A1A53).withOpacity(0.1),
                                backgroundImage: imageProvider,
                                onBackgroundImageError: (_, __) {},
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: isSelected
                                        ? Border.all(
                                            color: const Color(0xFF4CAF50),
                                            width: 2,
                                          )
                                        : null,
                                  ),
                                ),
                              )
                            : CircleAvatar(
                                radius: 20.w,
                                backgroundColor: isSelected
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFF1A1A53).withOpacity(0.1),
                                child: Text(
                                  displayName.isNotEmpty
                                      ? displayName[0].toUpperCase()
                                      : '?',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF1A1A53),
                                  ),
                                ),
                              ),
                        title: Text(
                          displayName,
                          style: GoogleFonts.poppins(
                            fontSize: 15.sp,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: const Color(0xFF1A1A53),
                          ),
                        ),
                        subtitle: member.department != null &&
                                member.department!.trim().isNotEmpty
                            ? Text(
                                member.department!.trim(),
                                style: GoogleFonts.poppins(
                                  fontSize: 12.sp,
                                  color: Colors.grey.shade600,
                                ),
                              )
                            : null,
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: const Color(0xFF4CAF50),
                                size: 24.w,
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer animation widget
class _ShimmerWidget extends StatefulWidget {
  final Widget child;

  const _ShimmerWidget({required this.child});

  @override
  State<_ShimmerWidget> createState() => _ShimmerWidgetState();
}

class _ShimmerWidgetState extends State<_ShimmerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Color(0xFFE0E0E0),
                Color(0xFFF5F5F5),
                Color(0xFFE0E0E0),
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}
