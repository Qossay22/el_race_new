abstract class ProjectListEvent {}

class LoadProjectsEvent extends ProjectListEvent {
  final bool refresh;
  LoadProjectsEvent({this.refresh = false});
}

class LoadProjectsByPartnerEvent extends ProjectListEvent {
  final int partnerId;
  final bool refresh;

  LoadProjectsByPartnerEvent({required this.partnerId, this.refresh = false});
}

class LoadProjectsByFiltersEvent extends ProjectListEvent {
  final int? agreementId;
  final int? partnerId;
  final int? projectManagerId;
  final int? cityId;
  final String? keyword;
  final bool refresh;

  LoadProjectsByFiltersEvent({
    this.agreementId,
    this.partnerId,
    this.projectManagerId,
    this.cityId,
    this.keyword,
    this.refresh = false,
  });
}

class GetProjectAttachmentsEvent extends ProjectListEvent {
  final String projectId;
  final String? folderType;

  GetProjectAttachmentsEvent(this.projectId, {this.folderType});
}

class LoadMoreProjectsEvent extends ProjectListEvent {}
