import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/todo_list/providers/todo_firebase_provider.dart';
import 'package:el_race/ui/presentation/todo_list/screens/todo_category_screen.dart';
import 'package:el_race/ui/presentation/todo_list/screens/todo_search_screen.dart';
import 'package:el_race/ui/presentation/todo_list/widgets/add_list_dialog.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TodoFirebaseProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final loginData = SharedPref.getLoginData();
    final userName = loginData.result?.data?.name ?? 'User';
    final userImage = SharedPref().getUserBase64Image();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const HeaderWidget(),
      body: Column(
        children: [
          const SizedBox(height: 10),
          // Header
          _buildHeader(),
          const SizedBox(height: 16),
          // User Profile Section
          _buildUserProfile(userName, userImage),
          const SizedBox(height: 24),
          // Categories List
          Expanded(
            child: Consumer<TodoFirebaseProvider>(
              builder: (context, provider, child) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    children: [
                      // My Day
                      _buildCategoryTile(
                        icon: Icons.wb_sunny_outlined,
                        title: translate('todo.my_day'),
                        count: provider.myDayCount,
                        onTap: () => _navigateToCategory(
                            TodoFilter.myDay, translate('todo.my_day')),
                      ),
                      SizedBox(height: 16.h),
                      // Important
                      _buildCategoryTile(
                        icon: Icons.star_border,
                        title: translate('todo.important'),
                        count: provider.importantCount,
                        onTap: () => _navigateToCategory(
                            TodoFilter.important, translate('todo.important')),
                      ),
                      SizedBox(height: 16.h),
                      // Planned
                      _buildCategoryTile(
                        icon: Icons.calendar_today_outlined,
                        title: translate('todo.planned'),
                        count: provider.plannedCount,
                        onTap: () => _navigateToCategory(
                            TodoFilter.planned, translate('todo.planned')),
                      ),
                      SizedBox(height: 16.h),
                      // Tasks (All)
                      _buildCategoryTile(
                        icon: Icons.check_box_outlined,
                        title: translate('todo.tasks'),
                        count: provider.totalCount,
                        onTap: () => _navigateToCategory(
                            TodoFilter.tasks, translate('todo.tasks')),
                      ),
                      SizedBox(height: 24.h),
                      // Custom Lists
                      if (provider.todoLists.isNotEmpty) ...[
                        Divider(color: Colors.grey.shade300),
                        SizedBox(height: 16.h),
                        ...provider.todoLists.map((list) => Padding(
                              padding: EdgeInsets.only(bottom: 16.h),
                              child: _buildCategoryTile(
                                icon: Icons.list_alt,
                                title: list.name,
                                count: 0, // Will be loaded dynamically
                                onTap: () => _navigateToCategory(
                                  TodoFilter.customList,
                                  list.name,
                                  listId: list.firebaseId,
                                ),
                                onLongPress: () => _showListOptions(
                                    list.firebaseId!, list.name),
                              ),
                            )),
                      ],
                      SizedBox(height: 80.h),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // Bottom Action Bar
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.checklist_rounded,
                  size: 28.w,
                  color: appFontColor,
                ),
                SizedBox(width: 8.w),
                Text(
                  translate('home.todo_list'),
                  style: GoogleFonts.poppins(
                    fontSize: 26.sp,
                    fontWeight: FontWeight.w500,
                    color: appFontColor,
                  ),
                  overflow: TextOverflow.visible,
                ),
              ],
            ),
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.search,
            size: 26.w,
            color: appFontColor,
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TodoSearchScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildUserProfile(String userName, String userImage) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          // Profile Image
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF1A1A53), width: 2),
            ),
            child: ClipOval(
              child: userImage.isNotEmpty
                  ? Image.memory(
                      Uri.parse('data:image/png;base64,$userImage')
                          .data!
                          .contentAsBytes(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
                    )
                  : _buildDefaultAvatar(),
            ),
          ),
          SizedBox(width: 12.w),
          // User Name
          Expanded(
            child: Text(
              userName.toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A53),
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.grey.shade300,
      child: Icon(
        Icons.person,
        size: 32.w,
        color: Colors.grey.shade600,
      ),
    );
  }

  Widget _buildCategoryTile({
    required IconData icon,
    required String title,
    required int count,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Row(
          children: [
            Icon(
              icon,
              size: 28.w,
              color: const Color(0xFF1A1A53),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A53),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            if (count > 0)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A53).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1A53),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // New List Button
            TextButton.icon(
              onPressed: _showAddListDialog,
              icon: Icon(
                Icons.add,
                color: const Color(0xFF2196F3),
                size: 24.w,
              ),
              label: Text(
                translate('todo.new_list'),
                style: GoogleFonts.poppins(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2196F3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToCategory(TodoFilter filter, String title, {String? listId}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TodoCategoryScreen(
          filter: filter,
          title: title,
          listId: listId,
        ),
      ),
    );
  }

  void _showAddListDialog() {
    showDialog(
      context: context,
      builder: (context) => const AddListDialog(),
    );
  }

  void _showListOptions(String listId, String listName) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(translate('common.edit')),
              onTap: () {
                Navigator.pop(context);
                _showEditListDialog(listId, listName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text(
                translate('common.delete'),
                style: const TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteList(listId);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditListDialog(String listId, String currentName) {
    showDialog(
      context: context,
      builder: (context) => AddListDialog(
        listId: listId,
        initialName: currentName,
      ),
    );
  }

  void _confirmDeleteList(String listId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(translate('todo.delete_list')),
        content: Text(translate('todo.delete_list_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(translate('common.cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<TodoFirebaseProvider>().deleteTodoList(listId);
            },
            child: Text(
              translate('common.delete'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
