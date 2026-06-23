/// Model for content items from get_contents API
/// Handles both photos and 360_view items
class ContentModel {
  final int id;
  final String fileName;
  final String projectName;
  final bool is360View;
  final String previewUrl;
  final String? thumbnailUrl;
  final DateTime? dateCreated;
  /// Raw file type from API (e.g. 'pdf', 'image', 'video', mime type, etc.)
  final String? fileType;

  const ContentModel({
    required this.id,
    required this.fileName,
    required this.projectName,
    required this.is360View,
    required this.previewUrl,
    this.thumbnailUrl,
    this.dateCreated,
    this.fileType,
  });

  /// Whether this item is a PDF document
  bool get isPdf {
    // Check fileType field from API
    final ft = (fileType ?? '').toLowerCase();
    if (ft.contains('pdf')) return true;
    // Check fileName extension
    final fn = fileName.toLowerCase();
    if (fn.endsWith('.pdf')) return true;
    // Check previewUrl
    final url = previewUrl.toLowerCase().split('?').first;
    if (url.endsWith('.pdf')) return true;
    return false;
  }

  /// URL to use for image display (thumbnail preferred)
  String get displayImageUrl => (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
      ? thumbnailUrl!
      : previewUrl;

  factory ContentModel.fromJson(Map<String, dynamic> json) {
    final previewUrls = _extractPreviewUrls(json);
    final thumbnail = json['thumbnail']?.toString()?.trim();

    return ContentModel(
      id: json['id'] ?? 0,
      fileName: json['file_name'] ?? '',
      projectName: json['project_name'] ?? '',
      is360View: json['is_360_view'] ?? false,
      previewUrl: previewUrls.isNotEmpty ? previewUrls.first : '',
      thumbnailUrl: (thumbnail != null && thumbnail.isNotEmpty) ? thumbnail : null,
      fileType: _extractFileType(json),
      dateCreated: _parseDateTime(json['date_created']) ??
          _parseDateTime(json['uploaded_on']) ??
          _parseDateTime(json['created_at']) ??
          _parseDateTime(json['create_date']) ??
          _parseDateTime(json['date']),
    );
  }

  /// Builds one or more photo models from API entry.
  ///
  /// Some payloads provide `preview_urls` (array) instead of `preview_url`.
  /// Each URL is treated as an individual photo item so all images can render.
  static List<ContentModel> fromPhotoJson(Map<String, dynamic> json) {
    final urls = _extractPreviewUrls(json);
    final thumbnail = json['thumbnail']?.toString()?.trim();
    final thumbnailUrl = (thumbnail != null && thumbnail.isNotEmpty) ? thumbnail : null;

    // If no preview URLs but we have a thumbnail, still create one item using thumbnail
    if (urls.isEmpty && thumbnailUrl == null) return const [];

    final baseId = (json['id'] is num) ? (json['id'] as num).toInt() : 0;
    final fileName = json['file_name']?.toString() ?? '';
    final projectName = json['project_name']?.toString() ?? '';
    final is360View = json['is_360_view'] == true;
    final parsedDate = _parseDateTime(json['date_created']) ??
        _parseDateTime(json['uploaded_on']) ??
        _parseDateTime(json['created_at']) ??
        _parseDateTime(json['create_date']) ??
        _parseDateTime(json['date']);
    final fileType = _extractFileType(json);

    // If no preview URLs, create a single item using thumbnail as previewUrl
    if (urls.isEmpty) {
      return [
        ContentModel(
          id: baseId == 0 ? 1 : baseId,
          fileName: fileName,
          projectName: projectName,
          is360View: is360View,
          previewUrl: thumbnailUrl!,
          thumbnailUrl: thumbnailUrl,
          fileType: fileType,
          dateCreated: parsedDate,
        )
      ];
    }

    return List<ContentModel>.generate(urls.length, (index) {
      final generatedId = baseId == 0 ? index + 1 : (baseId * 1000) + index;
      return ContentModel(
        id: generatedId,
        fileName: fileName,
        projectName: projectName,
        is360View: is360View,
        previewUrl: urls[index],
        thumbnailUrl: thumbnailUrl,
        fileType: fileType,
        dateCreated: parsedDate,
      );
    });
  }

  static List<String> _extractPreviewUrls(Map<String, dynamic> json) {
    final urls = <String>[];

    void addUrl(dynamic value) {
      if (value is! String) return;
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        urls.add(trimmed);
      }
    }

    addUrl(json['preview_url']);

    final many = json['preview_urls'];
    if (many is List) {
      for (final raw in many) {
        addUrl(raw);
      }
    }

    return urls.toSet().toList(growable: false);
  }

