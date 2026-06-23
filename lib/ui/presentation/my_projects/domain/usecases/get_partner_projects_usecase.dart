import 'package:el_race/ui/presentation/my_projects/domain/entities/partner_entity.dart';
import 'package:el_race/ui/presentation/my_projects/domain/repositories/project_repository.dart';

class GetPartnerProjectsUseCase {
  final ProjectRepository repository;

  GetPartnerProjectsUseCase({required this.repository});

  Future<List<PartnerEntity>> call({int? partnerId, String? keyword}) async {
    return await repository.getPartnerProjects(
        partnerId: partnerId, keyword: keyword);
  }
}
