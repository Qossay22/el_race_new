import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:camera/camera.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../../utils/safe_insets.dart';

import 'services/image_queue_service.dart';
import '../document_scanner/data/services/document_export_service.dart';
import '../document_scanner/data/services/image_processing_service.dart';
import '../document_scanner/domain/entities/document_page.dart';
import '../document_scanner/domain/entities/scanned_document.dart';
import '../qr_code/qr_scanner_screen.dart';

/// Camera Selection Screen with built-in camera preview
/// Shows SCAN and PHOTO buttons at bottom
class CameraSelectionScreen extends StatefulWidget {
  const CameraSelectionScreen({super.key});

  @override
  State<CameraSelectionScreen> createState() => _CameraSelectionScreenState();
}

class _CameraSelectionScreenState extends State<CameraSelectionScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  late Future<void> _initializeControllerFuture;
  String _currentDate = '';
  String _currentTime = '';
  String _currentLocation = '';
  bool _isCapturing = false;
  Uint8List? _logoBytes;
  Timer? _locationRefreshTimer;
  int _locationRetryCount = 0;

  // Image queue service for background processing
  final ImageQueueService _imageQueueService = ImageQueueService();
  StreamSubscription<int>? _queueCountSubscription;
  StreamSubscription<ProcessingStatus>? _processingStatusSubscription;
  int _pendingImagesCount = 0;
  int _totalCapturedCount = 0;
  String _processingStatusText = '';

  // Screenshot capture key
  final GlobalKey _captureKey = GlobalKey();
  int _savePendingCount = 0;

  // Inline scan/filter state
  final ImageProcessingService _imageProcessingService =
      ImageProcessingService();
  final DocumentExportService _exportService = DocumentExportService();
  String? _scanOriginalPath;
  String? _scanFilteredPath;
  bool _showScanOverlay = false;
  bool _isProcessingFilter = false;
  bool _isExportingPdf = false;
  ImageFilterType _selectedFilter = ImageFilterType.magic;
  final Map<ImageFilterType, String> _filterCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enableImmersiveMode();
    _initializeCamera();
    _updateTime();
    _loadLogo();
    _fetchLocation();

    // Refresh location every 60 seconds to keep it up-to-date
    _locationRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _fetchLocation();
    });

    // Listen to queue updates
    _queueCountSubscription = _imageQueueService.queueCount.listen((count) {
      if (mounted) {
        setState(() {
          _pendingImagesCount = count;
        });
      }
    });

    _processingStatusSubscription =
        _imageQueueService.processingStatus.listen((status) {
      if (mounted) {
        setState(() {
          _processingStatusText = status.progressText;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Re-enable immersive on resume (Samsung resets system bars)
    if (state == AppLifecycleState.resumed) {
      _enableImmersiveMode();
    }
  }

  void _enableImmersiveMode() {
    // Show all system UI (status bar and navigation bar)
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

  Future<void> _loadLogo() async {
    try {
      final data = await rootBundle.load('assets/logo/rcc2.png');
      if (mounted) {
        setState(() {
          _logoBytes = data.buffer.asUint8List();
        });
      }
      debugPrint('✓ Logo rcc2.png loaded: ${data.lengthInBytes} bytes');
    } catch (e) {
      debugPrint('✗ Error loading logo: $e');
    }
  }

  Future<void> _fetchLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled.');
        _scheduleLocationRetry();
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied');
          _scheduleLocationRetry();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied');
        return;
      }

      // Get current position with timeout
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw Exception('GPS timeout');
      });

      // Try to get address from coordinates
      String locationText = '';
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        ).timeout(const Duration(seconds: 8));

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;

          // Show the specific area/neighborhood + emirate/city
          // Priority: subLocality > thoroughfare > locality
          if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            locationText = place.subLocality!;
          } else if (place.thoroughfare != null &&
              place.thoroughfare!.isNotEmpty) {
            locationText = place.thoroughfare!;
          } else if (place.locality != null && place.locality!.isNotEmpty) {
            locationText = place.locality!;
          }

          // Add emirate/city (locality or administrativeArea)
          String emirate = '';
          if (place.locality != null &&
              place.locality!.isNotEmpty &&
              place.locality != locationText) {
            emirate = place.locality!;
          } else if (place.administrativeArea != null &&
              place.administrativeArea!.isNotEmpty) {
            emirate = place.administrativeArea!;
          }

          if (emirate.isNotEmpty && locationText.isNotEmpty) {
            locationText = '$locationText, $emirate';
          } else if (emirate.isNotEmpty) {
            locationText = emirate;
          }
        }
      } catch (geocodeError) {
        debugPrint('✗ Reverse geocoding failed: $geocodeError');
      }

      // Fallback to GPS coordinates if geocoding returned nothing
      if (locationText.isEmpty) {
        locationText =
            '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
        debugPrint('⚠ Using GPS coordinates as fallback: $locationText');
      }

      if (mounted) {
        setState(() {
          _currentLocation = locationText;
        });
        _locationRetryCount = 0; // Reset retry count on success
        debugPrint('✓ Location fetched: $_currentLocation');
      }
    } catch (e) {
      debugPrint('✗ Error fetching location: $e');
      _scheduleLocationRetry();
    }
  }

  /// Retry location fetch with increasing delay (max 3 retries)
  void _scheduleLocationRetry() {
    if (_locationRetryCount >= 3 || !mounted) return;
    _locationRetryCount++;
    final delay = Duration(seconds: 3 * _locationRetryCount);
    debugPrint(
        '↻ Retrying location fetch in ${delay.inSeconds}s (attempt $_locationRetryCount/3)');
    Future.delayed(delay, () {
      if (mounted) _fetchLocation();
    });
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.max,
        enableAudio: false,
      );

      // Fully await initialization before setState so FutureBuilder sees a
      // completed future immediately — prevents black-screen flash.
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      _controller = controller;
      _initializeControllerFuture = Future.value();
      setState(() {});
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentDate = DateFormat('dd/MM/yyyy').format(now);
      _currentTime = DateFormat('hh:mm a').format(now);
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _updateTime();
    });
  }

  @override
  void dispose() {
    _restoreSystemUI();
    _locationRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _queueCountSubscription?.cancel();
    _processingStatusSubscription?.cancel();
    super.dispose();
  }

  void _takePicture() {
    final boundary = _captureKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return;

    // Increment count instantly — zero delay for UI feedback
    _totalCapturedCount++;
    _savePendingCount++;
    if (mounted) setState(() {});

    // Fire-and-forget: capture + encode + save all in background
    _captureAndSave(boundary);
  }

  /// Entire capture pipeline runs async without blocking UI
  Future<void> _captureAndSave(RenderRepaintBoundary boundary) async {
    try {
      // pixelRatio 2.0 gives great quality, much faster than 3.0
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final int width = image.width;
      final int height = image.height;
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();

      if (byteData == null) {
        _savePendingCount--;
        if (mounted) setState(() {});
        return;
      }

      // Encode to JPEG in background isolate to avoid jank
      final Uint8List rgba = byteData.buffer.asUint8List();

      final Uint8List jpgBytes = await compute(
          _encodeRgbaToJpg,
          _EncodeParams(
            rgba: rgba,
            width: width,
            height: height,
          ));

      // Save to gallery
      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(filePath).writeAsBytes(jpgBytes, flush: true);
      await Gal.putImage(filePath, album: 'RCC');
      try {
        await File(filePath).delete();
      } catch (_) {}
      debugPrint('✓ Photo saved to gallery');
    } catch (e) {
      debugPrint('✗ Capture/save error: $e');
    }
    _savePendingCount--;
    if (mounted) setState(() {});
  }

  /// Overlay text style matching the live preview
  TextStyle _overlayTextStyle(double fontSize) {
    return GoogleFonts.poppins(
      fontSize: fontSize,
      color: Colors.grey[200]!.withOpacity(0.85),
      fontWeight: FontWeight.w400,
      shadows: [
        Shadow(
          color: Colors.grey.withOpacity(0.5),
          offset: const Offset(-1, -1),
          blurRadius: 2,
        ),
        Shadow(
          color: Colors.grey.withOpacity(0.5),
          offset: const Offset(1, -1),
          blurRadius: 2,
        ),
        Shadow(
          color: Colors.grey.withOpacity(0.5),
          offset: const Offset(1, 1),
          blurRadius: 2,
        ),
        Shadow(
          color: Colors.grey.withOpacity(0.5),
          offset: const Offset(-1, 1),
          blurRadius: 2,
        ),
        Shadow(
          color: Colors.grey.withOpacity(0.3),
          offset: const Offset(0, 0),
          blurRadius: 4,
        ),
      ],
    );
  }

  Future<String?> _composeWithOverlay(String imagePath) async {
    try {
      // Read base image
      final bytes = await File(imagePath).readAsBytes();
      img.Image? baseImage = img.decodeImage(bytes);
      if (baseImage == null) return imagePath;

      final int padding = (baseImage.width * 0.04).toInt();

      // Add logo if available
      if (_logoBytes != null) {
        img.Image? logo = img.decodeImage(_logoBytes!);
        if (logo != null) {
          // Resize logo with high quality interpolation
          final int logoWidth = (baseImage.width * 0.22).toInt();
          final int logoHeight = (logoWidth * logo.height / logo.width).toInt();
          logo = img.copyResize(
            logo,
            width: logoWidth,
            height: logoHeight,
            interpolation: img.Interpolation.cubic,
          );

          // Composite logo onto base image
          img.compositeImage(
            baseImage,
            logo,
            dstX: padding,
            dstY: padding,
          );
        }
      }

      // Draw date, time, and location text with shadow (all same font, aligned)
      final font = baseImage.width >= 2000 ? img.arial48 : img.arial24;
      final shadowOffset = 1;

      // Measure actual text widths using font metrics
      int measureWidth(img.BitmapFont f, String text) {
        int w = 0;
        for (var ch in text.codeUnits) {
          if (f.characters.containsKey(ch)) {
            w += f.characters[ch]!.xAdvance;
          }
        }
        return w;
      }

      final timeTextWidth = measureWidth(font, _currentTime);
      final dateTextWidth = measureWidth(font, _currentDate);
      final locationTextWidth = _currentLocation.isNotEmpty
          ? measureWidth(font, _currentLocation)
          : 0;

      // Find widest to align all from the same left edge
      int maxWidth = timeTextWidth;
      if (dateTextWidth > maxWidth) maxWidth = dateTextWidth;
      if (locationTextWidth > maxWidth) maxWidth = locationTextWidth;

      final int rightEdge = baseImage.width - padding;
      final int lineHeight =
          font.lineHeight + (baseImage.width >= 2000 ? 14 : 10);
      final int totalLines = _currentLocation.isNotEmpty ? 3 : 2;
      int currentY = baseImage.height - padding - (lineHeight * totalLines);

      // Draw time (right-aligned) — matching live preview colors
      final int timeX = rightEdge - timeTextWidth;
      img.drawString(baseImage, _currentTime,
          font: font,
          x: timeX + shadowOffset,
          y: currentY + shadowOffset,
          color: img.ColorRgb8(130, 130, 130));
      img.drawString(baseImage, _currentTime,
          font: font,
          x: timeX,
          y: currentY,
          color: img.ColorRgb8(205, 205, 205));

      currentY += lineHeight;

      // Draw date (right-aligned)
      final int dateX = rightEdge - dateTextWidth;
      img.drawString(baseImage, _currentDate,
          font: font,
          x: dateX + shadowOffset,
          y: currentY + shadowOffset,
          color: img.ColorRgb8(130, 130, 130));
      img.drawString(baseImage, _currentDate,
          font: font,
          x: dateX,
          y: currentY,
          color: img.ColorRgb8(205, 205, 205));

      // Draw location (right-aligned)
      if (_currentLocation.isNotEmpty) {
        currentY += lineHeight;
        final int locationX = rightEdge - locationTextWidth;
        img.drawString(baseImage, _currentLocation,
            font: font,
            x: locationX + shadowOffset,
            y: currentY + shadowOffset,
            color: img.ColorRgb8(130, 130, 130));
        img.drawString(baseImage, _currentLocation,
            font: font,
            x: locationX,
            y: currentY,
            color: img.ColorRgb8(205, 205, 205));
      }

      // Save the result with optimized quality
      final outputBytes = img.encodeJpg(baseImage, quality: 95);
      await File(imagePath).writeAsBytes(outputBytes);
      return imagePath;
    } catch (e) {
      debugPrint('Error composing overlay: $e');
      return imagePath;
    }
  }

  Future<void> _captureForScan() async {
    if (_isCapturing || _controller == null) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      await _initializeControllerFuture;
      final file = await _controller!.takePicture();

      // Show overlay immediately
      setState(() {
        _scanOriginalPath = file.path;
        _scanFilteredPath = null;
        _filterCache.clear();
        _selectedFilter = ImageFilterType.magic;
        _showScanOverlay = true;
        _isCapturing = false;
      });

      // Process overlay and filter in background
      _composeWithOverlay(file.path).then((withOverlay) {
        if (mounted) {
          setState(() {
            _scanOriginalPath = withOverlay ?? file.path;
          });
        }
        return _applyScanFilter(ImageFilterType.magic);
      });
    } catch (e) {
      debugPrint('Scan capture error: $e');
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _applyScanFilter(ImageFilterType filter) async {
    if (_scanOriginalPath == null) return;

    if (_filterCache[filter] != null) {
      setState(() {
        _selectedFilter = filter;
        _scanFilteredPath = _filterCache[filter];
      });
      return;
    }

    setState(() {
      _selectedFilter = filter;
      _isProcessingFilter = true;
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/inline_scan_${DateTime.now().millisecondsSinceEpoch}_${filter.name}.jpg';

      final processedPath = await _imageProcessingService.applyFilter(
        _scanOriginalPath!,
        filter,
        outputPath,
      );

      _filterCache[filter] = processedPath;

      if (mounted) {
        setState(() {
          _scanFilteredPath = processedPath;
        });
      }
    } catch (e) {
      debugPrint('Filter error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Filter failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingFilter = false;
        });
      }
    }
  }

  Future<void> _saveScanResult() async {
    final targetPath = _scanFilteredPath ?? _scanOriginalPath;
    if (targetPath == null) return;

    try {
      await Gal.putImage(targetPath, album: 'RCC');
      if (mounted) {
        // Navigate back first, then show snackbar on the previous screen
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scan saved to gallery ✓'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Save scan error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareScanAsPdf() async {
    final targetPath = _scanFilteredPath ?? _scanOriginalPath;
    if (targetPath == null) return;

    setState(() {
      _isExportingPdf = true;
    });

    try {
      final page = DocumentPage(
        id: 'inline-scan-${DateTime.now().millisecondsSinceEpoch}',
        originalImagePath: targetPath,
        processedImagePath: targetPath,
        filterType: _selectedFilter,
        pageNumber: 1,
        capturedAt: DateTime.now(),
        edgeDetectionSuccessful: false,
      );

      final exportDir = await _exportService.getExportDirectory();
      final pdfPath =
          '$exportDir/scan_${DateTime.now().millisecondsSinceEpoch}.pdf';

      await _exportService.exportToPdf([
        page,
      ], pdfPath, ExportQuality.high);

      await Share.shareXFiles([
        XFile(pdfPath),
      ]);
    } catch (e) {
      debugPrint('Export PDF error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF share failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExportingPdf = false;
        });
      }
    }
  }

  void _openScanner() async {
    try {
      final pictures = await CunningDocumentScanner.getPictures(
        noOfPages: 20,
        isGalleryImportAllowed: true,
      );

      if (!mounted) return;
      if (pictures == null || pictures.isEmpty) return;

      // Navigate back immediately so the UI is responsive
      Navigator.pop(context);

      // Process overlays + save in background (no main-thread freeze)
      int savedCount = 0;
      for (final picturePath in pictures) {
        try {
          await compute(
            _applyOverlayIsolate,
            _OverlayParams(
              imagePath: picturePath,
              logoBytes: _logoBytes,
              currentTime: _currentTime,
              currentDate: _currentDate,
              currentLocation: _currentLocation,
            ),
          );
          await Gal.putImage(picturePath, album: 'RCC');
          savedCount++;
        } catch (e) {
          debugPrint('Error processing scanned page: $e');
        }
      }

      if (savedCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$savedCount page${savedCount > 1 ? 's' : ''} scanned & saved',
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on PlatformException catch (e) {
      debugPrint('Document scanner error: $e');
    }
  }

  void _openQrScanner() async {
    try {
      // Grab the current controller but don't null it yet — keep the frozen
      // camera frame visible during the push transition (no loading flicker).
      final oldController = _controller;

      // Dispose silently so the hardware is released before QR scanner opens.
      _controller = null;
      await oldController?.dispose();

      // Navigate to QR scanner screen; returns true on successful scan
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => const QrScannerScreen(),
          fullscreenDialog: true,
        ),
      );

      // If QR was scanned successfully, leave the camera screen too
      if (result == true && mounted) {
        Navigator.pop(context);
        return;
      }

      if (!mounted) return;

      // Show a spinner while we wait for Android to fully release the hardware
      // from MobileScanner before we reopen it.
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 400));

      if (mounted) await _initializeCamera();
    } catch (e) {
      debugPrint('QR scanner error: $e');
      if (mounted) {
        await _initializeCamera();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('QR scanner error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final H = MediaQuery.of(context).size.height;

    if (_controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black12,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black12,
      body: FutureBuilder(
        future: _initializeControllerFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white));
          }

          return Stack(children: [
            /// ================================
            /// TRANSPARENT/GRADIENT BACKGROUND
            /// ================================
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.8,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.85),
                  ],
                ),
              ),
            ),

            /// ================================
            /// CAMERA PREVIEW WITH OVERLAYS (SCREENSHOT CAPTURE)
            /// ================================
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: RepaintBoundary(
                  key: _captureKey,
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Camera feed
                        CameraPreview(_controller!),
                        // Logo (top-left)
                        Positioned(
                          top: 5.h,
                          left: 10.w,
                          child: Image.asset(
                            'assets/logo/rcc2.png',
                            height: 27.h,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                        // Date/time/location (bottom-right)
                        Positioned(
                          bottom: 12.h,
                          right: 12.w,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _currentTime,
                                style: _overlayTextStyle(16.sp),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                _currentDate,
                                style: _overlayTextStyle(16.sp),
                              ),
                              if (_currentLocation.isNotEmpty) ...[
                                SizedBox(height: 4.h),
                                Text(
                                  _currentLocation,
                                  style: _overlayTextStyle(14.sp),
                                  textAlign: TextAlign.right,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            /// ================================
            /// TOP GLASS BAR (LOGO + BACK)
            /// ================================
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  height: 100.h,
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// BACK ARROW
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            /// ================================
            /// PHOTO COUNTER (RIGHT TOP)
            /// ================================
            if (_totalCapturedCount > 0)
              Center(
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Padding(
                    padding: EdgeInsets.only(top: 30.h, right: 20.w),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 12.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.photo_camera,
                              color: Colors.white,
                              size: 16.sp,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              '$_totalCapturedCount',
                              style: GoogleFonts.poppins(
                                fontSize: 16.sp,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            /// ================================
            /// BOTTOM CONTROLS CONTAINER
            /// ================================
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BottomDock(
                extra: 0,
                liftWithKeyboard:
                    false, // Camera doesn't need keyboard handling
                child: Container(
                  width: double.infinity,
                  height: H * 0.15,
                  padding:
                      EdgeInsets.symmetric(horizontal: 30.w, vertical: 2.h),
                  decoration: const BoxDecoration(
                    color: Colors.black12,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      /// ——— PROCESSING STATUS INDICATOR ———
                      if (_processingStatusText.isNotEmpty ||
                          _pendingImagesCount > 0 ||
                          _savePendingCount > 0)
                        Container(
                          margin: EdgeInsets.only(bottom: 4.h),
                          padding: EdgeInsets.symmetric(
                              horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_imageQueueService.isProcessing ||
                                  _savePendingCount > 0)
                                Padding(
                                  padding: EdgeInsets.only(right: 6.w),
                                  child: SizedBox(
                                    width: 10.w,
                                    height: 10.w,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              Text(
                                _savePendingCount > 0
                                    ? 'Saving $_savePendingCount photo${_savePendingCount > 1 ? 's' : ''}...'
                                    : _processingStatusText.isNotEmpty
                                        ? _processingStatusText
                                        : 'Saving $_pendingImagesCount photo${_pendingImagesCount > 1 ? 's' : ''}...',
                                style: GoogleFonts.poppins(
                                  fontSize: 10.sp,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                      /// ——— SHOOT BUTTON ———
                      GestureDetector(
                        onTap: _takePicture,
                        child: Container(
                          width: 50.w,
                          height: 50.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 55.w,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 6.h),

                      /// ——— SCAN / PHOTO / QR BUTTONS ———
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _glassButton("SCAN", _openScanner),
                          _glassButton("PHOTO", _takePicture),
                          _glassButton("QR", _openQrScanner),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (_showScanOverlay) _buildScanOverlay(),
          ]);
        },
      ),
    );
  }

  Widget _buildScanOverlay() {
    final previewPath = _scanFilteredPath ?? _scanOriginalPath;
    const appBlue = Color(0xff2B2C74);

    return Positioned.fill(
      child: Material(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              // ── App-style top bar ──────────────────────────────
              Container(
                color: appBlue,
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 20.sp),
                      onPressed: () => setState(() => _showScanOverlay = false),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            'Document Scan',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 17.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_isProcessingFilter) ...[
                            SizedBox(width: 10.w),
                            SizedBox(
                              width: 14.w,
                              height: 14.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _actionButton(
                      icon: Icons.save_alt_rounded,
                      label: 'Save',
                      onTap: _saveScanResult,
                      isPrimary: false,
                    ),
                    SizedBox(width: 8.w),
                    _actionButton(
                      icon: Icons.share_rounded,
                      label: 'PDF',
                      onTap: _isExportingPdf ? null : _shareScanAsPdf,
                      isLoading: _isExportingPdf,
                      isPrimary: true,
                    ),
                    SizedBox(width: 4.w),
                  ],
                ),
              ),

              // ── Image preview ──────────────────────────────────
              Expanded(
                child: Container(
                  color: const Color(0xffECECF2),
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                  child: previewPath == null
                      ? _buildLoadingSkeleton()
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Stack(
                            key: ValueKey(previewPath),
                            alignment: Alignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12.r),
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.12),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12.r),
                                  child: Image.file(
                                    File(previewPath),
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                  ),
                                ),
                              ),
                              if (_isProcessingFilter)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12.r),
                                  child: BackdropFilter(
                                    filter: ui.ImageFilter.blur(
                                        sigmaX: 3, sigmaY: 3),
                                    child: Container(
                                      color: Colors.white.withOpacity(0.4),
                                      child: Center(
                                          child: _buildProcessingIndicator()),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
              ),

              // ── Filter bar ────────────────────────────────────
              Container(
                color: Colors.white,
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 20.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_fix_high_rounded,
                            color: appBlue, size: 15.sp),
                        SizedBox(width: 6.w),
                        Text(
                          'Enhancement',
                          style: GoogleFonts.poppins(
                            color: appBlue,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    SizedBox(
                      height: 72.h,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: ImageFilterType.values.length,
                        itemBuilder: (context, index) =>
                            _modernFilterCard(ImageFilterType.values[index]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    const appBlue = Color(0xff2B2C74);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36.w,
              height: 36.w,
              child: const CircularProgressIndicator(
                strokeWidth: 2.5,
                color: appBlue,
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              'Processing scan...',
              style: GoogleFonts.poppins(
                color: const Color(0xff2B2C74),
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingIndicator() {
    const appBlue = Color(0xff2B2C74);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28.w,
            height: 28.w,
            child: const CircularProgressIndicator(
              strokeWidth: 2.5,
              color: appBlue,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            'Applying filter...',
            style: GoogleFonts.poppins(
              color: appBlue,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool isLoading = false,
    bool isPrimary = false,
  }) {
    // Primary = white fill (Save). Secondary = white outline (PDF).
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8.r),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: isPrimary ? Colors.white : Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: Colors.white.withOpacity(isPrimary ? 1.0 : 0.4),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 14.w,
                  height: 14.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xff2B2C74),
                  ),
                )
              else
                Icon(
                  icon,
                  color: isPrimary ? const Color(0xff2B2C74) : Colors.white,
                  size: 16.sp,
                ),
              SizedBox(width: 5.w),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: isPrimary ? const Color(0xff2B2C74) : Colors.white,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modernFilterCard(ImageFilterType type) {
    final bool selected = _selectedFilter == type;
    final filterMeta = _getFilterMeta(type);
    const appBlue = Color(0xff2B2C74);

    return GestureDetector(
      onTap: () => _applyScanFilter(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.only(right: 10.w),
        width: 68.w,
        decoration: BoxDecoration(
          color: selected ? appBlue : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: selected ? appBlue : const Color(0xffDDDDE8),
            width: 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: appBlue.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              filterMeta.icon,
              color: selected ? Colors.white : appBlue,
              size: 20.sp,
            ),
            SizedBox(height: 5.h),
            Text(
              filterMeta.label,
              style: GoogleFonts.poppins(
                color: selected ? Colors.white : const Color(0xff5A5A7A),
                fontSize: 11.sp,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  _FilterMeta _getFilterMeta(ImageFilterType type) {
    switch (type) {
      case ImageFilterType.magic:
        return _FilterMeta('Auto', Colors.cyan, Icons.auto_awesome_rounded);
      case ImageFilterType.enhanced:
        return _FilterMeta('Sharp', Colors.orange, Icons.tune_rounded);
      case ImageFilterType.blackAndWhite:
        return _FilterMeta('B&W', Colors.purple, Icons.filter_b_and_w_rounded);
      case ImageFilterType.grayscale:
        return _FilterMeta('Gray', Colors.blueGrey, Icons.tonality_rounded);
      case ImageFilterType.original:
        return _FilterMeta('Original', Colors.green, Icons.image_rounded);
    }
  }

  Widget _glassButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25.r),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.30),
              borderRadius: BorderRadius.circular(25.r),
              border: Border.all(
                color: Colors.white.withOpacity(0.04),
                width: 1.0,
              ),
            ),
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 15.sp,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// CustomPainter for shadow overlay showing safe zones
class CameraShadowOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Calculate exact overlay areas that match the photo composition
    final padding = size.width * 0.04;

    // Top overlay: Logo area (logo is 14% of width with proportional height)
    final logoWidth = size.width * 0.14;
    final logoHeight = logoWidth * 0.4; // Approximate logo aspect ratio
    final topOverlayHeight = padding * 2 + logoHeight + padding * 2;

    // Bottom overlay: Date/Time text area
    final fontSize = size.width * 0.045;
    final bottomTextHeight = fontSize + 10 + padding;
    final bottomOverlayHeight = bottomTextHeight + padding * 2;

    // Draw top gradient overlay (covers logo area)
    final topGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.black.withOpacity(0.75),
        Colors.black.withOpacity(0.55),
        Colors.black.withOpacity(0.25),
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 0.85, 1.0],
    );

    final topRect = Rect.fromLTWH(0, 0, size.width, topOverlayHeight);
    final topPaint = Paint()..shader = topGradient.createShader(topRect);
    canvas.drawRect(topRect, topPaint);

    // Draw bottom gradient overlay (covers date/time area)
    final bottomGradient = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        Colors.black.withOpacity(0.75),
        Colors.black.withOpacity(0.55),
        Colors.black.withOpacity(0.25),
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 0.85, 1.0],
    );

    final bottomRect = Rect.fromLTWH(
      0,
      size.height - bottomOverlayHeight,
      size.width,
      bottomOverlayHeight,
    );
    final bottomPaint = Paint()
      ..shader = bottomGradient.createShader(bottomRect);
    canvas.drawRect(bottomRect, bottomPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Helper class for filter metadata
class _FilterMeta {
  final String label;
  final Color color;
  final IconData icon;

  _FilterMeta(this.label, this.color, this.icon);
}

/// Parameters for overlay compositing in isolate
class _OverlayParams {
  final String imagePath;
  final Uint8List? logoBytes;
  final String currentTime;
  final String currentDate;
  final String currentLocation;

  _OverlayParams({
    required this.imagePath,
    required this.logoBytes,
    required this.currentTime,
    required this.currentDate,
    required this.currentLocation,
  });
}

/// Runs in a background isolate — applies logo + date/time/location onto image
Future<void> _applyOverlayIsolate(_OverlayParams p) async {
  try {
    final bytes = await File(p.imagePath).readAsBytes();
    img.Image? baseImage = img.decodeImage(bytes);
    if (baseImage == null) return;

    final int padding = (baseImage.width * 0.04).toInt();

    if (p.logoBytes != null) {
      img.Image? logo = img.decodeImage(p.logoBytes!);
      if (logo != null) {
        final int logoWidth = (baseImage.width * 0.22).toInt();
        final int logoHeight = (logoWidth * logo.height / logo.width).toInt();
        logo = img.copyResize(logo,
            width: logoWidth,
            height: logoHeight,
            interpolation: img.Interpolation.cubic);
        img.compositeImage(baseImage, logo, dstX: padding, dstY: padding);
      }
    }

    final font = baseImage.width >= 2000 ? img.arial48 : img.arial24;
    const shadowOffset = 1;

    int measureWidth(img.BitmapFont f, String text) {
      int w = 0;
      for (var ch in text.codeUnits) {
        if (f.characters.containsKey(ch)) w += f.characters[ch]!.xAdvance;
      }
      return w;
    }

    final timeW = measureWidth(font, p.currentTime);
    final dateW = measureWidth(font, p.currentDate);
    final locW = p.currentLocation.isNotEmpty
        ? measureWidth(font, p.currentLocation)
        : 0;

    final int rightEdge = baseImage.width - padding;
    final int lineHeight = font.lineHeight + (baseImage.width >= 2000 ? 12 : 6);
    final int totalLines = p.currentLocation.isNotEmpty ? 3 : 2;
    int y = baseImage.height - padding - (lineHeight * totalLines);

    void drawLine(String text, int w) {
      final x = rightEdge - w;
      img.drawString(baseImage!, text,
          font: font,
          x: x + shadowOffset,
          y: y + shadowOffset,
          color: img.ColorRgb8(130, 130, 130));
      img.drawString(baseImage, text,
          font: font, x: x, y: y, color: img.ColorRgb8(205, 205, 205));
      y += lineHeight;
    }

    drawLine(p.currentTime, timeW);
    drawLine(p.currentDate, dateW);
    if (p.currentLocation.isNotEmpty) drawLine(p.currentLocation, locW);

    final outputBytes = img.encodeJpg(baseImage, quality: 95);
    await File(p.imagePath).writeAsBytes(outputBytes);
  } catch (e) {
    debugPrint('Overlay isolate error: $e');
  }
}

/// Parameters for RGBA → JPG encoding in isolate
class _EncodeParams {
  final Uint8List rgba;
  final int width;
  final int height;
  _EncodeParams(
      {required this.rgba, required this.width, required this.height});
}

/// Runs in a background isolate — converts raw RGBA pixels to JPEG
Uint8List _encodeRgbaToJpg(_EncodeParams p) {
  final image = img.Image.fromBytes(
    width: p.width,
    height: p.height,
    bytes: p.rgba.buffer,
    numChannels: 4,
  );
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}
