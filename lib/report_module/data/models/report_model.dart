import 'package:hive/hive.dart';

part 'report_model.g.dart';

@HiveType(typeId: 105) // <-- make sure this is unique across your app
class ReportModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  /// Optional: to be removed in the future
  @HiveField(2)
  final String companyId;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final String folderId;

  @HiveField(5)
  final DateTime updatedAt;

  @HiveField(6)
  final String? reportType;

  ReportModel({
    required this.id,
    required this.name,
    required this.companyId,
    required this.folderId,
    required this.createdAt,
    required this.updatedAt,
    this.reportType,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'].toString(),
      name: (json['name'] ?? '').toString(),
      folderId: (json['folder_id'] ?? '').toString(),
      companyId: (json['company_id'] == false || json['company_id'] == null)
          ? ''
          : json['company_id'].toString(),
      createdAt: DateTime.tryParse(
              (json['created_at'] ?? json['create_at'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse((json['updated_at'] ??
                  json['created_at'] ??
                  json['create_at'] ??
                  '')
              .toString()) ??
          DateTime.now(),
      reportType: (json['report_type'] != null && json['report_type'] != false)
          ? json['report_type'].toString()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'company_id': companyId,
      'folder_id': folderId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'report_type': reportType,
    };
  }
}
