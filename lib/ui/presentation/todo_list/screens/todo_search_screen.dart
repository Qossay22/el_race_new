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

class TodoSearchScreen extends StatefulWidget {
  const TodoSearchScreen({super.key});

  @override
  State<TodoSearchScreen> createState() => _TodoSearchScreenState();
}

class _TodoSearchScreenState extends State<TodoSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    // Clear search when leaving
    context.read<TodoFirebaseProvider>().clearSearch();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const HeaderWidget(),
      body: Column(
        children: [
          const SizedBox(height: 10),
          // Header with search
          _buildHeader(),
          const SizedBox(height: 16),
          // Search results
          Expanded(
            child: Consumer<TodoFirebaseProvider>(
              builder: (context, provider, child) {
                if (provider.searchQuery.isEmpty) {
                  return _buildEmptySearchState();
                }

                if (provider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF1A1A53),
                    ),
                  );
                }

                if (provider.todos.isEmpty) {
                  return _buildNoResultsState();
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  physics: const BouncingScrollPhysics(),
                  itemCount: provider.todos.length,
                  itemBuilder: (context, index) {
                    final todo = provider.todos[index];
                    return TodoItemWidget(
                      todo: todo,
                      onToggleComplete: () => provider.toggleComplete(todo),
                      onToggleImportant: () => provider.toggleImportant(todo),
                      onTap: () => _showEditTodo(todo),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Container(
              height: 48.h,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                onChanged: (value) {
                  context.read<TodoFirebaseProvider>().search(value);
                },
                decoration: InputDecoration(
                  hintText: translate('todo.search_hint'),
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey.shade500,
                    fontSize: 15.sp,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey.shade500,
                    size: 22.w,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: Colors.grey.shade500,
                            size: 20.w,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            context.read<TodoFirebaseProvider>().clearSearch();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 14.h,
                  ),
                ),
                style: GoogleFonts.poppins(
                  fontSize: 15.sp,
                  color: appFontColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 80.w,
            color: Colors.grey.shade300,
          ),
          SizedBox(height: 16.h),
          Text(
            translate('todo.search_tasks'),
            style: GoogleFonts.poppins(
              fontSize: 18.sp,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade500,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            translate('todo.search_description'),
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              color: Colors.grey.shade400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80.w,
            color: Colors.grey.shade300,
          ),
          SizedBox(height: 16.h),
          Text(
            translate('todo.no_results'),
            style: GoogleFonts.poppins(
              fontSize: 18.sp,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade500,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            translate('todo.try_different_search'),
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditTodo(dynamic todo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTodoBottomSheet(
        filter: TodoFilter.all,
        todo: todo,
      ),
    );
  }
}
