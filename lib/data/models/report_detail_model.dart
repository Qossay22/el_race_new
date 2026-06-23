import 'package:el_race/data/models/report_detail_item.dart';
import 'package:hive/hive.dart';

part 'report_detail_model.g.dart';

@HiveType(typeId: 1)
class ReportDetailModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final Map<String, dynamic>? coverPage;

  @HiveField(2)
  final List<ReportDetailItem> items;
  @HiveField(3)
  final List<String> sections;

  ReportDetailModel({
    required this.id,
    required this.items,
    this.coverPage,
    required this.sections,
  });

  factory ReportDetailModel.fromJson(Map<String, dynamic> json) {
    return ReportDetailModel(
      id: json['id'] as String,
      coverPage: json['coverPage'] as Map<String, dynamic>,
      sections: json['sections'] as List<String>,
      items: (json['items'] as List<dynamic>)
          .map((e) => ReportDetailItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sections': sections,
      'coverPage': coverPage,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }

  ReportDetailModel copyWith({
    String? id,
    Map<String, dynamic>? coverPage,
    List<ReportDetailItem>? items,
    List<String>? sections,
  }) {
    return ReportDetailModel(
      id: id ?? this.id,
      sections: sections ?? this.sections,
      coverPage: coverPage ?? this.coverPage,
      items: items ?? this.items,
    );
  }
}
