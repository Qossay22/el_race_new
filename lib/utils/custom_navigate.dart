import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CustomPageRoute<T> extends MaterialPageRoute<T> {
  final Widget child;

  CustomPageRoute({required this.child, super.settings})
      : super(builder: (_) => child);

  @override
  Duration get transitionDuration => const Duration(milliseconds: 650);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 500);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final platform = Theme.of(context).platform;
    final isApple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    // Keep native iOS route transition to preserve interactive swipe-back.
    if (isApple) {
      return super.buildTransitions(
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }

    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOut,
    );

    final slide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(curved);

    final scaleIn = Tween<double>(
      begin: 0.90,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutBack,
    ));

    final fade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(curved);

    final isPopping = animation.status == AnimationStatus.reverse;

    return SlideTransition(
      position: slide,
      child: ScaleTransition(
        scale: isPopping ? const AlwaysStoppedAnimation(1.0) : scaleIn,
        child: FadeTransition(
          opacity: fade,
          child: child,
        ),
      ),
    );
  }
}

// Animation خاصة للصفحات الجانبية (Notifications, My Notes)
// يمتد من PageRoute مع CupertinoRouteTransitionMixin لدعم iOS swipe-back
class SlideRightPageRoute<T> extends PageRoute<T>
    with CupertinoRouteTransitionMixin<T> {
  final Widget child;

  SlideRightPageRoute({required this.child, super.settings});

  // مطلوب من CupertinoRouteTransitionMixin
  @override
  Widget buildContent(BuildContext context) => child;

  @override
  String? get title => null;

  @override
  bool get maintainState => true;

  // iOS swipe-back مفعّل دائماً
  @override
  bool get popGestureEnabled => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 400);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 350);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final platform = Theme.of(context).platform;
    final isApple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    // على iOS/macOS: نستخدم Cupertino transition الأصلية (تشمل swipe-back)
    if (isApple) {
      return CupertinoRouteTransitionMixin.buildPageTransitions(
        this,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }

    // على Android: animation مخصصة
    final isPopping = animation.status == AnimationStatus.reverse;

    if (isPopping) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      );

      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
          child: child,
        ),
      );
    }

    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(curved),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
        child: child,
      ),
    );
  }
}
