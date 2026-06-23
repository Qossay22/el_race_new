part of 'media_bloc.dart';

sealed class MediaState extends Equatable {
  const MediaState();

  @override
  List<Object> get props => [];
}

final class MediaInitial extends MediaState {}

final class MediaLoading extends MediaState {}

final class MediaLoaded extends MediaState {
  final List<MediaModel> mediaList;
  const MediaLoaded(this.mediaList);

  @override
  List<Object> get props => [mediaList];
}

final class ContentsLoaded extends MediaState {
  final ContentsResponse contents;
  const ContentsLoaded(this.contents);

  @override
  List<Object> get props => [contents];
}

final class MediaError extends MediaState {
  final String message;
  const MediaError(this.message);

  @override
  List<Object> get props => [message];
}

final class MediaActionLoading extends MediaState {}

final class MediaActionSuccess extends MediaState {}

final class MediaActionError extends MediaState {
  final String message;
  const MediaActionError(this.message);

  @override
  List<Object> get props => [message];
} 