import 'package:flutter/material.dart';

import '../../../chat/chat.dart';

/// Online presence indicator widget
class PresenceIndicator extends StatelessWidget {
  final String uid;
  final double size;
  final bool showText;

  const PresenceIndicator({
    super.key,
    required this.uid,
    this.size = 12,
    this.showText = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PresenceStatus>(
      stream: PresenceService.instance.subscribeToUserPresence(uid),
      builder: (context, snapshot) {
        final status = snapshot.data;
        final isOnline = status?.online ?? false;

        if (showText) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDot(isOnline),
              const SizedBox(width: 6),
              Text(
                isOnline ? 'متصل' : (status?.lastSeenText ?? 'غير متصل'),
                style: TextStyle(
                  fontSize: 12,
                  color: isOnline ? Colors.green : Colors.grey[500],
                ),
              ),
            ],
          );
        }

        return _buildDot(isOnline);
      },
    );
  }

  Widget _buildDot(bool isOnline) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOnline ? Colors.green : Colors.grey[400],
      ),
    );
  }
}

/// Online presence badge that wraps around an avatar
class PresenceBadge extends StatelessWidget {
  final String uid;
  final Widget child;
  final double badgeSize;
  final double offset;

  const PresenceBadge({
    super.key,
    required this.uid,
    required this.child,
    this.badgeSize = 14,
    this.offset = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          right: offset,
          bottom: offset,
          child: StreamBuilder<PresenceStatus>(
            stream: PresenceService.instance.subscribeToUserPresence(uid),
            builder: (context, snapshot) {
              final isOnline = snapshot.data?.online ?? false;
              
              if (!isOnline) {
                return const SizedBox.shrink();
              }

              return Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Last seen text widget
class LastSeenText extends StatelessWidget {
  final String uid;
  final TextStyle? style;
  final String onlineText;
  final String offlineText;

  const LastSeenText({
    super.key,
    required this.uid,
    this.style,
    this.onlineText = 'متصل الآن',
    this.offlineText = 'غير متصل',
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PresenceStatus>(
      stream: PresenceService.instance.subscribeToUserPresence(uid),
      builder: (context, snapshot) {
        final status = snapshot.data;

        if (status == null) {
          return Text(
            offlineText,
            style: style ?? TextStyle(color: Colors.grey[500], fontSize: 12),
          );
        }

        final text = status.online ? onlineText : status.lastSeenText;
        final color = status.online ? Colors.green : Colors.grey[500];

        return Text(
          text,
          style: style ?? TextStyle(color: color, fontSize: 12),
        );
      },
    );
  }
}
