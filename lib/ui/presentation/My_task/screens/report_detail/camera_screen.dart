import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../core/constants/colors.dart';
import '../../../../../core/constants/text_styles.dart';
import '../../../../../utils/safe_insets.dart';

import '../../../../../data/repositories/company_repository.dart';
import '../../../../widgets/square_button.dart';

class CustomCameraScreen extends StatefulWidget {
  final bool onePicture;
  const CustomCameraScreen({super.key, required this.onePicture});

  @override
  State<CustomCameraScreen> createState() => _CustomCameraScreenState();
}

class _CustomCameraScreenState extends State<CustomCameraScreen> {
  late CameraController controller;
  List<CameraDescription> _cameras = [];
  bool _cameraInitilaized = false;
  bool _showCameraAccessDeniedView = false;

  _init() async {
    _cameras = await availableCameras();
    controller = CameraController(_cameras[0], ResolutionPreset.high);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      _cameraInitilaized = true;
      setState(() {});
    }).catchError((Object e) {
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
    });
  }

  @override
  void initState() {
    _init();
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  final List<XFile> _images = [];
  Future<void> takePhoto() async {
    if (widget.onePicture && _images.length == 1) return;
    if (!_cameraInitilaized || !controller.value.isInitialized) {
      debugPrint("Camera not initialized");
      return;
    }
    try {
      final XFile file = await controller.takePicture();
      _images.add(file);
      setState(() {});
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
              Navigator.pop(context);
            },
          ),
        ),
        title: CompanyRepository.company == null
            ? const SizedBox.shrink()
            : Image.asset(
                CompanyRepository.company!.logo,
                height: 60,
              ),
        actions: [
          SquareButton(
            icon: Icons.check,
            color: CustomColors.blue,
            borderColor: CustomColors.white,
            onPressed: () {
              Navigator.pop(context, _images);
            },
          ),
          const SizedBox(width: 12),
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
                            child: CameraPreview(controller)),
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
                                height: 50,
                                width: 50,
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
