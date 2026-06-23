import '../data/note_model.dart';

abstract class INotesRepository {
  Future<List<NoteModel>> getNotes();
  Future<void> addNote(NoteModel note);
  Future<void> updateNote(NoteModel note);
  Future<void> deleteNote(String noteId);
} 