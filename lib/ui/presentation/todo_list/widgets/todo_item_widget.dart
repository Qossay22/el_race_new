import 'package:el_race/ui/presentation/todo_list/data/todo_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class TodoItemWidget extends StatelessWidget {
  final TodoModel todo;
  final VoidCallback onToggleComplete;
  final VoidCallback onToggleImportant;
  final VoidCallback onTap;

  const TodoItemWidget({
    super.key,
    required this.todo,
    required this.onToggleComplete,
    required this.onToggleImportant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: todo.isCompleted
              ? Colors.grey.shade300
              : const Color(0xFF1A1A53).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            child: Row(
              children: [
                // Checkbox
                GestureDetector(
                  onTap: onToggleComplete,
                  child: Container(
                    width: 24.w,
                    height: 24.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: todo.isCompleted
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFF1A1A53),
                        width: 2,
                      ),
                      color: todo.isCompleted
                          ? const Color(0xFF4CAF50)
                          : Colors.transparent,
                    ),
                    child: todo.isCompleted
                        ? Icon(
                            Icons.check,
                            size: 16.w,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
                SizedBox(width: 12.w),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        todo.title,
                        style: GoogleFonts.poppins(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w500,
                          color: todo.isCompleted
                              ? Colors.grey.shade500
                              : const Color(0xFF1A1A53),
                          decoration: todo.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.visible,
                      ),
                      // Meta info
                      if (_hasMetaInfo()) ...[
                        SizedBox(height: 4.h),
                        _buildMetaInfo(),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                // Important Star
                GestureDetector(
                  onTap: onToggleImportant,
                  child: Icon(
                    todo.isImportant ? Icons.star : Icons.star_border,
                    size: 24.w,
                    color: todo.isImportant
                        ? const Color(0xFFFFB800)
                        : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _hasMetaInfo() {
    return todo.dueDate != null ||
        todo.isMyDay ||
        todo.description != null ||
        todo.assignedToName != null;
  }

  Widget _buildMetaInfo() {
    final List<Widget> items = [];

    // Assigned to member
    if (todo.assignedToName != null && todo.assignedToName!.isNotEmpty) {
      items.add(_buildMetaChip(
        icon: Icons.person_outline,
        label: todo.assignedToName!,
        color: const Color(0xFF9C27B0),
      ));
    }

    // My Day indicator
    if (todo.isMyDay) {
      items.add(_buildMetaChip(
        icon: Icons.wb_sunny_outlined,
        label: 'My Day',
        color: const Color(0xFF2196F3),
      ));
    }

    // Due date
    if (todo.dueDate != null) {
      final isOverdue =
          todo.dueDate!.isBefore(DateTime.now()) && !todo.isCompleted;
      final isToday = _isToday(todo.dueDate!);

      items.add(_buildMetaChip(
        icon: Icons.calendar_today_outlined,
        label: isToday ? 'Today' : DateFormat('MMM d').format(todo.dueDate!),
        color: isOverdue ? Colors.red : Colors.grey.shade600,
      ));
    }

    // Description indicator
    if (todo.description != null && todo.description!.isNotEmpty) {
      items.add(Icon(
        Icons.notes,
        size: 14.w,
        color: Colors.grey.shade400,
      ));
    }

    return Wrap(
      spacing: 8.w,
      runSpacing: 4.h,
      children: items,
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12.w,
          color: color,
        ),
        SizedBox(width: 4.w),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}
