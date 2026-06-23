import 'document_page.dart';

/// Represents a complete scanned document with multiple pages.
///
/// This is the main entity that holds all scanned pages and metadata
/// about the document scanning session.
class ScannedDocument {
  /// Unique identifier for this document
  final String id;

  /// Display name for the document
  final String name;

  /// List of scanned pages in order
  final List<DocumentPage> pages;

  /// Timestamp when scanning started
  final DateTime createdAt;

  /// Timestamp of last modification
  final DateTime modifiedAt;

  /// Path to exported PDF (if exported)
  final String? exportedPdfPath;

  /// Paths to exported images (if exported)
  final List<String>? exportedImagePaths;

  const ScannedDocument({
    required this.id,
    required this.name,
    required this.pages,
    required this.createdAt,
    required this.modifiedAt,
    this.exportedPdfPath,
    this.exportedImagePaths,
  });

  /// Returns the total number of pages
  int get pageCount => pages.length;

  /// Returns true if document has been exported as PDF
  bool get hasExportedPdf => exportedPdfPath != null;

  /// Returns true if document has any pages
  bool get hasPages => pages.isNotEmpty;

  /// Returns the first page thumbnail for preview
  DocumentPage? get coverPage => pages.isNotEmpty ? pages.first : null;

  /// Creates a new document with an added page
  ScannedDocument addPage(DocumentPage page) {
    final newPages = List<DocumentPage>.from(pages)..add(page);
    return copyWith(
      pages: newPages,
      modifiedAt: DateTime.now(),
    );
  }

  /// Creates a new document with a removed page
  ScannedDocument removePage(String pageId) {
    final newPages = pages.where((p) => p.id != pageId).toList();
    // Reorder page numbers
    for (int i = 0; i < newPages.length; i++) {
      newPages[i] = newPages[i].copyWith(pageNumber: i + 1);
    }
    return copyWith(
      pages: newPages,
      modifiedAt: DateTime.now(),
    );
  }

  /// Creates a new document with an updated page
  ScannedDocument updatePage(DocumentPage updatedPage) {
    final newPages = pages.map((p) {
      return p.id == updatedPage.id ? updatedPage : p;
    }).toList();
    return copyWith(
      pages: newPages,
      modifiedAt: DateTime.now(),
    );
  }

  /// Reorders pages based on new order
  ScannedDocument reorderPages(List<String> newOrder) {
    final pageMap = {for (var p in pages) p.id: p};
    final newPages = <DocumentPage>[];

    for (int i = 0; i < newOrder.length; i++) {
      final page = pageMap[newOrder[i]];
      if (page != null) {
        newPages.add(page.copyWith(pageNumber: i + 1));
      }
    }

    return copyWith(
      pages: newPages,
      modifiedAt: DateTime.now(),
    );
  }

  /// Creates a copy with updated properties
  ScannedDocument copyWith({
    String? id,
    String? name,
    List<DocumentPage>? pages,
    DateTime? createdAt,
    DateTime? modifiedAt,
    String? exportedPdfPath,
    List<String>? exportedImagePaths,
  }) {
    return ScannedDocument(
      id: id ?? this.id,
      name: name ?? this.name,
      pages: pages ?? this.pages,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      exportedPdfPath: exportedPdfPath ?? this.exportedPdfPath,
      exportedImagePaths: exportedImagePaths ?? this.exportedImagePaths,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScannedDocument &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ScannedDocument(id: $id, name: $name, pages: ${pages.length})';
  }
}

/// Export format options
enum ExportFormat {
  /// Export as JPEG images
  jpeg,

  /// Export as PNG images
  png,

  /// Export as multi-page PDF
  pdf,
}

/// Extension for export format display names
extension ExportFormatExtension on ExportFormat {
  String get displayName {
    switch (this) {
      case ExportFormat.jpeg:
        return 'JPEG Image';
      case ExportFormat.png:
        return 'PNG Image';
      case ExportFormat.pdf:
        return 'PDF Document';
    }
  }

  String get fileExtension {
    switch (this) {
      case ExportFormat.jpeg:
        return '.jpg';
      case ExportFormat.png:
        return '.png';
      case ExportFormat.pdf:
        return '.pdf';
    }
  }
}

/// Export quality settings
enum ExportQuality {
  /// Low quality, smaller file size
  low,

  /// Medium quality, balanced
  medium,

  /// High quality, larger file size
  high,

  /// Maximum quality, best for archiving
  maximum,
}

/// Extension for export quality settings
extension ExportQualityExtension on ExportQuality {
  int get jpegQuality {
    switch (this) {
      case ExportQuality.low:
        return 60;
      case ExportQuality.medium:
        return 80;
      case ExportQuality.high:
        return 90;
      case ExportQuality.maximum:
        return 100;
    }
  }

  String get displayName {
    switch (this) {
      case ExportQuality.low:
        return 'Low';
      case ExportQuality.medium:
        return 'Medium';
      case ExportQuality.high:
        return 'High';
      case ExportQuality.maximum:
        return 'Maximum';
    }
  }
}
