import 'package:el_race/report_module/data/models/report_detail_model.dart';
import 'package:el_race/report_module/data/services/report_hive_service.dart';
import 'package:el_race/report_module/presentation/screens/report_detail/report_detail.dart';
import 'package:el_race/ui/presentation/todo_list/data/todo_model.dart';
import 'package:el_race/ui/presentation/todo_list/providers/todo_firebase_provider.dart';
import 'package:el_race/ui/presentation/todo_list/services/team_members_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AddTodoBottomSheet extends StatefulWidget {
  final TodoFilter filter;
  final String? listId;
  final TodoModel? todo;

  const AddTodoBottomSheet({
    super.key,
    required this.filter,
    this.listId,
    this.todo,
  });

  @override
  State<AddTodoBottomSheet> createState() => _AddTodoBottomSheetState();
}

class _AddTodoBottomSheetState extends State<AddTodoBottomSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late bool _isImportant;
  late bool _isMyDay;
  DateTime? _dueDate;
  bool _isLoading = false;

  // Member assignment
  TeamMember? _selectedMember;
  List<TeamMember> _teamMembers = [];
  bool _isLoadingMembers = false;

  bool get isEditing => widget.todo != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.todo?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.todo?.description ?? '');
    _isImportant =
        widget.todo?.isImportant ?? widget.filter == TodoFilter.important;
    _isMyDay = widget.todo?.isMyDay ?? widget.filter == TodoFilter.myDay;
    _dueDate = widget.todo?.dueDate;

    // If coming from planned, set due date to today by default
    if (widget.filter == TodoFilter.planned && _dueDate == null && !isEditing) {
      _dueDate = DateTime.now();
    }

    // Load team members
    _loadTeamMembers();
  }

  Future<void> _loadTeamMembers() async {
    setState(() => _isLoadingMembers = true);
    try {
      _teamMembers = await TeamMembersApiService.instance.getTeamMembers();

      // If editing and has assigned member, find them
      if (widget.todo?.assignedTo != null) {
        final assignedId = int.tryParse(widget.todo!.assignedTo!);
        if (assignedId != null) {
          _selectedMember = _teamMembers.firstWhere(
            (m) => m.id == assignedId,
            orElse: () => TeamMember(
              id: assignedId,
              name: widget.todo!.assignedToName ?? 'Unknown',
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading team members: $e');
    }
    if (mounted) {
      setState(() => _isLoadingMembers = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              // Title
              Text(
                isEditing
                    ? translate('todo.edit_task')
                    : translate('todo.add_task'),
                style: GoogleFonts.poppins(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A53),
                ),
              ),
              SizedBox(height: 20.h),
              // Task title input
              TextField(
                controller: _titleController,
                autofocus: !isEditing,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: translate('todo.task_title_hint'),
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey.shade400,
                  ),
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
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 14.h,
                  ),
                ),
                style: GoogleFonts.poppins(
                  fontSize: 16.sp,
                  color: const Color(0xFF1A1A53),
                ),
              ),
              SizedBox(height: 16.h),
              // Description input
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Write your description...',
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey.shade400,
                  ),
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
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 14.h,
                  ),
                ),
                style: GoogleFonts.poppins(
                  fontSize: 14.sp,
                  color: Colors.grey.shade700,
                ),
              ),
              SizedBox(height: 20.h),
              // Options
              Wrap(
                spacing: 12.w,
                runSpacing: 12.h,
                children: [
                  // My Day Toggle
                  _buildOptionChip(
                    icon: Icons.wb_sunny_outlined,
                    label: translate('todo.my_day'),
                    isSelected: _isMyDay,
                    onTap: () => setState(() => _isMyDay = !_isMyDay),
                  ),
                  // Important Toggle
                  _buildOptionChip(
                    icon: Icons.star_border,
                    label: translate('todo.important'),
                    isSelected: _isImportant,
                    selectedColor: const Color(0xFFFFB800),
                    onTap: () => setState(() => _isImportant = !_isImportant),
                  ),
                  // Due Date
                  _buildOptionChip(
                    icon: Icons.calendar_today_outlined,
                    label: _dueDate != null
                        ? DateFormat('MMM d, yyyy').format(_dueDate!)
                        : translate('todo.due_date'),
                    isSelected: _dueDate != null,
                    onTap: _selectDueDate,
                    onLongPress: _dueDate != null
                        ? () => setState(() => _dueDate = null)
                        : null,
                  ),
                  // Assign to Member
                  _buildOptionChip(
                    icon: Icons.person_add_outlined,
                    label: _selectedMember != null
                        ? _selectedMember!.name
                        : translate('todo.assigned_to_me'),
                    isSelected: _selectedMember != null,
                    selectedColor: const Color(0xFF4CAF50),
                    onTap: _showMemberPicker,
                    onLongPress: _selectedMember != null
                        ? () => setState(() => _selectedMember = null)
                        : null,
                  ),
                ],
              ),

              // View Report Button (if task is linked to a report)
              if (widget.todo?.reportId != null) ...[
                SizedBox(height: 16.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A53).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF1A1A53).withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.link,
                            size: 16.sp,
                            color: const Color(0xFF1A1A53),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            'Linked to Report',
                            style: GoogleFonts.poppins(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A1A53),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _navigateToReport(context),
                          icon: Icon(Icons.description, size: 16.sp),
                          label: Text(
                            'View Report',
                            style: GoogleFonts.poppins(fontSize: 13.sp),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1A1A53),
                            side: BorderSide(
                              color: const Color(0xFF1A1A53).withOpacity(0.3),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 10.h),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: 24.h),
              // Action buttons
              Row(
                children: [
                  // Cancel button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        translate('common.cancel'),
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  // Save button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveTodo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1A53),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 20.w,
                              height: 20.w,
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              isEditing
                                  ? translate('common.save')
                                  : translate('todo.add_task'),
                              style: GoogleFonts.poppins(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              // Delete button (only for editing)
              if (isEditing) ...[
                SizedBox(height: 8.h),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: _deleteTodo,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: Text(
                      translate('common.delete'),
                      style: GoogleFonts.poppins(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionChip({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    Color selectedColor = const Color(0xFF2196F3),
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withOpacity(0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? selectedColor : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18.w,
              color: isSelected ? selectedColor : Colors.grey.shade600,
            ),
            SizedBox(width: 6.w),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: isSelected ? selectedColor : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1A1A53),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1A1A53),
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() => _dueDate = date);
    }
  }

  void _showMemberPicker() {
    if (_isLoadingMembers) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading members...')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MemberPickerSheet(
        members: _teamMembers,
        selectedMember: _selectedMember,
        onMemberSelected: (member) {
          setState(() => _selectedMember = member);
          Navigator.pop(context);
        },
        onClear: () {
          setState(() => _selectedMember = null);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _saveTodo() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(translate('todo.title_required')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final provider = context.read<TodoFirebaseProvider>();
    bool success;

    if (isEditing) {
      final updatedTodo = widget.todo!.copyWith(
        title: title,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        isImportant: _isImportant,
        isMyDay: _isMyDay,
        dueDate: _dueDate,
        assignedTo: _selectedMember?.id.toString(),
        assignedToName: _selectedMember?.name,
        updatedAt: DateTime.now(),
      );
      success = await provider.updateTodo(updatedTodo);
    } else {
      final newTodo = await provider.addTodo(
        title: title,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        isImportant: _isImportant,
        isMyDay: _isMyDay,
        dueDate: _dueDate,
        assignedTo: _selectedMember?.id.toString(),
        assignedToName: _selectedMember?.name,
        listId: widget.listId,
      );
      success = newTodo != null;
    }

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _deleteTodo() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(translate('todo.delete_task')),
        content: Text(translate('todo.delete_task_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(translate('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              translate('common.delete'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<TodoFirebaseProvider>().deleteTodo(widget.todo!);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _navigateToReport(BuildContext context) async {
    if (widget.todo?.reportId == null) return;

    try {
      // Get Hive box
      final reportBox = await ReportHiveService.getReportDetailBox();

      // Search for the report by ID
      ReportDetailModel? reportDetail;
      for (var key in reportBox.keys) {
        final detail = reportBox.get(key);
        if (detail?.report.id == widget.todo!.reportId) {
          reportDetail = detail;
          break;
        }
      }

      if (reportDetail != null && mounted) {
        // Close bottom sheet
        Navigator.pop(context);

        // Navigate to report detail
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReportDetailScreen(
              report: reportDetail!.report,
              folderName: 'Report', // We don't have folder name here
            ),
          ),
        );
      } else if (mounted) {
        // Report not found
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Report not found. Please sync reports first.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Bottom sheet for picking a team member
class _MemberPickerSheet extends StatefulWidget {
  final List<TeamMember> members;
  final TeamMember? selectedMember;
  final Function(TeamMember) onMemberSelected;
  final VoidCallback onClear;

  const _MemberPickerSheet({
    required this.members,
    required this.selectedMember,
    required this.onMemberSelected,
    required this.onClear,
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
    setState(() {
      if (query.isEmpty) {
        _filteredMembers = widget.members;
      } else {
        _filteredMembers = widget.members
            .where((m) => m.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
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
                if (widget.selectedMember != null)
                  TextButton(
                    onPressed: widget.onClear,
                    child: Text(
                      'Clear',
                      style: GoogleFonts.poppins(
                        fontSize: 14.sp,
                        color: Colors.red,
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
                      final isSelected = widget.selectedMember?.id == member.id;

                      return ListTile(
                        onTap: () => widget.onMemberSelected(member),
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFF1A1A53).withOpacity(0.1),
                          child: Text(
                            member.name.isNotEmpty
                                ? member.name[0].toUpperCase()
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
                          member.name,
                          style: GoogleFonts.poppins(
                            fontSize: 15.sp,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: const Color(0xFF1A1A53),
                          ),
                        ),
                        subtitle: member.jobPosition != null
                            ? Text(
                                member.jobPosition!,
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
