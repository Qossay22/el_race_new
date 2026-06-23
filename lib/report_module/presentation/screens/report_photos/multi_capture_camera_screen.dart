import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// A camera screen that lets the user take multiple photos in one session.
/// Returns a list of [XFile] paths when the user taps "Done".
class MultiCaptureCameraScreen extends StatefulWidget {
  const MultiCaptureCameraScreen({super.key});

  @override
  State<MultiCaptureCameraScreen> createState() =>
      _MultiCaptureCameraScreenState();
}

class _MultiCaptureCameraScreenState extends State<MultiCaptureCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  final List<String> _capturedPaths = [];
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _permissionDenied = false;
  int _selectedCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    final permission = await Permission.camera.request();
    if (!permission.isGranted && !permission.isLimited) {
      if (mounted) setState(() => _permissionDenied = true);
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _permissionDenied = true);
        return;
      }
      await _setupController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      debugPrint('Camera list error: $e');
      if (mounted) setState(() => _permissionDenied = true);
    }
  }

  Future<void> _setupController(CameraDescription camera) async {
    _controller?.dispose();
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = controller;
    try {
      await controller.initialize();
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) Navigator.pop(context, <String>[]);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _setupController(_cameras[_selectedCameraIndex]);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return;
    }
    setState(() => _isCapturing = true);
    try {
      final file = await _controller!.takePicture();
      final squarePath = await _cropCapturedPhotoToSquare(file.path);
      setState(() => _capturedPaths.add(squarePath));
    } catch (e) {
      debugPrint('Capture error: $e');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<String> _cropCapturedPhotoToSquare(String originalPath) async {
    try {
      final originalBytes = await File(originalPath).readAsBytes();
      final decoded = img.decodeImage(originalBytes);
      if (decoded == null) return originalPath;

      final cropSize =
          decoded.width < decoded.height ? decoded.width : decoded.height;
      final x = ((decoded.width - cropSize) / 2).round();
      final y = ((decoded.height - cropSize) / 2).round();

      final square = img.copyCrop(
        decoded,
        x: x,
        y: y,
        width: cropSize,
        height: cropSize,
      );

      final encoded = Uint8List.fromList(img.encodeJpg(square, quality: 92));
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/square_${DateTime.now().microsecondsSinceEpoch}.jpg';
      await File(path).writeAsBytes(encoded, flush: true);
      return path;
    } catch (e) {
      debugPrint('Square crop error: $e');
      return originalPath;
    }
  }

  void _switchCamera() {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    setState(() => _isInitialized = false);
    _setupController(_cameras[_selectedCameraIndex]);
  }

  void _done() {
    Navigator.pop(context, _capturedPaths);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera preview
            if (_permissionDenied)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(24.w),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.camera_alt_outlined,
                          color: Colors.white, size: 56.sp),
                      SizedBox(height: 16.h),
                      Text(
                        'Camera access is required to take photos.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      const ElevatedButton(
                        onPressed: openAppSettings,
                        child: Text('Open Settings'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_isInitialized && _controller != null)
              Positioned.fill(
                child: CameraPreview(_controller!),
              )
            else
              const Center(
                  child: CircularProgressIndicator(color: Colors.white)),

            // Top bar — close + counter
            Positioned(
              top: 12.h,
              left: 16.w,
              right: 16.w,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Close (discard all)
                  GestureDetector(
                    onTap: () => Navigator.pop(context, <String>[]),
                    child: Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(24.r),
                      ),
                      child:
                          Icon(Icons.close, color: Colors.white, size: 24.sp),
                    ),
                  ),
                  // Photo counter badge
                  if (_capturedPaths.isNotEmpty)
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        '${_capturedPaths.length} photo${_capturedPaths.length == 1 ? '' : 's'}',
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom controls
            Positioned(
              bottom: 24.h,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Thumbnail row of captured photos
                  if (_capturedPaths.isNotEmpty)
                    Container(
                      height: 56.h,
                      margin: EdgeInsets.only(bottom: 16.h),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: 24.w),
                        itemCount: _capturedPaths.length,
                        separatorBuilder: (_, __) => SizedBox(width: 8.w),
                        itemBuilder: (_, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(8.r),
                          child: Image.file(
                            File(_capturedPaths[i]),
                            width: 56.h,
                            height: 56.h,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  // Shutter row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Switch camera
                      GestureDetector(
                        onTap: _switchCamera,
                        child: Container(
                          padding: EdgeInsets.all(12.r),
                          decoration: const BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.flip_camera_ios,
                              color: Colors.white, size: 26.sp),
                        ),
                      ),
                      // Shutter button
                      GestureDetector(
                        onTap: _capturePhoto,
                        child: Container(
                          width: 72.r,
                          height: 72.r,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4.r),
                          ),
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 100),
                              width: _isCapturing ? 54.r : 60.r,
                              height: _isCapturing ? 54.r : 60.r,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Done button
                      GestureDetector(
                        onTap: _capturedPaths.isNotEmpty ? _done : null,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 18.w, vertical: 10.h),
                          decoration: BoxDecoration(
                            color: _capturedPaths.isNotEmpty
                                ? const Color(0xFF27304E)
                                : Colors.black26,
                            borderRadius: BorderRadius.circular(24.r),
                          ),
                          child: Text(
                            'Done',
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              color: _capturedPaths.isNotEmpty
                                  ? Colors.white
                                  : Colors.white38,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
