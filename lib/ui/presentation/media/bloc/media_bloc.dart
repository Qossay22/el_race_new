import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/media_model.dart';
import '../data/content_model.dart';
import '../repository/i_media_repository.dart';

part 'media_event.dart';
part 'media_state.dart';

class MediaBloc extends Bloc<MediaEvent, MediaState> {
  final IMediaRepository mediaRepository;
  List<MediaModel> _allMedia = [];

  static MediaBloc get(BuildContext context) => BlocProvider.of(context);

  MediaBloc({required this.mediaRepository}) : super(MediaInitial()) {
    on<FetchMediaList>(_fetchMediaList);
    on<FetchContents>(_fetchContents);
    on<FetchMediaByType>(_fetchMediaByType);
    on<SearchMedia>(_searchMedia);
    on<AddMedia>(_addMedia);
    on<UpdateMedia>(_updateMedia);
    on<DeleteMedia>(_deleteMedia);
  }

  Future<void> _fetchMediaList(
    FetchMediaList event,
    Emitter<MediaState> emit,
  ) async {
    try {
      emit(MediaLoading());
      final mediaList = await mediaRepository.getMediaList();
      _allMedia = mediaList;
      emit(MediaLoaded(mediaList));
    } catch (e) {
      emit(MediaError(e.toString()));
    }
  }

  Future<void> _fetchContents(
    FetchContents event,
    Emitter<MediaState> emit,
  ) async {
    try {
      emit(MediaLoading());
      final contents = await mediaRepository.getContents();
      if (contents != null) {
        emit(ContentsLoaded(contents));
      } else {
        emit(const MediaError('Failed to fetch contents. Please check your connection.'));
      }
    } catch (e, stackTrace) {
      emit(MediaError('Error loading contents: ${e.toString()}'));
    }
  }

  Future<void> _searchMedia(
    SearchMedia event,
    Emitter<MediaState> emit,
  ) async {
    final query = event.keyword.trim().toLowerCase();
    if (query.isEmpty) {
      emit(MediaLoaded(_allMedia));
      return;
    }
    final filtered = _allMedia.where((m) {
      final name = m.name.toLowerCase();
      final typeLabel = m.isImage ? 'image' : 'video';
      final id = m.id.toLowerCase();
      final url = (m.url).toLowerCase();
      final s3 = (m.xWebUrl ?? '').toLowerCase();
      final ext = m.fileExtension.toLowerCase();
      return name.contains(query) ||
          typeLabel.contains(query) ||
          id.contains(query) ||
          url.contains(query) ||
          s3.contains(query) ||
          ext.contains(query);
    }).toList();
    emit(MediaLoaded(filtered));
  }

  Future<void> _fetchMediaByType(
    FetchMediaByType event,
    Emitter<MediaState> emit,
  ) async {
    try {
      emit(MediaLoading());
      final mediaList = await mediaRepository.getMediaByType(event.type);
      _allMedia = mediaList;
      emit(MediaLoaded(mediaList));
    } catch (e) {
      emit(MediaError(e.toString()));
    }
  }

  Future<void> _addMedia(
    AddMedia event,
    Emitter<MediaState> emit,
  ) async {
    try {
      emit(MediaActionLoading());
      await mediaRepository.addMedia(event.media);
      emit(MediaActionSuccess());
      add(const FetchMediaList());
    } catch (e) {
      emit(MediaActionError(e.toString()));
    }
  }

  Future<void> _updateMedia(
    UpdateMedia event,
    Emitter<MediaState> emit,
  ) async {
    try {
      emit(MediaActionLoading());
      await mediaRepository.updateMedia(event.media);
      emit(MediaActionSuccess());
      add(const FetchMediaList());
    } catch (e) {
      emit(MediaActionError(e.toString()));
    }
  }

  Future<void> _deleteMedia(
    DeleteMedia event,
    Emitter<MediaState> emit,
  ) async {
    try {
      emit(MediaActionLoading());
      await mediaRepository.deleteMedia(event.mediaId);
      emit(MediaActionSuccess());
      add(const FetchMediaList());
    } catch (e) {
      emit(MediaActionError(e.toString()));
    }
  }
}
