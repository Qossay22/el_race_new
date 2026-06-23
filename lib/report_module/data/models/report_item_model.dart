import 'package:hive/hive.dart';

part 'report_item_model.g.dart';

@HiveType(typeId: 104) // <-- ensure this is unique across your app
class ReportItemModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String reportId;

  @HiveField(2)
  final String type;

  /// If this is a file path or base64 string, String is fine.
  /// If you later switch to binary bytes, change to Uint8List.
  @HiveField(3)
  final String image;

  @HiveField(4)
  final String location;

  @HiveField(5)
  final String description;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final DateTime updatedAt;

  ReportItemModel({
    required this.id,
    required this.reportId,
    required this.type,
    required this.image,
    required this.location,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReportItemModel.fromJson(
      Map<String, dynamic> json, dynamic reportID) {
    return ReportItemModel(
      id: (json['item_id'] ?? json['id'] ?? '').toString(),
      reportId: reportID.toString(),
      type: (json['type'] ?? 'image').toString(),
      image: (json['item_data'] ?? json['image'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'report_id': reportId,
      'type': type,
      'image': image,
      'location': location,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ReportItemModel copyWith({
    String? itemId, // backward-compatible alias for `id`
    String? reportId,
    String? type,
    String? image, // backward-compatible alias for `image`
    String? location,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReportItemModel(
      id: itemId ?? id,
      reportId: reportId ?? this.reportId,
      type: type ?? this.type,
      image: image ?? this.image,
      location: location ?? this.location,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
