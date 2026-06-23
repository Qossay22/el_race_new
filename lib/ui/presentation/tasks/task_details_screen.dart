import 'package:el_race/report_module/data/models/report_model.dart';
import 'package:el_race/report_module/data/provider/reports_provider.dart';
import 'package:el_race/report_module/presentation/screens/report_detail/report_detail.dart';
import 'package:el_race/ui/presentation/tasks/data/task_model.dart';
import 'package:el_race/ui/presentation/tasks/logic/tasks_provider.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class TaskDetailsScreen extends StatelessWidget {
  final TaskModel task;

  const TaskDetailsScreen({super.key, required this.task});

  Color _priorityColor(String? priority) {
    switch (priority) {
      case '1':
        return Colors.red.shade600;
      case '2':
        return Colors.orange.shade600;
      case '3':
        return Colors.green.shade600;
      default:
        return Colors.grey;
    }
  }

  Color _priorityColorssssDeleteMe(String? priority) {
    switch (priority) {
      case '1':
        return Colors.red.shade600;
      case '2':
        return Colors.orange.shade600;
      case '3':
        return Colors.green.shade600;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  }

  TaskModel _resolveTask(TasksProvider provider) {
    if (task.id == null) return task;
    return provider.tasks.firstWhere(
      (t) => t.id == task.id,
      orElse: () => task,
    );
  }

  Future<void> _showEditSheet(BuildContext context, TasksProvider provider,
      TaskModel currentTask) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _EditTaskSheet(
        task: currentTask,
        provider: provider,
        parentContext: context,
      ),
    );
  }

  Future<void> _showLinkReportDialog(BuildContext context,
      TasksProvider provider, TaskModel currentTask) async {
    if (currentTask.id == null) return;

    final reportsProvider = Provider.of<ReportProvider>(context, listen: false);

    // Get available reports
    final allReports = reportsProvider.reports;

    if (allReports.isEmpty) {
      Fluttertoast.showToast(
        msg: 'No reports found. Please create or load reports first.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.orange,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    // Filter out reports that are already linked to this task
    final linkedReportIds =
        currentTask.reportIds.map((r) => r.toString()).toSet();
    final availableReports = allReports
        .where((report) => !linkedReportIds.contains(report.id.toString()))
        .toList();

    if (availableReports.isEmpty) {
      Fluttertoast.showToast(
        msg: 'All reports are already linked to this task',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.blue,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    String? selectedReportId;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Link Report'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select a report to link:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedReportId,
                    decoration: InputDecoration(
                      labelText: 'Report',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: availableReports.map((report) {
                      return DropdownMenuItem<String>(
                        value: report.id.toString(),
                        child: Text(
                          report.name,
                          overflow: TextOverflow.visible,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedReportId = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedReportId == null
                      ? null
                      : () async {
                          final msg = await provider.linkReport(
                            taskId: currentTask.id!,
                            reportId: selectedReportId!,
                          );
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            if (msg != null) {
                              Fluttertoast.showToast(
                                msg: msg,
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.BOTTOM,
                                backgroundColor: Colors.green,
                                textColor: Colors.white,
                                fontSize: 16.0,
                              );
                            } else if (provider.errorMessage != null) {
                              Fluttertoast.showToast(
                                msg: provider.errorMessage!,
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.BOTTOM,
                                backgroundColor: Colors.red,
                                textColor: Colors.white,
                                fontSize: 16.0,
                              );
                            }
                          }
                        },
                  child: const Text('Link'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasksProvider = context.watch<TasksProvider>();
    final reportsProvider = context.watch<ReportProvider>();
    final currentTask = _resolveTask(tasksProvider);
    final priorityColor = _priorityColor(currentTask.priority);
    final isDeleting =
        tasksProvider.deletingTaskIds.contains(currentTask.id ?? -1);
    final isCompleting =
        tasksProvider.completingTaskIds.contains(currentTask.id ?? -1);
    final isLinking =
        tasksProvider.linkingTaskIds.contains(currentTask.id ?? -1);
    final isUpdating =
        tasksProvider.updatingTaskIds.contains(currentTask.id ?? -1);
    final linkedReportIds =
        currentTask.reportIds.map((r) => r.toString()).toSet();
    final hasLinkableReports = reportsProvider.reports
        .any((report) => !linkedReportIds.contains(report.id.toString()));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const HeaderWidget(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: appFontColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Icon(Icons.task_outlined, size: 24.w, color: appFontColor),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Task Details',
                      style: GoogleFonts.poppins(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w500,
                        color: appFontColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: priorityColor.withOpacity(0.15), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: priorityColor.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: -4,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (currentTask.id != null)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: isDeleting
                              ? null
                              : () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogCtx) {
                                      return AlertDialog(
                                        title: const Text('Delete Task'),
                                        content: const Text(
                                            'Are you sure you want to delete this task?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dialogCtx, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dialogCtx, true),
                                            child: const Text('Delete',
                                                style: TextStyle(
                                                    color: Colors.red)),
                                          ),
                                        ],
                                      );
                                    },
                                  );

                                  if (confirmed != true) return;

                                  final msg = await tasksProvider
                                      .deleteTask(currentTask.id!);
                                  if (context.mounted) {
                                    if (msg != null) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                              SnackBar(content: Text(msg)));
                                    } else if (tasksProvider.errorMessage !=
                                        null) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                tasksProvider.errorMessage!)),
                                      );
                                    }
                                  }
                                },
                          icon: isDeleting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.red),
                                )
                              : const Icon(Icons.delete, color: Colors.red),
                          label: const Text(
                            'Delete Task',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.red),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side:
                                const BorderSide(color: Colors.red, width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    if (task.id != null) const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                priorityColor,
                                priorityColor.withOpacity(0.6)
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            currentTask.name ?? 'Untitled Task',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: appFontColor),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                priorityColor.withOpacity(0.15),
                                priorityColor.withOpacity(0.08)
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: priorityColor.withOpacity(0.4),
                                width: 1.5),
                          ),
                          child: Text(
                            'P${currentTask.priority ?? '-'}',
                            style: TextStyle(
                                color: priorityColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    if (currentTask.stage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: task.isCompleted
                              ? Colors.green.shade50
                              : appFontColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: task.isCompleted
                                ? Colors.green
                                : appFontColor.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              currentTask.isCompleted
                                  ? Icons.check_circle
                                  : Icons.flag_rounded,
                              size: 16,
                              color: currentTask.isCompleted
                                  ? Colors.green.shade700
                                  : appFontColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              currentTask.stage ?? '-',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: task.isCompleted
                                    ? Colors.green.shade700
                                    : appFontColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Divider(color: Colors.grey.shade200),
                    const SizedBox(height: 16),
                    if ((currentTask.description ?? '').isNotEmpty) ...[
                      Text(
                        'Description',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: appFontColor),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          currentTask.description ?? '',
                          style: TextStyle(
                              fontSize: 14,
                              color: appFontColor.withOpacity(0.8),
                              height: 1.5),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if ((currentTask.projectId ?? '').isNotEmpty) ...[
                      _buildInfoRow(Icons.folder_open, 'Project',
                          currentTask.projectId ?? '-', Colors.blue),
                      const SizedBox(height: 12),
                    ],
                    if ((currentTask.assignedUser ?? '').isNotEmpty) ...[
                      _buildInfoRow(Icons.person, 'Assigned to',
                          currentTask.assignedUser ?? '-', Colors.purple),
                      const SizedBox(height: 12),
                    ],
                    if ((currentTask.team ?? '').isNotEmpty) ...[
                      _buildInfoRow(Icons.group, 'Team',
                          currentTask.team ?? '-', Colors.orange),
                      const SizedBox(height: 12),
                    ],
                    _buildInfoRow(Icons.calendar_today, 'Created',
                        _formatDate(currentTask.createdAt), Colors.teal),
                    if (currentTask.reportIds.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Divider(color: Colors.grey.shade200),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.insert_drive_file,
                              size: 18, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Linked Reports (${currentTask.reportIds.length})',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: appFontColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildLinkedReports(context, currentTask),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (!currentTask.isCompleted && currentTask.id != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isUpdating
                            ? null
                            : () => _showEditSheet(
                                context, tasksProvider, currentTask),
                        icon: isUpdating
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: appFontColor),
                              )
                            : Icon(Icons.edit, color: appFontColor),
                        label: Text(
                          'Edit Task',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: appFontColor),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: appFontColor, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isCompleting
                            ? null
                            : () async {
                                final msg = await tasksProvider
                                    .completeTask(currentTask.id!);
                                if (context.mounted && msg != null) {
                                  Fluttertoast.showToast(
                                    msg: msg,
                                    toastLength: Toast.LENGTH_SHORT,
                                    gravity: ToastGravity.BOTTOM,
                                    backgroundColor: Colors.green,
                                    textColor: Colors.white,
                                    fontSize: 16.0,
                                  );
                                  Navigator.pop(context);
                                }
                              },
                        icon: isCompleting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle, size: 20),
                        label: const Text('Mark as Complete',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isLinking || !hasLinkableReports
                            ? null
                            : () => _showLinkReportDialog(
                                context, tasksProvider, currentTask),
                        icon: isLinking
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: appFontColor),
                              )
                            : Icon(Icons.link, color: appFontColor),
                        label: Text(
                          'Link Report',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: appFontColor),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: appFontColor, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                    fontSize: 14,
                    color: appFontColor,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLinkedReports(BuildContext context, TaskModel currentTask) {
    return Consumer<ReportProvider>(
      builder: (context, reportProvider, _) {
        final parsedReports = currentTask.reportIds.map((e) {
          if (e is Map && e['id'] != null) {
            return (id: e['id'].toString(), name: e['name']?.toString());
          }
          return (id: e.toString(), name: null);
        }).toList();

        return Column(
          children: parsedReports.map((reportData) {
            final report = reportProvider.reports.firstWhere(
              (r) => r.id == reportData.id,
              orElse: () => ReportModel(
                id: reportData.id,
                name: reportData.name ?? 'Report ${reportData.id}',
                companyId: '',
                folderId: '',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.description,
                      color: Colors.blue.shade700, size: 20),
                ),
                title: Text(
                  report.name,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: appFontColor),
                ),
                subtitle: Text(
                  'ID: ${report.id}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.blue.shade700),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReportDetailScreen(
                        report: report,
                        folderName: report.name,
                      ),
                    ),
                  );
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _EditTaskSheet extends StatefulWidget {
  final TaskModel task;
  final TasksProvider provider;
  final BuildContext parentContext;

  const _EditTaskSheet({
    required this.task,
    required this.provider,
    required this.parentContext,
  });

  @override
  State<_EditTaskSheet> createState() => _EditTaskSheetState();
}

class _EditTaskSheetState extends State<_EditTaskSheet> {
  late final TextEditingController nameController;
  late final TextEditingController descController;
  late String priority;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.task.name ?? '');
    descController = TextEditingController(text: widget.task.description ?? '');
    priority = widget.task.priority ?? '2';
  }

  @override
  void dispose() {
    nameController.dispose();
    descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUpdating = context
        .watch<TasksProvider>()
        .updatingTaskIds
        .contains(widget.task.id ?? -1);

    return Padding(
      padding: EdgeInsets.only(
        left: 16.w,
        right: 16.w,
        top: 16.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16.h,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.edit, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Edit Task',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Title',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: 'Enter title',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: appFontColor, width: 2),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Description',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: descController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Write your description...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: appFontColor, width: 2),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Priority',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: priority,
              decoration: InputDecoration(
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: appFontColor, width: 2),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: const [
                DropdownMenuItem(value: '1', child: Text('High')),
                DropdownMenuItem(value: '2', child: Text('Medium')),
                DropdownMenuItem(value: '3', child: Text('Low')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => priority = val);
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: isUpdating
                    ? null
                    : () async {
                        if (widget.task.id == null) return;
                        final msg = await widget.provider.updateTask(
                          taskId: widget.task.id!,
                          name: nameController.text.trim() == widget.task.name
                              ? null
                              : nameController.text.trim(),
                          description: descController.text.trim() ==
                                  widget.task.description
                              ? null
                              : descController.text.trim(),
                          priority: priority == widget.task.priority
                              ? null
                              : priority,
                        );

                        if (!mounted) return;

                        if (msg != null) {
                          await widget.provider
                              .refreshTasks(); // ensure list reflects latest edits after closing
                          if (!mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(widget.parentContext)
                              .showSnackBar(SnackBar(content: Text(msg)));
                        } else if (widget.provider.errorMessage != null) {
                          ScaffoldMessenger.of(widget.parentContext)
                              .showSnackBar(SnackBar(
                                  content:
                                      Text(widget.provider.errorMessage!)));
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: appFontColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: isUpdating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
