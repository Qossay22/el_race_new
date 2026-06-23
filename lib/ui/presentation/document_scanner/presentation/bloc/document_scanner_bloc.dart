import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/document_scanner_repository_impl.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/document_scanner_repository.dart';
import '../../domain/usecases/scan_document_usecase.dart';
import 'document_scanner_event.dart';
import 'document_scanner_state.dart';

/// BLoC for managing document scanning state and operations.
///
/// This BLoC orchestrates the entire scanning workflow:
/// 1. Camera capture
/// 2. Edge detection
/// 3. Corner adjustment
/// 4. Image processing (crop + filter)
/// 5. Multi-page management
/// 6. Export (PDF/images)
class DocumentScannerBloc
    extends Bloc<DocumentScannerEvent, DocumentScannerState> {
  final ScanDocumentUseCase _scanDocumentUseCase;

  DocumentScannerBloc({
    ScanDocumentUseCase? scanDocumentUseCase,
    IDocumentScannerRepository? repository,
  })  : _scanDocumentUseCase = scanDocumentUseCase ??
            ScanDocumentUseCase(
              repository: repository ?? DocumentScannerRepositoryImpl(),
            ),
        super(const DocumentScannerState()) {
    // Register event handlers
    on<InitializeScanner>(_onInitializeScanner);
    on<StartNewDocument>(_onStartNewDocument);
    on<ImageCaptured>(_onImageCaptured);
    on<UpdateCorners>(_onUpdateCorners);
    on<ProcessPage>(_onProcessPage);
    on<ApplyFilter>(_onApplyFilter);
    on<ApplyFilterToAll>(_onApplyFilterToAll);
    on<RemovePage>(_onRemovePage);
    on<ReorderPages>(_onReorderPages);
    on<ExportAsPdf>(_onExportAsPdf);
    on<ExportAsImages>(_onExportAsImages);
    on<SelectPage>(_onSelectPage);
    on<FinishScanning>(_onFinishScanning);
    on<ResetScanner>(_onResetScanner);
    on<EdgeDetectionCompleted>(_onEdgeDetectionCompleted);
    on<ToggleAutoCapture>(_onToggleAutoCapture);
    on<SetDocumentName>(_onSetDocumentName);
  }

  /// Initializes the scanner.
  Future<void> _onInitializeScanner(
    InitializeScanner event,
    Emitter<DocumentScannerState> emit,
  ) async {
    emit(state.copyWith(
      phase: ScannerPhase.camera,
      clearError: true,
    ));
  }

  /// Starts a new document scanning session.
  Future<void> _onStartNewDocument(
    StartNewDocument event,
    Emitter<DocumentScannerState> emit,
  ) async {
    final document = _scanDocumentUseCase.createNewDocument(name: event.name);
    emit(state.copyWith(
      phase: ScannerPhase.camera,
      document: document,
      clearError: true,
      clearSelectedPage: true,
      clearExport: true,
    ));
  }

  /// Handles image capture from camera.
  Future<void> _onImageCaptured(
    ImageCaptured event,
    Emitter<DocumentScannerState> emit,
  ) async {
    debugPrint('📸 [DocumentScannerBloc] ImageCaptured event received');
    debugPrint('📸 [DocumentScannerBloc] Image path: ${event.imagePath}');

    emit(state.processing(message: 'Processing image...'));
    debugPrint('📸 [DocumentScannerBloc] State emitted: processing');

    try {
      // Ensure we have a document
      var document = state.document;
      if (document == null) {
        debugPrint('📸 [DocumentScannerBloc] Creating new document...');
        document = _scanDocumentUseCase.createNewDocument();
      }
      debugPrint('📸 [DocumentScannerBloc] Document ready, adding page...');

      // Add the captured page
      document = await _scanDocumentUseCase.addCapturedPage(
        document,
        event.imagePath,
        autoDetectEdges: event.autoDetectEdges,
      );
      debugPrint('📸 [DocumentScannerBloc] Page added successfully');

      // Get the newly added page
      final newPage = document.pages.last;
      debugPrint('📸 [DocumentScannerBloc] New page ID: ${newPage.id}');
      debugPrint('📸 [DocumentScannerBloc] Emitting cornerAdjustment phase...');

      emit(state.copyWith(
        document: document,
        selectedPage: newPage,
        phase: ScannerPhase.cornerAdjustment,
        isProcessing: false,
        clearError: true,
      ));
      debugPrint('📸 [DocumentScannerBloc] State emitted: cornerAdjustment');
    } catch (e, stackTrace) {
      debugPrint('❌ [DocumentScannerBloc] Error processing image: $e');
      debugPrint('❌ [DocumentScannerBloc] Stack trace: $stackTrace');
      emit(state.withError('Failed to process image: ${e.toString()}'));
    }
  }

  /// Updates corners after manual adjustment.
  Future<void> _onUpdateCorners(
    UpdateCorners event,
    Emitter<DocumentScannerState> emit,
  ) async {
    if (state.document == null) return;

    try {
      final updatedDocument = await _scanDocumentUseCase.updatePageCorners(
        state.document!,
        event.pageId,
        event.corners,
      );

      // Update selected page
      final updatedPage = updatedDocument.pages.firstWhere(
        (p) => p.id == event.pageId,
      );

      emit(state.copyWith(
        document: updatedDocument,
        selectedPage: updatedPage,
      ));
    } catch (e) {
      emit(state.withError('Failed to update corners: ${e.toString()}'));
    }
  }

  /// Processes a page with crop and filter.
  Future<void> _onProcessPage(
    ProcessPage event,
    Emitter<DocumentScannerState> emit,
  ) async {
    if (state.document == null) return;

    emit(state.processing(message: 'Applying corrections...'));

    try {
      final updatedDocument = await _scanDocumentUseCase.processPage(
        state.document!,
        event.pageId,
        filterType: event.filterType,
      );

      // Update selected page
      final updatedPage = updatedDocument.pages.firstWhere(
        (p) => p.id == event.pageId,
      );

      emit(state.copyWith(
        document: updatedDocument,
        selectedPage: updatedPage,
        phase: ScannerPhase.filtering,
        isProcessing: false,
      ));
    } catch (e) {
      emit(state.withError('Failed to process page: ${e.toString()}'));
    }
  }

  /// Applies a filter to a specific page.
  Future<void> _onApplyFilter(
    ApplyFilter event,
    Emitter<DocumentScannerState> emit,
  ) async {
    if (state.document == null) return;

    emit(state.processing(message: 'Applying filter...'));

    try {
      final updatedDocument = await _scanDocumentUseCase.processPage(
        state.document!,
        event.pageId,
        filterType: event.filterType,
      );

      final updatedPage = updatedDocument.pages.firstWhere(
        (p) => p.id == event.pageId,
      );

      emit(state.copyWith(
        document: updatedDocument,
        selectedPage: updatedPage,
        isProcessing: false,
      ));
    } catch (e) {
      emit(state.withError('Failed to apply filter: ${e.toString()}'));
    }
  }

  /// Applies a filter to all pages.
  Future<void> _onApplyFilterToAll(
    ApplyFilterToAll event,
    Emitter<DocumentScannerState> emit,
  ) async {
    if (state.document == null) return;

    emit(state.processing(message: 'Applying filter to all pages...'));

    try {
      final updatedDocument = await _scanDocumentUseCase.applyFilterToAll(
        state.document!,
        event.filterType,
      );

      emit(state.copyWith(
        document: updatedDocument,
        isProcessing: false,
      ));
    } catch (e) {
      emit(state.withError('Failed to apply filter: ${e.toString()}'));
    }
  }

  /// Removes a page from the document.
  Future<void> _onRemovePage(
    RemovePage event,
    Emitter<DocumentScannerState> emit,
  ) async {
    if (state.document == null) return;

    try {
      final updatedDocument = await _scanDocumentUseCase.removePage(
        state.document!,
        event.pageId,
      );

      emit(state.copyWith(
        document: updatedDocument,
        clearSelectedPage: state.selectedPage?.id == event.pageId,
      ));

      // If no more pages, go back to camera
      if (!updatedDocument.hasPages) {
        emit(state.copyWith(phase: ScannerPhase.camera));
      }
    } catch (e) {
      emit(state.withError('Failed to remove page: ${e.toString()}'));
    }
  }

  /// Reorders pages in the document.
  Future<void> _onReorderPages(
    ReorderPages event,
    Emitter<DocumentScannerState> emit,
  ) async {
    if (state.document == null) return;

    try {
      final updatedDocument = await _scanDocumentUseCase.reorderPages(
        state.document!,
        event.newOrder,
      );

      emit(state.copyWith(document: updatedDocument));
    } catch (e) {
      emit(state.withError('Failed to reorder pages: ${e.toString()}'));
    }
  }

  /// Exports document as PDF.
  Future<void> _onExportAsPdf(
    ExportAsPdf event,
    Emitter<DocumentScannerState> emit,
  ) async {
    if (state.document == null || !state.hasPages) return;

    emit(state.copyWith(
      phase: ScannerPhase.exporting,
      isProcessing: true,
      processingMessage: 'Creating PDF...',
    ));

    try {
      final updatedDocument = await _scanDocumentUseCase.exportAsPdf(
        state.document!,
        quality: event.quality,
      );

      emit(state.copyWith(
        document: updatedDocument,
        phase: ScannerPhase.completed,
        exportedFilePath: updatedDocument.exportedPdfPath,
        exportFormat: ExportFormat.pdf,
        isProcessing: false,
      ));
    } catch (e) {
      emit(state.withError('Failed to export PDF: ${e.toString()}'));
    }
  }

  /// Exports document as images.
  Future<void> _onExportAsImages(
    ExportAsImages event,
    Emitter<DocumentScannerState> emit,
  ) async {
    if (state.document == null || !state.hasPages) return;

    emit(state.copyWith(
      phase: ScannerPhase.exporting,
      isProcessing: true,
      processingMessage: 'Exporting images...',
    ));

    try {
      final updatedDocument = await _scanDocumentUseCase.exportAsImages(
        state.document!,
        format: event.format,
        quality: event.quality,
      );

      emit(state.copyWith(
        document: updatedDocument,
        phase: ScannerPhase.completed,
        exportedFilePath: updatedDocument.exportedImagePaths?.first,
        exportFormat: event.format,
        isProcessing: false,
      ));
    } catch (e) {
      emit(state.withError('Failed to export images: ${e.toString()}'));
    }
  }

  /// Selects a page for editing.
  Future<void> _onSelectPage(
    SelectPage event,
    Emitter<DocumentScannerState> emit,
  ) async {
    if (state.document == null) return;

    final page = state.document!.pages.firstWhere(
      (p) => p.id == event.pageId,
      orElse: () => throw Exception('Page not found'),
    );

    emit(state.copyWith(selectedPage: page));
  }

  /// Finishes scanning and goes to preview.
  Future<void> _onFinishScanning(
    FinishScanning event,
    Emitter<DocumentScannerState> emit,
  ) async {
    if (!state.hasPages) {
      emit(state.withError('No pages scanned'));
      return;
    }

    emit(state.copyWith(
      phase: ScannerPhase.preview,
      clearSelectedPage: true,
    ));
  }

  /// Resets the scanner to initial state.
  Future<void> _onResetScanner(
    ResetScanner event,
    Emitter<DocumentScannerState> emit,
  ) async {
    // Cleanup temporary files
    if (state.document != null) {
      await _scanDocumentUseCase.cleanup(state.document!);
    }

    emit(const DocumentScannerState(phase: ScannerPhase.camera));
  }

  /// Updates detected corners from real-time detection.
  Future<void> _onEdgeDetectionCompleted(
    EdgeDetectionCompleted event,
    Emitter<DocumentScannerState> emit,
  ) async {
    emit(state.copyWith(detectedCorners: event.corners));
  }

  /// Toggles auto-capture mode.
  Future<void> _onToggleAutoCapture(
    ToggleAutoCapture event,
    Emitter<DocumentScannerState> emit,
  ) async {
    emit(state.copyWith(autoCaptureEnabled: event.enabled));
  }

  /// Sets the document name.
  Future<void> _onSetDocumentName(
    SetDocumentName event,
    Emitter<DocumentScannerState> emit,
  ) async {
    if (state.document == null) return;

    emit(state.copyWith(
      document: state.document!.copyWith(name: event.name),
    ));
  }

  @override
  Future<void> close() async {
    // Cleanup on close
    if (state.document != null) {
      await _scanDocumentUseCase.cleanup(state.document!);
    }
    return super.close();
  }
}
