class QrMediaModel {
  final int id;
  final String name;
  final String url;
  final String? thumbnailUrl;
  final String mediaType; // 'video' or 'image'
  final String? description;
  final Duration? duration;
  final DateTime? uploadDate;

  QrMediaModel({
    required this.id,
    required this.name,
    required this.url,
    this.thumbnailUrl,
    required this.mediaType,
    this.description,
    this.duration,
    this.uploadDate,
  });

  factory QrMediaModel.fromJson(Map<String, dynamic> json) {
    return QrMediaModel(
      id: json['id'] ?? 0,
      name: json['media_name'] ?? json['name'] ?? '',
      url: json['file_link'] ?? json['url'] ?? json['file_url'] ?? '',
      thumbnailUrl: json['thumbnail_url'] ?? json['thumbnail'],
      mediaType: json['media_type'] ?? json['type'] ?? 'video',
      description: json['project_name'] ?? json['description'],
      duration:
          json['duration'] != null ? Duration(seconds: json['duration']) : null,
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
      'thumbnail_url': thumbnailUrl,
      'media_type': mediaType,
      'description': description,
      'duration': duration?.inSeconds,
      'upload_date': uploadDate?.toIso8601String(),
    };
  }

  bool get isVideo => mediaType.toLowerCase() == 'video';
  bool get isImage => mediaType.toLowerCase() == 'image';
  bool get isYouTube => url.contains('youtube.com') || url.contains('youtu.be');
}
