import 'package:hive/hive.dart';
import 'package:el_race/report_module/data/models/report_model.dart';
import 'package:el_race/report_module/data/models/report_item_model.dart';
import 'package:el_race/report_module/data/models/cover_page_model.dart';

part 'report_detail_model.g.dart';

@HiveType(typeId: 103) // <-- make sure this is unique across your app
class ReportDetailModel extends HiveObject {
  @HiveField(0)
  final ReportModel report;

  @HiveField(1)
  final List<ReportItemModel> reportItems;

  @HiveField(2)
  final CoverPageModel? coverPage;

  ReportDetailModel({
    required this.report,
    required this.coverPage,
    required this.reportItems,
  });

  factory ReportDetailModel.fromJson(Map<String, dynamic> json) {
    final reportItems = json['report_items'];
    final reportId = json['report'] != null ? json['report']['id'] : '';
    return ReportDetailModel(
      report: ReportModel.fromJson(json['report']),
      coverPage: json['cover_page'] != null
          ? CoverPageModel.fromJson(json['cover_page'])
          : null,
      reportItems: reportItems != null && reportItems is List
          ? reportItems
              .map((item) => ReportItemModel.fromJson(item as Map<String, dynamic>, reportId))
              .toList()
          : <ReportItemModel>[],
    );
  }

  Map<String, dynamic> toJson() => {
        'report': report, // if ReportModel has toJson(), use report.toJson()
        'cover_page': coverPage, // idem: coverPage?.toJson()
        'report_items': reportItems, // map each to .toJson() if available
      };

  ReportDetailModel copyWith({
    ReportModel? report,
    CoverPageModel? coverPage,
    List<ReportItemModel>? reportItems,
  }) {
    return ReportDetailModel(
      report: report ?? this.report,
      coverPage: coverPage,
      reportItems: reportItems ?? this.reportItems,
    );
  }
}
