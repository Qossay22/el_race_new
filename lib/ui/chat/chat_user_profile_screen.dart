import 'dart:async';

import 'package:flutter/material.dart';

import '../../chat/chat.dart';
import '../presentation/todo_list/services/team_members_api_service.dart';
import '../../resources/app_colors.dart';
import '../widgets/header_widget.dart';
import 'chat_display_utils.dart';

class ChatUserProfileScreen extends StatefulWidget {
  final String chatId;
  final String peerUid;
  final String fallbackName;

  const ChatUserProfileScreen({
    super.key,
    required this.chatId,
    required this.peerUid,
    required this.fallbackName,
  });

  @override
  State<ChatUserProfileScreen> createState() => _ChatUserProfileScreenState();
}

class _ChatUserProfileScreenState extends State<ChatUserProfileScreen> {
  final Set<String> _hydrationInProgress = <String>{};
  TeamMember? _directoryMember;

  @override
  void initState() {
    super.initState();
    _loadDirectoryProfile();
  }

  Future<void> _loadDirectoryProfile() async {
    final user = await UserRepository.instance.getUser(widget.peerUid);
    if (user == null) return;

    final match = await UserRepository.instance.findDirectoryMatchForUser(user);
    if (mounted) {
      setState(() => _directoryMember = match);
    }
    _maybeHydrateMissingProfileFields(user);
  }

