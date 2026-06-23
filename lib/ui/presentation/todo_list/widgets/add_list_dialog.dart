import 'package:el_race/ui/presentation/todo_list/providers/todo_firebase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class AddListDialog extends StatefulWidget {
  final String? listId;
  final String? initialName;

  const AddListDialog({
    super.key,
    this.listId,
    this.initialName,
  });

  @override
  State<AddListDialog> createState() => _AddListDialogState();
}

class _AddListDialogState extends State<AddListDialog> {
  late final TextEditingController _nameController;
  bool _isLoading = false;

  bool get isEditing => widget.listId != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        isEditing ? translate('todo.edit_list') : translate('todo.new_list'),
        style: GoogleFonts.poppins(
          fontSize: 20.sp,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1A1A53),
        ),
      ),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: translate('todo.list_name_hint'),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            translate('common.cancel'),
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveList,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A1A53),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isLoading
              ? SizedBox(
                  width: 16.w,
                  height: 16.w,
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  isEditing
                      ? translate('common.save')
                      : translate('todo.create'),
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _saveList() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(translate('todo.list_name_required')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final provider = context.read<TodoFirebaseProvider>();
    bool success;

    if (isEditing) {
      final lists = provider.todoLists;
      final existingList =
          lists.firstWhere((l) => l.firebaseId == widget.listId);
      final updatedList = existingList.copyWith(name: name);
      success = await provider.updateTodoList(updatedList);
    } else {
      final newList = await provider.addTodoList(name: name);
      success = newList != null;
    }

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.pop(context);
    }
  }
}