  static String? _extractFileType(Map<String, dynamic> json) {
    for (final key in const ['file_type', 'type', 'content_type', 'mime_type', 'format', 'media_type']) {
      final v = json[key]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) {
      // Heuristic: treat large values as milliseconds, else seconds.
      if (value > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      if (value > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000);
      }
      return null;
    }
    if (value is String) {
      final s = value.trim();
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'file_name': fileName,
      'project_name': projectName,
      'is_360_view': is360View,
      'preview_url': previewUrl,
      'thumbnail': thumbnailUrl,
      'date_created': dateCreated?.toIso8601String(),
    };
  }

  ContentModel copyWith({
    int? id,
    String? fileName,
    String? projectName,
    bool? is360View,
    String? previewUrl,
    String? thumbnailUrl,
    DateTime? dateCreated,
    String? fileType,
  }) {
    return ContentModel(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      projectName: projectName ?? this.projectName,
      is360View: is360View ?? this.is360View,
      previewUrl: previewUrl ?? this.previewUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      dateCreated: dateCreated ?? this.dateCreated,
      fileType: fileType ?? this.fileType,
    );
  }

  /// Display name without extension
  String get displayName {
    if (fileName.contains('.')) {
      return fileName.substring(0, fileName.lastIndexOf('.'));
    }
    return fileName;
  }

  /// Check if this is a photo (non-360 view)
  bool get isPhoto => !is360View;

  /// Check if this is a 360 view
  bool get is360 => is360View;
}

/// Response model for get_contents API
class ContentsResponse {
  final List<ContentModel> photos;
  final List<List<ContentModel>> photoGroups;
  final List<ContentModel> view360;

  const ContentsResponse({
    required this.photos,
    this.photoGroups = const [],
    required this.view360,
  });

  factory ContentsResponse.fromJson(Map<String, dynamic> json) {
    try {
      final dynamic rawData = json['result']?['data'] ?? json['data'] ?? json;
      final Map<String, dynamic> data =
          rawData is Map<String, dynamic> ? rawData : <String, dynamic>{};

      List<ContentModel> photosList = [];
      List<List<ContentModel>> photoGroupsList = [];
      List<ContentModel> view360List = [];

      final rawPhotos = data['photos'];
      if (rawPhotos is List) {
        for (final entry in rawPhotos) {
          if (entry is List) {
            final group = <ContentModel>[];
            for (final item in entry.whereType<Map<String, dynamic>>()) {
              group.addAll(ContentModel.fromPhotoJson(item));
            }
            _sortNewestFirst(group);
            if (group.isNotEmpty) {
              photoGroupsList.add(group);
              photosList.addAll(group);
            }
          } else if (entry is Map<String, dynamic>) {
            photosList.addAll(ContentModel.fromPhotoJson(entry));
          }
        }

        if (photoGroupsList.isEmpty && photosList.isNotEmpty) {
          _sortNewestFirst(photosList);
          photoGroupsList = [List<ContentModel>.from(photosList)];
        }
      }

      if (data['360_view'] != null && data['360_view'] is List) {
        view360List = (data['360_view'] as List)
            .whereType<Map<String, dynamic>>()
            .map(ContentModel.fromJson)
            .toList();
      }

      _sortNewestFirst(photosList);
      _sortNewestFirst(view360List);

      return ContentsResponse(
        photos: photosList,
        photoGroups: photoGroupsList,
        view360: view360List,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Get all content items combined
  List<ContentModel> get allContent => [...photos, ...view360];

  /// Check if there are any photos
  bool get hasPhotos => photos.isNotEmpty;

  /// Check if there are any 360 views
  bool get has360Views => view360.isNotEmpty;

  /// Check if there is any content
  bool get hasContent => hasPhotos || has360Views;

  static void _sortNewestFirst(List<ContentModel> items) {
    items.sort((a, b) {
      final aDate = a.dateCreated;
      final bDate = b.dateCreated;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
  }
}
