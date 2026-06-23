import 'package:el_race/ui/presentation/my_projects/data/models/user_project_model.dart';

class UserProjectsResponse {
  final bool success;
  final int employeeId;
  final List<UserProjectModel> projects;

  const UserProjectsResponse({
    required this.success,
    required this.employeeId,
    required this.projects,
  });
}
