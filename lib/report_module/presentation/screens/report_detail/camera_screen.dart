import 'package:camera/camera.dart';
import 'package:el_race/report_module/core/constants/colors.dart';
import 'package:el_race/report_module/core/constants/text_styles.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:el_race/report_module/data/repositories/company_repository.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../widgets/square_button.dart';

class CustomCameraScreen extends StatefulWidget {
  final bool onePicture;
  const CustomCameraScreen({super.key, required this.onePicture});

  @override
  State<CustomCameraScreen> createState() => _CustomCameraScreenState();
}

class _CustomCameraScreenState extends State<CustomCameraScreen> {
  CameraController? controller;
  List<CameraDescription> _cameras = [];
  bool _cameraInitilaized = false;
  bool _showCameraAccessDeniedView = false;

  double _currentZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;

  _init() async {
    final permission = await Permission.camera.request();
    if (!permission.isGranted && !permission.isLimited) {
      if (mounted) {
        setState(() => _showCameraAccessDeniedView = true);
      }
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() => _showCameraAccessDeniedView = true);
        }
        return;
      }
      final cameraController = CameraController(
        _cameras.first,
        ResolutionPreset.max,
        enableAudio: false,
      );
      controller = cameraController;
      await cameraController.initialize();
      if (!mounted) {
        return;
      }
      _minZoomLevel = await cameraController.getMinZoomLevel();
      _maxZoomLevel = await cameraController.getMaxZoomLevel();
      _currentZoomLevel = _minZoomLevel;
      _cameraInitilaized = true;
      setState(() {});
    } catch (e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            _showCameraAccessDeniedView = true;
            setState(() {});
            break;
          default:
            debugPrint(e.code);
            break;
        }
      }
    }
  }

  @override
  void initState() {
    _init();
    super.initState();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  final List<XFile> _images = [];
  Future<void> takePhoto() async {
    if (widget.onePicture && _images.length == 1) return;
    final cameraController = controller;
    if (!_cameraInitilaized ||
        cameraController == null ||
        !cameraController.value.isInitialized) {
      debugPrint("Camera not initialized");
      return;
    }
    try {
      final XFile file = await cameraController.takePicture();
      _images.add(file);
      if (!mounted) return;
      setState(() {});
      if (widget.onePicture) {
        Navigator.pop(context, _images);
      }
    } catch (e) {
      debugPrint("Error capturing photo: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // MaterialApp(home: CameraPreview(controller),);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        surfaceTintColor: Colors.transparent,
        backgroundColor: CustomColors.white,
        centerTitle: true,
        leadingWidth: 60,
        leading: Align(
          alignment: Alignment.centerRight,
          child: SquareButton(
            icon: Icons.keyboard_backspace,
            color: CustomColors.white,
            borderColor: CustomColors.black,
            onPressed: () {
              // Navigator.pop(context);
              Navigator.pop(context, _images);
            },
          ),
        ),
        title: Image.asset(
          CompanyRepository.company!.logo,
          height: 60,
        ),
        actions: const [
          // SquareButton(
          //   icon: Icons.check,
          //   color: CustomColors.blue,
          //   borderColor: CustomColors.white,
          //   onPressed: () {
          //     Navigator.pop(context, _images);
          //   },
          // ),
          // const SizedBox(width: 12),
        ],
      ),
      body: _showCameraAccessDeniedView
          ? Center(
              child: Text(
                "Please Go to Settings and enable camera permission",
                style:
                    CustomTextStyle.heading.copyWith(color: CustomColors.black),
              ),
            )
          : _cameraInitilaized
              ? LayoutBuilder(builder: (context, constraint) {
                  return SizedBox(
                    height: constraint.maxHeight,
                    width: constraint.maxWidth,
                    child: Stack(
                      children: [
                        SizedBox(
                            height: constraint.maxHeight,
                            width: constraint.maxWidth,
                            child: CameraPreview(controller!)),
                        Positioned(
                          top: 80,
                          bottom: 100,
                          right: 10,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              RotatedBox(
                                quarterTurns: 3, // rotate slider to be vertical
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    thumbColor: Colors.white, // knob color
                                    activeTrackColor: CustomColors.blue,
                                    inactiveTrackColor: Colors.white
                                      ..withValues(alpha: 0.3),
                                    overlayColor: Colors.white
                                      ..withValues(alpha: 0.1),
                                    thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 10),
                                    trackHeight: 4,
                                  ),
                                  child: Slider(
                                    min: _minZoomLevel,
                                    max: _maxZoomLevel,
                                    value: _currentZoomLevel,
                                    onChanged: (value) async {
                                      _currentZoomLevel = value;
                                      await controller!
                                          .setZoomLevel(_currentZoomLevel);
                                      setState(() {});
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "${_currentZoomLevel.toStringAsFixed(1)}x",
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 5,
                          right: 0,
                          left: 0,
                          child: Center(
                            child: Container(
                              height: 40,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                  color:
                                      CustomColors.blue.withValues(alpha: .5),
                                  borderRadius: BorderRadius.circular(16)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.image_outlined,
                                      color: Colors.white),
                                  const SizedBox(
                                    width: 14,
                                  ),
                                  Text(
                                    _images.length.toString(),
                                    style: CustomTextStyle.reportHeader,
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: context.systemBottomInset + 5,
                          right: 0,
                          left: 0,
                          child: Center(
                            child: CupertinoButton(
                              onPressed: takePhoto,
                              child: Container(
                                height: 70,
                                width: 70,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: (widget.onePicture &&
                                          _images.length == 1)
                                      ? CustomColors.white.withValues(alpha: .3)
                                      : CustomColors.white,
                                  border: Border.all(
                                      color: CustomColors.blue, width: 2),
                                ),
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  );
                })
              : Center(
                  child: CircularProgressIndicator(
                    color: CustomColors.blue,
                  ),
                ),
    );
  }
}
