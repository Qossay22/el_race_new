import 'package:el_race/report_module/core/constants/colors.dart';
import 'package:el_race/report_module/core/constants/text_styles.dart';
import 'package:el_race/ui/presentation/tasks/data/task_model.dart';
import 'package:el_race/ui/presentation/tasks/task_details_screen.dart';
import 'package:el_race/ui/presentation/tasks/tasks_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

/// Widget لعرض Tasks المرتبطة بـ Report
class LinkedTasksList extends StatelessWidget {
  final List<TaskModel> tasks;
  final Future<void> Function(TaskModel task)? onSubmit;
  final Set<int> submittingTaskIds;

  const LinkedTasksList({
    super.key,
    required this.tasks,
    this.onSubmit,
    this.submittingTaskIds = const {},
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: CustomColors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: CustomColors.maroon.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: CustomColors.maroon.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  Icons.task_alt,
                  color: CustomColors.maroon,
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Linked Tasks',
                      style: CustomTextStyle.heading.copyWith(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${tasks.length} task${tasks.length > 1 ? 's' : ''}',
                      style: CustomTextStyle.reportTitle.copyWith(
                        fontSize: 12.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _navigateToTasks(context),
                child: Text(
                  'View All',
                  style: TextStyle(
                    color: CustomColors.maroon,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 12.h),
          Divider(color: Colors.grey[200], height: 1),
          SizedBox(height: 12.h),

          // Tasks List
          ...tasks.take(3).map((task) => Builder(
                builder: (context) => _buildTaskItem(context, task),
              )),

          // Show more indicator
          if (tasks.length > 3)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Center(
                child: TextButton(
                  onPressed: () => _navigateToTasks(context),
                  style: TextButton.styleFrom(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '+${tasks.length - 3} more tasks',
                        style: TextStyle(
                          color: CustomColors.maroon,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12.sp,
                        color: CustomColors.maroon,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, TaskModel task) {
    final completed = task.isCompleted;
    final isSubmitting = submittingTaskIds.contains((task.id ?? -1));
    final stageLabel = (task.stage ?? '').isNotEmpty
        ? task.stage!
        : completed
            ? 'Completed'
            : 'In Progress';
    final projectLabel = (task.projectId ?? '').isNotEmpty
        ? 'Project ${task.projectId}'
        : 'No project linked';
    final createdDate = task.createdAt != null
        ? DateFormat('dd MMM yyyy').format(task.createdAt!)
        : null;

    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openTaskDetails(context, task),
          borderRadius: BorderRadius.circular(12.r),
          child: Ink(
            decoration: BoxDecoration(
              color: completed
                  ? Colors.grey[100]
                  : CustomColors.maroon.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: completed
                    ? Colors.grey[300]!
                    : CustomColors.maroon.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(12.w),
              child: Row(
                children: [
                  Container(
                    width: 20.w,
                    height: 20.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: completed ? Colors.green : CustomColors.maroon,
                        width: 2,
                      ),
                      color: completed ? Colors.green : Colors.transparent,
                    ),
                    child: completed
                        ? Icon(
                            Icons.check,
                            size: 14.sp,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.name ?? 'Untitled task',
                          style: CustomTextStyle.reportTitle.copyWith(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: completed
                                ? Colors.grey[600]
                                : CustomColors.black,
                            decoration: completed
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                          maxLines: null,
                          overflow: TextOverflow.visible,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          stageLabel,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color:
                                completed ? Colors.green : CustomColors.maroon,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          projectLabel,
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.grey[600],
                          ),
                          maxLines: null,
                          overflow: TextOverflow.visible,
                        ),
                        if (createdDate != null) ...[
                          SizedBox(height: 4.h),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 12.sp,
                                color: Colors.grey[600],
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                createdDate,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!completed && onSubmit != null)
                    TextButton.icon(
                      onPressed:
                          isSubmitting ? null : () => onSubmit?.call(task),
                      icon: isSubmitting
                          ? SizedBox(
                              width: 16.w,
                              height: 16.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              Icons.send,
                              size: 16.sp,
                              color: CustomColors.maroon,
                            ),
                      label: Text(
                        'Submit',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: CustomColors.maroon,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 10.w),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openTaskDetails(BuildContext context, TaskModel task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailsScreen(task: task),
      ),
    );
  }

  void _navigateToTasks(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TasksScreen(),
      ),
    );
  }
}
