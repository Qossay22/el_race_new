import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../bloc/document_scanner_bloc.dart';
import '../bloc/document_scanner_event.dart';
import '../widgets/corner_handle.dart';

/// Screen for adjusting document corners after capture.
///
/// Features:
/// - Displays the captured image
/// - Shows detected/adjustable corners
/// - Allows dragging corners to adjust
/// - Preview of crop result
class CropAdjustmentScreen extends StatefulWidget {
  /// The page being adjusted
  final DocumentPage page;

  /// Callback when adjustment is complete
  final VoidCallback? onComplete;

  /// Callback when user wants to retake
  final VoidCallback? onRetake;

  const CropAdjustmentScreen({
    super.key,
    required this.page,
    this.onComplete,
    this.onRetake,
  });

  @override
  State<CropAdjustmentScreen> createState() => _CropAdjustmentScreenState();
}

class _CropAdjustmentScreenState extends State<CropAdjustmentScreen> {
  late List<Offset> _corners;
  Size? _imageSize;
  Size? _displaySize;

  final GlobalKey _imageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initializeCorners();
  }

  void _initializeCorners() {
    // Use existing corners or create default
    if (widget.page.effectiveCorners != null &&
        widget.page.effectiveCorners!.length == 4) {
      _corners = List.from(widget.page.effectiveCorners!);
    } else if (widget.page.originalSize != null) {
      // Default to full image
      final size = widget.page.originalSize!;
      _corners = [
        const Offset(0, 0),
        Offset(size.width, 0),
        Offset(size.width, size.height),
        Offset(0, size.height),
      ];
    } else {
      // Placeholder corners, will be updated after layout
      _corners = [
        const Offset(50, 50),
        const Offset(250, 50),
        const Offset(250, 350),
        const Offset(50, 350),
      ];
    }
    _imageSize = widget.page.originalSize;
  }

  void _updateDisplayMetrics() {
    final RenderBox? renderBox =
        _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      _displaySize = renderBox.size;
    }
  }

  Offset _imageToDisplay(Offset imagePoint) {
    if (_imageSize == null || _displaySize == null) {
      return imagePoint;
    }

    final scaleX = _displaySize!.width / _imageSize!.width;
    final scaleY = _displaySize!.height / _imageSize!.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    // Calculate offset for centering
    final scaledWidth = _imageSize!.width * scale;
    final scaledHeight = _imageSize!.height * scale;
    final offsetX = (_displaySize!.width - scaledWidth) / 2;
    final offsetY = (_displaySize!.height - scaledHeight) / 2;

    return Offset(
      imagePoint.dx * scale + offsetX,
      imagePoint.dy * scale + offsetY,
    );
  }

  Offset _displayToImage(Offset displayPoint) {
    if (_imageSize == null || _displaySize == null) {
      return displayPoint;
    }

    final scaleX = _displaySize!.width / _imageSize!.width;
    final scaleY = _displaySize!.height / _imageSize!.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    // Calculate offset for centering
    final scaledWidth = _imageSize!.width * scale;
    final scaledHeight = _imageSize!.height * scale;
    final offsetX = (_displaySize!.width - scaledWidth) / 2;
    final offsetY = (_displaySize!.height - scaledHeight) / 2;

    return Offset(
      (displayPoint.dx - offsetX) / scale,
      (displayPoint.dy - offsetY) / scale,
    );
  }

  void _onCornerDrag(int cornerIndex, Offset delta) {
    setState(() {
      final currentDisplay = _imageToDisplay(_corners[cornerIndex]);
      final newDisplay = currentDisplay + delta;
      _corners[cornerIndex] = _displayToImage(newDisplay);

      // Clamp to image bounds
      if (_imageSize != null) {
        _corners[cornerIndex] = Offset(
          _corners[cornerIndex].dx.clamp(0, _imageSize!.width),
          _corners[cornerIndex].dy.clamp(0, _imageSize!.height),
        );
      }
    });
  }

  void _onConfirm() {
    // Save corners to bloc
    context.read<DocumentScannerBloc>().add(
          UpdateCorners(
            pageId: widget.page.id,
            corners: _corners,
          ),
        );

    // Process the page with current filter
    context.read<DocumentScannerBloc>().add(
          ProcessPage(
            pageId: widget.page.id,
            filterType: widget.page.filterType,
          ),
        );

    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Adjust Corners',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: _onConfirm,
            child: const Text(
              'Done',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Image with corners
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        // Image
                        Center(
                          child: Image.file(
                            File(widget.page.originalImagePath),
                            key: _imageKey,
                            fit: BoxFit.contain,
                            frameBuilder: (context, child, frame,
                                wasSynchronouslyLoaded) {
                              if (frame != null) {
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  _updateDisplayMetrics();
                                  if (mounted) setState(() {});
                                });
                              }
                              return child;
                            },
                          ),
                        ),

                        // Corner overlay and handles
                        if (_displaySize != null)
                          CustomPaint(
                            painter: CropOverlayPainter(
                              corners: _corners.map(_imageToDisplay).toList(),
                            ),
                            child: Stack(
                              children: List.generate(4, (index) {
                                final displayCorner =
                                    _imageToDisplay(_corners[index]);
                                return Positioned(
                                  left: displayCorner.dx - 20,
                                  top: displayCorner.dy - 20,
                                  child: GestureDetector(
                                    onPanUpdate: (details) {
                                      _onCornerDrag(index, details.delta);
                                    },
                                    child: const CornerHandle(),
                                  ),
                                );
                              }),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // Bottom controls
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Retake button
                  TextButton.icon(
                    onPressed: widget.onRetake,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text(
                      'Retake',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),

                  // Auto-detect button
                  TextButton.icon(
                    onPressed: _autoDetectCorners,
                    icon: const Icon(Icons.auto_fix_high, color: Colors.white),
                    label: const Text(
                      'Auto',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),

                  // Reset button
                  TextButton.icon(
                    onPressed: _resetCorners,
                    icon: const Icon(Icons.crop_free, color: Colors.white),
                    label: const Text(
                      'Reset',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _autoDetectCorners() {
    // Re-run edge detection
    if (widget.page.detectedCorners != null &&
        widget.page.detectedCorners!.length == 4) {
      setState(() {
        _corners = List.from(widget.page.detectedCorners!);
      });
    }
  }

  void _resetCorners() {
    if (_imageSize != null) {
      setState(() {
        _corners = [
          const Offset(0, 0),
          Offset(_imageSize!.width, 0),
          Offset(_imageSize!.width, _imageSize!.height),
          Offset(0, _imageSize!.height),
        ];
      });
    }
  }
}

/// Painter for the crop overlay
class CropOverlayPainter extends CustomPainter {
  final List<Offset> corners;

  CropOverlayPainter({required this.corners});

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length != 4) return;

    // Draw semi-transparent overlay outside the crop area
    final path = Path()
      ..moveTo(corners[0].dx, corners[0].dy)
      ..lineTo(corners[1].dx, corners[1].dy)
      ..lineTo(corners[2].dx, corners[2].dy)
      ..lineTo(corners[3].dx, corners[3].dy)
      ..close();

    // Draw the crop border
    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(path, borderPaint);

    // Draw grid lines inside the crop area
    final gridPaint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Vertical grid lines
    for (int i = 1; i < 3; i++) {
      final t = i / 3.0;
      final topPoint = Offset.lerp(corners[0], corners[1], t)!;
      final bottomPoint = Offset.lerp(corners[3], corners[2], t)!;
      canvas.drawLine(topPoint, bottomPoint, gridPaint);
    }

    // Horizontal grid lines
    for (int i = 1; i < 3; i++) {
      final t = i / 3.0;
      final leftPoint = Offset.lerp(corners[0], corners[3], t)!;
      final rightPoint = Offset.lerp(corners[1], corners[2], t)!;
      canvas.drawLine(leftPoint, rightPoint, gridPaint);
    }
  }

  @override
  bool shouldRepaint(CropOverlayPainter oldDelegate) {
    return corners != oldDelegate.corners;
  }
}
