import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/document_scanner_bloc.dart';
import '../bloc/document_scanner_state.dart';

/// Bottom controls for the scanner camera screen.
///
/// Includes:
/// - Capture button (large, centered)
/// - Page thumbnail (left, shows captured pages)
/// - Done button (right, when pages exist)
class ScannerControls extends StatelessWidget {
  /// Callback when capture button is pressed
  final VoidCallback onCapture;

  /// Callback when done button is pressed
  final VoidCallback? onFinish;

  /// Whether currently capturing
  final bool isCapturing;

  const ScannerControls({
    super.key,
    required this.onCapture,
    this.onFinish,
    this.isCapturing = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DocumentScannerBloc, DocumentScannerState>(
      builder: (context, state) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Page thumbnail / count
            SizedBox(
              width: 60,
              child: state.hasPages
                  ? _buildPageThumbnail(context, state)
                  : const SizedBox.shrink(),
            ),

            // Capture button
            _buildCaptureButton(),

            // Done button
            SizedBox(
              width: 60,
              child: state.hasPages
                  ? _buildDoneButton(context)
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: isCapturing ? null : onCapture,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 4,
          ),
        ),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCapturing ? Colors.grey : Colors.white,
          ),
          child: isCapturing
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.grey,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildPageThumbnail(BuildContext context, DocumentScannerState state) {
    final coverPage = state.document?.coverPage;

    return GestureDetector(
      onTap: onFinish,
      child: Stack(
        children: [
          // Thumbnail
          Container(
            width: 48,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: coverPage?.thumbnail != null
                  ? Image.memory(
                      coverPage!.thumbnail!,
                      fit: BoxFit.cover,
                    )
                  : const Icon(
                      Icons.description,
                      color: Colors.grey,
                      size: 24,
                    ),
            ),
          ),

          // Page count badge
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${state.pageCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoneButton(BuildContext context) {
    return GestureDetector(
      onTap: onFinish,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Done',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
