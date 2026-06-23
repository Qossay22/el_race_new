import 'package:flutter/material.dart';

import '../chat_display_utils.dart';

/// WhatsApp-style typing indicator widget with user names
/// Shows "أحمد يكتب..." for single user or "أحمد وعلي يكتبون..." for multiple
class TypingIndicatorWidget extends StatefulWidget {
  /// Names of users who are typing
  final List<String> typingUserNames;
  
  /// Whether this is a group chat (affects text)
  final bool isGroupChat;

  const TypingIndicatorWidget({
    super.key,
    this.typingUserNames = const [],
    this.isGroupChat = false,
  });

  @override
  State<TypingIndicatorWidget> createState() => _TypingIndicatorWidgetState();
}

class _TypingIndicatorWidgetState extends State<TypingIndicatorWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  String _buildTypingText() {
    final names = widget.typingUserNames;
    
    if (names.isEmpty) {
      return 'typing...';
    }
    
    if (names.length == 1) {
      if (widget.isGroupChat) {
        return '${limitChatDisplayName(names[0])} is typing...';
      }
      return 'typing...';
    }

    if (names.length == 2) {
      return '${limitChatDisplayName(names[0])} and ${limitChatDisplayName(names[1])} are typing...';
    }

    // 3 or more
    return '${limitChatDisplayName(names[0])} and ${names.length - 1} others are typing...';
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TypingDotsAnimation(),
            const SizedBox(width: 8),
            Text(
              _buildTypingText(),
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated typing dots - WhatsApp style bouncing dots
class TypingDotsAnimation extends StatefulWidget {
  final Color? color;
  final double dotSize;

  const TypingDotsAnimation({
    super.key,
    this.color,
    this.dotSize = 6,
  });

  @override
  State<TypingDotsAnimation> createState() => _TypingDotsAnimationState();
}

class _TypingDotsAnimationState extends State<TypingDotsAnimation>
    with TickerProviderStateMixin {
  late List<AnimationController> _dotControllers;
  late List<Animation<double>> _dotAnimations;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _dotControllers = List.generate(3, (index) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
    });

    _dotAnimations = _dotControllers.map((controller) {
      return Tween<double>(begin: 0, end: -5).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();

    // Start animations with staggered delay - WhatsApp wave effect
    for (var i = 0; i < _dotControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 180), () {
        if (mounted) {
          _dotControllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _dotControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _dotAnimations[index],
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _dotAnimations[index].value),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: widget.dotSize,
                height: widget.dotSize,
                decoration: BoxDecoration(
                  color: widget.color ?? const Color(0xFF25D366), // WhatsApp green
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

/// Simple typing dots for compact use (e.g., in chat list)
class TypingDotsCompact extends StatefulWidget {
  final Color? color;
  final double dotSize;

  const TypingDotsCompact({
    super.key,
    this.color,
    this.dotSize = 5,
  });

  @override
  State<TypingDotsCompact> createState() => _TypingDotsCompactState();
}

class _TypingDotsCompactState extends State<TypingDotsCompact>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.25;
            final animValue = ((_controller.value + delay) % 1.0);
            final opacity = _calculateOpacity(animValue);
            
            return Container(
              margin: EdgeInsets.symmetric(horizontal: widget.dotSize * 0.25),
              width: widget.dotSize,
              height: widget.dotSize,
              decoration: BoxDecoration(
                color: (widget.color ?? const Color(0xFF25D366)).withOpacity(opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }

  double _calculateOpacity(double animValue) {
    if (animValue < 0.5) {
      return 0.4 + (animValue * 1.2);
    } else {
      return 1.0 - ((animValue - 0.5) * 1.2);
    }
  }
}

/// Inline typing text widget for use in subtitle
class TypingTextWidget extends StatelessWidget {
  final List<String> typingUserNames;
  final bool isGroupChat;
  final TextStyle? style;

  const TypingTextWidget({
    super.key,
    this.typingUserNames = const [],
    this.isGroupChat = false,
    this.style,
  });

  String _buildText() {
    final names = typingUserNames;
    
    if (names.isEmpty) {
      return 'typing...';
    }
    
    if (names.length == 1) {
      if (isGroupChat) {
        return '${limitChatDisplayName(names[0])} is typing...';
      }
      return 'typing...';
    }

    if (names.length == 2) {
      return '${limitChatDisplayName(names[0])} and ${limitChatDisplayName(names[1])} are typing...';
    }

    return '${limitChatDisplayName(names[0])} and ${names.length - 1} others are typing...';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const TypingDotsCompact(),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            _buildText(),
            style: style ?? TextStyle(
              fontSize: 13,
              color: const Color(0xFF25D366),
              fontStyle: FontStyle.italic,
            ),
            overflow: TextOverflow.visible,
          ),
        ),
      ],
    );
  }
}
