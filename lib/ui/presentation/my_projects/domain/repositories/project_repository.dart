import 'package:el_race/ui/presentation/my_projects/domain/entities/attachment_entity.dart';
import 'package:el_race/ui/presentation/my_projects/domain/entities/partner_entity.dart';
import 'package:el_race/ui/presentation/my_projects/domain/entities/project_entity.dart';

abstract class ProjectRepository {
  Future<List<ProjectEntity>> getProjects();
  Future<List<AttachmentEntity>> getProjectAttachement(String projectID,
      {String? folderType});
  Future<List<PartnerEntity>> getPartnerProjects(
      {int? partnerId, String? keyword});
  Future<List<ProjectEntity>> getProjectsByPartnerId(int partnerId);
  Future<List<ProjectEntity>> getProjectsByFilters({
    int? agreementId,
    int? partnerId,
    int? projectManagerId,
    int? cityId,
    String? keyword,
  });
}
