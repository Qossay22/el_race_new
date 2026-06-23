import 'package:el_race/ui/presentation/my_projects/domain/entities/project_entity.dart';
import 'package:el_race/ui/presentation/my_projects/domain/repositories/project_repository.dart';

class GetProjectsByPartnerUseCase {
  final ProjectRepository repository;

  GetProjectsByPartnerUseCase({required this.repository});

  Future<List<ProjectEntity>> call(int partnerId) async {
    return await repository.getProjectsByPartnerId(partnerId);
  }
}
