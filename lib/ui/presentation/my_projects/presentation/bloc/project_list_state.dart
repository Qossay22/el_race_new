abstract class ProjectListState {
  const ProjectListState();
}

class ProjectListInitial extends ProjectListState {}

class ProjectListLoading extends ProjectListState {}

class ProjectListLoaded extends ProjectListState {
  ProjectListLoaded();
}

class ProjectListError extends ProjectListState {
  final String message;

  ProjectListError(this.message);
}

class ProjectAttachmentsLoading extends ProjectListState {}

class ProjectAttachmentsLoaded extends ProjectListState {
  const ProjectAttachmentsLoaded();
}

class ProjectAttachmentsError extends ProjectListState {
  final String message;

  const ProjectAttachmentsError(this.message);
}
