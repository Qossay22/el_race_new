import 'dart:async';

import 'package:el_race/core/constants/app_version.dart';
import 'package:el_race/core/biometric/unified_biometric_helper.dart';
import 'package:el_race/core/services/update_service.dart';
import 'package:el_race/core/app_globals.dart' show appInitCompleter;
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/firebase_service.dart';
import 'package:el_race/ui/presentation/signin/sign_in_screen.dart';
import 'package:el_race/ui/widgets/update_dialog.dart';
import 'package:flutter/material.dart';
import 'package:el_race/ui/presentation/home_screen/screens/home_screen.dart';
import 'package:el_race/utils/Util.dart';
import 'package:el_race/core/services/app_config_service.dart';
import 'package:el_race/core/security/device_security_service.dart';
import 'package:provider/provider.dart';
import 'package:el_race/ui/presentation/qr_survey/providers/qr_survey_data_provider.dart';
import 'package:video_player/video_player.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isSecurityCheckComplete = false;
  bool _isDeviceSecure = true;
  bool _didScheduleNavigation = false;
  late VideoPlayerController _videoController;
  bool _isVideoReady = false;
  final Completer<void> _videoCompletedCompleter = Completer<void>();

  @override
  void initState() {
    super.initState();

    // Initialize video player (uses hardware decoder, not main thread)
    _videoController = VideoPlayerController.asset('assets/mp4/intro.mp4')
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isVideoReady = true);
          _videoController.addListener(_onVideoProgress);
          _videoController.play();
        }
      }).catchError((e) {
        print('⚠️ Video init error: $e');
        _completeVideoIfNeeded();
      });

    // Defer security check & QR clear to after the first frame so
    // the splash background paints immediately without any blocking work.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performSecurityCheck();
      final provider =
          Provider.of<QrSurveyDataProvider>(context, listen: false);
      provider.clearData();
      print('🧹 SplashScreen - Cleared QR data on app start');
    });
  }

  /// Perform security check before allowing app usage
  Future<void> _performSecurityCheck() async {
    try {
      print('🔒 Starting security check...');
      final result =
          await DeviceSecurityService.instance.performSecurityCheck();

      if (mounted) {
        setState(() {
          _isDeviceSecure = result.isSecure;
          _isSecurityCheckComplete = true;
        });

        if (!result.isSecure) {
          print('❌ Device security check failed!');
          // Show security warning dialog
          DeviceSecurityService.showSecurityBlockDialog(context, result);
        } else {
          print('✅ Device security check passed!');
        }
      }
    } catch (e) {
      print('⚠️ Error during security check: $e');
      // On error, allow app to continue (fail-open for better UX)
      if (mounted) {
        setState(() {
          _isSecurityCheckComplete = true;
          _isDeviceSecure = true;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only schedule navigation once (didChangeDependencies can be called many times)
    if (_didScheduleNavigation) return;
    _didScheduleNavigation = true;

    _waitForInitAndNavigate();
  }

  /// Wait for both: 1) minimum 3-second splash, 2) heavy init complete,
  /// 3) security check, then navigate.
  Future<void> _waitForInitAndNavigate() async {
    // Wait for BOTH heavy init and intro video completion.
    await Future.wait<void>([
      appInitCompleter.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          print('⚠️ Heavy init timeout in splash – continuing anyway');
        },
      ),
      _videoCompletedCompleter.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          print('⚠️ Video completion timeout in splash – continuing anyway');
        },
      ),
    ]);

    if (!mounted) return;

    // Check security
    if (!_isDeviceSecure && _isSecurityCheckComplete) {
      print('🚫 Navigation blocked - device not secure');
      return;
    }

    // Wait for security check if not complete yet
    if (!_isSecurityCheckComplete) {
      print('⏳ Waiting for security check...');
      await _waitForSecurityCheck();
    }

    if (!mounted) return;
    if (!_isDeviceSecure) return;

    _navigateToNextScreen();
  }

  void _onVideoProgress() {
    if (!_videoController.value.isInitialized) return;

    final duration = _videoController.value.duration;
    final position = _videoController.value.position;

    if (duration == Duration.zero) return;

    if (position >= duration - const Duration(milliseconds: 100)) {
      _completeVideoIfNeeded();
    }
  }

  void _completeVideoIfNeeded() {
    if (!_videoCompletedCompleter.isCompleted) {
      _videoCompletedCompleter.complete();
    }
  }

  /// Wait for security check to complete (up to 5 seconds)
  Future<void> _waitForSecurityCheck() async {
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (_isSecurityCheckComplete) return;
    }
    // Timeout - allow to proceed
    print('⚠️ Security check timeout – proceeding');
  }

  /// Navigate to the appropriate screen after security check.
  /// Runs the update check first, then proceeds with routing.
  void _navigateToNextScreen() {
    if (!mounted) return;
    _checkForUpdateThenNavigate();
  }

  Future<void> _checkForUpdateThenNavigate() async {
    if (!mounted) return;

    try {
      const String currentVersion = AppVersion.name;

      final updateResult =
          await UpdateService.instance.checkForUpdate(currentVersion);

      if (!mounted) return;

      final blocked = await UpdateDialog.showIfNeeded(
        context,
        updateResult,
        isRtl: Directionality.of(context) == TextDirection.rtl,
      );

      // Force-update: block navigation until user updates the app
      if (blocked) return;
    } catch (e) {
      print('⚠️ Update check error (ignored): $e');
    }

    if (!mounted) return;
    _doNavigate();
  }

  Future<void> _authenticateBeforeEnteringApp() async {
    if (!mounted) return;

    bool authenticated = false;
    while (!authenticated && mounted) {
      final hasBiometrics = await UnifiedBiometricHelper.isBiometricAvailable();
      if (!mounted) return;

      if (!hasBiometrics) {
        await _showBiometricRequiredDialog();
        continue;
      }

      authenticated = await UnifiedBiometricHelper.authenticate(
        context: context,
        title: 'تحقق من الهوية',
        subtitle: 'يرجى التحقق من هويتك للمتابعة',
        reason: 'تحقق من هويتك قبل دخول التطبيق',
      );

      if (!authenticated && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يجب التحقق من هويتك للمتابعة'),
            duration: Duration(seconds: 2),
          ),
        );
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  Future<void> _showBiometricRequiredDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('البصمة مطلوبة'),
        content: const Text(
          'يجب تفعيل بصمة الوجه أو بصمة الإصبع على الجهاز للمتابعة. رمز PIN أو كلمة المرور غير مسموحين لأسباب أمنية.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Future<void> _doNavigate() async {
    if (!mounted) return;

    try {
      // Check authentication first
      final isAuthenticated = SharedPref.isUserAuthenticated();

      if (isAuthenticated && !AppConfigService.instance.shouldSkipFaceId) {
        await _authenticateBeforeEnteringApp();
        if (!mounted) return;
      }

      // Fetch home screen data (with error handling inside the function)
      // This won't throw - errors are handled internally
      Util.fetchHomeScreenData(context);

      if (isAuthenticated) {
        // Check if face registration is in progress or pending
        final isRegistrationInProgress =
            SharedPref().getPreferenceBoolean('isFaceRegistrationInProgress');
        final isPendingFaceVerification =
            SharedPref().getPreferenceBoolean('pendingFaceVerification');
        final isFaceRegistered =
            SharedPref().getPreferenceBoolean('isFaceRegistered');

        // If registration was in progress, user must complete it
        if (isRegistrationInProgress ||
            (isPendingFaceVerification && !isFaceRegistered)) {
          // In Test Mode, skip face registration
          if (AppConfigService.instance.isTestMode) {
            SharedPref()
                .setPreferencesBoolean('pendingFaceVerification', false);
            SharedPref()
                .setPreferencesBoolean('isFaceRegistrationInProgress', false);
            Util.pushPageAndRemoveRoutes(const HomeScreen(), context);
            FirebaseService.markHomeReady();
            return;
          }

          // User needs to register face - go to home, it will be triggered from there
          Util.pushPageAndRemoveRoutes(const HomeScreen(), context);
          FirebaseService.markHomeReady();
        } else {
          // User already registered or no pending verification
          Util.pushPageAndRemoveRoutes(const HomeScreen(), context);
          FirebaseService.markHomeReady();
        }
      } else {
        Util.pushPageAndRemoveRoutes(const SignInScreen(), context);
      }
    } catch (e) {
      print('❌ Error navigating from splash: $e');
      // Fallback based on authentication status, not to login screen blindly
      if (mounted) {
        if (SharedPref.isUserAuthenticated()) {
          Util.pushPageAndRemoveRoutes(const HomeScreen(), context);
          FirebaseService.markHomeReady();
        } else {
          Util.pushPageAndRemoveRoutes(const SignInScreen(), context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isVideoReady
          ? SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController.value.size.width,
                  height: _videoController.value.size.height,
                  child: VideoPlayer(_videoController),
                ),
              ),
            )
          : const SizedBox.expand(),
    );
  }

  @override
  void dispose() {
    _videoController.removeListener(_onVideoProgress);
    _videoController.dispose();
    super.dispose();
  }
}
