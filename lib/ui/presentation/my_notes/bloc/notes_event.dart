part of 'notes_bloc.dart';

sealed class NotesEvent extends Equatable {
  const NotesEvent();

  @override
  List<Object> get props => [];
}

final class FetchNotes extends NotesEvent {
  const FetchNotes();
}

final class AddNote extends NotesEvent {
  final NoteModel note;
  const AddNote(this.note);
  
  @override
  List<Object> get props => [note];
}

final class UpdateNote extends NotesEvent {
  final NoteModel note;
  const UpdateNote(this.note);
  
  @override
  List<Object> get props => [note];
}

final class DeleteNote extends NotesEvent {
  final String noteId;
  const DeleteNote(this.noteId);
  
  @override
  List<Object> get props => [noteId];
}
