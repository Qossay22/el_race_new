/// Model for announcements/news/circulars
/// Category mapping:
/// 1 → News
/// 2 → Announcements
/// 3 → Circulars
class AnnouncementModel {
  final int id;
  final String name;
  final String description;
  final bool hasAttachment;
  final String? attachmentUrl;

  AnnouncementModel({
    required this.id,
    required this.name,
    required this.description,
    required this.hasAttachment,
    this.attachmentUrl,
  });

  /// Factory constructor to parse from JSON response
  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    final rawAttachmentUrl = json['attachment_url'] ?? json['file_url'];

    return AnnouncementModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      name: _firstNonEmptyString(json['name'], json['title']),
      description:
          _firstNonEmptyString(json['description'], json['announcement_text']),
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
      'name': name,
      'description': description,
      'has_attachment': hasAttachment,
      'attachment_url': attachmentUrl,
    };
  }

  /// Copy with method for immutability
  AnnouncementModel copyWith({
    int? id,
    String? name,
    String? description,
    bool? hasAttachment,
    String? attachmentUrl,
  }) {
    return AnnouncementModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      hasAttachment: hasAttachment ?? this.hasAttachment,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
    );
  }

  @override
  String toString() {
    return 'AnnouncementModel(id: $id, name: $name, hasAttachment: $hasAttachment)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AnnouncementModel &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.hasAttachment == hasAttachment &&
        other.attachmentUrl == attachmentUrl;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        description.hashCode ^
        hasAttachment.hashCode ^
        attachmentUrl.hashCode;
  }
}
