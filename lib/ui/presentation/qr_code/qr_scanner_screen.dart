import 'dart:async';
import 'package:el_race/core/constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:el_race/ui/presentation/qr_code/data/qr_login_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final QrLoginService _qrLoginService = QrLoginService();
  final MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _isProcessing = false;
  bool _isTorchOn = false;
  bool _isCheckingCameraPermission = true;
  bool _hasCameraPermission = false;
  bool _isCameraPermissionPermanentlyDenied = false;

  // ── Zoom ──────────────────────────────────────────────────────────
  double _currentZoom = 1.0;
  double _baseZoom = 1.0;
  static const double _minZoom = 1.0;
  static const double _maxZoom = 5.0;
  bool _showZoomLabel = false;
  Timer? _zoomLabelTimer;

  // ── Scan-line animation ───────────────────────────────────────────
  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnim;

  // ── Frame pulse animation ─────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkCameraPermission();

    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _scanLineAnim =
        CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanLineController.dispose();
    _pulseController.dispose();
    _zoomLabelTimer?.cancel();
    cameraController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkCameraPermission(requestIfNeeded: false);
    }
  }

  Future<void> _checkCameraPermission({bool requestIfNeeded = true}) async {
    var status = await Permission.camera.status;
    if (requestIfNeeded && status.isDenied) {
      status = await Permission.camera.request();
    }

    if (!mounted) return;
    setState(() {
      _isCheckingCameraPermission = false;
      _hasCameraPermission = status.isGranted || status.isLimited;
      _isCameraPermissionPermanentlyDenied =
          status.isPermanentlyDenied || status.isRestricted;
    });
  }

  Future<void> _openCameraSettings() async {
    await openAppSettings();
  }

  // ── Zoom helpers ──────────────────────────────────────────────────
  void _onScaleStart(ScaleStartDetails d) {
    _baseZoom = _currentZoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount < 2) return;
    final newZoom = (_baseZoom * d.scale).clamp(_minZoom, _maxZoom);
    if ((newZoom - _currentZoom).abs() < 0.02) return;
    setState(() {
      _currentZoom = newZoom;
      _showZoomLabel = true;
    });
    final normalized = (_currentZoom - _minZoom) / (_maxZoom - _minZoom);
    cameraController.setZoomScale(normalized);
    _zoomLabelTimer?.cancel();
    _zoomLabelTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showZoomLabel = false);
    });
  }

  void _setZoom(double value) {
    setState(() {
      _currentZoom = value;
      _showZoomLabel = true;
    });
    final normalized = (value - _minZoom) / (_maxZoom - _minZoom);
    cameraController.setZoomScale(normalized);
    _zoomLabelTimer?.cancel();
    _zoomLabelTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showZoomLabel = false);
    });
  }

  // ── QR detection ─────────────────────────────────────────────────
  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue?.trim();
      if (code != null && code.isNotEmpty) {
        _handleQrScan(code);
        break;
      }
    }
  }

  Future<void> _handleQrScan(String qrCode) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    _scanLineController.stop();

    Fluttertoast.showToast(
      msg: "Signing in...",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      backgroundColor: CustomColors.blue,
      textColor: Colors.white,
      fontSize: 16.0,
    );

    try {
      final result = await _qrLoginService.loginWithQrCode(qrCode);
      if (mounted) {
        if (result['success'] == true) {
          Fluttertoast.showToast(
            msg: "Signed in successfully!",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.CENTER,
            backgroundColor: Colors.green,
            textColor: Colors.white,
            fontSize: 16.0,
          );
          Navigator.pop(context, true);
        } else {
          Fluttertoast.showToast(
            msg: result['message'] ?? 'Sign-in failed',
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.CENTER,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0,
          );
          setState(() => _isProcessing = false);
          _scanLineController.repeat(reverse: true);
        }
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: "Error: ${e.toString()}",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.CENTER,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        setState(() => _isProcessing = false);
        _scanLineController.repeat(reverse: true);
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final frameSize = 260.w;

    if (_isCheckingCameraPermission) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (!_hasCameraPermission) {
      return _CameraPermissionView(
        permanentlyDenied: _isCameraPermissionPermanentlyDenied,
        onRetry: _checkCameraPermission,
        onOpenSettings: _openCameraSettings,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(64.h),
        child: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/png/header_bg.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    'Scan QR Code',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 48.w),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Camera area ────────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Live camera
                  MobileScanner(
                    controller: cameraController,
                    fit: BoxFit.cover,
                    onDetect: _onDetect,
                    errorBuilder: (context, error) => Center(
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: Colors.redAccent, width: 1.5),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.no_photography_outlined,
                                color: Colors.redAccent, size: 40),
                            SizedBox(height: 12.h),
                            const Text('Camera unavailable',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                            SizedBox(height: 4.h),
                            Text(error.errorCode.name,
                                style: const TextStyle(color: Colors.white54)),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Dark mask outside scan frame
                  _ScanMask(frameSize: frameSize),

                  // Scan frame with animated corners + scan line
                  Center(
                    child: ScaleTransition(
                      scale: _pulseAnim,
                      child: SizedBox(
                        width: frameSize,
                        height: frameSize,
                        child: Stack(
                          children: [
                            const _Corner(a: Alignment.topLeft),
                            const _Corner(a: Alignment.topRight),
                            const _Corner(a: Alignment.bottomLeft),
                            const _Corner(a: Alignment.bottomRight),
                            if (!_isProcessing)
                              AnimatedBuilder(
                                animation: _scanLineAnim,
                                builder: (_, __) => Positioned(
                                  top: _scanLineAnim.value * (frameSize - 4),
                                  left: 16.w,
                                  right: 16.w,
                                  child: Container(
                                    height: 2.5,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: [
                                        Colors.transparent,
                                        CustomColors.blue
                                            .withValues(alpha: 0.8),
                                        Colors.white,
                                        CustomColors.blue
                                            .withValues(alpha: 0.8),
                                        Colors.transparent,
                                      ]),
                                      borderRadius: BorderRadius.circular(2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: CustomColors.blue
                                              .withValues(alpha: 0.5),
                                          blurRadius: 10,
                                          spreadRadius: 3,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Verifying overlay
                  if (_isProcessing)
                    Container(
                      color: Colors.black54,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: CustomColors.blue,
                              strokeWidth: 3,
                            ),
                            SizedBox(height: 14.h),
                            Text(
                              'Verifying...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Zoom badge
                  if (_showZoomLabel)
                    Positioned(
                      top: 14.h,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 14.w, vertical: 5.h),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                          child: Text(
                            '${_currentZoom.toStringAsFixed(1)}×',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Bottom panel ───────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0E0E1A),
              border: Border(
                top: BorderSide(
                    color: CustomColors.blue.withValues(alpha: 0.35), width: 1),
              ),
            ),
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Place the QR code inside the frame',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Auto-detects when ready',
                  style: TextStyle(color: Colors.white38, fontSize: 12.sp),
                ),
                SizedBox(height: 14.h),

                // Zoom slider row
                Row(
                  children: [
                    Text('1×',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 11.sp)),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          thumbColor: CustomColors.blue,
                          activeTrackColor: CustomColors.blue,
                          inactiveTrackColor: Colors.white12,
                          overlayColor:
                              CustomColors.blue.withValues(alpha: 0.15),
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7),
                          trackHeight: 3,
                        ),
                        child: Slider(
                          value: _currentZoom,
                          min: _minZoom,
                          max: _maxZoom,
                          onChanged: _setZoom,
                        ),
                      ),
                    ),
                    Text('${_maxZoom.toInt()}×',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 11.sp)),
                  ],
                ),

                SizedBox(height: 10.h),

                // Torch + Flip
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ControlButton(
                      icon: _isTorchOn
                          ? Icons.flash_on_rounded
                          : Icons.flash_off_rounded,
                      label: _isTorchOn ? 'Flash On' : 'Flash Off',
                      active: _isTorchOn,
                      onTap: () async {
                        await cameraController.toggleTorch();
                        setState(() => _isTorchOn = !_isTorchOn);
                      },
                    ),
                    SizedBox(width: 52.w),
                    _ControlButton(
                      icon: Icons.cameraswitch_rounded,
                      label: 'Flip',
                      active: false,
                      onTap: () => cameraController.switchCamera(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dark mask outside the scan frame ──────────────────────────────
class _ScanMask extends StatelessWidget {
  final double frameSize;
  const _ScanMask({required this.frameSize});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _MaskPainter(frameSize: frameSize));
}

class _MaskPainter extends CustomPainter {
  final double frameSize;
  const _MaskPainter({required this.frameSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final cx = size.width / 2;
    final cy = size.height / 2;
    final half = frameSize / 2;

    final outer = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final inner = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - half, cy - half, cx + half, cy + half),
        const Radius.circular(16),
      ));

    canvas.drawPath(
      Path.combine(PathOperation.difference, outer, inner),
      paint,
    );
  }

  @override
  bool shouldRepaint(_MaskPainter old) => old.frameSize != frameSize;
}

// ── Corner bracket ─────────────────────────────────────────────────
class _Corner extends StatelessWidget {
  final Alignment a;
  const _Corner({required this.a});

  @override
  Widget build(BuildContext context) {
    final isTop = a == Alignment.topLeft || a == Alignment.topRight;
    final isLeft = a == Alignment.topLeft || a == Alignment.bottomLeft;
    return Align(
      alignment: a,
      child: Container(
        width: 26.w,
        height: 26.w,
        decoration: BoxDecoration(
          border: Border(
            top: isTop
                ? BorderSide(color: CustomColors.blue, width: 3.5)
                : BorderSide.none,
            bottom: !isTop
                ? BorderSide(color: CustomColors.blue, width: 3.5)
                : BorderSide.none,
            left: isLeft
                ? BorderSide(color: CustomColors.blue, width: 3.5)
                : BorderSide.none,
            right: !isLeft
                ? BorderSide(color: CustomColors.blue, width: 3.5)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// ── Bottom control button ──────────────────────────────────────────
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ControlButton(
      {required this.icon,
      required this.label,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 54.w,
            height: 54.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? CustomColors.blue.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.08),
              border: Border.all(
                color: active ? CustomColors.blue : Colors.white24,
                width: 1.5,
              ),
            ),
            child: Icon(icon,
                color: active ? CustomColors.blue : Colors.white70,
                size: 24.sp),
          ),
          SizedBox(height: 6.h),
          Text(
            label,
            style: TextStyle(
              color: active ? CustomColors.blue : Colors.white38,
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraPermissionView extends StatelessWidget {
  final bool permanentlyDenied;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  const _CameraPermissionView({
    required this.permanentlyDenied,
    required this.onRetry,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Camera Permission'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined,
                  color: Colors.white, size: 56),
              const SizedBox(height: 16),
              const Text(
                'Camera access is required to scan QR codes.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: permanentlyDenied ? onOpenSettings : onRetry,
                child:
                    Text(permanentlyDenied ? 'Open Settings' : 'Allow Camera'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
