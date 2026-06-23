import 'package:el_race/ui/presentation/my_projects/data/models/project_model.dart';
import 'package:el_race/ui/presentation/my_projects/domain/entities/partner_entity.dart';

class PartnerModel extends PartnerEntity {
  final List<ProjectModel> projects;

  const PartnerModel({
    required super.id,
    required super.name,
    required super.icon,
    required super.workOrdersCount,
    required this.projects,
  });

  factory PartnerModel.fromJson(Map<String, dynamic> json) {
    final projectsList = json['projects'] as List<dynamic>? ?? [];
    final projects =
        projectsList.map((project) => ProjectModel.fromJson(project)).toList();

    // Fix malformed photo URL from API (erp.elrace.compublic -> erp.elrace.com/public)
    String? iconUrl =
        json['icon']?.toString() ?? json['partner_photo']?.toString();
    if (iconUrl != null && iconUrl.contains('erp.elrace.compublic')) {
      iconUrl =
          iconUrl.replaceAll('erp.elrace.compublic', 'erp.elrace.com/public');
    }

    return PartnerModel(
      id: json['partner_id'] ?? 0,
      name: json['partner_name'] ?? '',
      icon: iconUrl,
      workOrdersCount: projects.length,
      projects: projects,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'partner_id': id,
      'partner_name': name,
      'icon': icon,
      'projects': projects.map((project) => project.toJson()).toList(),
    };
  }
}
