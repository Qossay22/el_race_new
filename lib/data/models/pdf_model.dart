import 'package:hive/hive.dart';

part 'pdf_model.g.dart';

@HiveType(typeId: 4)
class PdfModel {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final String path;

  @HiveField(2)
  final DateTime date;

  @HiveField(3)
  final String reportID;
  @HiveField(4)
  final String id;

  PdfModel({
    required this.name,
    required this.id,
    required this.path,
    required this.date,
    required this.reportID,
  });

  factory PdfModel.fromJson(Map<String, dynamic> json) {
    return PdfModel(
      name: json['name'] as String,
      id: json['id'] as String,
      reportID: json['reportID'] as String,
      path: json['path'] as String,
      date: DateTime.parse(json['date'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'id': id,
      'reportID': reportID,
      'path': path,
      'date': date.toIso8601String(),
    };
  }

  PdfModel copyWith({
    String? name,
    String? path,
    String? id,
    String? reportID,
    DateTime? date,
  }) {
    return PdfModel(
      name: name ?? this.name,
      id: id ?? this.id,
      reportID: reportID ?? this.reportID,
      path: path ?? this.path,
      date: date ?? this.date,
    );
  }
}
