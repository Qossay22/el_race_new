import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:gal/gal.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Regular Camera Screen with Logo on top and Date/Time on bottom
/// Saves photo to device gallery
class RegularCameraScreen extends StatefulWidget {
  final CameraController cameraController;
  final List<CameraDescription> cameras;

  const RegularCameraScreen({
    super.key,
    required this.cameraController,
    required this.cameras,
  });

  @override
  State<RegularCameraScreen> createState() => _RegularCameraScreenState();
}

class _RegularCameraScreenState extends State<RegularCameraScreen> {
  late CameraController _controller;
  int _selectedCameraIndex = 0;
  String _currentDateTime = '';
  String _currentLocation = '';
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.cameraController;
    _selectedCameraIndex = widget.cameras.indexWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
    );
    if (_selectedCameraIndex == -1) _selectedCameraIndex = 0;
    _updateDateTime();
    _fetchLocation();

    // Update time every second
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        _updateDateTime();
        return true;
      }
      return false;
    });
  }

  void _updateDateTime() {
    if (mounted) {
      setState(() {
        final now = DateTime.now();
        _currentDateTime = DateFormat('dd/MM/yyyy\nhh:mm a').format(now);
      });
    }
  }

  Future<void> _fetchLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled.');
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied');
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks.first;
        String locationText = '';
        
        // Show the specific area/neighborhood + emirate/city
        // Priority: subLocality > thoroughfare > locality
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          locationText = place.subLocality!;
        } else if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) {
          locationText = place.thoroughfare!;
        } else if (place.locality != null && place.locality!.isNotEmpty) {
          locationText = place.locality!;
        }
        
        // Add emirate/city (locality or administrativeArea)
        String emirate = '';
        if (place.locality != null && place.locality!.isNotEmpty && place.locality != locationText) {
          emirate = place.locality!;
        } else if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          emirate = place.administrativeArea!;
        }
        
        if (emirate.isNotEmpty && locationText.isNotEmpty) {
          locationText = '$locationText, $emirate';
        } else if (emirate.isNotEmpty) {
          locationText = emirate;
        }

        setState(() {
          _currentLocation = locationText;
        });
        debugPrint('✓ Location fetched: $_currentLocation');
      }
    } catch (e) {
      debugPrint('✗ Error fetching location: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (widget.cameras.length < 2) return;

    _selectedCameraIndex = (_selectedCameraIndex + 1) % widget.cameras.length;

    final newController = CameraController(
      widget.cameras[_selectedCameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller.dispose();
    await newController.initialize();

    if (mounted) {
      setState(() {
        _controller = newController;
      });
    }
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing) return;
    if (!_controller.value.isInitialized) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      // Capture image
      final XFile imageFile = await _controller.takePicture();

      // Save to gallery using Gal
      await Gal.putImage(imageFile.path, album: 'RCC');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo saved to gallery'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );

        // Go back after a short delay
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      debugPrint('Error capturing photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          if (_controller.value.isInitialized)
            Positioned.fill(
              child: CameraPreview(_controller),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // Top Logo with RCC Image
          Positioned(
            top: 60.h,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Image.asset(
                  'assets/logo/rcc2.png',
                  height: 42.h,
                ),
              ),
            ),
          ),

          // Back Button
          Positioned(
            top: 50.h,
            left: 20.w,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Switch Camera Button
          if (widget.cameras.length > 1)
            Positioned(
              top: 50.h,
              right: 20.w,
              child: IconButton(
                icon: const Icon(
                  Icons.flip_camera_ios,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: _switchCamera,
              ),
            ),

          // Date, Time and Location at bottom right
          Positioned(
            bottom: 120.h,
            right: 20.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentDateTime,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  if (_currentLocation.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    Text(
                      _currentLocation,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Capture Button
          Positioned(
            bottom: 40.h,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _isCapturing ? null : _capturePhoto,
                child: Container(
                  width: 75.w,
                  height: 75.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(_isCapturing ? 0.5 : 0.9),
                    border: Border.all(
                      color: Colors.white,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: _isCapturing
                      ? Padding(
                          padding: EdgeInsets.all(20.w),
                          child: const CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 3,
                          ),
                        )
                      : Center(
                          child: Container(
                            width: 65.w,
                            height: 65.w,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),

          // Small thumbnail preview at bottom left (optional)
          Positioned(
            bottom: 50.h,
            left: 30.w,
            child: Container(
              width: 50.w,
              height: 50.w,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.photo_library,
                color: Colors.white.withOpacity(0.7),
                size: 24.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
