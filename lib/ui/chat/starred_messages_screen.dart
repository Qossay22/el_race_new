import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../chat/chat.dart';
import '../../resources/app_colors.dart';
import '../widgets/header_widget.dart';
import 'chat_display_utils.dart';
import 'chat_screen.dart';

/// Screen that displays all starred messages for the current user
class StarredMessagesScreen extends StatefulWidget {
  const StarredMessagesScreen({super.key});

  @override
  State<StarredMessagesScreen> createState() => _StarredMessagesScreenState();
}

class _StarredMessagesScreenState extends State<StarredMessagesScreen> {
  String? _currentUid;

  DateTime? _parseStarredDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) {
      // Accept both seconds and milliseconds epoch.
      if (value > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      if (value > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000);
      }
      return null;
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value.trim());
      return parsed;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryColor,
      appBar: const HeaderWidget(),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Container(
                color: const Color(0xFFF2F2F2),
                child: _buildStarredList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.primaryColor,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.star_rounded, color: Color(0xFFF4C542), size: 24),
          const SizedBox(width: 8),
          const Text(
            'Starred Messages',
            style: TextStyle(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarredList() {
    if (_currentUid == null) {
      return const Center(child: Text('Not authenticated'));
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ChatRepository.instance.subscribeToStarredMessages(),
      builder: (context, starredSnapshot) {
        if (starredSnapshot.hasError) {
          return Center(
            child: Text(
              'Error loading starred messages',
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }

        final starredMessages = starredSnapshot.data ?? [];

        if (starredMessages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_outline_rounded,
                    size: 60, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No starred messages',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Long-press a message and tap Star\nto save it here',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ],
            ),
          );
        }

        return StreamBuilder<List<UserChat>>(
          stream: ChatRepository.instance.subscribeToUserChats(_currentUid!),
          builder: (context, chatsSnapshot) {
            final chats = chatsSnapshot.data ?? const <UserChat>[];
            final chatsById = {for (final c in chats) c.chatId: c};

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: starredMessages.length,
              itemBuilder: (context, index) {
                final data = starredMessages[index];
                final chatId = data['chat_id'] as String?;
                final chatTitle =
                    (chatId != null) ? chatsById[chatId]?.title : null;

                return _StarredMessageTile(
                  data: data,
                  currentUid: _currentUid!,
                  chatTitle: chatTitle,
                  onTap: () => _navigateToChat(data),
                  onUnstar: () => _unstarMessage(data['id'] as String),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _navigateToChat(Map<String, dynamic> data) async {
    final chatId = data['chat_id'] as String?;
    if (chatId == null) return;

    final messageId =
        (data['message_id'] as String?) ?? (data['id'] as String?);
    final messageCreatedAt = _parseStarredDate(data['created_at']) ??
        _parseStarredDate(data['starred_at']);
    final messageSenderId = data['sender_id'] as String?;
    final messageType = data['type'] as String?;
    final messageText = data['text'] as String?;
    final messageFileName = data['file_name'] as String?;

    print('🔎 STAR_JUMP[source]: open from starred tile '
        'chatId=$chatId messageId=$messageId type=$messageType '
        'createdAt=$messageCreatedAt senderId=$messageSenderId '
        'fileName=$messageFileName textLen=${messageText?.length ?? 0}');

    final userChat = await ChatRepository.instance.getUserChat(chatId);
    if (!mounted) return;

    final chatType = userChat?.type ?? ChatType.dm;
    final title = limitChatDisplayName(userChat?.title ?? 'Chat');
    final peerUid = userChat?.peerUid;
    final supportUserUid = userChat?.supportUserUid;
    final supportGroupTitle = userChat?.supportGroupTitle;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          title: title,
          chatType: chatType,
          peerUid: peerUid,
          supportUserUid: supportUserUid,
          supportGroupTitle: supportGroupTitle,
          initialMessageId: messageId,
          initialMessageCreatedAt: messageCreatedAt,
          initialMessageSenderId: messageSenderId,
          initialMessageType: messageType,
          initialMessageText: messageText,
          initialMessageFileName: messageFileName,
        ),
      ),
    );
  }

  void _unstarMessage(String messageId) {
    ChatRepository.instance.unstarMessage(messageId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message unstarred'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}

class _StarredMessageTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String currentUid;
  final String? chatTitle;
  final VoidCallback onTap;
  final VoidCallback onUnstar;

  const _StarredMessageTile({
    required this.data,
    required this.currentUid,
    required this.chatTitle,
    required this.onTap,
    required this.onUnstar,
  });

  @override
  Widget build(BuildContext context) {
    final senderId = data['sender_id'] as String? ?? '';
    final type = data['type'] as String? ?? 'text';
    final text = data['text'] as String?;
    final isMe = senderId == currentUid;
    final createdAt = (data['created_at'] as Timestamp?)?.toDate();
    final effectiveChatTitle =
        (chatTitle != null && chatTitle!.trim().isNotEmpty)
            ? limitChatDisplayName(chatTitle!)
            : (isMe ? 'You' : 'Contact');

    // Build preview text
    String preview;
    if (text != null && text.isNotEmpty) {
      preview = text;
    } else {
      switch (type) {
        case 'image':
          preview = '📷 Photo';
          break;
        case 'audio':
          preview = '🎵 Voice message';
          break;
        case 'video':
          preview = '🎬 Video';
          break;
        case 'file':
          final fileName = data['file_name'] as String?;
          preview = '📎 ${fileName ?? 'File'}';
          break;
        default:
          preview = 'Message';
      }
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: () {
        showMenu<String>(
          context: context,
          position: RelativeRect.fromLTRB(100, 300, 100, 300),
          elevation: 8,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
          items: [
            PopupMenuItem(
              value: 'unstar',
              child: Row(
                children: const [
                  Icon(Icons.star_rounded, color: Color(0xFFF4C542), size: 22),
                  SizedBox(width: 14),
                  Text(
                    'Unstar',
                    style: TextStyle(
                      color: Color(0xFF2C2C2E),
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ).then((value) {
          if (value == 'unstar') onUnstar();
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Star icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.star_rounded,
                  color: Color(0xFFF4C542), size: 22),
            ),
            const SizedBox(width: 12),
            // Message content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          effectiveChatTitle,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1D2449),
                          ),
                          maxLines: null,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                      if (createdAt != null)
                        Text(
                          _formatDateTime(createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF5A6570),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Type icon
            _buildTypeIcon(type),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeIcon(String type) {
    IconData icon;
    Color color;
    switch (type) {
      case 'image':
        icon = Icons.image_rounded;
        color = Colors.green;
        break;
      case 'audio':
        icon = Icons.mic_rounded;
        color = Colors.orange;
        break;
      case 'video':
        icon = Icons.videocam_rounded;
        color = Colors.blue;
        break;
      case 'file':
        icon = Icons.insert_drive_file_rounded;
        color = Colors.indigo;
        break;
      default:
        icon = Icons.chat_bubble_outline_rounded;
        color = Colors.grey;
    }

    return Icon(icon, size: 18, color: color.withValues(alpha: 0.6));
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day - 1) {
      return 'Yesterday';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
