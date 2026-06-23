import 'dart:typed_data';
import 'dart:ui';

/// Represents a single page in a scanned document.
///
/// Contains the original image, processed image, and metadata
/// about the scanning process.
class DocumentPage {
  /// Unique identifier for this page
  final String id;

  /// Original captured image path
  final String originalImagePath;

  /// Processed/enhanced image path (after cropping and filters)
  final String? processedImagePath;

  /// Thumbnail image for preview (memory efficient)
  final Uint8List? thumbnail;

  /// Detected document corners (for perspective correction)
  final List<Offset>? detectedCorners;

  /// User-adjusted corners (if manually adjusted)
  final List<Offset>? adjustedCorners;

  /// Applied filter type
  final ImageFilterType filterType;

  /// Page order in the document (1-based)
  final int pageNumber;

  /// Timestamp when the page was captured
  final DateTime capturedAt;

  /// Whether edge detection was successful
  final bool edgeDetectionSuccessful;

  /// Original image dimensions
  final Size? originalSize;

  const DocumentPage({
    required this.id,
    required this.originalImagePath,
    this.processedImagePath,
    this.thumbnail,
    this.detectedCorners,
    this.adjustedCorners,
    this.filterType = ImageFilterType.original,
    required this.pageNumber,
    required this.capturedAt,
    this.edgeDetectionSuccessful = false,
    this.originalSize,
  });

  /// Returns the effective corners to use (adjusted or detected)
  List<Offset>? get effectiveCorners => adjustedCorners ?? detectedCorners;

  /// Returns the image path to display (processed or original)
  String get displayImagePath => processedImagePath ?? originalImagePath;

  /// Creates a copy with updated properties
  DocumentPage copyWith({
    String? id,
    String? originalImagePath,
    String? processedImagePath,
    Uint8List? thumbnail,
    List<Offset>? detectedCorners,
    List<Offset>? adjustedCorners,
    ImageFilterType? filterType,
    int? pageNumber,
    DateTime? capturedAt,
    bool? edgeDetectionSuccessful,
    Size? originalSize,
  }) {
    return DocumentPage(
      id: id ?? this.id,
      originalImagePath: originalImagePath ?? this.originalImagePath,
      processedImagePath: processedImagePath ?? this.processedImagePath,
      thumbnail: thumbnail ?? this.thumbnail,
      detectedCorners: detectedCorners ?? this.detectedCorners,
      adjustedCorners: adjustedCorners ?? this.adjustedCorners,
      filterType: filterType ?? this.filterType,
      pageNumber: pageNumber ?? this.pageNumber,
      capturedAt: capturedAt ?? this.capturedAt,
      edgeDetectionSuccessful:
          edgeDetectionSuccessful ?? this.edgeDetectionSuccessful,
      originalSize: originalSize ?? this.originalSize,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentPage &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'DocumentPage(id: $id, pageNumber: $pageNumber, filter: $filterType)';
  }
}

/// Available image filter types for document enhancement
enum ImageFilterType {
  /// Original image without any filter
  original,

  /// Grayscale conversion
  grayscale,

  /// Black and white (scan mode) with adaptive thresholding
  blackAndWhite,

  /// Enhanced contrast for better readability
  enhanced,

  /// Magic filter - auto-adjusts brightness, contrast, and sharpness
  magic,
}

/// Extension to provide display names for filters
extension ImageFilterTypeExtension on ImageFilterType {
  String get displayName {
    switch (this) {
      case ImageFilterType.original:
        return 'Original';
      case ImageFilterType.grayscale:
        return 'Grayscale';
      case ImageFilterType.blackAndWhite:
        return 'B&W Scan';
      case ImageFilterType.enhanced:
        return 'Enhanced';
      case ImageFilterType.magic:
        return 'Magic';
    }
  }

  String get description {
    switch (this) {
      case ImageFilterType.original:
        return 'Keep the original colors';
      case ImageFilterType.grayscale:
        return 'Convert to grayscale';
      case ImageFilterType.blackAndWhite:
        return 'Black and white scan mode';
      case ImageFilterType.enhanced:
        return 'Enhance contrast and clarity';
      case ImageFilterType.magic:
        return 'Auto-optimize for documents';
    }
  }
}
