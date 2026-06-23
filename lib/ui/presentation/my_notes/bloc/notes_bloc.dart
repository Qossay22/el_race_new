import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/note_model.dart';
import '../repository/i_notes_repository.dart';

part 'notes_event.dart';
part 'notes_state.dart';

class NotesBloc extends Bloc<NotesEvent, NotesState> {
  final INotesRepository notesRepository;

  static NotesBloc get(BuildContext context) => BlocProvider.of(context);

  NotesBloc({required this.notesRepository}) : super(NotesInitial()) {
    on<FetchNotes>(_fetchNotes);
    on<AddNote>(_addNote);
    on<UpdateNote>(_updateNote);
    on<DeleteNote>(_deleteNote);
  }

  Future<void> _fetchNotes(
    FetchNotes event,
    Emitter<NotesState> emit,
  ) async {
    try {
      emit(NotesLoading());
      final notes = await notesRepository.getNotes();
      emit(NotesLoaded(notes));
    } catch (e) {
      emit(NotesError(e.toString()));
    }
  }

  Future<void> _addNote(
    AddNote event,
    Emitter<NotesState> emit,
  ) async {
    try {
      emit(NoteActionLoading());
      await notesRepository.addNote(event.note);
      emit(NoteActionSuccess());
      add(const FetchNotes());
    } catch (e) {
      emit(NoteActionError(e.toString()));
    }
  }

  Future<void> _updateNote(
    UpdateNote event,
    Emitter<NotesState> emit,
  ) async {
    try {
      emit(NoteActionLoading());
      await notesRepository.updateNote(event.note);
      emit(NoteActionSuccess());
      add(const FetchNotes());
    } catch (e) {
      emit(NoteActionError(e.toString()));
    }
  }

  Future<void> _deleteNote(
    DeleteNote event,
    Emitter<NotesState> emit,
  ) async {
    try {
      emit(NoteActionLoading());
      await notesRepository.deleteNote(event.noteId);
      emit(NoteActionSuccess());
      add(const FetchNotes());
    } catch (e) {
      emit(NoteActionError(e.toString()));
    }
  }
} 