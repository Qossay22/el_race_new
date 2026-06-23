import 'package:el_race/ui/presentation/my_projects/data/datasources/project_remote_datasource.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/partner_model.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_model.dart';
import 'package:el_race/ui/presentation/my_projects/domain/entities/attachment_entity.dart';
import 'package:el_race/ui/presentation/my_projects/domain/entities/partner_entity.dart';
import 'package:el_race/ui/presentation/my_projects/domain/entities/project_entity.dart';
import 'package:el_race/ui/presentation/my_projects/domain/repositories/project_repository.dart';

class ProjectRepositoryImpl implements ProjectRepository {
  final ProjectRemoteDataSource remoteDataSource;

  ProjectRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<ProjectEntity>> getProjects() async {
    final List<ProjectModel> models = await remoteDataSource.fetchProjects();
    return models
        .map((model) => ProjectEntity(
              projectId: model.projectId,
              partnerId: model.partnerId,
              agreementId: model.agreementId,
              woRefNo: model.woRefNo,
              name: model.name,
              woAmount: model.woAmount,
              projectStatus: model.projectStatus,
              date: model.date,
              dateStart: model.dateStart,
            ))
        .toList();
  }

  @override
  Future<List<AttachmentEntity>> getProjectAttachement(String projectID,
      {String? folderType}) async {
    final List<AttachmentEntity> models = await remoteDataSource
        .fetchProjectAttachments(projectID, folderType: folderType);
    return models
        .map((model) => AttachmentEntity(
              name: model.name,
              type: model.type,
              url: model.url,
              source: model.source,
              isFile: model.isFile,
              folder: model.folder,
              id: model.id,
            ))
        .toList();
  }

  @override
  Future<List<PartnerEntity>> getPartnerProjects(
      {int? partnerId, String? keyword}) async {
    final List<PartnerModel> models =
        await remoteDataSource.fetchPartnerProjects(
      partnerId: partnerId,
      keyword: keyword,
    );
    return models
        .map((model) => PartnerEntity(
              id: model.id,
              name: model.name,
              icon: model.icon,
              workOrdersCount: model.workOrdersCount,
            ))
        .toList();
  }

  @override
  Future<List<ProjectEntity>> getProjectsByPartnerId(int partnerId) async {
    final List<ProjectModel> models =
        await remoteDataSource.fetchProjectsByPartnerId(partnerId);
    return models
        .map((model) => ProjectEntity(
              projectId: model.projectId,
              partnerId: model.partnerId,
              agreementId: model.agreementId,
              woRefNo: model.woRefNo,
              name: model.name,
              woAmount: model.woAmount,
              projectStatus: model.projectStatus,
              date: model.date,
              dateStart: model.dateStart,
              differenceDays: model.differenceDays,
              projectManagerPhoto: model.projectManagerPhoto,
            ))
        .toList();
  }

  @override
  Future<List<ProjectEntity>> getProjectsByFilters({
    int? agreementId,
    int? partnerId,
    int? projectManagerId,
    int? cityId,
    String? keyword,
  }) async {
    final List<ProjectModel> models =
        await remoteDataSource.fetchProjectsByFilters(
      agreementId: agreementId,
      partnerId: partnerId,
      projectManagerId: projectManagerId,
      cityId: cityId,
      keyword: keyword,
    );

    return models
        .map((model) => ProjectEntity(
              projectId: model.projectId,
              partnerId: model.partnerId,
              agreementId: model.agreementId,
              woRefNo: model.woRefNo,
              name: model.name,
              woAmount: model.woAmount,
              projectStatus: model.projectStatus,
              date: model.date,
              dateStart: model.dateStart,
              differenceDays: model.differenceDays,
              projectManagerPhoto: model.projectManagerPhoto,
            ))
        .toList();
  }
}
