import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../bloc/notes_bloc.dart';
import '../data/note_model.dart';
import '../widgets/notes_header_widget.dart';

class AddNoteScreen extends StatefulWidget {
  const AddNoteScreen({super.key});

  @override
  State<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen> {
  final TextEditingController _noteController = TextEditingController();
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
    _noteController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _saveNote() {
    final noteText = _noteController.text.trim();
    if (noteText.isNotEmpty) {
      final lines = noteText.split('\n');
      final title = lines.first.trim();
      final description = lines.length > 1 
          ? lines.skip(1).join('\n').trim() 
          : title;
      
      final note = NoteModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title.isEmpty ? 'Untitled' : title,
        description: description.isEmpty ? title : description,
        date: DateTime.now(),
      );
      
      context.read<NotesBloc>().add(AddNote(note));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentDateTime = DateFormat('EEEE, MMMM dd, yyyy • hh:mm a').format(DateTime.now());
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const HeaderWidget(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          NotesHeaderWidget(
            onBackPressed: () {
              if (_noteController.text.trim().isNotEmpty) {
                _showSaveDialog();
              } else {
                Navigator.of(context).pop();
              }
            },
            showAddButton: false,
          ),
          Text(
            currentDateTime,
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              color: const Color(0xff313131),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: TextField(
                controller: _noteController,
                focusNode: _focusNode,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: GoogleFonts.poppins(
                  fontSize: 16.sp,
                  height: 1.5,
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Start typing your note...',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 16.sp,
                    color: const Color(0xff313131),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                onChanged: (value) {
                  setState(() {});
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _noteController.text.trim().isNotEmpty
          ? FloatingActionButton(
              onPressed: _saveNote,
              backgroundColor: appFontColor,
              child: const Icon(
                Icons.check,
                color: Colors.white,
              ),
            )
          : null,
    );
  }

  void _showSaveDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save Note?'),
        content: const Text('Do you want to save your note before leaving?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _saveNote();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
} 