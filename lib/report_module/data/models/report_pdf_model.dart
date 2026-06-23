class ReportPdfModel {
  final String fileId;  // hash used as unique identifier e.g. 279fd159...
  final String id;     // integer id from /reports/list, used for delete/update
  final String reportId;
  final String fileName;
  final String createdAt;
  final String reportLink;

  ReportPdfModel({
    required this.fileId,
    this.id = '',
    this.reportId = '',
    required this.fileName,
    required this.createdAt,
    required this.reportLink,
  });

  factory ReportPdfModel.fromJson(Map<String, dynamic> json) {
    return ReportPdfModel(
      fileId: json['file_id']?.toString() ?? '',
      id: (json['id'] ?? '').toString(),
      reportId: (json['report_id'] ?? json['reportId'] ?? '').toString(),
      fileName: json['file_name']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      reportLink: json['report_link']?.toString() ?? '',
    );
  }

  ReportPdfModel copyWith({String? id}) => ReportPdfModel(
        fileId: fileId,
        id: id ?? this.id,
        reportId: reportId,
        fileName: fileName,
        createdAt: createdAt,
        reportLink: reportLink,
      );
}
