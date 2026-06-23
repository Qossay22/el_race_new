import 'dart:ui';

import 'package:equatable/equatable.dart';

import '../../domain/entities/entities.dart';

/// Base class for all document scanner events.
abstract class DocumentScannerEvent extends Equatable {
  const DocumentScannerEvent();

  @override
  List<Object?> get props => [];
}

/// Event to initialize the scanner.
class InitializeScanner extends DocumentScannerEvent {
  const InitializeScanner();
}

/// Event to start a new scanning session.
class StartNewDocument extends DocumentScannerEvent {
  final String? name;

  const StartNewDocument({this.name});

  @override
  List<Object?> get props => [name];
}

/// Event when an image is captured from the camera.
class ImageCaptured extends DocumentScannerEvent {
  final String imagePath;
  final bool autoDetectEdges;

  const ImageCaptured({
    required this.imagePath,
    this.autoDetectEdges = true,
  });

  @override
  List<Object?> get props => [imagePath, autoDetectEdges];
}

/// Event to update corners after manual adjustment.
class UpdateCorners extends DocumentScannerEvent {
  final String pageId;
  final List<Offset> corners;

  const UpdateCorners({
    required this.pageId,
    required this.corners,
  });

  @override
  List<Object?> get props => [pageId, corners];
}

/// Event to process a page (crop and filter).
class ProcessPage extends DocumentScannerEvent {
  final String pageId;
  final ImageFilterType filterType;

  const ProcessPage({
    required this.pageId,
    this.filterType = ImageFilterType.original,
  });

  @override
  List<Object?> get props => [pageId, filterType];
}

/// Event to apply a filter to a page.
class ApplyFilter extends DocumentScannerEvent {
  final String pageId;
  final ImageFilterType filterType;

  const ApplyFilter({
    required this.pageId,
    required this.filterType,
  });

  @override
  List<Object?> get props => [pageId, filterType];
}

/// Event to apply filter to all pages.
class ApplyFilterToAll extends DocumentScannerEvent {
  final ImageFilterType filterType;

  const ApplyFilterToAll({required this.filterType});

  @override
  List<Object?> get props => [filterType];
}

/// Event to remove a page from the document.
class RemovePage extends DocumentScannerEvent {
  final String pageId;

  const RemovePage({required this.pageId});

  @override
  List<Object?> get props => [pageId];
}

/// Event to reorder pages.
class ReorderPages extends DocumentScannerEvent {
  final List<String> newOrder;

  const ReorderPages({required this.newOrder});

  @override
  List<Object?> get props => [newOrder];
}

/// Event to export document as PDF.
class ExportAsPdf extends DocumentScannerEvent {
  final ExportQuality quality;

  const ExportAsPdf({this.quality = ExportQuality.high});

  @override
  List<Object?> get props => [quality];
}

/// Event to export document as images.
class ExportAsImages extends DocumentScannerEvent {
  final ExportFormat format;
  final ExportQuality quality;

  const ExportAsImages({
    this.format = ExportFormat.jpeg,
    this.quality = ExportQuality.high,
  });

  @override
  List<Object?> get props => [format, quality];
}

/// Event to select a page for editing.
class SelectPage extends DocumentScannerEvent {
  final String pageId;

  const SelectPage({required this.pageId});

  @override
  List<Object?> get props => [pageId];
}

/// Event to finish scanning and go to preview.
class FinishScanning extends DocumentScannerEvent {
  const FinishScanning();
}

/// Event to reset and start over.
class ResetScanner extends DocumentScannerEvent {
  const ResetScanner();
}

/// Event when edge detection completes for real-time preview.
class EdgeDetectionCompleted extends DocumentScannerEvent {
  final List<Offset>? corners;

  const EdgeDetectionCompleted({this.corners});

  @override
  List<Object?> get props => [corners];
}

/// Event to toggle auto-capture mode.
class ToggleAutoCapture extends DocumentScannerEvent {
  final bool enabled;

  const ToggleAutoCapture({required this.enabled});

  @override
  List<Object?> get props => [enabled];
}

/// Event to set document name.
class SetDocumentName extends DocumentScannerEvent {
  final String name;

  const SetDocumentName({required this.name});

  @override
  List<Object?> get props => [name];
}
