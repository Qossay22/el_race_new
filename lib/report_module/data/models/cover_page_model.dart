import 'package:hive/hive.dart';

part 'cover_page_model.g.dart'; // Needed for Hive type adapter generation

@HiveType(typeId: 102) // Change typeId for each model you create
class CoverPageModel extends HiveObject {
  @HiveField(0)
  final String empId;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String? description;

  @HiveField(3)
  final String? id; // for update

  @HiveField(4)
  final DateTime? createdAt;

  @HiveField(5)
  final DateTime? updatedAt;

  CoverPageModel({
    required this.empId,
    required this.title,
    this.description,
    this.id,
    this.createdAt,
    this.updatedAt,
  });

  factory CoverPageModel.fromJson(Map<String, dynamic> json) => CoverPageModel(
        empId: json['emp_id'] ?? '',
        title: json['title'],
        description: json['description'],
        id: json['id'],
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'])
            : null,
      );

  Map<String, dynamic> toJson() => {
        'emp_id': empId,
        'title': title,
        'description': description,
        'id': id,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  CoverPageModel copyWith({
    String? empId,
    String? title,
    String? description,
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CoverPageModel(
      empId: empId ?? this.empId,
      title: title ?? this.title,
      description: description ?? this.description,
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
