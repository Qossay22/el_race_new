import 'package:hive/hive.dart';

part 'report_model.g.dart';

@HiveType(typeId: 0)
class ReportModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  final DateTime updatedAt;

  @HiveField(4)
  final int report; // 1 for report, 2 for folder

  @HiveField(5)
  final String? description;

  @HiveField(6)
  final String? folderID;

  @HiveField(7)
  final String? companyID;

  ReportModel({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.report,
    required this.companyID,
    this.description,
    this.folderID,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] as String,
      companyID: json['companyID'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      report: json['report'] as int,
      description: json['description'] as String?,
      folderID: json['folderID'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'report': report,
      'description': description,
      'folderID': folderID,
    };
  }

  ReportModel copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? report,
    String? description,
    String? folderID,
  }) {
    return ReportModel(
      id: id ?? this.id,
      name: name ?? this.name,
      companyID: companyID ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      report: report ?? this.report,
      description: description ?? this.description,
      folderID: folderID ?? this.folderID,
    );
  }
}
