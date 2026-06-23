import 'dart:convert';
import 'dart:io';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/report_module/core/constants/colors.dart';
import 'package:el_race/report_module/core/constants/text_styles.dart';
import 'package:el_race/report_module/data/models/report_detail_model.dart';
import 'package:el_race/ui/presentation/tasks/logic/tasks_provider.dart';
import 'package:el_race/ui/presentation/tasks/task_details_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Bottom sheet لإنشاء Task من Report مع pre-filled data
/// UX: سهل، واضح، وسريع
class CreateTaskFromReportSheet extends StatefulWidget {
  final ReportDetailModel reportDetail;

  const CreateTaskFromReportSheet({
    super.key,
    required this.reportDetail,
  });

  @override
  State<CreateTaskFromReportSheet> createState() =>
      _CreateTaskFromReportSheetState();
}

class _CreateTaskFromReportSheetState extends State<CreateTaskFromReportSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _commentController;
  bool _isLoading = false;
  String _priority = '1';
  int? _selectedUserId;
  String? _attachmentBase64;
  String? _attachmentFilename;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _ensureAssignableUsers());
  }

  void _initializeControllers() {
    // Pre-fill title with report name
    _titleController = TextEditingController(
      text: widget.reportDetail.report.name,
    );

    // Pre-fill description with report info
    _descriptionController = TextEditingController(
      text: _generateDescriptionFromReport(),
    );

    _commentController = TextEditingController();
  }

  String _generateDescriptionFromReport() {
    final buffer = StringBuffer();
    buffer.writeln('📋 Report: ${widget.reportDetail.report.name}');
    buffer.writeln(
        '📅 Created: ${DateFormat('dd MMM yyyy, HH:mm').format(widget.reportDetail.report.createdAt)}');
    buffer.writeln();

    // Add report items summary
    if (widget.reportDetail.reportItems.isNotEmpty) {
      buffer.writeln(
          '📸 Report Items (${widget.reportDetail.reportItems.length}):');
      int imageCount = 0;
      int textCount = 0;
      int locationCount = 0;

      for (var item in widget.reportDetail.reportItems) {
        if (item.type == 'image') imageCount++;
        if (item.type == 'text') textCount++;
        if (item.type == 'location') locationCount++;
      }

      if (imageCount > 0) buffer.writeln('  • Images: $imageCount');
      if (textCount > 0) buffer.writeln('  • Text notes: $textCount');
      if (locationCount > 0) buffer.writeln('  • Locations: $locationCount');
      buffer.writeln();
    }

    // Add cover page info if exists
    if (widget.reportDetail.coverPage != null) {
      buffer.writeln('📄 Has cover page');
      buffer.writeln();
    }

    buffer.writeln('🔗 Linked to Report ID: ${widget.reportDetail.report.id}');

    return buffer.toString();
  }

  Future<void> _ensureAssignableUsers() async {
    final tasksProvider = Provider.of<TasksProvider>(context, listen: false);
    if (!tasksProvider.usersLoaded && !tasksProvider.isLoadingUsers) {
      await tasksProvider.loadAssignableUsers();
    }
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      final bytes = file.bytes ??
          (file.path != null ? await File(file.path!).readAsBytes() : null);
      if (bytes != null) {
        setState(() {
          _attachmentBase64 = base64Encode(bytes);
          _attachmentFilename = file.name;
        });
      }
    }
  }

  Future<void> _createTask() async {
    if (_titleController.text.trim().isEmpty) {
      Fluttertoast.showToast(
        msg: 'Please enter a task title',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: CustomColors.maroon,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final tasksProvider = Provider.of<TasksProvider>(context, listen: false);

    final commentText = _commentController.text.trim().isEmpty
        ? null
        : _commentController.text.trim();

    // Default assignee to current user if none selected
    int? userId = _selectedUserId;
    if (userId == null) {
      final login = SharedPref.getLoginDataOrNull();
      userId = login?.result?.data?.uid;
    }

    final createdTask = await tasksProvider.createTaskForReport(
      name: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      priority: _priority,
      reportId: widget.reportDetail.report.id,
      userId: userId,
      comment: commentText,
      attachmentBase64: _attachmentBase64,
      attachmentFilename: _attachmentFilename,
    );

    setState(() {
      _isLoading = false;
    });

    if (createdTask != null && mounted) {
      Navigator.pop(context, true); // Close bottom sheet first

      Fluttertoast.showToast(
        msg: '✅ Task "${createdTask.name ?? ''}" created successfully!',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0,
      );

      // Navigate to task details
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TaskDetailsScreen(task: createdTask),
        ),
      );
    } else if (mounted) {
      final error = tasksProvider.errorMessage ?? 'Failed to create task';
      Fluttertoast.showToast(
        msg: error,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: CustomColors.maroon,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 20.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
      ),
      decoration: BoxDecoration(
        color: CustomColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.task_alt,
                  color: CustomColors.maroon,
                  size: 28.sp,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'Create Task from Report',
                    style: CustomTextStyle.heading.copyWith(fontSize: 18.sp),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, size: 24.sp),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            SizedBox(height: 20.h),

            // Title Field
            Text(
              'Task Title',
              style: CustomTextStyle.reportTitle.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 14.sp,
              ),
            ),
            SizedBox(height: 8.h),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Enter task title',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: CustomColors.maroon, width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 14.h,
                ),
              ),
              style: CustomTextStyle.reportTitle,
            ),

            SizedBox(height: 16.h),

            // Description Field
            Text(
              'Description',
              style: CustomTextStyle.reportTitle.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 14.sp,
              ),
            ),
            SizedBox(height: 8.h),
            TextField(
              controller: _descriptionController,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: 'Task description (auto-generated from report)',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: CustomColors.maroon, width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 14.h,
                ),
              ),
              style: CustomTextStyle.reportTitle.copyWith(fontSize: 13.sp),
            ),

            SizedBox(height: 16.h),

            // Comment Field
            Text(
              'Comment',
              style: CustomTextStyle.reportTitle.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 14.sp,
              ),
            ),
            SizedBox(height: 8.h),
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Add a comment (optional)',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: CustomColors.maroon, width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 14.h,
                ),
              ),
              style: CustomTextStyle.reportTitle.copyWith(fontSize: 13.sp),
            ),

            SizedBox(height: 16.h),

            // Priority & Assign
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _priority,
                    decoration: InputDecoration(
                      labelText: 'Priority',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(color: Colors.transparent),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide:
                            BorderSide(color: CustomColors.maroon, width: 2),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 14.w, vertical: 12.h),
                    ),
                    icon: const Icon(Icons.arrow_drop_down),
                    dropdownColor: Colors.white,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: '1',
                        child: Text('🔴 High', style: TextStyle(fontSize: 14)),
                      ),
                      DropdownMenuItem(
                        value: '2',
                        child:
                            Text('🟠 Medium', style: TextStyle(fontSize: 14)),
                      ),
                      DropdownMenuItem(
                        value: '3',
                        child: Text('🟢 Low', style: TextStyle(fontSize: 14)),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _priority = val);
                    },
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Consumer<TasksProvider>(
                    builder: (context, tasksProvider, _) {
                      if (tasksProvider.isLoadingUsers &&
                          tasksProvider.assignableUsers.isEmpty) {
                        return Container(
                          height: 56.h,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }

                      return DropdownButtonFormField<int>(
                        initialValue: _selectedUserId,
                        decoration: InputDecoration(
                          labelText: 'Assign to',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide:
                                const BorderSide(color: Colors.transparent),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide(
                                color: CustomColors.maroon, width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 14.w, vertical: 12.h),
                        ),
                        icon: const Icon(Icons.arrow_drop_down),
                        dropdownColor: Colors.white,
                        isExpanded: true,
                        items: tasksProvider.assignableUsers
                            .map((u) => DropdownMenuItem(
                                  value: u.id,
                                  child: Text(
                                    u.name,
                                    style: const TextStyle(fontSize: 14),
                                    overflow: TextOverflow.visible,
                                  ),
                                ))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedUserId = val),
                      );
                    },
                  ),
                ),
              ],
            ),

            SizedBox(height: 16.h),

            // Attachment Picker
            Text(
              'Attachment (optional)',
              style: CustomTextStyle.reportTitle.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 14.sp,
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickAttachment,
                    icon: const Icon(Icons.attach_file),
                    label: Text(
                      _attachmentFilename ?? 'Add file',
                      overflow: TextOverflow.visible,
                      style: CustomTextStyle.reportTitle.copyWith(
                        fontSize: 13.sp,
                        color: Colors.grey[800],
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 12.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                ),
                if (_attachmentFilename != null) ...[
                  SizedBox(width: 8.w),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _attachmentBase64 = null;
                        _attachmentFilename = null;
                      });
                    },
                  ),
                ],
              ],
            ),

            SizedBox(height: 24.h),

            // Create Task Button
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CustomColors.maroon,
                  foregroundColor: CustomColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 24.h,
                        width: 24.h,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Create Task',
                        style: CustomTextStyle.reportTitle.copyWith(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: CustomColors.white,
                        ),
                      ),
              ),
            ),

            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }
}
