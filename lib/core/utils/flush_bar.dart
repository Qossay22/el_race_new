import 'package:flutter/material.dart';
import 'package:el_race/core/app_globals.dart' show navKey;

/// Overlay-based flush bar that does NOT push a navigator route,
/// avoiding '!_debugLocked' assertion failures when the navigator
/// is mid-transition.
Future<void> showFlushBar(BuildContext context,
    {required String message}) async {
  OverlayState? overlay;
  try {
    overlay = navKey.currentState?.overlay;
  } catch (_) {}
  overlay ??= Overlay.maybeOf(context);
  if (overlay == null) return;

  late final OverlayEntry entry;

  entry = OverlayEntry(
    builder: (ctx) => _FlushOverlay(
      message: message,
      onDismissed: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );

  overlay.insert(entry);
}

class _FlushOverlay extends StatefulWidget {
  final String message;
  final VoidCallback onDismissed;

  const _FlushOverlay({
    required this.message,
    required this.onDismissed,
  });

  @override
  State<_FlushOverlay> createState() => _FlushOverlayState();
}

class _FlushOverlayState extends State<_FlushOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();
    Future.delayed(const Duration(seconds: 3), _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _controller.reverse().then((_) {
      widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topPadding + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF303030),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  widget.message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
