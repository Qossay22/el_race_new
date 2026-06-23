/// Model for circular/announcement items
class CircularAnnouncementItem {
  final int id;
  final String title;
  final String description;
  final String category;
  final String? fileUrl;
  final DateTime? date;

  const CircularAnnouncementItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.fileUrl,
    this.date,
  });

  /// Factory constructor to parse from JSON response
  factory CircularAnnouncementItem.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    final dateStr =
        (json['date'] ?? json['created_at'] ?? json['create_date']) as String?;
    if (dateStr != null && dateStr.isNotEmpty) {
      parsedDate = DateTime.tryParse(dateStr);
    }

    // Build full file URL
    String? fullFileUrl;
    final fileUrlPath = (json['file_url'] ?? json['attachment_url']) as String?;
    if (fileUrlPath != null && fileUrlPath.isNotEmpty) {
      if (fileUrlPath.startsWith('http')) {
        fullFileUrl = fileUrlPath;
      } else {
        fullFileUrl = 'https://erp.elrace.com$fileUrlPath';
      }
    }

    return CircularAnnouncementItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: _firstNonEmptyString(json['title'], json['name']),
      description:
          _firstNonEmptyString(json['description'], json['announcement_text']),
      category: json['category']?.toString() ?? '',
      fileUrl: fullFileUrl,
      date: parsedDate,
    );
  }

  static String _firstNonEmptyString(dynamic first, dynamic second) {
    final firstValue = first?.toString().trim() ?? '';
    if (firstValue.isNotEmpty) return firstValue;
    return second?.toString().trim() ?? '';
  }

  /// Convert model to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'file_url': fileUrl,
      'date': date?.toIso8601String(),
    };
  }

  /// Check if this item has an attached file
  bool get hasFile => fileUrl != null && fileUrl!.isNotEmpty;

  /// Check if this is a circular
  bool get isCircular => category.toLowerCase() == 'circular';

  /// Check if this is an announcement
  bool get isAnnouncement => category.toLowerCase() == 'announcement';

  /// Display-friendly primary title for UI cards and headers
  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    return description.trim();
  }

  /// Display-friendly body text for UI cards (can be empty)
  String get displayBody {
    final body = description.trim();
    if (body.isEmpty || body == displayTitle) return '';
    return body;
  }

  @override
  String toString() {
    return 'CircularAnnouncementItem(id: $id, title: $title, category: $category)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CircularAnnouncementItem &&
        other.id == id &&
        other.category == category;
  }

  @override
  int get hashCode => id.hashCode ^ category.hashCode;
}

/// Response model for circular/announcement API
class CircularAnnouncementResponse {
  final int circularCount;
  final int announcementCount;
  final List<CircularAnnouncementItem> circulars;
  final List<CircularAnnouncementItem> announcements;

  const CircularAnnouncementResponse({
    required this.circularCount,
    required this.announcementCount,
    required this.circulars,
    required this.announcements,
  });

  /// Factory constructor to parse from API response
  factory CircularAnnouncementResponse.fromJson(Map<String, dynamic> json) {
    // Navigate through JSON-RPC structure
    final result = json['result'] as Map<String, dynamic>? ?? json;

    // Parse counters
    final counters = result['counters'] as Map<String, dynamic>? ?? {};
    final circularCount = (counters['circular'] as num?)?.toInt() ?? 0;
    final announcementCount = (counters['announcement'] as num?)?.toInt() ?? 0;

    // Parse data
    final rawData = result['data'];
    final data = rawData is Map<String, dynamic>
        ? rawData
        : rawData is Map
            ? Map<String, dynamic>.from(rawData)
            : <String, dynamic>{};

    List<dynamic> _readList(Map<String, dynamic> source, List<String> keys) {
      for (final key in keys) {
        final value = source[key];
        if (value is List) return value;
      }
      return const [];
    }

    // Trust backend buckets to avoid any swapped tabs caused by per-item labels.
    // Backend payload is currently reversed, so map buckets inversely.
    final rawCirculars =
        _readList(data, const ['announcement', 'announcements']);
    final rawAnnouncements = _readList(data, const ['circular', 'circulars']);

    List<CircularAnnouncementItem> _toItems(List<dynamic> rawItems) {
      return rawItems
          .whereType<Map>()
          .map((item) => CircularAnnouncementItem.fromJson(
              Map<String, dynamic>.from(item)))
          .toList(growable: false);
    }

    var finalCirculars = _toItems(rawCirculars);
    var finalAnnouncements = _toItems(rawAnnouncements);

    // Fallback for flat list payloads: split by category only when buckets are absent.
    if (finalCirculars.isEmpty &&
        finalAnnouncements.isEmpty &&
        rawData is List) {
      final combined = rawData
          .whereType<Map>()
          .map((item) => CircularAnnouncementItem.fromJson(
              Map<String, dynamic>.from(item)))
          .toList(growable: false);

      finalCirculars = combined
          .where((item) => item.category.toLowerCase().contains('circular'))
          .toList(growable: false);
      finalAnnouncements = combined
          .where((item) => item.category.toLowerCase().contains('announcement'))
          .toList(growable: false);
    }

    return CircularAnnouncementResponse(
      circularCount: circularCount,
      announcementCount: announcementCount,
      circulars: finalCirculars,
      announcements: finalAnnouncements,
    );
  }

  /// Get total count of all items
  int get totalCount => circularCount + announcementCount;

  /// Check if there are any items
  bool get isEmpty => circulars.isEmpty && announcements.isEmpty;

  /// Check if there are any items
  bool get isNotEmpty => !isEmpty;

  @override
  String toString() {
    return 'CircularAnnouncementResponse(circulars: ${circulars.length}, announcements: ${announcements.length})';
  }
}
