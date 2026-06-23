import 'package:el_race/ui/presentation/my_projects/domain/entities/attachment_entity.dart';
import 'package:el_race/ui/presentation/my_projects/domain/entities/project_entity.dart';
import 'package:el_race/ui/presentation/my_projects/domain/repositories/project_repository.dart';

class GetProjectsUseCase {
  final ProjectRepository repository;

  const GetProjectsUseCase({required this.repository});

  Future<List<ProjectEntity>> call() async {
    return await repository.getProjects();
  }
}

class GetProjectAttachmentsUseCase {
  final ProjectRepository repository;

  const GetProjectAttachmentsUseCase({required this.repository});

  Future<List<AttachmentEntity>> call(String projectID, {String? folderType}) async {
    return await repository.getProjectAttachement(projectID, folderType: folderType);
  }
}