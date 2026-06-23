import 'package:flutter/material.dart';

class TiltingCard extends StatefulWidget {
  final Widget child;

  const TiltingCard({
    required this.child,
    required Key key,
  }) : super(key: key);

  @override
  State<TiltingCard> createState() => _TiltingCardState();
}

class _TiltingCardState extends State<TiltingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.01,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationAnimation.value,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
