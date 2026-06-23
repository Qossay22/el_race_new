import 'package:flutter/widgets.dart';

/// Extension for easy access to safe insets across the app
/// Helps prevent Samsung gesture bar from overlaying UI
extension SafeInsetsExtension on BuildContext {
  /// Returns persistent system bar inset (navigation/gesture bar)
  /// Always non-zero on devices with system bars, ignores keyboard
  double get systemBottomInset => MediaQuery.of(this).viewPadding.bottom;

  /// Returns keyboard height when visible, 0 otherwise
  double get keyboardInset => MediaQuery.of(this).viewInsets.bottom;

  /// Returns the appropriate bottom inset based on keyboard state
  /// - If liftWithKeyboard=true: returns max(systemBar, keyboard)
  /// - If liftWithKeyboard=false: returns systemBar only
  /// Use for bottom-anchored controls that should move above keyboard
  double safeBottomInset({bool liftWithKeyboard = true}) {
    final systemBar = systemBottomInset;
    final keyboard = keyboardInset;

    if (!liftWithKeyboard) {
      return systemBar;
    }

    // Return the larger value to handle both system bar and keyboard
    return systemBar > keyboard ? systemBar : keyboard;
  }

  /// Check if keyboard is currently visible
  bool get isKeyboardVisible => keyboardInset > 0;
}

/// Reusable widget that adds safe bottom padding to prevent UI overlap
/// with Samsung system bars and keyboard
///
/// Usage:
/// ```dart
/// Positioned(
///   bottom: 0,
///   child: BottomDock(
///     extra: 16,
///     liftWithKeyboard: true,
///     child: ElevatedButton(...),
///   ),
/// )
/// ```
class BottomDock extends StatelessWidget {
  /// The child widget to be padded
  final Widget child;

  /// Additional padding beyond system insets (optional)
  final double extra;

  /// Whether to lift above keyboard (true) or stay fixed to screen bottom (false)
  /// Set to false for FABs, true for input fields/buttons
  final bool liftWithKeyboard;

  /// Animation duration for keyboard transitions
  final Duration animationDuration;

  const BottomDock({
    Key? key,
    required this.child,
    this.extra = 0,
    this.liftWithKeyboard = true,
    this.animationDuration = const Duration(milliseconds: 200),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        context.safeBottomInset(liftWithKeyboard: liftWithKeyboard);

    return AnimatedPadding(
      duration: animationDuration,
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset + extra),
      child: child,
    );
  }
}

/// Alternative widget for wrapping content that should avoid system UI
/// Use this for scrollable content padding
class SafeScrollPadding extends StatelessWidget {
  final Widget child;
  final double extraBottom;
  final double extraTop;
  final double extraLeft;
  final double extraRight;

  const SafeScrollPadding({
    Key? key,
    required this.child,
    this.extraBottom = 0,
    this.extraTop = 0,
    this.extraLeft = 0,
    this.extraRight = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final systemBottom = context.systemBottomInset;
    final systemTop = MediaQuery.of(context).viewPadding.top;

    return Padding(
      padding: EdgeInsets.only(
        top: systemTop + extraTop,
        bottom: systemBottom + extraBottom,
        left: extraLeft,
        right: extraRight,
      ),
      child: child,
    );
  }
}
