import 'package:el_race/ui/presentation/todo_list/providers/todo_firebase_provider.dart';
import 'package:el_race/ui/presentation/todo_list/widgets/add_todo_bottom_sheet.dart';
import 'package:el_race/ui/presentation/todo_list/widgets/todo_item_widget.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class TodoCategoryScreen extends StatefulWidget {
  final TodoFilter filter;
  final String title;
  final String? listId;

  const TodoCategoryScreen({
    super.key,
    required this.filter,
    required this.title,
    this.listId,
  });

  @override
  State<TodoCategoryScreen> createState() => _TodoCategoryScreenState();
}

class _TodoCategoryScreenState extends State<TodoCategoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<TodoFirebaseProvider>()
          .setFilter(widget.filter, listId: widget.listId);
    });
  }

  IconData _getIconForFilter() {
    switch (widget.filter) {
      case TodoFilter.myDay:
        return Icons.wb_sunny_outlined;
      case TodoFilter.important:
        return Icons.star_border;
      case TodoFilter.planned:
        return Icons.calendar_today_outlined;
      case TodoFilter.assignedToMe:
        return Icons.person_outline;
      case TodoFilter.customList:
        return Icons.list_alt;
      case TodoFilter.all:
      case TodoFilter.tasks:
        return Icons.check_box_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const HeaderWidget(),
      body: Column(
        children: [
          const SizedBox(height: 10),
          // Header
          _buildHeader(),
          const SizedBox(height: 16),
          // Todos List
          Expanded(
            child: Consumer<TodoFirebaseProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF1A1A53),
                    ),
                  );
                }

                if (provider.todos.isEmpty) {
                  return _buildEmptyState();
                }

                return ReorderableListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  physics: const BouncingScrollPhysics(),
                  itemCount: provider.todos.length,
                  onReorder: (oldIndex, newIndex) {
                    provider.reorderTodos(oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final todo = provider.todos[index];
                    return Dismissible(
                      key: ValueKey(todo.firebaseId ?? todo.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.only(right: 20.w),
                        margin: EdgeInsets.only(bottom: 8.h),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                          size: 28.w,
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        return await _confirmDelete(context);
                      },
                      onDismissed: (direction) {
                        provider.deleteTodo(todo);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(translate('todo.task_deleted')),
                            action: SnackBarAction(
                              label: translate('common.undo'),
                              onPressed: () {
                                // Undo delete - re-add the todo
                                provider.addTodo(
                                  title: todo.title,
                                  description: todo.description,
                                  isImportant: todo.isImportant,
                                  isMyDay: todo.isMyDay,
                                  dueDate: todo.dueDate,
                                  assignedTo: todo.assignedTo,
                                  assignedToName: todo.assignedToName,
                                  listId: todo.listId,
                                );
                              },
                            ),
                          ),
                        );
                      },
                      child: TodoItemWidget(
                        key:
                            ValueKey('todo_item_${todo.firebaseId ?? todo.id}'),
                        todo: todo,
                        onToggleComplete: () => provider.toggleComplete(todo),
                        onToggleImportant: () => provider.toggleImportant(todo),
                        onTap: () => _showEditTodo(todo),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTodo,
        backgroundColor: const Color(0xFF1A1A53),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        Icon(
          _getIconForFilter(),
          size: 28.w,
          color: appFontColor,
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            widget.title.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 24.sp,
              fontWeight: FontWeight.w500,
              color: appFontColor,
            ),
            overflow: TextOverflow.visible,
          ),
        ),
        Consumer<TodoFirebaseProvider>(
          builder: (context, provider, child) {
            final count = provider.todos.where((t) => !t.isCompleted).length;
            if (count == 0) return const SizedBox.shrink();
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              margin: EdgeInsets.only(right: 16.w),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A53).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                count.toString(),
                style: GoogleFonts.poppins(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A53),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getIconForFilter(),
            size: 80.w,
            color: Colors.grey.shade300,
          ),
          SizedBox(height: 16.h),
          Text(
            translate('todo.no_tasks'),
            style: GoogleFonts.poppins(
              fontSize: 18.sp,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade500,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            translate('todo.add_task_hint'),
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) async {
    return showDialog<bool>(
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
  }

  void _showAddTodo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTodoBottomSheet(
        filter: widget.filter,
        listId: widget.listId,
      ),
    );
  }

  void _showEditTodo(dynamic todo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTodoBottomSheet(
        filter: widget.filter,
        listId: widget.listId,
        todo: todo,
      ),
    );
  }
}
