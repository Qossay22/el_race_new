import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../bloc/document_scanner_bloc.dart';
import '../bloc/document_scanner_event.dart';
import '../bloc/document_scanner_state.dart';
import 'crop_adjustment_screen.dart';
import 'document_preview_screen.dart';
import 'filter_screen.dart';
import 'scanner_camera_screen.dart';

/// Main document scanner screen that orchestrates the scanning workflow.
///
/// This screen manages navigation between different phases:
/// 1. Camera capture
/// 2. Corner adjustment
/// 3. Filter application
/// 4. Document preview
/// 5. Export
///
/// Usage:
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (context) => DocumentScannerScreen(
///       onDocumentScanned: (document) {
///         // Handle completed document
///       },
///     ),
///   ),
/// );
/// ```
class DocumentScannerScreen extends StatelessWidget {
  /// Callback when document scanning is complete
  final void Function(ScannedDocument document)? onDocumentScanned;

  /// Callback when export is complete
  final void Function(String path, ExportFormat format)? onExportComplete;

  /// Whether to allow multiple pages
  final bool allowMultiplePages;

  /// Initial document name
  final String? documentName;

  const DocumentScannerScreen({
    super.key,
    this.onDocumentScanned,
    this.onExportComplete,
    this.allowMultiplePages = true,
    this.documentName,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DocumentScannerBloc()
        ..add(const InitializeScanner())
        ..add(StartNewDocument(name: documentName)),
      child: _DocumentScannerView(
        onDocumentScanned: onDocumentScanned,
        onExportComplete: onExportComplete,
        allowMultiplePages: allowMultiplePages,
      ),
    );
  }
}

class _DocumentScannerView extends StatefulWidget {
  final void Function(ScannedDocument document)? onDocumentScanned;
  final void Function(String path, ExportFormat format)? onExportComplete;
  final bool allowMultiplePages;

  const _DocumentScannerView({
    this.onDocumentScanned,
    this.onExportComplete,
    this.allowMultiplePages = true,
  });

  @override
  State<_DocumentScannerView> createState() => _DocumentScannerViewState();
}

class _DocumentScannerViewState extends State<_DocumentScannerView> {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DocumentScannerBloc, DocumentScannerState>(
      listenWhen: (previous, current) {
        debugPrint(
            '🔄 [DocumentScannerScreen] listenWhen: prev=${previous.phase}, curr=${current.phase}');
        return previous.phase != current.phase ||
            previous.error != current.error;
      },
      listener: (context, state) {
        debugPrint(
            '🔊 [DocumentScannerScreen] listener: phase=${state.phase}, error=${state.error}');
        // Handle errors
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: Colors.red,
            ),
          );
        }

        // Handle completion
        if (state.phase == ScannerPhase.completed && state.document != null) {
          widget.onDocumentScanned?.call(state.document!);
        }
      },
      builder: (context, state) {
        debugPrint(
            '🏗️ [DocumentScannerScreen] builder: phase=${state.phase}, selectedPage=${state.selectedPage?.id}, isProcessing=${state.isProcessing}');

        // Show loading overlay when processing
        return Stack(
          children: [
            WillPopScope(
              onWillPop: () => _handleBackPress(context, state),
              child: _buildCurrentPhase(context, state),
            ),
            if (state.isProcessing)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.processingMessage ?? 'Processing...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCurrentPhase(BuildContext context, DocumentScannerState state) {
    debugPrint('🎨 [DocumentScannerScreen] _buildCurrentPhase: ${state.phase}');
    switch (state.phase) {
      case ScannerPhase.initial:
      case ScannerPhase.camera:
        return ScannerCameraScreen(
          onBack: () => _handleExit(context, state),
          onFinish: () => _handleFinishScanning(context),
        );

      case ScannerPhase.cornerAdjustment:
        if (state.selectedPage == null) {
          return ScannerCameraScreen(
            onBack: () => _handleExit(context, state),
            onFinish: () => _handleFinishScanning(context),
          );
        }
        return CropAdjustmentScreen(
          page: state.selectedPage!,
          onComplete: () => _handleCropComplete(context),
          onRetake: () => _handleRetake(context, state.selectedPage!),
        );

      case ScannerPhase.filtering:
        if (state.selectedPage == null) {
          return _buildPreviewScreen(context);
        }
        return FilterScreen(
          page: state.selectedPage!,
          onComplete: () => _handleFilterComplete(context),
        );

      case ScannerPhase.preview:
      case ScannerPhase.exporting:
      case ScannerPhase.completed:
        return _buildPreviewScreen(context);
    }
  }

  Widget _buildPreviewScreen(BuildContext context) {
    return DocumentPreviewScreen(
      onAddPages: () => _handleAddMorePages(context),
      onExportComplete: (path, format) {
        widget.onExportComplete?.call(path, format);
      },
    );
  }

  Future<bool> _handleBackPress(
    BuildContext context,
    DocumentScannerState state,
  ) async {
    switch (state.phase) {
      case ScannerPhase.initial:
      case ScannerPhase.camera:
        return _handleExit(context, state);

      case ScannerPhase.cornerAdjustment:
        // Go back to camera
        context.read<DocumentScannerBloc>().add(const InitializeScanner());
        return false;

      case ScannerPhase.filtering:
        // Go back to corner adjustment or camera
        if (state.selectedPage != null) {
          // For now, go to preview
          context.read<DocumentScannerBloc>().add(const FinishScanning());
        }
        return false;

      case ScannerPhase.preview:
        // Show confirmation if there are pages
        if (state.hasPages) {
          final shouldExit = await _showExitConfirmation(context);
          if (shouldExit == true) {
            context.read<DocumentScannerBloc>().add(const ResetScanner());
            Navigator.of(context).pop();
          }
          return false;
        }
        return true;

      case ScannerPhase.exporting:
        // Don't allow back during export
        return false;

      case ScannerPhase.completed:
        Navigator.of(context).pop();
        return false;
    }
  }

  Future<bool> _handleExit(
    BuildContext context,
    DocumentScannerState state,
  ) async {
    if (state.hasPages) {
      final shouldExit = await _showExitConfirmation(context);
      if (shouldExit == true) {
        context.read<DocumentScannerBloc>().add(const ResetScanner());
        Navigator.of(context).pop();
      }
      return false;
    }
    Navigator.of(context).pop();
    return true;
  }

  Future<bool?> _showExitConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Scan?'),
        content: const Text(
          'You have unsaved pages. Are you sure you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  void _handleFinishScanning(BuildContext context) {
    context.read<DocumentScannerBloc>().add(const FinishScanning());
  }

  void _handleCropComplete(BuildContext context) {
    // Processing happens in bloc, will automatically transition to filtering
  }

  void _handleFilterComplete(BuildContext context) {
    if (widget.allowMultiplePages) {
      // Go back to camera for more pages
      context.read<DocumentScannerBloc>().add(const InitializeScanner());
    } else {
      // Single page mode - go to preview
      context.read<DocumentScannerBloc>().add(const FinishScanning());
    }
  }

  void _handleRetake(BuildContext context, DocumentPage page) {
    // Remove the current page and go back to camera
    context.read<DocumentScannerBloc>().add(RemovePage(pageId: page.id));
    context.read<DocumentScannerBloc>().add(const InitializeScanner());
  }

  void _handleAddMorePages(BuildContext context) {
    context.read<DocumentScannerBloc>().add(const InitializeScanner());
  }
}
