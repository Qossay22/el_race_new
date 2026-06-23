/// Model for project document items (folders and files) from the cloud API
class ProjectDocumentItem {
  final String id;
  final String name;
  final String type; // 'folder' or 'file'
  final String? downloadUrl;

  const ProjectDocumentItem({
    required this.id,
    required this.name,
    required this.type,
    this.downloadUrl,
  });

  bool get isFolder => type == 'folder';
  bool get isFile => type == 'file';

  /// Get file extension from name
  String get fileExtension {
    if (!isFile) return '';
    final parts = name.split('.');
    if (parts.length > 1) {
      return parts.last.toLowerCase();
    }
    return '';
  }

  /// Check if file is PDF
  bool get isPdf => fileExtension == 'pdf';

  /// Check if file is Excel
  bool get isExcel =>
      fileExtension == 'xlsx' ||
      fileExtension == 'xls' ||
      fileExtension == 'csv';

  /// Check if file is Word document
  bool get isWord => fileExtension == 'doc' || fileExtension == 'docx';

  /// Check if file is image
  bool get isImage =>
      fileExtension == 'jpg' ||
      fileExtension == 'jpeg' ||
      fileExtension == 'png' ||
      fileExtension == 'gif' ||
      fileExtension == 'webp';

  factory ProjectDocumentItem.fromJson(Map<String, dynamic> json) {
    return ProjectDocumentItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? 'file',
      downloadUrl: json['download_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'download_url': downloadUrl,
      };

  @override
  String toString() => 'ProjectDocumentItem(id: $id, name: $name, type: $type)';
}

/// Response model for project documents API
class ProjectDocumentsResponse {
  final String status;
  final int projectId;
  final List<ProjectDocumentItem> items;
  final String? nextLink;

  const ProjectDocumentsResponse({
    required this.status,
    required this.projectId,
    required this.items,
    this.nextLink,
  });

  factory ProjectDocumentsResponse.fromJson(Map<String, dynamic> json) {
    final result = json['result'] as Map<String, dynamic>? ?? json;
    final itemsList = result['items'] as List<dynamic>? ?? [];

    return ProjectDocumentsResponse(
      status: result['status']?.toString() ?? 'error',
      projectId: result['project_id'] as int? ?? 0,
      items: itemsList
          .map((e) => ProjectDocumentItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextLink: result['next_link']?.toString(),
    );
  }
}

/// Response model for folder contents API
class FolderContentsResponse {
  final String status;
  final int projectId;
  final String folderId;
  final List<ProjectDocumentItem> items;
  final String? nextLink;

  const FolderContentsResponse({
    required this.status,
    required this.projectId,
    required this.folderId,
    required this.items,
    this.nextLink,
  });

  factory FolderContentsResponse.fromJson(Map<String, dynamic> json) {
    final result = json['result'] as Map<String, dynamic>? ?? json;
    final itemsList = result['items'] as List<dynamic>? ?? [];

    return FolderContentsResponse(
      status: result['status']?.toString() ?? 'error',
      projectId: result['project_id'] as int? ?? 0,
      folderId: result['folder_id']?.toString() ?? '',
      items: itemsList
          .map((e) => ProjectDocumentItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextLink: result['next_link']?.toString(),
    );
  }
}

/// Response model for file details API
class FileDetailsResponse {
  final String status;
  final int projectId;
  final String fileId;
  final String name;
  final String viewUrl;
  final String downloadUrl;

  const FileDetailsResponse({
    required this.status,
    required this.projectId,
    required this.fileId,
    required this.name,
    required this.viewUrl,
    required this.downloadUrl,
  });

  factory FileDetailsResponse.fromJson(Map<String, dynamic> json) {
    final result = json['result'] as Map<String, dynamic>? ?? json;

    return FileDetailsResponse(
      status: result['status']?.toString() ?? 'error',
      projectId: result['project_id'] as int? ?? 0,
      fileId: result['file_id']?.toString() ?? '',
      name: result['name']?.toString() ?? '',
      viewUrl: result['view_url']?.toString() ?? '',
      downloadUrl: result['download_url']?.toString() ?? '',
    );
  }
}
