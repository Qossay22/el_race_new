import 'package:el_race/ui/presentation/home_screen/screens/main_screens.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:el_race/utils/Util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';

import '../bloc/notes_bloc.dart';
import '../data/note_model.dart';
import '../widgets/note_item_widget.dart';
import '../widgets/notes_header_widget.dart';
import 'add_note_screen.dart';

class MyNotesScreen extends StatefulWidget {
  const MyNotesScreen({super.key});

  @override
  State<MyNotesScreen> createState() => _MyNotesScreenState();
}

class _MyNotesScreenState extends State<MyNotesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<NotesBloc>().add(const FetchNotes());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const HeaderWidget(),
      bottomNavigationBar: const CustomBottomNavBar(isMain: false),
      body: BlocConsumer<NotesBloc, NotesState>(
        listener: (context, state) {
          if (state is NotesError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
          if (state is NoteActionError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
          if (state is NoteActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Note action completed successfully')),
            );
          }
        },
        builder: (context, state) {
          return Builder(
            builder: (context) {
              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 14.w,
                  right: 14.w,
                  bottom: kBottomNavigationBarHeight + context.systemBottomInset + 16,
                ),
                child: Column(
              children: [
                NotesHeaderWidget(
                  onAddPressed: () {
                    Util.pushPage(const AddNoteScreen(), context);
                  },
                ),
                if (state is NotesLoading)
                  const Padding(
                    padding: EdgeInsets.all(50.0),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (state is NotesLoaded)
                  state.notes.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(50.0),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.note_alt_outlined,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No notes yet',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Tap the + button to add your first note',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            searchWidget(state.notes),
                            RefreshIndicator(
                              onRefresh: () async {
                                context
                                    .read<NotesBloc>()
                                    .add(const FetchNotes());
                              },
                              child: ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: searchlist.isNotEmpty
                                    ? searchlist.length
                                    : state.notes.length,
                                itemBuilder: (context, index) {
                                  final note = searchlist.isNotEmpty
                                      ? searchlist[index]
                                      : state.notes[index];
                                  return NoteItemWidget(
                                    note: note,
                                    onTap: () {
                                      // _showNoteDetailsDialog(context, note);
                                    },
                                    onLongPress: () {
                                      // _showDeleteConfirmation(context, note.id);
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        )
                else if (state is NotesError)
                  Padding(
                    padding: const EdgeInsets.all(50.0),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading notes',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            state.message,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              context.read<NotesBloc>().add(const FetchNotes());
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
              );
            },
          );
        },
      ),
    );
  }

  List<NoteModel> searchlist = [];
  Widget searchWidget(List<NoteModel> list) {
    return Container(
      height: 40,
      width: 250,
      decoration: BoxDecoration(
          border: Border.all(
            color: Colors.grey,
          ),
          // boxShadow: const [
          //   BoxShadow(color: darkGrey, offset: Offset(2, 4), blurRadius: 12)
          // ],
          borderRadius: BorderRadius.circular(25),
          gradient: const LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [
                Color(0xff999999),
                Color(0xffFFFFFF),
              ])),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: TextFormField(
          onChanged: (value) {
            searchlist.clear();
            final filtered = list
                .where((note) =>
                    note.title.toLowerCase().contains(value.toLowerCase()))
                .toList();
            setState(() {
              searchlist.addAll(filtered);
              print(searchlist.length);
            });
          },
          style: const TextStyle(
            color: Color(0xFF1A1A53),
            fontSize: 15,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w400,
          ),
          decoration: InputDecoration(
              border: InputBorder.none,
              // hintText: 'SEARCH CONTACT',
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              hintStyle: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF1A1A53)),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset(
                  'assets/png/menu.png',
                  color: Colors.black,
                  width: 10,
                  height: 10,
                ),
              ),
              suffixIcon: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.asset(
                    "assets/png/search_icon.png",
                    width: 14,
                    height: 14,
                    color: Colors.black,
                  ))),
        ),
      ),
    );
  }

  void _showAddNoteDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(translate('notes.add_new_note')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: translate('notes.title'),
                border: const OutlineInputBorder(),
              ),
              maxLines: null,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: translate('notes.description'),
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(translate('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty &&
                  descriptionController.text.trim().isNotEmpty) {
                final note = NoteModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: titleController.text.trim(),
                  description: descriptionController.text.trim(),
                  date: DateTime.now(),
                );
                context.read<NotesBloc>().add(AddNote(note));
                Navigator.of(dialogContext).pop();
              }
            },
            child: Text(translate('common.add')),
          ),
        ],
      ),
    );
  }

  void _showNoteDetailsDialog(BuildContext context, NoteModel note) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(note.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              translate('notes.created', args: {
                'date': '${note.date.day}/${note.date.month}/${note.date.year}'
              }),
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Text(note.description),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(translate('common.close')),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String noteId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(translate('notes.delete_note')),
        content: Text(translate('notes.delete_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(translate('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<NotesBloc>().add(DeleteNote(noteId));
              Navigator.of(dialogContext).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(translate('common.delete')),
          ),
        ],
      ),
    );
  }
}
