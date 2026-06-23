import 'dart:convert';
import 'dart:io';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/report_module/data/provider/reports_provider.dart';
import 'package:el_race/ui/presentation/tasks/data/task_model.dart';
import 'package:el_race/ui/presentation/tasks/logic/tasks_provider.dart';
import 'package:el_race/ui/presentation/tasks/task_details_screen.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  Future<void> _showCreateTaskSheet(
    BuildContext context,
    TasksProvider provider,
  ) async {
    if (provider.assignableUsers.isEmpty && !provider.isLoadingUsers) {
      await provider.loadAssignableUsers();
      if (provider.errorMessage != null && context.mounted) {
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

    final nameController = TextEditingController();
    final descController = TextEditingController();
    final commentController = TextEditingController();
    String priority = '1';
    int? selectedUserId;
    String? attachmentBase64;
    String? attachmentFilename;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              Future<void> pickAttachment() async {
                final result = await FilePicker.pickFiles(
                  allowMultiple: false,
                  type: FileType.custom,
                  allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
                  withData: true,
                );

                if (result != null && result.files.isNotEmpty) {
                  final file = result.files.first;
                  final bytes = file.bytes ??
                      (file.path != null
                          ? await File(file.path!).readAsBytes()
                          : null);
                  if (bytes != null) {
                    setState(() {
                      attachmentBase64 = base64Encode(bytes);
                      attachmentFilename = file.name;
                    });
                  }
                }
              }

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.task_alt, color: appFontColor, size: 24),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Create Task',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Task Title',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'Enter task title',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: appFontColor, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Description',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Write your description...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: appFontColor, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Comment',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: commentController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Add a comment (optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: appFontColor, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: priority,
                            decoration: InputDecoration(
                              labelText: 'Priority',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: '1', child: Text('High')),
                              DropdownMenuItem(
                                  value: '2', child: Text('Medium')),
                              DropdownMenuItem(value: '3', child: Text('Low')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => priority = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: provider.isLoadingUsers
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : DropdownButtonFormField<int>(
                                  value: selectedUserId,
                                  decoration: InputDecoration(
                                    labelText: 'Assign to',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                  ),
                                  items: provider.assignableUsers
                                      .map(
                                        (u) => DropdownMenuItem(
                                          value: u.id,
                                          child: Text(u.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) =>
                                      setState(() => selectedUserId = val),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Attachment (optional)',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: pickAttachment,
                            icon: const Icon(Icons.attach_file),
                            label: Text(
                              attachmentFilename ?? 'Add file',
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ),
                        if (attachmentFilename != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                attachmentBase64 = null;
                                attachmentFilename = null;
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: provider.isCreating
                            ? null
                            : () async {
                                if (nameController.text.trim().isEmpty) {
                                  Fluttertoast.showToast(
                                    msg: 'Name is required',
                                    toastLength: Toast.LENGTH_SHORT,
                                    gravity: ToastGravity.BOTTOM,
                                    backgroundColor: Colors.red,
                                    textColor: Colors.white,
                                    fontSize: 16.0,
                                  );
                                  return;
                                }

                                int? userIdToAssign = selectedUserId;
                                if (userIdToAssign == null) {
                                  final loginData = SharedPref.getLoginData();
                                  final uid = loginData.result?.data?.uid;
                                  if (uid != null) userIdToAssign = uid;
                                }

                                final createdTask = await provider.createTask(
                                  name: nameController.text.trim(),
                                  description: descController.text.trim(),
                                  priority: priority,
                                  userId: userIdToAssign,
                                  comment: commentController.text.trim().isEmpty
                                      ? null
                                      : commentController.text.trim(),
                                  attachmentBase64: attachmentBase64,
                                  attachmentFilename: attachmentFilename,
                                );

                                if (context.mounted) {
                                  if (createdTask != null) {
                                    Navigator.pop(context);
                                    Fluttertoast.showToast(
                                      msg:
                                          'Task "${createdTask.name ?? ''}" created successfully',
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
                                        builder: (context) => TaskDetailsScreen(
                                            task: createdTask),
                                      ),
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appFontColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: provider.isCreating
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Create Task',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    nameController.dispose();
    descController.dispose();
    commentController.dispose();
  }

  Future<void> _showLinkReportDialog(
    BuildContext context,
    TasksProvider provider,
    TaskModel task,
  ) async {
    final reportProvider = context.read<ReportProvider>();

    if (reportProvider.reports.isEmpty) {
      if (context.mounted) {
        Fluttertoast.showToast(
          msg: 'No reports found. Please create or load reports first.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
      return;
    }

    final linkedIds = task.reportIds.map((r) => r.toString()).toSet();
    final availableReports = reportProvider.reports
        .where((r) => !linkedIds.contains(r.id.toString()))
        .toList();

    if (availableReports.isEmpty) {
      if (context.mounted) {
        Fluttertoast.showToast(
          msg: 'All reports are already linked to this task',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.blue,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
      return;
    }

    String? selectedReportId = availableReports.first.id.toString();

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Link report'),
              content: DropdownButtonFormField<String>(
                value: selectedReportId,
                decoration: const InputDecoration(
                  labelText: 'Report',
                ),
                items: availableReports
                    .map((r) => DropdownMenuItem(
                          value: r.id.toString(),
                          child: Text(r.name),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => selectedReportId = val),
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
                            taskId: task.id!,
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

  Widget _buildTaskTile(
    BuildContext context,
    TasksProvider provider,
    TaskModel task,
  ) {
    final id = task.id;
    final isCompleting = id != null && provider.completingTaskIds.contains(id);
    final isLinking = id != null && provider.linkingTaskIds.contains(id);
    final isDeleting = id != null && provider.deletingTaskIds.contains(id);

    final dateText = task.createdAt != null
        ? DateFormat.yMMMd().format(task.createdAt!)
        : 'N/A';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TaskDetailsScreen(task: task),
            ),
          ).then((_) {
            if (context.mounted) {
              provider.refreshTasks(); // ensure list pulls latest after edits
            }
          });
        },
        title: Text(task.name ?? 'Untitled Task'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description != null && task.description!.isNotEmpty)
              Text(
                task.description!,
                maxLines: 2,
                overflow: TextOverflow.visible,
              ),
            Text('Priority P${task.priority ?? '-'} · $dateText'),
          ],
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            if (!task.isCompleted)
              IconButton(
                tooltip: 'Link report',
                icon: isLinking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link),
                onPressed: id == null || isLinking
                    ? null
                    : () => _showLinkReportDialog(context, provider, task),
              ),
            if (!(task.isCompleted))
              IconButton(
                tooltip: 'Complete',
                icon: isCompleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                onPressed: id == null || isCompleting
                    ? null
                    : () async {
                        final msg = await provider.completeTask(id);
                        if (context.mounted && msg != null) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(msg)));
                        }
                      },
              ),
            IconButton(
              tooltip: 'Delete',
              icon: isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
              onPressed: id == null || isDeleting
                  ? null
                  : () async {
                      final msg = await provider.deleteTask(id);
                      if (context.mounted && msg != null) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(msg)));
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TasksProvider, ReportProvider>(
      builder: (context, tasksProvider, reportProvider, _) {
        if (tasksProvider.status == TasksStatus.initial) {
          Future.microtask(tasksProvider.loadTasks);
          Future.microtask(tasksProvider.loadAssignableUsers);
        }

        Widget body;
        switch (tasksProvider.status) {
          case TasksStatus.loading:
          case TasksStatus.initial:
            body = const Center(child: CircularProgressIndicator());
            break;
          case TasksStatus.error:
            body = _ErrorState(
              message: tasksProvider.errorMessage ?? 'Failed to load tasks.',
              onRetry: tasksProvider.loadTasks,
            );
            break;
          case TasksStatus.empty:
            body = const _EmptyState();
            break;
          case TasksStatus.loaded:
            body = RefreshIndicator(
              onRefresh: tasksProvider.refreshTasks,
              child: ListView.builder(
                itemCount: tasksProvider.tasks.length,
                itemBuilder: (context, index) {
                  final task = tasksProvider.tasks[index];
                  return _buildTaskTile(context, tasksProvider, task);
                },
              ),
            );
            break;
        }

        return Scaffold(
          appBar: const HeaderWidget(),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showCreateTaskSheet(context, tasksProvider),
            backgroundColor: appFontColor,
            child: const Icon(Icons.add, color: Colors.white),
          ),
          body: SafeArea(child: body),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: appFontColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.task_outlined,
              size: 64,
              color: appFontColor.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No tasks available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: appFontColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first task to get started',
            style: TextStyle(
              fontSize: 14,
              color: appFontColor.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 56,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: appFontColor.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: appFontColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
