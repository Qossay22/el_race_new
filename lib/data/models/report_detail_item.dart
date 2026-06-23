import 'package:hive/hive.dart';

part 'report_detail_item.g.dart';

@HiveType(typeId: 2)
class ReportDetailItem {
  @HiveField(0)
  final String? title;

  @HiveField(1)
  final String? description;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  final String type;

  @HiveField(4)
  final String? sectionName;

  @HiveField(5)
  final String updatedAt;

  @HiveField(6)
  final String? image;
  @HiveField(7)
  final String id;

  ReportDetailItem({
    this.title,
    this.description,
    required this.id,
    required this.createdAt,
    required this.type,
    this.sectionName,
    required this.updatedAt,
    this.image,
  });

  factory ReportDetailItem.fromJson(Map<String, dynamic> json) {
    return ReportDetailItem(
      title: json['title'] as String?,
      id: json['id'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      type: json['type'] as String,
      sectionName: json['sectionName'] as String?,
      updatedAt: json['updatedAt'] as String,
      image: json['image'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'type': type,
      'sectionName': sectionName,
      'updatedAt': updatedAt,
      'image': image,
    };
  }

  ReportDetailItem copyWith({
    String? title,
    String? description,
    DateTime? createdAt,
    String? type,
    String? sectionName,
    String? updatedAt,
    String? image,
    String? id,
  }) {
    return ReportDetailItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      type: type ?? this.type,
      sectionName: sectionName ?? this.sectionName,
      updatedAt: updatedAt ?? this.updatedAt,
      image: image ?? this.image,
    );
  }
}
