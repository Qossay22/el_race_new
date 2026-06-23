part of 'notes_bloc.dart';

sealed class NotesState extends Equatable {
  const NotesState();

  @override
  List<Object> get props => [];
}

final class NotesInitial extends NotesState {}

final class NotesLoading extends NotesState {}

final class NotesLoaded extends NotesState {
  final List<NoteModel> notes;
  const NotesLoaded(this.notes);

  @override
  List<Object> get props => [notes];
}

final class NotesError extends NotesState {
  final String message;
  const NotesError(this.message);

  @override
  List<Object> get props => [message];
}

final class NoteActionLoading extends NotesState {}

final class NoteActionSuccess extends NotesState {}

final class NoteActionError extends NotesState {
  final String message;
  const NoteActionError(this.message);

  @override
  List<Object> get props => [message];
}


