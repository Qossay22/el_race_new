import 'package:el_race/ui/presentation/my_projects/domain/entities/project_entity.dart';

class ProjectModel extends ProjectEntity {
  const ProjectModel({
    required super.projectId,
    required super.partnerId,
    required super.agreementId,
    required super.woRefNo,
    required super.name,
    required super.woAmount,
    required super.projectStatus,
    required super.date,
    required super.dateStart,
    super.differenceDays,
    super.projectManagerPhoto,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    // Fix malformed photo URL from API (erp.elrace.compublic -> erp.elrace.com/public)
    String? projectManagerPhoto = json['project_manager_photo'] as String?;
    if (projectManagerPhoto != null &&
        projectManagerPhoto.contains('erp.elrace.compublic')) {
      projectManagerPhoto = projectManagerPhoto.replaceAll(
          'erp.elrace.compublic', 'erp.elrace.com/public');
    }

    return ProjectModel(
      projectId: json['project_id'] ?? 0,
      partnerId: json['partner_id'].toString(),
      agreementId: json['agreement_id'].toString(),
      woRefNo: json['wo_ref_no'] ?? '',
      name: json['name']?.toString() ?? '',
      woAmount: (json['wo_amount'] as num?)?.toDouble() ?? 0.0,
      projectStatus: json['project_status']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      dateStart: json['date_start']?.toString() ?? '',
      differenceDays: json['difference_days'] as int?,
      projectManagerPhoto: projectManagerPhoto,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'project_id': projectId,
      'partner_id': partnerId,
      'agreement_id': agreementId,
      'wo_ref_no': woRefNo,
      'name': name,
      'wo_amount': woAmount,
      'project_status': projectStatus,
      'date': date,
      'date_start': dateStart,
      'difference_days': differenceDays,
      'project_manager_photo': projectManagerPhoto,
    };
  }
}
