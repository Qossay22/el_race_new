import '../data/note_model.dart';
import 'i_notes_repository.dart';

class NotesRepository implements INotesRepository {
  static final List<NoteModel> _dummyNotes = [
    NoteModel(
      id: '1',
      title: 'Meeting with Team',
      description: 'Discuss project requirements and timeline for the upcoming sprint.',
      date: DateTime.now().subtract(const Duration(days: 1)),
    ),
    NoteModel(
      id: '2',
      title: 'Flutter Development Tips',
      description: 'Remember to use proper state management and follow clean architecture principles.',
      date: DateTime.now().subtract(const Duration(days: 2)),
    ),
    NoteModel(
      id: '3',
      title: 'Shopping List',
      description: 'Groceries: milk, bread, eggs, fruits, vegetables for the week.',
      date: DateTime.now().subtract(const Duration(days: 3)),
    ),
    NoteModel(
      id: '4',
      title: 'Book Recommendations',
      description: 'Clean Code by Robert Martin, Effective Dart programming guidelines.',
      date: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  @override
  Future<List<NoteModel>> getNotes() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return List.from(_dummyNotes);
  }

  @override
  Future<void> addNote(NoteModel note) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _dummyNotes.insert(0, note);
  }

  @override
  Future<void> updateNote(NoteModel note) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _dummyNotes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      _dummyNotes[index] = note;
    }
  }

  @override
  Future<void> deleteNote(String noteId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _dummyNotes.removeWhere((note) => note.id == noteId);
  }
} 