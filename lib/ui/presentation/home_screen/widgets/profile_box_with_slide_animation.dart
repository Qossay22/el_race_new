import 'dart:convert';
import 'dart:typed_data';
import 'package:el_race/core/services/notification_api_service.dart';
import 'package:el_race/core/services/notification_storage_service.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/data/services/hive_service.dart';
import 'package:el_race/data/services/prayer_notification_service.dart';
import 'package:el_race/ui/presentation/home_screen/bloc/home_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:el_race/core/app_globals.dart';
import 'package:el_race/providers/profile_box_provider.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/profile_widgets/app_settings_widget.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/profile_widgets/profile_paint_widgets.dart';
import 'package:el_race/ui/presentation/qr_code/data/repository.dart';
import 'package:el_race/utils/Util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:provider/provider.dart';

class ProfileBoxWithSlideAnimation extends StatefulWidget {
  const ProfileBoxWithSlideAnimation({super.key});

  @override
  State<ProfileBoxWithSlideAnimation> createState() =>
      _ProfileBoxWithSlideAnimationState();
}

class _ProfileBoxWithSlideAnimationState
    extends State<ProfileBoxWithSlideAnimation> with TickerProviderStateMixin {
  final QrCodeRepository _qrCodeRepository = QrCodeRepository();
  Uint8List? _qrCodeData;
  bool _isLoadingQr = true;
  String? _qrErrorMessage;
  bool _isMutePopupVisible = false;
  final Set<String> _savingMuteKeys = <String>{};
  List<_MuteChannelConfig> _muteChannels = <_MuteChannelConfig>[];
  Map<String, bool> _muteValueByKey = <String, bool>{};

  // Animation controller for moving numbers
  late AnimationController _numbersAnimationController;
  late Animation<double> _numbersAnimation;

  @override
  void initState() {
    super.initState();
    print('🎬 Profile Box: initState called');

    // Defer QR code load until heavy init is complete to avoid
    // blocking the main thread during splash screen.
    appInitCompleter.future.then((_) {
      if (mounted) _loadQrCode();
    });

    // Initialize animation controller for moving numbers
    _numbersAnimationController = AnimationController(
      duration: const Duration(
          milliseconds: 1500), // Faster - 1.5 seconds instead of 3
      vsync: this,
    );

    _numbersAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _numbersAnimationController,
      curve: Curves.linear,
    ));

    // Animation will be started when the profile box becomes visible.
    // Don't start here to avoid 60fps repaints while the drawer is hidden.
  }

  @override
  void dispose() {
    print('🛑 Profile Box: dispose called');
    _numbersAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadQrCode() async {
    try {
      print('🔄 Profile Box: Starting QR code load...');
      print('📍 Profile Box: Repository instance = $_qrCodeRepository');

      if (mounted) {
        setState(() {
          _isLoadingQr = true;
          _qrErrorMessage = null;
        });
      }

      print('⏳ Profile Box: About to call getQrCodeImageDirect()...');
      final qrData = await _qrCodeRepository.getQrCodeImageDirect();
      print('🎉 Profile Box: getQrCodeImageDirect() returned!');

      print(
          '📦 Profile Box: QR data received: ${qrData != null ? "${qrData.length} bytes" : "NULL"}');

      if (mounted) {
        if (qrData != null && qrData.isNotEmpty) {
          print('✅ Profile Box: QR code loaded successfully!');
          setState(() {
            _qrCodeData = qrData;
            _isLoadingQr = false;
            _qrErrorMessage = null;
          });
        } else {
          print('❌ Profile Box: QR code data is NULL or empty');
          setState(() {
            _qrCodeData = null;
            _isLoadingQr = false;
            _qrErrorMessage =
                'QR code not available. Please check your network connection.';
          });
        }
      }
    } catch (e, stackTrace) {
      print('❌ Profile Box: Exception loading QR code: $e');
      print(
          '📍 Profile Box: Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}');

      if (mounted) {
        setState(() {
          _isLoadingQr = false;
          _qrCodeData = null;
          _qrErrorMessage =
              'Network error: Unable to load QR code. Check your internet connection.';
        });
      }
    }
  }

  String _pickExistingMuteKey(
    Map<String, bool> settings,
    List<String> candidates,
  ) {
    for (final candidate in candidates) {
      final key = candidate.trim().toLowerCase();
      if (settings.containsKey(key)) {
        return key;
      }
    }
    return candidates.first.trim().toLowerCase();
  }

  bool _isHiddenNotificationCategory(String model, {String? title}) {
    final normalizedModel =
        model.trim().toLowerCase().replaceAll(RegExp(r'[_\-.]+'), ' ');
    final normalizedTitle =
        (title ?? '').toLowerCase().replaceAll(RegExp(r'[_\-.]+'), ' ');
    final haystack = '$normalizedModel $normalizedTitle';
    return haystack.contains('check out') && haystack.contains('reminder');
  }

  /// Local-only categories that are not returned by the API.
  static const List<_MuteChannelConfig> _localOnlyChannels = [
    _MuteChannelConfig(label: 'Chat', key: 'chat_message'),
    _MuteChannelConfig(label: 'Tasks', key: 'task'),
    _MuteChannelConfig(label: 'Adhan', key: 'adhan'),
  ];

  Future<void> _openMuteControlPopup() async {
    final results = await Future.wait([
      NotificationStorageService.getMuteSettings(),
      NotificationStorageService.getNotificationCategories(),
      HiveService.isPrayerSoundMuted(),
    ]);
    if (!mounted) return;

    final settings = results[0] as Map<String, bool>;
    final apiCategories = results[1] as List<NotificationCategoryApiModel>;
    final adhanMuted = results[2] as bool;

    final apiChannels = apiCategories
        .where((c) =>
            c.model.trim().isNotEmpty &&
            !_isHiddenNotificationCategory(c.model, title: c.title))
        .map(
          (c) => _MuteChannelConfig(
            label: c.title.trim().isNotEmpty ? c.title : c.model,
            key: c.model.trim().toLowerCase(),
          ),
        )
        .toList();

    // Merge: add local-only channels that are not already in the API list
    final existingKeys = apiChannels.map((c) => c.key).toSet();
    for (final local in _localOnlyChannels) {
      if (!existingKeys.contains(local.key)) {
        apiChannels.add(local);
      }
    }

    setState(() {
      _muteChannels = apiChannels;
      _muteValueByKey = <String, bool>{
        for (final channel in apiChannels)
          channel.key: channel.key == 'adhan'
              ? adhanMuted
              : (settings[channel.key] == true),
      };
      _isMutePopupVisible = true;
      _savingMuteKeys.clear();
    });
  }

  /// Whether this key is a local-only category (not synced to API).
  static bool _isLocalOnlyKey(String key) {
    return _localOnlyChannels.any((c) => c.key == key);
  }

  Future<void> _updateMuteChannel(_MuteChannelConfig item, bool value) async {
    if (_savingMuteKeys.contains(item.key)) return;

    final previous = _muteValueByKey[item.key] ?? false;
    setState(() {
      _muteValueByKey[item.key] = value;
      _savingMuteKeys.add(item.key);
    });

    try {
      if (_isLocalOnlyKey(item.key)) {
        // Local-only: handle adhan separately via HiveService
        if (item.key == 'adhan') {
          await HiveService.setPrayerSoundMuted(value);
          if (value) {
            await PrayerNotificationService().cancelAllPendingAdhan();
          }
          // Sync prayer widget icon immediately
          if (mounted) {
            context.read<HomeBloc>().add(const LoadPrayerMuteStateEvent());
          }
        }
        await NotificationStorageService.setLocalMuteSetting(item.key, value);
      } else {
        await NotificationStorageService.setMuteSetting(item.key, value);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _muteValueByKey[item.key] = previous;
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Failed to update mute setting'),
          backgroundColor: Color(0xffBA1719),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _savingMuteKeys.remove(item.key);
      });
    }
  }

  void _closeMuteControlPopup() {
    if (!mounted) return;
    setState(() {
      _isMutePopupVisible = false;
      _savingMuteKeys.clear();
    });
  }

  /// Get profile image - handles both base64 and URL formats
  ImageProvider _getProfileImage(String imageData) {
    if (imageData.isEmpty) {
      return const AssetImage('assets/png/profile_1.png');
    }

    // Check if it's a URL (starts with http:// or https://)
    if (imageData.startsWith('http://') || imageData.startsWith('https://')) {
      return NetworkImage(imageData);
    }

    // Check if it's valid base64
    if (Util.isValidBase64(imageData)) {
      try {
        return MemoryImage(base64Decode(imageData));
      } catch (_) {
        return const AssetImage('assets/png/profile_1.png');
      }
    }

    // Default fallback
    return const AssetImage('assets/png/profile_1.png');
  }

  // Custom painter for QR code background with animated numbers
  Widget _buildQRBackground(String empId) {
    return AnimatedBuilder(
      animation: _numbersAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(220.w, 220.w),
          painter: AnimatedQRBackgroundPainter(_numbersAnimation.value, empId),
        );
      },
    );
  }

  void _showCertificateOverEverything() {
    print('🎯 _showCertificateOverEverything called');

    final loginData = SharedPref.getLoginData();
    final certificateData = loginData.result?.data?.certificate;

    // Debug: print certificate data
    print('DEBUG: certificateData = $certificateData');
    print('DEBUG: certificateData type = ${certificateData.runtimeType}');
    if (certificateData != null) {
      print('DEBUG: certificateData["error"] = ${certificateData['error']}');
      print(
          'DEBUG: certificateData["image"] = ${certificateData['image'] != null ? "exists" : "null"}');
      print('DEBUG: certificateData["url"] = ${certificateData['url']}');
    }

    // Check if certificate has error or is null
    final hasError =
        certificateData == null || certificateData['error'] != null;
    final hasImage =
        certificateData != null && certificateData['image'] != null;
    final hasUrl = certificateData != null && certificateData['url'] != null;

    print(
        'DEBUG: hasError = $hasError, hasImage = $hasImage, hasUrl = $hasUrl');

    // Close the drawer first using the provider
    final profileBoxProvider =
        Provider.of<ProfileBoxProvider>(context, listen: false);
    profileBoxProvider.toggleProfileBox();

    print('🚪 Closing drawer...');

    // Use the navigation key to get proper context
    final BuildContext? navContext = navKey.currentContext;
    if (navContext == null) {
      print('❌ navContext is null!');
      return;
    }

    // Wait a bit for drawer to close, then show dialog
    Future.delayed(const Duration(milliseconds: 300), () {
      print('✅ Showing dialog with navContext');

      // Show dialog directly with higher priority
      showGeneralDialog(
        context: navContext,
        barrierDismissible: true,
        barrierLabel: 'Certificate',
        barrierColor: Colors.black26,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(20),
            child: hasError
                ? Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          certificateData?['error'] ?? 'No certificate found',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HexColor("#161B54"),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            child: Text(
                              'OK',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.9,
                        height: MediaQuery.of(context).size.height * 0.7,
                        child: Stack(
                          children: [
                            // Certificate image
                            Positioned.fill(
                              child: hasImage
                                  ? Image.memory(
                                      base64Decode(certificateData['image']),
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        print(
                                            'Error loading certificate image: $error');
                                        return const Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            size: 48,
                                            color: Colors.grey,
                                          ),
                                        );
                                      },
                                    )
                                  : hasUrl
                                      ? Image.network(
                                          certificateData['url'],
                                          fit: BoxFit.contain,
                                          loadingBuilder: (context, child,
                                              loadingProgress) {
                                            if (loadingProgress == null) {
                                              return child;
                                            }
                                            return Center(
                                              child: CircularProgressIndicator(
                                                value: loadingProgress
                                                            .expectedTotalBytes !=
                                                        null
                                                    ? loadingProgress
                                                            .cumulativeBytesLoaded /
                                                        loadingProgress
                                                            .expectedTotalBytes!
                                                    : null,
                                              ),
                                            );
                                          },
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            print(
                                                'Error loading certificate from URL: $error');
                                            return const Center(
                                              child: Icon(
                                                Icons.broken_image,
                                                size: 48,
                                                color: Colors.grey,
                                              ),
                                            );
                                          },
                                        )
                                      : const Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.card_membership,
                                                size: 64,
                                                color: Colors.grey,
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                  'No certificate data available'),
                                            ],
                                          ),
                                        ),
                            ),
                            // Close button
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          );
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutBack,
                ),
              ),
              child: child,
            ),
          );
        },
      );
    });
  }

  bool muteNotifications = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileBoxProvider>(
      builder: (context, profileBoxProvider, child) {
        final isAuthenticated = SharedPref.isUserAuthenticated();
        if (isAuthenticated == false) return const SizedBox.shrink();

        // ── Fast path: skip ALL heavy work when the drawer is hidden ──
        if (!profileBoxProvider.isProfileVisible && !_isMutePopupVisible) {
          // Stop animation when hidden to avoid 60fps repaints
          if (_numbersAnimationController.isAnimating) {
            _numbersAnimationController.stop();
          }
          return const SizedBox.shrink();
        }

        // Start animation when visible (if not already running)
        if (!_numbersAnimationController.isAnimating) {
          _numbersAnimationController.repeat();
        }

        final screenWidth = MediaQuery.of(context).size.width;
        final drawerWidth = screenWidth * 0.75;

        final base64Image = SharedPref().getUserBase64Image();
        final hasValidImage =
            base64Image.isNotEmpty && Util.isValidBase64(base64Image);

        final loginData = SharedPref.getLoginData();

        return Stack(
          children: [
            // Black transparent overlay
            if (profileBoxProvider.isProfileVisible)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => profileBoxProvider.hideProfileBox(),
                  child: Container(
                    color: Colors.black26,
                  ),
                ),
              ),
            // Side menu
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              left: SharedPref().isArabic()
                  ? null
                  : (profileBoxProvider.isProfileVisible ? 0 : -drawerWidth),
              right: SharedPref().isArabic()
                  ? (profileBoxProvider.isProfileVisible ? 0 : -drawerWidth)
                  : null,
              top: 0,
              child: Material(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    image: DecorationImage(
                        image:
                            AssetImage("assets/newapp/profile_background.png"),
                        fit: BoxFit.fill),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  width: drawerWidth,
                  child: SingleChildScrollView(
                    child: Column(
                      // إزالة الفراغ السفلي الناتج عن التوسيط العمودي
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            SizedBox(
                              height: 60.h,
                            ),
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.black, width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 28,
                                backgroundImage: _getProfileImage(base64Image),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              () {
                                // Try multiple sources for name
                                String? displayName =
                                    loginData.result?.data?.name;
                                if (displayName == null ||
                                    displayName.isEmpty ||
                                    displayName == 'false') {
                                  displayName = loginData
                                      .result?.data?.partnerDisplayName;
                                }
                                if (displayName == null ||
                                    displayName.isEmpty ||
                                    displayName == 'false') {
                                  displayName =
                                      loginData.result?.data?.username;
                                }
                                if (displayName != null &&
                                    displayName.isNotEmpty &&
                                    displayName != 'false') {
                                  return displayName
                                      .split(' ')
                                      .take(2)
                                      .join(' ');
                                }
                                return translate('profile.name_not_available');
                              }(),
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700, fontSize: 11.26),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              () {
                                final jobId = loginData.result?.data?.job_id;
                                if (jobId != null &&
                                    jobId.isNotEmpty &&
                                    jobId != 'null' &&
                                    jobId != 'false') {
                                  return jobId;
                                }
                                return translate(
                                    'profile.job_id_not_available');
                              }(),
                              style: GoogleFonts.poppins(
                                  fontSize: 11.26, fontWeight: FontWeight.w400),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              () {
                                final empId = loginData.result?.data?.emp_id;
                                if (empId != null &&
                                    empId.isNotEmpty &&
                                    empId != 'null' &&
                                    empId != 'false') {
                                  return empId;
                                }
                                return translate('profile.id_not_available');
                              }(),
                              style: GoogleFonts.poppins(
                                  fontSize: 11.26, fontWeight: FontWeight.w400),
                            ),
                            const SizedBox(height: 1),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () {
                                print('🏆 Certificate icon tapped!');
                                _showCertificateOverEverything();
                              },
                              borderRadius: BorderRadius.circular(50),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                child: Image.asset(
                                  'assets/png/cert_icon.png',
                                  height: 30,
                                  width: 30,
                                  errorBuilder: (context, error, stackTrace) {
                                    // If image not found, use icon instead
                                    return const Icon(
                                      Icons.workspace_premium,
                                      size: 30,
                                      color: Colors.amber,
                                    );
                                  },
                                ),
                              ),
                            ),
                            SizedBox(height: 8.h),
                            SizedBox(
                              width: 220.w,
                              child: Text(
                                loginData.result?.data?.qr_status == true
                                    ? 'Status : Active'
                                    : 'Status : Not Active',
                                style: GoogleFonts.poppins(
                                    fontSize: 11.26,
                                    fontWeight: FontWeight.bold,
                                    color: loginData.result?.data?.qr_status ==
                                            true
                                        ? const Color(0xff4CAF50)
                                        : const Color(0xff9E9E9E)),
                              ),
                            ),
                            SizedBox(
                              width: 250.w,
                              height: 250.h,
                              child: Stack(
                                alignment: Alignment.center,
                                clipBehavior: Clip.hardEdge,
                                children: [
                                  // Background with repeated numbers
                                  Container(
                                    width: 240.w,
                                    height: 240.w,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.grey.shade100,
                                          Colors.grey.shade200,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(
                                        color:
                                            loginData.result?.data?.qr_status ==
                                                    true
                                                ? HexColor("#009859")
                                                : Colors.grey.shade400,
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                        child: _buildQRBackground(loginData
                                                .result?.data?.emp_id
                                                ?.toString() ??
                                            '000')),
                                  ),
                                  // QR Code (rotated 45 degrees)
                                  Transform.rotate(
                                    angle: 0.785398, // 45 degrees in radians
                                    child: Container(
                                      width: 140.w,
                                      height: 140.w,
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        border: Border.all(
                                          color: loginData.result?.data
                                                      ?.qr_status ==
                                                  true
                                              ? HexColor("#009859")
                                              : Colors.grey.shade400,
                                          width: 1.5,
                                        ),
                                        //borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: loginData.result?.data
                                                        ?.qr_status ==
                                                    true
                                                ? HexColor("#009859")
                                                : Colors.grey.shade400,
                                            blurRadius: 5,
                                            offset: const Offset(1, 1),
                                          ),
                                        ],
                                      ),
                                      child: _isLoadingQr
                                          ? const Center(
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : _qrCodeData != null
                                              ? Image.memory(
                                                  _qrCodeData!,
                                                  fit: BoxFit
                                                      .contain, // Changed from cover to contain
                                                  errorBuilder: (context, error,
                                                      stackTrace) {
                                                    print(
                                                        '❌ Image.memory error: $error');
                                                    return const Center(
                                                      child: Icon(
                                                        Icons.broken_image,
                                                        color: Colors.white,
                                                        size: 40,
                                                      ),
                                                    );
                                                  },
                                                )
                                              : Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(
                                                      Icons.qr_code_2,
                                                      color: Colors.white,
                                                      size: 40,
                                                    ),
                                                    const SizedBox(height: 8),
                                                    if (_qrErrorMessage != null)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 12,
                                                                vertical: 4),
                                                        child: Text(
                                                          _qrErrorMessage!,
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 9,
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                          maxLines: 3,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    const SizedBox(height: 4),
                                                    ElevatedButton(
                                                      onPressed: () {
                                                        print(
                                                            '🔄 Retry button pressed');
                                                        _loadQrCode();
                                                      },
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor: Colors
                                                            .white
                                                            .withOpacity(0.2),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 16,
                                                          vertical: 6,
                                                        ),
                                                      ),
                                                      child: const Text(
                                                        'Retry',
                                                        style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 12),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        AppSettingsWidget(
                          navKey: navKey,
                          onMuteControlTap: _openMuteControlPopup,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_isMutePopupVisible)
              Positioned.fill(
                child: Material(
                  color: Colors.black54,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _savingMuteKeys.isNotEmpty
                        ? null
                        : _closeMuteControlPopup,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {},
                        child: Container(
                          width: 304,
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7E7E7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final item in _muteChannels)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.label,
                                          style: const TextStyle(
                                            color: Color(0xFF1A1D55),
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                            height: 1,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 58,
                                        child: Transform.scale(
                                          scale: 0.86,
                                          child: Directionality(
                                            textDirection: TextDirection.ltr,
                                            child: Switch(
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              value:
                                                  !(_muteValueByKey[item.key] ??
                                                      false),
                                              onChanged: _savingMuteKeys
                                                      .contains(item.key)
                                                  ? null
                                                  : (value) =>
                                                      _updateMuteChannel(
                                                        item,
                                                        !value,
                                                      ),
                                              activeThumbColor:
                                                  const Color(0xFF43A047),
                                              activeTrackColor:
                                                  const Color(0xFFA5D6A7),
                                              inactiveThumbColor:
                                                  const Color(0xFFE53935),
                                              inactiveTrackColor:
                                                  const Color(0xFFEF9A9A),
                                              trackOutlineColor:
                                                  const WidgetStatePropertyAll(
                                                Colors.transparent,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 4),
                              SizedBox(
                                height: 30,
                                child: ElevatedButton.icon(
                                  onPressed: _savingMuteKeys.isNotEmpty
                                      ? null
                                      : _closeMuteControlPopup,
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    backgroundColor: const Color(0xFF0FA25E),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.check_circle_outline,
                                    size: 17,
                                  ),
                                  label: const Text(
                                    'DONE',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MuteChannelConfig {
  final String label;
  final String key;

  const _MuteChannelConfig({
    required this.label,
    required this.key,
  });
}






      // Stack(
                                    //   clipBehavior: Clip.none,
                                    //   children: [
                                    //     Container(
                                    //       margin: const EdgeInsets.only(top: 0),
                                    //       padding: const EdgeInsets.only(
                                    //           top: 4, bottom: 4),
                                    //       color: Colors.grey.shade100,
                                    //       child: Column(
                                    //         children: [
                                    //           const SizedBox(height: 0),
                                    //           Container(
                                    //             decoration: BoxDecoration(
                                    //               color: Colors.white,
                                    //               boxShadow: [
                                    //                 BoxShadow(
                                    //                   color: Colors.black
                                    //                       .withAlpha(
                                    //                           (0.15 * 255)
                                    //                               .toInt()),
                                    //                   offset:
                                    //                       const Offset(0, 1.68),
                                    //                   // blurRadius: 4,
                                    //                 ),
                                    //               ],
                                    //             ),
                                    //             child: Row(
                                    //               mainAxisAlignment:
                                    //                   MainAxisAlignment.center,
                                    //               children: [
                                    //                 Padding(
                                    //                   padding: const EdgeInsets
                                    //                       .symmetric(
                                    //                       vertical: 8),
                                    //                   child: Container(
                                    //                     width: 94.13,
                                    //                     height: 30.03,
                                    //                     decoration:
                                    //                         BoxDecoration(
                                    //                       gradient:
                                    //                           LinearGradient(
                                    //                         colors: !SharedPref()
                                    //                                 .isArabic()
                                    //                             ? [
                                    //                                 const Color(
                                    //                                     0xFF151544),
                                    //                                 const Color(
                                    //                                     0xFF3535AA)
                                    //                               ] // لو مش عربي
                                    //                             : [
                                    //                                 Colors
                                    //                                     .white,
                                    //                                 Colors.grey[
                                    //                                     300]!
                                    //                               ], // لو عربي
                                    //                         begin: Alignment
                                    //                             .centerLeft,
                                    //                         end: Alignment
                                    //                             .centerRight,
                                    //                       ),
                                    //                       borderRadius:
                                    //                           BorderRadius
                                    //                               .circular(
                                    //                                   20.3),
                                    //                     ),
                                    //                     child: ElevatedButton(
                                    //                       onPressed: () async {
                                    //                         if (profileBoxProvider
                                    //                             .isProfileVisible) {
                                    //                           profileBoxProvider
                                    //                               .hideProfileBox();
                                    //                         }
                                    //                         await Util
                                    //                             .saveAndChangeLocale(
                                    //                                 context,
                                    //                                 'en');
                                    //                       },
                                    //                       style: ElevatedButton
                                    //                           .styleFrom(
                                    //                         backgroundColor:
                                    //                             Colors
                                    //                                 .transparent,
                                    //                         //  backgroundColor: !SharedPref().isArabic()
                                    //                         //       ? appFontColor
                                    //                         //       : Colors.white,
                                    //                         minimumSize:
                                    //                             const Size(
                                    //                                 100, 16),
                                    //                         shape: RoundedRectangleBorder(
                                    //                             borderRadius:
                                    //                                 BorderRadius
                                    //                                     .circular(
                                    //                                         20.3)),
                                    //                       ),
                                    //                       child: Text(
                                    //                           translate(
                                    //                               'profile.english'),
                                    //                           style: TextStyle(
                                    //                               color: !SharedPref()
                                    //                                       .isArabic()
                                    //                                   ? Colors
                                    //                                       .white
                                    //                                   : Colors
                                    //                                       .black,
                                    //                               fontSize:
                                    //                                   10)),
                                    //                     ),
                                    //                   ),
                                    //                 ),
                                    //                 const SizedBox(width: 10),
                                    //                 Container(
                                    //                   width: 94.13,
                                    //                   height: 30.03,
                                    //                   decoration: BoxDecoration(
                                    //                     borderRadius:
                                    //                         BorderRadius
                                    //                             .circular(20.3),
                                    //                   ),
                                    //                   child: ElevatedButton(
                                    //                     onPressed: () async {
                                    //                       if (profileBoxProvider
                                    //                           .isProfileVisible) {
                                    //                         profileBoxProvider
                                    //                             .hideProfileBox();
                                    //                       }
                                    //                       await Util
                                    //                           .saveAndChangeLocale(
                                    //                               context,
                                    //                               'ar');
                                    //                     },
                                    //                     style: ElevatedButton
                                    //                         .styleFrom(
                                    //                       backgroundColor:
                                    //                           SharedPref()
                                    //                                   .isArabic()
                                    //                               ? appFontColor
                                    //                               : Colors.grey
                                    //                                   .shade200,
                                    //                       minimumSize:
                                    //                           const Size(
                                    //                               100, 16),
                                    //                       shape: RoundedRectangleBorder(
                                    //                           borderRadius:
                                    //                               BorderRadius
                                    //                                   .circular(
                                    //                                       20.3)),
                                    //                     ),
                                    //                     child: Text(
                                    //                         translate(
                                    //                             'profile.arabic'),
                                    //                         style: TextStyle(
                                    //                             color: SharedPref()
                                    //                                     .isArabic()
                                    //                                 ? Colors
                                    //                                     .white
                                    //                                 : Colors
                                    //                                     .black,
                                    //                             fontSize: 12)),
                                    //                   ),
                                    //                 ),
                                    //               ],
                                    //             ),
                                    //           ),
                                    //
                                    //           const SizedBox(height: 1),
                                    //           // Container(
                                    //           //   height: 2,
                                    //           //   width: double.infinity,
                                    //           //   decoration: BoxDecoration(
                                    //           //     color: Colors.grey.shade300,
                                    //           //     // boxShadow: [
                                    //           //     //   BoxShadow(
                                    //           //     //     color: Colors.black.withAlpha(
                                    //           //     //         (0.15 * 255).toInt()),
                                    //           //     //     offset: const Offset(0, 2),
                                    //           //     //     blurRadius: 4,
                                    //           //     //   ),
                                    //           //     // ],
                                    //           //   ),
                                    //           // ),
                                    //
                                    //           Container(
                                    //             padding:
                                    //                 const EdgeInsets.symmetric(
                                    //                     horizontal: 12,
                                    //                     vertical: 12),
                                    //             decoration: BoxDecoration(
                                    //               boxShadow: [
                                    //                 BoxShadow(
                                    //                   color: Colors.black
                                    //                       .withAlpha(
                                    //                           (0.15 * 255)
                                    //                               .toInt()),
                                    //                   offset:
                                    //                       const Offset(0, 1.68),
                                    //                   //blurRadius: 4,
                                    //                 )
                                    //               ],
                                    //               color: Colors.white,
                                    //             ),
                                    //             child: Row(
                                    //               mainAxisAlignment:
                                    //                   MainAxisAlignment.start,
                                    //               children: [
                                    //                 Image.asset(
                                    //                     'assets/png/notification_filled_icon.png'),
                                    //                 const SizedBox(width: 12),
                                    //                 Text(
                                    //                     translate(
                                    //                         'profile.mute_notifications'),
                                    //                     style:
                                    //                         GoogleFonts.poppins(
                                    //                             fontSize: 11)),
                                    //                 const Spacer(),
                                    //                 SizedBox(
                                    //                   height: 10.57,
                                    //                   child: Transform.scale(
                                    //                     scale:
                                    //                         0.7, // تصغير الحجم
                                    //                     child: const Switch(
                                    //                       value: false,
                                    //                       onChanged: null,
                                    //                       activeColor:
                                    //                           appFontColor, // لون الزر لما يكون ON
                                    //                       activeTrackColor: Color(
                                    //                           0xffD9D9D9), // لون الخلفية لما يكون ON
                                    //                       inactiveThumbColor: Color(
                                    //                           0xff3E3C3C), // لون الزر لما يكون OFF
                                    //                       inactiveTrackColor: Color(
                                    //                           0xffD9D9D9), // لون الخلفية لما يكون OFF
                                    //                     ),
                                    //                   ),
                                    //                 )
                                    //                 // Switch.adaptive(
                                    //                 //   value: isMuted,
                                    //                 //   onChanged: (val) => _updateMuteStatus(val),
                                    //                 //   activeColor: const Color(0xFF1A1A53),
                                    //                 //   activeTrackColor: Colors.grey.shade400,
                                    //                 // ),
                                    //               ],
                                    //             ),
                                    //           ),
                                    //           // 🔹 Divider with shadow
                                    //           // Container(
                                    //           //   height: 2,
                                    //           //   width: double.infinity,
                                    //           //   decoration: BoxDecoration(
                                    //           //     color: Colors.grey.shade300,
                                    //           // boxShadow: [
                                    //           //   BoxShadow(
                                    //           //     color: Colors.black.withAlpha(
                                    //           //         (0.15 * 255).toInt()),
                                    //           //     offset: const Offset(0, 2),
                                    //           //     blurRadius: 4,
                                    //           //   ),
                                    //           // ],
                                    //           //   ),
                                    //           // ),
                                    //           const SizedBox(
                                    //             height: 8,
                                    //           ),
                                    //           // Container(
                                    //           //   padding: const EdgeInsets.symmetric(
                                    //           //         horizontal: 20, vertical: 12),
                                    //           //   decoration: BoxDecoration(
                                    //           //       color: Colors.white,
                                    //           //       boxShadow: [
                                    //           //         BoxShadow(
                                    //           //           color: Colors.black.withAlpha(
                                    //           //               (0.15 * 255).toInt()),
                                    //           //           offset: const Offset(0, 1.68),
                                    //           //           // blurRadius: 4,
                                    //           //         )
                                    //           //       ]),
                                    //           //   child: Row(
                                    //           //     children: [
                                    //           //       SizedBox(
                                    //           //         child: Image.asset(
                                    //           //             'assets/png/dark_mode_icon.png'),
                                    //           //       ),
                                    //           //       const SizedBox(width: 22),
                                    //           //       Text(
                                    //           //           translate(
                                    //           //               'profile.dark_mode'),
                                    //           //           style: const TextStyle(
                                    //           //               fontSize: 12)),
                                    //           //     ],
                                    //           //   ),
                                    //           // ),
                                    //         ],
                                    //       ),
                                    //     ),
                                    //     // Positioned(
                                    //     //   top: -10,
                                    //     //   left: 0,
                                    //     //   right: 0,
                                    //     //   child: Center(
                                    //     //     child: // QR Code section
                                    //     //         Container(
                                    //     //       margin: const EdgeInsets.only(
                                    //     //           top: 20, bottom: 36),
                                    //     //       width: 200,
                                    //     //       height: 200,
                                    //     //       child: Stack(
                                    //     //         alignment: Alignment.center,
                                    //     //         clipBehavior: Clip.hardEdge,
                                    //     //         children: [
                                    //     //           // Background with repeated numbers
                                    //     //           Container(
                                    //     //             width: 200,
                                    //     //             height: 200,
                                    //     //             decoration: BoxDecoration(
                                    //     //               gradient: LinearGradient(
                                    //     //                 begin: Alignment.topLeft,
                                    //     //                 end: Alignment.bottomRight,
                                    //     //                 colors: [
                                    //     //                   Colors.grey.shade100,
                                    //     //                   Colors.grey.shade200,
                                    //     //                 ],
                                    //     //               ),
                                    //     //               borderRadius:
                                    //     //                   BorderRadius.circular(16),
                                    //     //               border: Border.all(
                                    //     //                 color: Colors.grey.shade400,
                                    //     //                 width: 1,
                                    //     //               ),
                                    //     //               boxShadow: [
                                    //     //                 BoxShadow(
                                    //     //                   color: Colors.black
                                    //     //                       .withOpacity(0.1),
                                    //     //                   blurRadius: 4,
                                    //     //                   offset: const Offset(0, 2),
                                    //     //                 ),
                                    //     //               ],
                                    //     //             ),
                                    //     //             child: _buildQRBackground(),
                                    //     //           ),
                                    //     //           // QR Code (rotated 45 degrees)
                                    //     //           Transform.rotate(
                                    //     //             angle:
                                    //     //                 0.785398, // 45 degrees in radians
                                    //     //             child: Container(
                                    //     //               width: 100,
                                    //     //               height: 100,
                                    //     //               decoration: BoxDecoration(
                                    //     //                 color: Colors.black,
                                    //     //                 borderRadius:
                                    //     //                     BorderRadius.circular(8),
                                    //     //                 boxShadow: [
                                    //     //                   BoxShadow(
                                    //     //                     color:
                                    //     //                         Colors.grey.shade600,
                                    //     //                     blurRadius: 2,
                                    //     //                     offset:
                                    //     //                         const Offset(0, 1),
                                    //     //                   ),
                                    //     //                 ],
                                    //     //               ),
                                    //     //               child: Image.asset(
                                    //     //                 'assets/png/qr_code.png',
                                    //     //                 fit: BoxFit.cover,
                                    //     //               ),
                                    //     //             ),
                                    //     //           ),
                                    //     //         ],
                                    //     //       ),
                                    //     //     ),
                                    //     //   ),
                                    //     // ),
                                    //   ],
                                    // ),


                                     // Container(
                                //
                                //   decoration: BoxDecoration(
                                //     color: Colors.grey[300],
                                //     borderRadius: const BorderRadius.only(
                                //       bottomRight: Radius.circular(20),
                                //     ),
                                //   ),
                                //   child: Row(
                                //     mainAxisAlignment: MainAxisAlignment.start,
                                //     children: [
                                //       const SizedBox(
                                //         width: 20,
                                //       ),
                                //       Image.asset(
                                //           'assets/png/log_out_icon.png'),
                                //       const SizedBox(
                                //         width: 26,
                                //       ),
                                //       TextButton(
                                //         onPressed: () async {
                                //           try {
                                //             print('🚪 Logout button pressed');
                                //
                                //             // Hide profile box first
                                //             if (profileBoxProvider
                                //                 .isProfileVisible) {
                                //               profileBoxProvider
                                //                   .hideProfileBox();
                                //             }
                                //
                                //             // Clear user preferences
                                //             print('🧹 Clearing preferences...');
                                //             await SharedPref()
                                //                 .clearPreferences();
                                //             print('✅ Preferences cleared');
                                //
                                //             // Use global navigation key for navigation
                                //             print(
                                //                 '🧭 Navigating to sign in...');
                                //             if (navKey.currentContext != null) {
                                //               Navigator.pushAndRemoveUntil(
                                //                 navKey.currentContext!,
                                //                 MaterialPageRoute(
                                //                     builder: (context) =>
                                //                         const SignInScreen()),
                                //                 (route) => false,
                                //               );
                                //             } else {
                                //               // Fallback to local context
                                //               Navigator.pushAndRemoveUntil(
                                //                 context,
                                //                 MaterialPageRoute(
                                //                     builder: (context) =>
                                //                         const SignInScreen()),
                                //                 (route) => false,
                                //               );
                                //             }
                                //             print('✅ Navigation completed');
                                //           } catch (e) {
                                //             print('❌ Logout error: $e');
                                //           }
                                //         },
                                //         child: Text(translate('profile.logout'),
                                //             style: const TextStyle(
                                //                 color: Color(0xffBA1719))),
                                //       ),
                                //     ],
                                //   ),
                                // ),



                                // Row(
                                    //   children: [
                                    //     const SizedBox(
                                    //       width: 120.0,
                                    //     ),
                                    //     Container(
                                    //       padding: const EdgeInsets.all(2),
                                    //       decoration: BoxDecoration(
                                    //         shape: BoxShape.circle,
                                    //         border: Border.all(
                                    //             color: Colors.black, width: 2),
                                    //       ),
                                    //       child: CircleAvatar(
                                    //         radius: 28,
                                    //         backgroundImage: hasValidImage
                                    //             ? MemoryImage(
                                    //                 base64Decode(base64Image))
                                    //             : const AssetImage(
                                    //                     'assets/png/profile_1.png')
                                    //                 as ImageProvider,
                                    //       ),
                                    //     ),
                                    //     const SizedBox(
                                    //       width: 12.4,
                                    //     ),
                                    //     // Container(
                                    //     //   width: 48,
                                    //     //   height: 48,
                                    //     //   decoration: BoxDecoration(
                                    //     //       color: Colors.white,
                                    //     //       borderRadius:
                                    //     //           BorderRadius.circular(24)),
                                    //     //   child: Image.asset(
                                    //     //       'assets/png/name_tag_icon.png'),
                                    //     // ),
                                    //   ],
                                    // ),




                                    //   final ctx = navKey.currentContext!;
                                      //   showDialog(
                                      //     context: ctx,
                                      //     builder: (_) {
                                      //       return Dialog(
                                      //         insetPadding: const EdgeInsets.all(15),
                                      //         child: Container(
                                      //           width: double.infinity,
                                      //           height:
                                      //               MediaQuery.of(ctx).size.height *
                                      //                   0.3,
                                      //           decoration: BoxDecoration(
                                      //             color: Colors.black,
                                      //             borderRadius:
                                      //                 BorderRadius.circular(12),
                                      //           ),
                                      //           child: ClipRRect(
                                      //             borderRadius:
                                      //                 BorderRadius.circular(12),
                                      //             child: Image.asset(
                                      //                 'assets/png/certificate.png',
                                      //                 fit: BoxFit.cover),
                                      //           ),
                                      //         ),
                                      //       );
                                      //     },
                                      //   );
