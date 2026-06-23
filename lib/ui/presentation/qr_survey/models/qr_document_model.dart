class QrDocumentModel {
  final int id;
  final String name;
  final String url;
  final String? description;
  final String? fileType;
  final DateTime? uploadDate;

  QrDocumentModel({
    required this.id,
    required this.name,
    required this.url,
    this.description,
    this.fileType,
    this.uploadDate,
  });

  factory QrDocumentModel.fromJson(Map<String, dynamic> json) {
    return QrDocumentModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      url: json['url'] ?? json['file_url'] ?? '',
      description: json['description'],
      fileType: json['file_type'] ?? 'pdf',
      uploadDate: json['upload_date'] != null
          ? DateTime.tryParse(json['upload_date'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'description': description,
      'file_type': fileType,
      'upload_date': uploadDate?.toIso8601String(),
    };
  }

  bool get isPdf => fileType?.toLowerCase() == 'pdf';
}
