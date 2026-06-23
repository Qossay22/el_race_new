import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraScreen({super.key, required this.camera});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  String _currentDate = '';
  String _currentTime = '';
  String _currentLocation = '';

  @override
  void initState() {
    super.initState();

    _controller = CameraController(
      widget.camera,
      ResolutionPreset.max,
      enableAudio: false,
    );

    _initializeControllerFuture = _controller.initialize();

    _updateTime();
    _updateLocation();
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

  Future<void> _updateLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _currentLocation = '';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _currentLocation =
              place.locality ?? place.subAdministrativeArea ?? '';
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error getting location: $e');
      setState(() {
        _currentLocation = '';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    try {
      await _initializeControllerFuture;
      final file = await _controller.takePicture();

      if (!mounted) return;

      final composedPath = await _composeWithOverlay(file.path);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved: ${composedPath ?? file.path}')),
      );
    } catch (e) {
      // ignore: avoid_print
      print('Camera error: $e');
    }
  }

  Future<String?> _composeWithOverlay(String imagePath) async {
    try {
      // ignore: avoid_print
      print('🎨 Starting to compose overlay on image...');
      // ignore: avoid_print
      print('⏰ Time: $_currentTime');
      // ignore: avoid_print
      print('📅 Date: $_currentDate');
      // ignore: avoid_print
      print('📍 Location: $_currentLocation');

      final bytes = await File(imagePath).readAsBytes();
      final baseImage = img.decodeImage(bytes);
      if (baseImage == null) {
        // ignore: avoid_print
        print('❌ Failed to decode image');
        return imagePath;
      }

      // ignore: avoid_print
      print('✅ Image decoded: ${baseImage.width}x${baseImage.height}');

      final int padding = (baseImage.width * 0.04).toInt();
      final img.BitmapFont overlayFont =
          baseImage.width >= 2000 ? img.arial48 : img.arial24;
      final shadowOffset = baseImage.width >= 2000 ? 2 : 1;
      final lineHeight =
          overlayFont.lineHeight + (baseImage.width >= 2000 ? 12 : 8);

      int measureWidth(img.BitmapFont f, String text) {
        int w = 0;
        for (var ch in text.codeUnits) {
          if (f.characters.containsKey(ch)) {
            w += f.characters[ch]!.xAdvance;
          }
        }
        return w;
      }

      final timeTextWidth = measureWidth(overlayFont, _currentTime);
      final dateTextWidth = measureWidth(overlayFont, _currentDate);
      final locationTextWidth = _currentLocation.isNotEmpty
          ? measureWidth(overlayFont, _currentLocation)
          : 0;

      int maxTextWidth = timeTextWidth;
      if (dateTextWidth > maxTextWidth) maxTextWidth = dateTextWidth;
      if (locationTextWidth > maxTextWidth) maxTextWidth = locationTextWidth;

      int currentY = baseImage.height -
          padding -
          (lineHeight * (_currentLocation.isNotEmpty ? 3 : 2));

      final timeX = baseImage.width - padding - maxTextWidth;
      img.drawString(
        baseImage,
        _currentTime,
        font: overlayFont,
        x: timeX + shadowOffset,
        y: currentY + shadowOffset,
        color: img.ColorRgb8(40, 40, 40),
      );
      img.drawString(
        baseImage,
        _currentTime,
        font: overlayFont,
        x: timeX,
        y: currentY,
        color: img.ColorRgb8(255, 255, 255),
      );

      currentY += lineHeight;
      final dateX = baseImage.width - padding - maxTextWidth;
      img.drawString(
        baseImage,
        _currentDate,
        font: overlayFont,
        x: dateX + shadowOffset,
        y: currentY + shadowOffset,
        color: img.ColorRgb8(40, 40, 40),
      );
      img.drawString(
        baseImage,
        _currentDate,
        font: overlayFont,
        x: dateX,
        y: currentY,
        color: img.ColorRgb8(255, 255, 255),
      );

      if (_currentLocation.isNotEmpty) {
        currentY += lineHeight;
        final locationX = baseImage.width - padding - maxTextWidth;
        img.drawString(
          baseImage,
          _currentLocation,
          font: overlayFont,
          x: locationX + shadowOffset,
          y: currentY + shadowOffset,
          color: img.ColorRgb8(40, 40, 40),
        );
        img.drawString(
          baseImage,
          _currentLocation,
          font: overlayFont,
          x: locationX,
          y: currentY,
          color: img.ColorRgb8(255, 255, 255),
        );
      }

      final composedFile = File(imagePath);
      composedFile.writeAsBytesSync(img.encodeJpg(baseImage, quality: 95));

      // ignore: avoid_print
      print('✅ Image saved with overlay: $imagePath');
      return composedFile.path;
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error composing image: $e');
      return imagePath;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder(
        future: _initializeControllerFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          return Stack(
            children: [
              /// ================================
              /// REAL CAMERA PREVIEW (FULL FIT)
              /// ================================
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.previewSize!.height,
                    height: _controller.value.previewSize!.width,
                    child: CameraPreview(_controller),
                  ),
                ),
              ),

              /// ================================
              /// TOP GLASS BAR (PERFECT MATCH)
              /// ================================
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 175.h,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                  ),
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Image.asset(
                          'assets/logo/rcc2.png',
                          height: 42.h,
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),

              /// ================================
              /// BOTTOM GLASS CONTAINER (FULL FOOTER)
              /// ================================
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: BottomDock(
                  extra: 0,
                  liftWithKeyboard: false,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(0),
                    child: Container(
                      width: double.infinity,
                      height: screenHeight * 0.28,
                      padding: EdgeInsets.symmetric(
                        horizontal: 30.w,
                        vertical: 20.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _currentTime,
                                  style: GoogleFonts.poppins(
                                    fontSize: 15.sp,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  _currentDate,
                                  style: GoogleFonts.poppins(
                                    fontSize: 15.sp,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                if (_currentLocation.isNotEmpty) ...[
                                  SizedBox(height: 2.h),
                                  Text(
                                    _currentLocation,
                                    style: GoogleFonts.poppins(
                                      fontSize: 15.sp,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: _takePicture,
                            child: Container(
                              width: 55.w,
                              height: 55.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 60.w,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 20.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _glassButton('SCAN'),
                              _glassButton('PHOTO'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _glassButton(String text) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 36.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.30),
            borderRadius: BorderRadius.circular(30.r),
            border: Border.all(
              color: Colors.white.withOpacity(0.20),
              width: 1.2,
            ),
          ),
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 17.sp,
              letterSpacing: 1.4,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
