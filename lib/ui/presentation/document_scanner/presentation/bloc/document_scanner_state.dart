import 'dart:ui';

import 'package:equatable/equatable.dart';

import '../../domain/entities/entities.dart';

/// Represents the current phase of the scanning workflow.
enum ScannerPhase {
  /// Initial state, not yet started
  initial,

  /// Camera is active, ready to capture
  camera,

  /// Adjusting corners after capture
  cornerAdjustment,

  /// Applying filters to the image
  filtering,

  /// Previewing the document
  preview,

  /// Exporting the document
  exporting,

  /// Export completed successfully
  completed,
}

/// State class for the document scanner BLoC.
class DocumentScannerState extends Equatable {
  /// Current phase of the scanning workflow
  final ScannerPhase phase;

  /// The current document being scanned
  final ScannedDocument? document;

  /// Currently selected page for editing
  final DocumentPage? selectedPage;

  /// Currently detected corners (for real-time preview)
  final List<Offset>? detectedCorners;

  /// Whether the scanner is processing
  final bool isProcessing;

  /// Error message if any
  final String? error;

  /// Whether auto-capture is enabled
  final bool autoCaptureEnabled;

  /// Path to the exported file (after export)
  final String? exportedFilePath;

  /// Export format used (after export)
  final ExportFormat? exportFormat;

  /// Progress value for long operations (0.0 to 1.0)
  final double? progress;

  /// Message to show during processing
  final String? processingMessage;

  const DocumentScannerState({
    this.phase = ScannerPhase.initial,
    this.document,
    this.selectedPage,
    this.detectedCorners,
    this.isProcessing = false,
    this.error,
    this.autoCaptureEnabled = false,
    this.exportedFilePath,
    this.exportFormat,
    this.progress,
    this.processingMessage,
  });

  /// Returns true if there are pages to show
  bool get hasPages => document?.hasPages ?? false;

  /// Returns the total page count
  int get pageCount => document?.pageCount ?? 0;

  /// Returns true if ready to export
  bool get canExport => hasPages && !isProcessing;

  /// Returns true if in initial or camera phase
  bool get isCapturing =>
      phase == ScannerPhase.initial || phase == ScannerPhase.camera;

  /// Creates a copy with updated fields
  DocumentScannerState copyWith({
    ScannerPhase? phase,
    ScannedDocument? document,
    DocumentPage? selectedPage,
    List<Offset>? detectedCorners,
    bool? isProcessing,
    String? error,
    bool? autoCaptureEnabled,
    String? exportedFilePath,
    ExportFormat? exportFormat,
    double? progress,
    String? processingMessage,
    bool clearError = false,
    bool clearDetectedCorners = false,
    bool clearSelectedPage = false,
    bool clearExport = false,
  }) {
    return DocumentScannerState(
      phase: phase ?? this.phase,
      document: document ?? this.document,
      selectedPage:
          clearSelectedPage ? null : (selectedPage ?? this.selectedPage),
      detectedCorners: clearDetectedCorners
          ? null
          : (detectedCorners ?? this.detectedCorners),
      isProcessing: isProcessing ?? this.isProcessing,
      error: clearError ? null : (error ?? this.error),
      autoCaptureEnabled: autoCaptureEnabled ?? this.autoCaptureEnabled,
      exportedFilePath:
          clearExport ? null : (exportedFilePath ?? this.exportedFilePath),
      exportFormat: clearExport ? null : (exportFormat ?? this.exportFormat),
      progress: progress ?? this.progress,
      processingMessage: processingMessage ?? this.processingMessage,
    );
  }

  @override
  List<Object?> get props => [
        phase,
        document,
        selectedPage,
        detectedCorners,
        isProcessing,
        error,
        autoCaptureEnabled,
        exportedFilePath,
        exportFormat,
        progress,
        processingMessage,
      ];
}

/// Extension for common state transitions
extension DocumentScannerStateExtensions on DocumentScannerState {
  /// Creates state for showing processing indicator
  DocumentScannerState processing({String? message}) {
    return copyWith(
      isProcessing: true,
      processingMessage: message,
      clearError: true,
    );
  }

  /// Creates state for error
  DocumentScannerState withError(String errorMessage) {
    return copyWith(
      isProcessing: false,
      error: errorMessage,
    );
  }

  /// Creates state with processing complete
  DocumentScannerState processingComplete() {
    return copyWith(
      isProcessing: false,
      processingMessage: null,
      clearError: true,
    );
  }
}
