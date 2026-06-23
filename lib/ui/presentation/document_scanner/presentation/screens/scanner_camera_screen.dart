import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../../utils/safe_insets.dart';

import '../bloc/document_scanner_bloc.dart';
import '../bloc/document_scanner_event.dart';
import '../bloc/document_scanner_state.dart';
import '../widgets/document_edge_overlay.dart';
import '../widgets/scanner_controls.dart';

/// Camera screen for capturing document images.
///
/// Features:
/// - Full-screen camera preview
/// - Real-time edge detection overlay
/// - Capture button
/// - Flash toggle
/// - Multi-page indicator
class ScannerCameraScreen extends StatefulWidget {
  /// Callback when user wants to go back
  final VoidCallback? onBack;

  /// Callback when user finishes scanning
  final VoidCallback? onFinish;

  const ScannerCameraScreen({
    super.key,
    this.onBack,
    this.onFinish,
  });

  @override
  State<ScannerCameraScreen> createState() => _ScannerCameraScreenState();
}

class _ScannerCameraScreenState extends State<ScannerCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isCapturing = false;
  FlashMode _flashMode = FlashMode.auto;
  String? _error;

  // Edge detection debouncing
  Timer? _edgeDetectionTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enableImmersiveMode();
    _initializeCamera();
  }

  bool _isDisposed = false;

  void _enableImmersiveMode() {
    // Hide bottom navigation bar only, keep status bar
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top],
    );
  }

  void _restoreSystemUI() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _restoreSystemUI();
    WidgetsBinding.instance.removeObserver(this);
    _edgeDetectionTimer?.cancel();
    // Dispose camera asynchronously to avoid CameraX crash
    _disposeCameraAsync();
    super.dispose();
  }

  Future<void> _disposeCameraAsync() async {
    try {
      // Add a small delay to let CameraX finish its operations
      await Future.delayed(const Duration(milliseconds: 100));
      if (_cameraController != null) {
        await _cameraController!.dispose();
        _cameraController = null;
      }
    } catch (e) {
      debugPrint('📷 [ScannerCamera] Error disposing camera: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _enableImmersiveMode(); // Re-enable immersive on Samsung devices
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    // Request camera permission
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() {
        _error = 'Camera permission denied';
      });
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _error = 'No cameras available';
        });
        return;
      }

      // Use back camera
      final camera = _cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        camera,
        // Use high resolution for document scanning
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup:
            Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      // Set focus mode to auto for document scanning
      if (_cameraController!.value.isInitialized) {
        await _cameraController!.setFocusMode(FocusMode.auto);
        await _cameraController!.setFlashMode(_flashMode);
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _error = null;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize camera: $e';
      });
    }
  }

  Future<void> _captureImage() async {
    debugPrint('📷 [ScannerCamera] _captureImage called');
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isCapturing) {
      debugPrint('📷 [ScannerCamera] Camera not ready or already capturing');
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      // Ensure focus is locked before capture
      debugPrint('📷 [ScannerCamera] Setting focus mode to locked');
      await _cameraController!.setFocusMode(FocusMode.locked);

      debugPrint('📷 [ScannerCamera] Taking picture...');
      final image = await _cameraController!.takePicture();
      debugPrint('📷 [ScannerCamera] Picture taken: ${image.path}');

      // Store the image path
      final imagePath = image.path;

      // Reset focus mode (don't await to avoid delays)
      _cameraController?.setFocusMode(FocusMode.auto);

      if (mounted) {
        // Emit event to bloc - let the widget tree handle camera disposal naturally
        debugPrint('📷 [ScannerCamera] Sending ImageCaptured event to BLoC');
        context.read<DocumentScannerBloc>().add(
              ImageCaptured(imagePath: imagePath),
            );
        debugPrint('📷 [ScannerCamera] Event sent successfully');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [ScannerCamera] Error capturing: $e');
      debugPrint('❌ [ScannerCamera] Stack: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    FlashMode newMode;
    switch (_flashMode) {
      case FlashMode.off:
        newMode = FlashMode.auto;
        break;
      case FlashMode.auto:
        newMode = FlashMode.always;
        break;
      case FlashMode.always:
        newMode = FlashMode.torch;
        break;
      case FlashMode.torch:
        newMode = FlashMode.off;
        break;
    }

    try {
      await _cameraController!.setFlashMode(newMode);
      setState(() {
        _flashMode = newMode;
      });
    } catch (e) {
      // Some devices don't support all flash modes
    }
  }

  IconData _getFlashIcon() {
    switch (_flashMode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.torch:
        return Icons.flashlight_on;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DocumentScannerBloc, DocumentScannerState>(
      listenWhen: (previous, current) => previous.phase != current.phase,
      listener: (context, state) {
        // Handle phase changes if needed
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _buildErrorView();
    }

    if (!_isInitialized) {
      return _buildLoadingView();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        _buildCameraPreview(),

        // Edge detection overlay
        BlocBuilder<DocumentScannerBloc, DocumentScannerState>(
          buildWhen: (previous, current) =>
              previous.detectedCorners != current.detectedCorners,
          builder: (context, state) {
            return DocumentEdgeOverlay(
              corners: state.detectedCorners,
              previewSize: _cameraController!.value.previewSize!,
            );
          },
        ),

        // Top controls
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildTopControls(),
        ),

        // Bottom controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: BottomDock(
            extra: 0,
            liftWithKeyboard: false, // Scanner doesn't need keyboard
            child: _buildBottomControls(),
          ),
        ),

        // Processing overlay
        BlocBuilder<DocumentScannerBloc, DocumentScannerState>(
          buildWhen: (previous, current) =>
              previous.isProcessing != current.isProcessing,
          builder: (context, state) {
            if (state.isProcessing) {
              return _buildProcessingOverlay(state.processingMessage);
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildCameraPreview() {
    final controller = _cameraController!;
    final size = MediaQuery.of(context).size;

    // Calculate the scale to fill the screen while maintaining aspect ratio
    double scale = size.aspectRatio * controller.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return Center(
      child: Transform.scale(
        scale: scale,
        child: CameraPreview(controller),
      ),
    );
  }

  Widget _buildTopControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.6),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          IconButton(
            onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
          ),

          // Page count indicator
          BlocBuilder<DocumentScannerBloc, DocumentScannerState>(
            buildWhen: (previous, current) =>
                previous.pageCount != current.pageCount,
            builder: (context, state) {
              if (state.pageCount == 0) return const SizedBox.shrink();

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.description,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${state.pageCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Flash button
          IconButton(
            onPressed: _toggleFlash,
            icon: Icon(_getFlashIcon(), color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: ScannerControls(
        onCapture: _captureImage,
        onFinish: widget.onFinish,
        isCapturing: _isCapturing,
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Initializing camera...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeCamera,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingOverlay(String? message) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(message),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
