import 'package:flutter/material.dart';

/// Chat avatar widget with optional online indicator
class ChatAvatar extends StatelessWidget {
  final String? photoUrl;
  final String displayName;
  final double radius;
  final bool showOnlineIndicator;
  final bool isOnline;
  final bool isGroup;

  const ChatAvatar({
    super.key,
    this.photoUrl,
    required this.displayName,
    this.radius = 24,
    this.showOnlineIndicator = false,
    this.isOnline = false,
    this.isGroup = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildAvatar(),
        if (showOnlineIndicator && isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.4,
              height: radius * 0.4,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAvatar() {
    if (isGroup) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.transparent,
        backgroundImage: const AssetImage('assets/newapp/grouplogo.png'),
      );
    }

    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(photoUrl!),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: _getColorFromName(displayName),
      child: Text(
        _getInitials(displayName),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Color _getColorFromName(String name) {
    final colors = [
      Colors.blue[400]!,
      Colors.green[400]!,
      Colors.orange[400]!,
      Colors.purple[400]!,
      Colors.teal[400]!,
      Colors.pink[400]!,
      Colors.indigo[400]!,
      Colors.cyan[400]!,
    ];
    
    final index = name.hashCode.abs() % colors.length;
    return colors[index];
  }
}

/// Group avatar with multiple member photos
class GroupAvatar extends StatelessWidget {
  final List<String?> memberPhotos;
  final List<String> memberNames;
  final double radius;

  const GroupAvatar({
    super.key,
    required this.memberPhotos,
    required this.memberNames,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    if (memberPhotos.isEmpty) {
      return ChatAvatar(
        displayName: 'مجموعة',
        radius: radius,
        isGroup: true,
      );
    }

    if (memberPhotos.length == 1) {
      return ChatAvatar(
        photoUrl: memberPhotos[0],
        displayName: memberNames.isNotEmpty ? memberNames[0] : '?',
        radius: radius,
      );
    }

    // Show 2-4 member avatars in a grid
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        children: [
          // Bottom right (or single if only 2)
          Positioned(
            right: 0,
            bottom: 0,
            child: CircleAvatar(
              radius: radius * 0.6,
              backgroundImage: memberPhotos[0] != null 
                  ? NetworkImage(memberPhotos[0]!) 
                  : null,
              backgroundColor: Colors.blue[100],
              child: memberPhotos[0] == null
                  ? Text(
                      _getInitial(memberNames.isNotEmpty ? memberNames[0] : '?'),
                      style: TextStyle(fontSize: radius * 0.4),
                    )
                  : null,
            ),
          ),
          // Top left
          Positioned(
            left: 0,
            top: 0,
            child: CircleAvatar(
              radius: radius * 0.6,
              backgroundImage: memberPhotos.length > 1 && memberPhotos[1] != null
                  ? NetworkImage(memberPhotos[1]!)
                  : null,
              backgroundColor: Colors.green[100],
              child: (memberPhotos.length <= 1 || memberPhotos[1] == null)
                  ? Text(
                      _getInitial(memberNames.length > 1 ? memberNames[1] : '?'),
                      style: TextStyle(fontSize: radius * 0.4),
                    )
                  : null,
            ),
          ),
          // Show count if more than 2
          if (memberPhotos.length > 2)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: radius * 0.7,
                height: radius * 0.7,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '+${memberPhotos.length - 2}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: radius * 0.35,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getInitial(String name) {
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
