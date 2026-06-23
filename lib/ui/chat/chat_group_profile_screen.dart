import 'package:flutter/material.dart';

import '../../chat/chat.dart';
import '../../resources/app_colors.dart';
import '../widgets/header_widget.dart';
import 'chat_display_utils.dart';

/// Profile screen for group / support chats.
/// Same visual design as ChatUserProfileScreen but shows
/// group info + member list + shared media.
class ChatGroupProfileScreen extends StatelessWidget {
  final String chatId;
  final String title;
  final ChatType chatType;
  final String? supportGroupTitle;

  const ChatGroupProfileScreen({
    super.key,
    required this.chatId,
    required this.title,
    required this.chatType,
    this.supportGroupTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryColor,
      appBar: const HeaderWidget(),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<ChatMember>>(
          future: ChatRepository.instance.getChatMembers(chatId),
          builder: (context, membersSnap) {
            final members = membersSnap.data ?? [];

            return FutureBuilder<List<ChatUser>>(
              future: members.isNotEmpty
                  ? UserRepository.instance
                      .getUsersByIds(members.map((m) => m.uid).toList())
                  : Future.value([]),
              builder: (context, usersSnap) {
                final users = usersSnap.data ?? [];
                final userMap = {for (final u in users) u.uid: u};

                return StreamBuilder<List<Message>>(
                  stream: ChatRepository.instance.subscribeToMessages(
                    chatId,
                    pageSize: 200,
                  ),
                  builder: (context, messageSnapshot) {
                    final mediaItems =
                        _extractMedia(messageSnapshot.data ?? const []);

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 22),
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F4F4),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _GroupIdentityCard(
                              title: title,
                              subtitle: chatType == ChatType.support
                                  ? 'Support Group'
                                  : 'Group Chat',
                              memberCount: members.length,
                              chatType: chatType,
                            ),
                            // Group info section
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(18, 16, 18, 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _InfoRow(
                                    label: 'Group Name',
                                    value: limitChatDisplayName(title),
                                  ),
                                  _InfoRow(
                                    label: 'Type',
                                    value: _chatTypeLabel(chatType),
                                  ),
                                  _InfoRow(
                                    label: 'Members',
                                    value: '${members.length} members',
                                  ),
                                  if (supportGroupTitle != null)
                                    _InfoRow(
                                      label: 'Department',
                                      value: supportGroupTitle!,
                                    ),
                                ],
                              ),
                            ),
                            // Members list
                            _MembersSection(
                              members: members,
                              userMap: userMap,
                            ),
                            // Media section
                            _MediaSection(
                              items: mediaItems,
                              onTapItem: (item) =>
                                  _openMediaPreview(context, item),
                              onViewAll: mediaItems.isEmpty
                                  ? null
                                  : () => _showAllMediaBottomSheet(
                                      context, mediaItems),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  static String _chatTypeLabel(ChatType type) {
    switch (type) {
      case ChatType.dm:
        return 'Direct Message';
      case ChatType.role:
        return 'Role Group';
      case ChatType.group:
        return 'Group Chat';
      case ChatType.support:
        return 'Support Group';
    }
  }

  static List<_SharedMediaItem> _extractMedia(List<Message> messages) {
    final items = <_SharedMediaItem>[];
    for (final message in messages) {
      final url = (message.mediaUrl ?? '').trim();
      if (url.isEmpty) continue;
      if (message.type == MessageType.image) {
        items.add(_SharedMediaItem(
          type: MessageType.image,
          url: url,
          thumbUrl: message.thumbUrl,
        ));
      } else if (message.type == MessageType.video) {
        items.add(_SharedMediaItem(
          type: MessageType.video,
          url: url,
          thumbUrl: message.thumbUrl,
        ));
      }
    }
    return items;
  }

  static void _openMediaPreview(BuildContext context, _SharedMediaItem item) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 32),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 0.78,
                child: Container(
                  color: Colors.black,
                  child: Image.network(
                    item.displayUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: Colors.white70, size: 38),
                    ),
                  ),
                ),
              ),
            ),
            if (item.type == MessageType.video)
              const Positioned.fill(
                child: Center(
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: Color(0x77000000),
                    child: Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 34),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static void _showAllMediaBottomSheet(
      BuildContext context, List<_SharedMediaItem> items) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A3358),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemBuilder: (_, index) {
                final item = items[index];
                return _MediaThumb(
                  item: item,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openMediaPreview(context, item);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// ── Identity Card ──

class _GroupIdentityCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int memberCount;
  final ChatType chatType;

  const _GroupIdentityCard({
    required this.title,
    required this.subtitle,
    required this.memberCount,
    required this.chatType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: const BoxDecoration(
        color: AppColors.primaryColor,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(1.3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border:
                  Border.all(color: const Color(0xFFE9B23A), width: 1.2),
            ),
            child: const CircleAvatar(
              radius: 24,
              backgroundImage: AssetImage('assets/logo/rcc2.png'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  limitChatDisplayName(title),
                  maxLines: null,
                  overflow: TextOverflow.visible,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$subtitle • $memberCount members',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info Row ──

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF121212),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Members Section ──

class _MembersSection extends StatelessWidget {
  final List<ChatMember> members;
  final Map<String, ChatUser> userMap;

  const _MembersSection({
    required this.members,
    required this.userMap,
  });

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Group Members',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ...members.map((member) {
            final user = userMap[member.uid];
            final name = limitChatDisplayName(user?.name ?? 'Unknown');
            final role = user?.jobTitle ?? user?.roleName ?? '';
            final avatarUrl = user?.avatarUrl;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  // Avatar
                  StreamBuilder<PresenceStatus>(
                    stream: PresenceService.instance
                        .subscribeToUserPresence(member.uid),
                    builder: (context, snap) {
                      final isOnline = snap.data?.online ?? false;
                      return Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFE9B23A),
                                width: 1,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFFECECEC),
                              backgroundImage:
                                  avatarUrl != null && avatarUrl.isNotEmpty
                                      ? NetworkImage(avatarUrl)
                                      : null,
                              child:
                                  avatarUrl == null || avatarUrl.isEmpty
                                      ? Text(
                                          _initials(name),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF2D2D2D),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        )
                                      : null,
                            ),
                          ),
                          if (isOnline)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2DD65B),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 1.5),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  // Name + role
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1D2449),
                          ),
                          maxLines: null,
                          overflow: TextOverflow.visible,
                        ),
                        if (role.isNotEmpty)
                          Text(
                            role,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                            maxLines: null,
                            overflow: TextOverflow.visible,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static String _initials(String value) {
    final parts =
        value.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

// ── Media Section ──

class _MediaSection extends StatelessWidget {
  final List<_SharedMediaItem> items;
  final VoidCallback? onViewAll;
  final ValueChanged<_SharedMediaItem> onTapItem;

  const _MediaSection({
    required this.items,
    required this.onTapItem,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final previewItems = items.take(9).toList();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2A3358),
        borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: Column(
        children: [
          Container(
            width: 66,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Row(
            children: [
              const Text(
                'Media Shared',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onViewAll,
                child: Text(
                  'View All',
                  style: TextStyle(
                    color: onViewAll == null ? Colors.white38 : Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (previewItems.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 26),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'No media shared yet',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              itemCount: previewItems.length,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemBuilder: (_, index) {
                final item = previewItems[index];
                return _MediaThumb(
                  item: item,
                  onTap: () => onTapItem(item),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ── Media Thumbnail ──

class _MediaThumb extends StatelessWidget {
  final _SharedMediaItem item;
  final VoidCallback onTap;

  const _MediaThumb({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFE9B23A), width: 1.2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11.5),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                item.displayUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.white.withValues(alpha: 0.08),
                  child: const Icon(Icons.broken_image_outlined,
                      color: Colors.white70),
                ),
              ),
              if (item.type == MessageType.video)
                const Center(
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor: Color(0x77000000),
                    child: Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared Media Item model ──

class _SharedMediaItem {
  final MessageType type;
  final String url;
  final String? thumbUrl;

  const _SharedMediaItem({
    required this.type,
    required this.url,
    this.thumbUrl,
  });

  String get displayUrl {
    final thumb = thumbUrl?.trim() ?? '';
    return thumb.isNotEmpty ? thumb : url;
  }
}
