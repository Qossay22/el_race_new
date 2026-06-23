import 'package:el_race/ui/presentation/my_projects/domain/entities/project_entity.dart';
import 'package:el_race/ui/presentation/my_projects/domain/repositories/project_repository.dart';

class GetProjectsByFiltersUseCase {
  final ProjectRepository repository;

  GetProjectsByFiltersUseCase({required this.repository});

  Future<List<ProjectEntity>> call({
    int? agreementId,
    int? partnerId,
    int? projectManagerId,
    int? cityId,
    String? keyword,
  }) async {
    return repository.getProjectsByFilters(
      agreementId: agreementId,
      partnerId: partnerId,
      projectManagerId: projectManagerId,
      cityId: cityId,
      keyword: keyword,
    );
  }
}