  void _maybeHydrateMissingProfileFields(ChatUser? user) {
    if (user == null) return;

    if (_hydrationInProgress.contains(user.uid)) return;
    _hydrationInProgress.add(user.uid);

    UserRepository.instance
        .hydrateUserProfileFromEmployeeDirectory(user)
        .whenComplete(() {
      _hydrationInProgress.remove(user.uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryColor,
      appBar: const HeaderWidget(),
      body: SafeArea(
        top: false,
        child: StreamBuilder<ChatUser?>(
          stream: UserRepository.instance.subscribeToUser(widget.peerUid),
          builder: (context, userSnapshot) {
            final user = userSnapshot.data;
            _maybeHydrateMissingProfileFields(user);
            _debugPrintProfile(userSnapshot, user);
            return StreamBuilder<PresenceStatus>(
              stream: PresenceService.instance
                  .subscribeToUserPresence(widget.peerUid),
              builder: (context, presenceSnapshot) {
                final isOnline = presenceSnapshot.data?.online ?? false;
                return StreamBuilder<List<Message>>(
                  stream: ChatRepository.instance.subscribeToMessages(
                    widget.chatId,
                    pageSize: 200,
                  ),
                  builder: (context, messageSnapshot) {
                    final mediaItems =
                        _extractMedia(messageSnapshot.data ?? const []);

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                          child: SizedBox(
                            height: constraints.maxHeight - 6,
                            child: Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: const Color(0xFFECECEE),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                    _TopIdentityCard(
                                      displayName: limitChatDisplayName(
                                        user?.name.trim().isNotEmpty == true
                                            ? user!.name
                                            : widget.fallbackName,
                                      ),
                                      avatarUrl: user?.avatarUrl,
                                      initials: _initials(
                                        user?.name.trim().isNotEmpty == true
                                            ? user!.name
                                            : widget.fallbackName,
                                      ),
                                      isOnline: isOnline,
                                    ),
                                    Flexible(
                                      child: SingleChildScrollView(
                                        padding: const EdgeInsets.fromLTRB(
                                            22, 22, 22, 8),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                          _InfoRow(
                                            label: 'Display Name',
                                            value: limitChatDisplayName(
                                              user?.name.trim().isNotEmpty ==
                                                      true
                                                  ? user!.name
                                                  : widget.fallbackName,
                                            ),
                                          ),
                                          _InfoRow(
                                            label: 'Email Address',
                                            value: _displayEmail(
                                              user,
                                              _directoryMember,
                                            ),
                                          ),
                                          _InfoRow(
                                            label: 'Job Title',
                                            value: _resolveJobTitle(
                                              user,
                                              _directoryMember,
                                            ),
                                          ),
                                          _InfoRow(
                                            label: 'Employee Number',
                                            value: _resolveEmployeeNumber(
                                              user,
                                              _directoryMember,
                                            ),
                                          ),
                                          _InfoRow(
                                            label: 'Phone Number',
                                            value: _displayPhone(
                                              user,
                                              _directoryMember,
                                            ),
                                          ),
                                        ],
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: _MediaSection(
                                        items: mediaItems,
                                        onTapItem: (item) =>
                                            _openMediaPreview(context, item),
                                        onViewAll: mediaItems.isEmpty
                                            ? null
                                            : () => _showAllMediaBottomSheet(
                                                context, mediaItems),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                      },
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

  static int? _employeeNumberFromName(String? name) {
    if (name == null) return null;
    final match = RegExp(r'^\s*(\d+)').firstMatch(name.trim());
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  static bool _isValidEmail(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return false;
    final lower = normalized.toLowerCase();
    if (lower == 'null' || lower == 'false' || lower == 'n/a') return false;
    return normalized.contains('@') && normalized.contains('.');
  }

  static bool _isWeakJobTitle(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return true;
    if (RegExp(r'^\d+$').hasMatch(normalized)) return true;
    if (RegExp(r'^role\s*\d+$', caseSensitive: false).hasMatch(normalized)) {
      return true;
    }
    return false;
  }

  static String _resolveEmployeeNumber(ChatUser? user, TeamMember? directory) {
    if (user != null &&
        user.employeeFileNumber != null &&
        user.employeeFileNumber! > 0) {
      return user.employeeFileNumber.toString();
    }
    if (directory?.employeeFileNumber != null &&
        directory!.employeeFileNumber! > 0) {
      return directory.employeeFileNumber.toString();
    }
    final fromName = _employeeNumberFromName(user?.name);
    if (fromName != null && fromName > 0) return fromName.toString();
    if (directory?.employeeId != null && directory!.employeeId! > 0) {
      return directory.employeeId.toString();
    }
    if (user?.employeeId != null && user!.employeeId! > 0) {
      return user.employeeId.toString();
    }
    final odooMatch = RegExp(r'^odoo_(\d+)$').firstMatch(user?.uid ?? '');
    if (odooMatch != null) return odooMatch.group(1)!;
    if (user != null && user.odooUserId > 0) return user.odooUserId.toString();
    return '-';
  }

  static String _resolveJobTitle(ChatUser? user, TeamMember? directory) {
    if (user == null && directory == null) return '-';

    final fromProfile = user?.jobTitle?.trim() ?? '';
    if (fromProfile.isNotEmpty &&
        !_isWeakJobTitle(fromProfile) &&
        fromProfile.toLowerCase() !=
            (user?.roleName?.trim().toLowerCase() ?? '')) {
      return fromProfile;
    }

    final fromDirectory = directory?.jobPosition?.trim() ?? '';
    if (fromDirectory.isNotEmpty && !_isWeakJobTitle(fromDirectory)) {
      return fromDirectory;
    }

    final department = directory?.department?.trim() ?? '';
    if (department.isNotEmpty) return department;

    return '-';
  }

  static String _notEmptyOrDash(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return '-';
    final lower = trimmed.toLowerCase();
    if (lower == 'null' || lower == 'false' || lower == 'n/a') return '-';
    return trimmed;
  }

  static String _displayEmail(ChatUser? user, TeamMember? directory) {
    if (user != null && _isValidEmail(user.email)) {
      return user.email!.trim();
    }
    if (directory != null && _isValidEmail(directory.email)) {
      return directory.email!.trim();
    }
    return '-';
  }

  static String _displayPhone(ChatUser? user, TeamMember? directory) {
    final fromUser = _notEmptyOrDash(user?.phoneNumber);
    if (fromUser != '-') return fromUser;
    final fromDirectory = _notEmptyOrDash(directory?.phone);
    if (fromDirectory != '-') return fromDirectory;
    return '-';
  }

  static void _debugPrintProfile(
    AsyncSnapshot<ChatUser?> snapshot,
    ChatUser? user,
  ) {
    final state = snapshot.connectionState.name;
    debugPrint(
        '👤 ChatProfile: state=$state hasData=${snapshot.hasData} hasError=${snapshot.hasError}');
    if (snapshot.error != null) {
      debugPrint('👤 ChatProfile: snapshot.error=${snapshot.error}');
    }
    if (user == null) {
      debugPrint('👤 ChatProfile: user=NULL');
      return;
    }
    debugPrint('👤 ChatProfile: uid=${user.uid}');
    debugPrint('👤 ChatProfile: name=${user.name}');
    debugPrint('👤 ChatProfile: email=${user.email}');
    debugPrint('👤 ChatProfile: phone=${user.phoneNumber}');
    debugPrint(
        '👤 ChatProfile: jobTitle=${user.jobTitle} roleName=${user.roleName} roleId=${user.roleId}');
    debugPrint(
        '👤 ChatProfile: employeeId=${user.employeeId} '
        'employeeFileNumber=${user.employeeFileNumber} odooUserId=${user.odooUserId}');
  }

  static String _initials(String value) {
    final parts =
        value.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 32),
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

class _TopIdentityCard extends StatelessWidget {
  final String displayName;
  final String? avatarUrl;
  final String initials;
  final bool isOnline;

  const _TopIdentityCard({
    required this.displayName,
    required this.avatarUrl,
    required this.initials,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.primaryColor,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: const Color(0xFFE9B23A), width: 2),
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFE7E7E7),
                  backgroundImage: (avatarUrl?.trim().isNotEmpty == true)
                      ? NetworkImage(avatarUrl!.trim())
                      : null,
                  child: (avatarUrl?.trim().isNotEmpty == true)
                      ? null
                      : Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF2D2D2D),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              if (isOnline)
                Positioned(
                  right: 1,
                  bottom: 1,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2DD65B),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: null,
                  overflow: TextOverflow.visible,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOnline ? 'Active now' : 'Offline',
                  style: TextStyle(
                    color: isOnline ? const Color(0xFF6BE483) : Colors.white70,
                    fontSize: 12,
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              textAlign: TextAlign.start,
              style: const TextStyle(
                color: Color(0xFF8A8A8A),
                fontSize: 12,
                height: 1,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              textAlign: TextAlign.start,
              style: const TextStyle(
                color: Color(0xFF121212),
                fontSize: 16,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF2A3358),
        borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 66,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Row(
            children: [
              const Text(
                'Media Shared',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: previewItems.isEmpty
                ? Container(
                    width: double.infinity,
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
                : GridView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: previewItems.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
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
          ),
        ],
      ),
    );
  }
}

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
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white70,
                  ),
                ),
              ),
              if (item.type == MessageType.video)
                const Center(
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor: Color(0x77000000),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

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
