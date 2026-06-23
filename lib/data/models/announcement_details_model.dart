/// Model for announcement details (banner/carousel use)
/// Used for displaying detailed announcement information on home banners
class AnnouncementDetailsModel {
  final int id;
  final String title;
  final String announcementText;
  final bool hasAttachment;
  final String? attachmentUrl;

  AnnouncementDetailsModel({
    required this.id,
    required this.title,
    required this.announcementText,
    required this.hasAttachment,
    this.attachmentUrl,
  });

  /// Factory constructor to parse from JSON response
  factory AnnouncementDetailsModel.fromJson(Map<String, dynamic> json) {
    final rawAttachmentUrl = json['attachment_url'] ?? json['file_url'];

    return AnnouncementDetailsModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      title: _firstNonEmptyString(json['title'], json['name']),
      announcementText:
          _firstNonEmptyString(json['announcement_text'], json['description']),
      hasAttachment:
          _toBool(json['has_attachment']) || _toBool(json['has_file']),
      attachmentUrl: _normalizeAttachmentUrl(rawAttachmentUrl),
    );
  }

  static String _firstNonEmptyString(dynamic first, dynamic second) {
    final firstValue = first?.toString().trim() ?? '';
    if (firstValue.isNotEmpty) return firstValue;
    return second?.toString().trim() ?? '';
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  static String? _normalizeAttachmentUrl(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    if (raw.startsWith('/')) {
      return 'https://erp.elrace.com$raw';
    }
    return raw;
  }

  /// Convert model to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'announcement_text': announcementText,
      'has_attachment': hasAttachment,
      'attachment_url': attachmentUrl,
    };
  }

  /// Copy with method for immutability
  AnnouncementDetailsModel copyWith({
    int? id,
    String? title,
    String? announcementText,
    bool? hasAttachment,
    String? attachmentUrl,
  }) {
    return AnnouncementDetailsModel(
      id: id ?? this.id,
      title: title ?? this.title,
      announcementText: announcementText ?? this.announcementText,
      hasAttachment: hasAttachment ?? this.hasAttachment,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
    );
  }

  @override
  String toString() {
    return 'AnnouncementDetailsModel(id: $id, title: $title, announcementText: ${announcementText.length > 50 ? '${announcementText.substring(0, 50)}...' : announcementText}, hasAttachment: $hasAttachment, attachmentUrl: $attachmentUrl)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AnnouncementDetailsModel &&
        other.id == id &&
        other.title == title &&
        other.announcementText == announcementText &&
        other.hasAttachment == hasAttachment &&
        other.attachmentUrl == attachmentUrl;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        announcementText.hashCode ^
        hasAttachment.hashCode ^
        (attachmentUrl?.hashCode ?? 0);
  }
}
