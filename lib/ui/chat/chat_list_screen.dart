import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../chat/chat.dart';
import '../../resources/app_colors.dart';
import '../widgets/header_widget.dart';
import 'chat_display_utils.dart';
import 'chat_screen.dart';
import 'starred_messages_screen.dart';
import 'widgets/typing_indicator.dart';

/// Main chat list screen showing all user's conversations
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  String? _currentUid;
  bool _isChatAvailable = false;
  bool _isInitializing = false;
  final ValueNotifier<bool> _isScrolledNotifier = ValueNotifier(false);

  final TextEditingController _localSearchController = TextEditingController();
  final ValueNotifier<String> _searchNotifier = ValueNotifier('');
  Timer? _debounce;

  // Tab state for Groups / Support — ValueNotifier so only tab section rebuilds
  final ValueNotifier<int> _topTabNotifier =
      ValueNotifier(0); // 0 = Groups, 1 = Support
  List<Chat> _supportGroups = [];

  /// Cached chat stream — created once, reused across rebuilds
  Stream<List<UserChat>>? _userChatsStream;

  // Global user search state — ValueNotifiers so only the bottom section rebuilds
  final ValueNotifier<List<ChatUser>> _globalResultsNotifier =
      ValueNotifier([]);
  final ValueNotifier<bool> _globalSearchingNotifier = ValueNotifier(false);
  ChatUser? _currentUser;
  Timer? _globalDebounce;

  @override
  void initState() {
    super.initState();
    _initializeChat();

    _localSearchController.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), () {
        final q = _localSearchController.text.trim().toLowerCase();
        if (q != _searchNotifier.value) {
          _searchNotifier.value = q;
        }
      });

      // Also trigger global user search
      _globalDebounce?.cancel();
      _globalDebounce = Timer(const Duration(milliseconds: 500), () {
        _performGlobalSearch(_localSearchController.text.trim());
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _globalDebounce?.cancel();
    _localSearchController.dispose();
    _searchNotifier.dispose();
    _topTabNotifier.dispose();
    _isScrolledNotifier.dispose();
    _globalResultsNotifier.dispose();
    _globalSearchingNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    if (_currentUid != null) {
      _currentUser = await UserRepository.instance.getUser(_currentUid!);
      // One-shot Firestore cleanup for legacy "Chat" ghost rows.
      unawaited(ChatRepository.instance.repairUserChatIndex(_currentUid!));
    }
    // Load support groups for the Support tab
    _loadSupportGroups();
  }

  Future<void> _loadSupportGroups() async {
    try {
      final groups = await ChatRepository.instance.getAllRoleGroups();
      if (mounted) {
        setState(() {
          _supportGroups = groups;
        });
      }
    } catch (e) {
      print('⚠️ ChatListScreen: Error loading support groups: $e');
    }
  }

  Future<void> _performGlobalSearch(String query) async {
    final isNumericQuery = RegExp(r'^\d+$').hasMatch(query);
    if (query.length < 2 && !isNumericQuery) {
      _globalResultsNotifier.value = [];
      _globalSearchingNotifier.value = false;
      return;
    }

    _globalSearchingNotifier.value = true;

    try {
      final result = await UserRepository.instance
          .searchUsers(query: query)
          .timeout(const Duration(seconds: 15));
      final filtered = result.users.where((u) => u.uid != _currentUid).toList();
      if (mounted) {
        _globalResultsNotifier.value = filtered;
      }
    } catch (e) {
      if (mounted) {
        _globalResultsNotifier.value = [];
      }
    } finally {
      if (mounted) {
        _globalSearchingNotifier.value = false;
      }
    }
  }

  Future<void> _initializeChat() async {
    _currentUid = FirebaseAuth.instance.currentUser?.uid;
    _isChatAvailable = ChatModuleHelper.instance.isChatEnabled;

    // If chat is not available but user is authenticated, try to restore session
    if (!_isChatAvailable && !_isInitializing) {
      setState(() => _isInitializing = true);

      try {
        print(
            '🔷 ChatListScreen: Chat not available, attempting to restore session...');
        final result = await ChatModuleHelper.instance
            .restoreFromStoredSession()
            .timeout(const Duration(seconds: 15), onTimeout: () {
          print('⚠️ ChatListScreen: Chat restore timed out');
          return null;
        });

        if (result != null && result.chatEnabled) {
          _currentUid = FirebaseAuth.instance.currentUser?.uid;
          _isChatAvailable = true;
          _loadCurrentUser();
          print('✅ ChatListScreen: Chat session restored successfully');
        } else {
          print(
              '⚠️ ChatListScreen: Failed to restore chat session: ${result?.error}');
        }
      } catch (e) {
        print('❌ ChatListScreen: Error restoring chat session: $e');
      } finally {
        if (mounted) {
          setState(() => _isInitializing = false);
        }
      }
    } else {
      _loadCurrentUser();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while initializing chat
    if (_isInitializing) {
      return Scaffold(
        appBar: const HeaderWidget(),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isChatAvailable || _currentUid == null) {
      return Scaffold(
        appBar: const HeaderWidget(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Chat not available',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  ChatModuleHelper.instance.getStatusMessage(),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _initializeChat,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              // Show logout button if error mentions session expired
              if (ChatModuleHelper.instance
                      .getStatusMessage()
                      .contains('expired') ||
                  ChatModuleHelper.instance
                      .getStatusMessage()
                      .contains('login again'))
                TextButton.icon(
                  onPressed: () {
                    // Navigate to logout or login screen
                    Navigator.of(context).pushReplacementNamed('/signIN');
                  },
                  icon: const Icon(Icons.logout, size: 20),
                  label: const Text('Logout & Login Again'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.primaryColor,
      appBar: const HeaderWidget(),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            StreamBuilder<List<UserChat>>(
              stream: _userChatsStream ??=
                  ChatRepository.instance.subscribeToUserChats(_currentUid!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 56, color: Colors.red[300]),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Error: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final rawChats = (snapshot.data ?? [])
                    .map((c) => ChatRepository.instance
                        .normalizeUserChatIndex(_currentUid!, c))
                    .toList();

                // Main list: real conversations only (no ghosts / empty titles).
                final personalChats = rawChats
                    .where((c) =>
                        ChatRepository.instance.shouldShowInConversationList(
                          c,
                          uid: _currentUid,
                        ) &&
                        c.type != ChatType.role &&
                        c.type != ChatType.group)
                    .toList();
                final activeDepartmentChats =
                    ChatRepository.instance.deduplicateDepartmentUserChats(
                  rawChats
                      .where((c) =>
                          ChatRepository.instance.shouldShowInConversationList(
                            c,
                            uid: _currentUid,
                          ) &&
                          (c.type == ChatType.role ||
                              c.type == ChatType.group))
                      .toList(),
                );
                final allChats = [...personalChats, ...activeDepartmentChats]
                  ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

                // Groups tab: deduplicated memberships (may be empty until first message).
                final membershipGroups =
                    ChatRepository.instance.deduplicateDepartmentUserChats(
                  rawChats
                      .where((c) =>
                          !ChatRepository.instance.isGhostListEntry(c) &&
                          (c.type == ChatType.role ||
                              c.type == ChatType.group ||
                              c.chatId.startsWith('role_')) &&
                          ChatRepository.instance
                                  .resolveUserChatDisplayTitle(
                                c,
                                roleCatalog: _supportGroups,
                              )
                              .toLowerCase() !=
                          'chat')
                      .toList(),
                );

                // Pre-warm user cache for all DM peer avatars
                final peerUids = allChats
                    .where((c) => c.type == ChatType.dm && c.peerUid != null)
                    .map((c) => c.peerUid!)
                    .toList();
                if (peerUids.isNotEmpty) {
                  UserRepository.instance.prefetchUsers(peerUids);
                }

                return NotificationListener<ScrollNotification>(
                  onNotification: (scrollNotification) {
                    if (scrollNotification is ScrollUpdateNotification ||
                        scrollNotification is ScrollEndNotification) {
                      final isScrolled = scrollNotification.metrics.pixels > 10;
                      if (isScrolled != _isScrolledNotifier.value) {
                        _isScrolledNotifier.value = isScrolled;
                      }
                    }
                    return false;
                  },
                  child: CustomScrollView(
                    slivers: [
                      const SliverToBoxAdapter(child: SizedBox(height: 74)),
                      // Search bar
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                          child: _ChatSearchBar(
                            controller: _localSearchController,
                            onClear: () {
                              _globalResultsNotifier.value = [];
                              _globalSearchingNotifier.value = false;
                            },
                          ),
                        ),
                      ),
                      // ── Tabs (Groups | Support) — only this section rebuilds ──
                      SliverToBoxAdapter(
                        child: ValueListenableBuilder<int>(
                          valueListenable: _topTabNotifier,
                          builder: (context, tabIndex, _) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Tab buttons
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 10),
                                  child: Row(
                                    children: [
                                      _TopTab(
                                        label: 'Groups',
                                        isActive: tabIndex == 0,
                                        onTap: () {
                                          if (tabIndex != 0)
                                            _topTabNotifier.value = 0;
                                        },
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10),
                                        child: Text(
                                          '|',
                                          style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.4),
                                            fontSize: 20,
                                            fontWeight: FontWeight.w300,
                                          ),
                                        ),
                                      ),
                                      _TopTab(
                                        label: 'Supports',
                                        isActive: tabIndex == 1,
                                        onTap: () {
                                          if (tabIndex != 1)
                                            _topTabNotifier.value = 1;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                // Tab content (horizontal bubbles)
                                SizedBox(
                                  height: 100,
                                  child: tabIndex == 0
                                      // ── Groups tab ──
                                      ? (membershipGroups.isEmpty
                                          ? const Center(
                                              child: Text(
                                                'No groups yet',
                                                style: TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 13),
                                              ),
                                            )
                                          : ListView.builder(
                                              padding: const EdgeInsets.only(
                                                  left: 16),
                                              scrollDirection: Axis.horizontal,
                                              itemCount: membershipGroups.length,
                                              itemBuilder: (context, i) {
                                                final g = membershipGroups[i];
                                                return _GroupQuickItem(
                                                  label: limitChatDisplayName(
                                                    ChatRepository.instance
                                                        .resolveUserChatDisplayTitle(
                                                      g,
                                                      roleCatalog:
                                                          _supportGroups,
                                                    ),
                                                  ),
                                                  onTap: () => _openChat(g),
                                                );
                                              },
                                            ))
                                      // ── Support tab ──
                                      : (_supportGroups.isEmpty
                                          ? const Center(
                                              child: Text(
                                                'No departments available',
                                                style: TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 13),
                                              ),
                                            )
                                          : ListView.builder(
                                              padding: const EdgeInsets.only(
                                                  left: 16),
                                              scrollDirection: Axis.horizontal,
                                              itemCount: _supportGroups.length,
                                              itemBuilder: (context, i) {
                                                final g = _supportGroups[i];
                                                return _SupportGroupQuickItem(
                                                  label: limitChatDisplayName(
                                                    g.title ??
                                                        'Dept ${g.roleId}',
                                                  ),
                                                  onTap: () =>
                                                      _startSupportChat(g),
                                                );
                                              },
                                            )),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 14)),
                      // White card header (drag handle)
                      SliverToBoxAdapter(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(30)),
                          ),
                          padding: const EdgeInsets.only(top: 9, bottom: 8),
                          alignment: Alignment.center,
                          child: Container(
                            width: 70,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ),
                      // Chat list items — only this section rebuilds on search
                      ValueListenableBuilder<String>(
                        valueListenable: _searchNotifier,
                        builder: (context, query, _) {
                          return ValueListenableBuilder<List<ChatUser>>(
                            valueListenable: _globalResultsNotifier,
                            builder: (context, globalResults, _) {
                              return ValueListenableBuilder<bool>(
                                valueListenable: _globalSearchingNotifier,
                                builder: (context, isGlobalSearching, _) {
                                  final filteredChats = query.isEmpty
                                      ? allChats
                                      : allChats
                                          .where((c) => _chatMatchesSearchQuery(
                                                c,
                                                query,
                                                _supportGroups,
                                              ))
                                          .toList();

                                  final bool hasQuery = query.isNotEmpty;
                                  final bool hasGlobalResults =
                                      globalResults.isNotEmpty;
                                  final bool showNoResults = hasQuery &&
                                      filteredChats.isEmpty &&
                                      !hasGlobalResults &&
                                      !isGlobalSearching;

                                  if (showNoResults) {
                                    return SliverFillRemaining(
                                      hasScrollBody: false,
                                      child: Container(
                                        color: Colors.white,
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.chat_bubble_outline,
                                                  size: 70,
                                                  color: Colors.grey[400]),
                                              const SizedBox(height: 12),
                                              Text(
                                                allChats.isEmpty
                                                    ? 'No chats yet'
                                                    : 'No results',
                                                style: TextStyle(
                                                    fontSize: 17,
                                                    color: Colors.grey[700]),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  // Build combined list: filtered chats + global user results
                                  final List<Widget> items = [];

                                  for (final userChat in filteredChats) {
                                    items.add(
                                      Container(
                                        color: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12),
                                        child: _ChatListTile(
                                          userChat: userChat,
                                          currentUid: _currentUid!,
                                          roleCatalog: _supportGroups,
                                          onTap: () => _openChat(userChat),
                                        ),
                                      ),
                                    );
                                  }

                                  // Show global search results when searching
                                  if (hasQuery &&
                                      (isGlobalSearching || hasGlobalResults)) {
                                    items.add(
                                      Container(
                                        color: Colors.white,
                                        padding: const EdgeInsets.fromLTRB(
                                            16, 16, 16, 8),
                                        child: Row(
                                          children: [
                                            Text(
                                              'Users',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            if (isGlobalSearching) ...[
                                              const SizedBox(width: 8),
                                              const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );

                                    for (final user in globalResults) {
                                      items.add(
                                        Container(
                                          color: Colors.white,
                                          child: _InlineUserTile(
                                            user: user,
                                            onTap: () =>
                                                _startChatWithUser(user),
                                          ),
                                        ),
                                      );
                                    }

                                    if (!isGlobalSearching &&
                                        globalResults.isEmpty) {
                                      items.add(
                                        Container(
                                          color: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          child: Center(
                                            child: Text(
                                              'No users found',
                                              style: TextStyle(
                                                  color: Colors.grey[500],
                                                  fontSize: 13),
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  }

                                  if (items.isEmpty && !hasQuery) {
                                    return SliverFillRemaining(
                                      hasScrollBody: false,
                                      child: Container(
                                        color: Colors.white,
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.chat_bubble_outline,
                                                  size: 70,
                                                  color: Colors.grey[400]),
                                              const SizedBox(height: 12),
                                              Text(
                                                'No chats yet',
                                                style: TextStyle(
                                                    fontSize: 17,
                                                    color: Colors.grey[700]),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  return SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) => items[index],
                                      childCount: items.length,
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                      // Fill remaining space with white
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Container(color: Colors.white),
                      ),
                      // Bottom safe area padding (iOS home indicator)
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: (MediaQuery.of(context).padding.bottom / 2).clamp(0.0, 6.0),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ValueListenableBuilder<bool>(
                valueListenable: _isScrolledNotifier,
                builder: (context, isScrolled, child) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor,
                      border: Border(
                        bottom: BorderSide(
                          color: isScrolled
                              ? Colors.white.withOpacity(0.18)
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                    ),
                    child:
                        _SecondaryChatBar(onMessagesTap: _openStarredMessages),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openChat(UserChat userChat) async {
    String title;
    if (userChat.type == ChatType.dm && userChat.peerUid != null) {
      final peer = await UserRepository.instance.getUser(userChat.peerUid!);
      title = peer?.name.trim().isNotEmpty == true
          ? limitChatDisplayName(peer!.name)
          : limitChatDisplayName(userChat.title ?? 'Chat');
    } else {
      final chatDoc = await ChatRepository.instance.getChat(userChat.chatId);
      title = limitChatDisplayName(
        ChatRepository.instance.resolveUserChatDisplayTitle(
          userChat,
          chatDoc: chatDoc,
          roleCatalog: _supportGroups,
        ),
      );
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatId: userChat.chatId,
          title: title,
          chatType: userChat.type,
          peerUid: userChat.peerUid,
          supportUserUid: userChat.supportUserUid,
          supportGroupTitle: userChat.supportGroupTitle,
        ),
      ),
    );
  }

  /// Start a support chat with a department group
  Future<void> _startSupportChat(Chat group) async {
    if (_currentUid == null || _currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final chatId = await ChatRepository.instance.createOrGetSupportChat(
        userUid: _currentUid!,
        userName: _currentUser!.name,
        targetRoleId: group.roleId!,
        groupTitle: group.title ?? 'Group ${group.roleId}',
        sourceRoleChatId: group.id,
        supportGroupKey: group.id,
        userRoleId: _currentUser!.roleId,
        userBranchId: _currentUser!.branchId,
        userCompanyId: _currentUser!.companyId,
      );

      if (mounted) Navigator.of(context).pop(); // dismiss loading

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              title: group.title ?? 'Group ${group.roleId}',
              chatType: ChatType.support,
              supportUserUid: _currentUid,
              supportGroupTitle: group.title ?? 'Group ${group.roleId}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // dismiss loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start support chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openStarredMessages() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const StarredMessagesScreen(),
      ),
    );
  }

  Future<void> _startChatWithUser(ChatUser user) async {
    if (_currentUid == null) return;

    final existing =
        await ChatRepository.instance.findExistingDmForUser(user);
    final resolvedUser = existing == null
        ? await UserRepository.instance.resolveCanonicalChatUser(user)
        : await UserRepository.instance.getUser(existing.peerUid) ?? user;

    final chatId = existing?.chatId ??
        Chat.generateDmChatId(_currentUid!, resolvedUser.uid);

    _localSearchController.clear();

    // Just navigate to chat screen — the chat doc will be created
    // when the first message is sent via ChatRepository.sendText
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: chatId,
            title: existing?.title ?? resolvedUser.name,
            chatType: ChatType.dm,
            peerUid: resolvedUser.uid,
          ),
        ),
      );
    }
  }
}

bool _chatMatchesSearchQuery(
  UserChat chat,
  String query,
  List<Chat> roleCatalog,
) {
  final q = query.toLowerCase().trim();
  if (q.isEmpty) return true;

  if ((chat.title ?? '').toLowerCase().contains(q)) return true;
  if ((chat.supportGroupTitle ?? '').toLowerCase().contains(q)) return true;
  if (chat.roleId?.toString().contains(q) ?? false) return true;

  final resolved = ChatRepository.instance.resolveUserChatDisplayTitle(
    chat,
    roleCatalog: roleCatalog,
  );
  return resolved.toLowerCase().contains(q);
}

/// Chat list tile widget
class _ChatListTile extends StatelessWidget {
  final UserChat userChat;
  final String currentUid;
  final List<Chat> roleCatalog;
  final VoidCallback onTap;

  const _ChatListTile({
    required this.userChat,
    required this.currentUid,
    this.roleCatalog = const [],
    required this.onTap,
  });

  UserChat get _effectiveChat =>
      ChatRepository.instance.normalizeUserChatIndex(currentUid, userChat);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effective = _effectiveChat;

    return StreamBuilder<Chat?>(
      stream: ChatRepository.instance.subscribeToChat(userChat.chatId),
      builder: (context, chatSnapshot) {
        final chat = chatSnapshot.data;
        final lastMessage = chat?.lastMessage;

        final hasUnread = userChat.hasUnread(lastMessage?.createdAt);

        return StreamBuilder<TypingInfo>(
          stream: PresenceService.instance
              .subscribeToTypingWithNames(userChat.chatId),
          builder: (context, typingSnapshot) {
            final typingInfo = typingSnapshot.data;
            final isTyping = typingInfo?.isTyping ?? false;

            return InkWell(
              onTap: onTap,
              onLongPress: () => _showChatActions(context),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildAvatar(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // For DM chats, always show the peer's actual name
                          // from the users collection (avoids showing role name duplicates)
                          if (effective.type == ChatType.dm &&
                              effective.peerUid != null)
                            FutureBuilder<ChatUser?>(
                              future: UserRepository.instance
                                  .getUser(effective.peerUid!),
                              builder: (context, snap) {
                                final rawName = snap.data?.name ??
                                    effective.title ??
                                    'Chat';
                                final displayName =
                                    limitChatDisplayName(rawName);
                                return Text(
                                  displayName,
                                  style:
                                      theme.textTheme.titleMedium?.copyWith(
                                    color: const Color(0xFF171717),
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                );
                              },
                            )
                          else
                            Text(
                              limitChatDisplayName(
                                ChatRepository.instance
                                    .resolveUserChatDisplayTitle(
                                  effective,
                                  chatDoc: chat,
                                  roleCatalog: roleCatalog,
                                ),
                              ),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: const Color(0xFF171717),
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          const SizedBox(height: 4),
                          DefaultTextStyle.merge(
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF8B8B8B),
                              fontWeight:
                                  hasUnread ? FontWeight.w600 : FontWeight.w400,
                            ),
                            child: isTyping
                                ? TypingTextWidget(
                                    typingUserNames: typingInfo!.typingNames,
                                    isGroupChat: effective.type != ChatType.dm,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF20B051),
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                : _buildLastMessage(lastMessage),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    StreamBuilder<int>(
                      stream: ChatRepository.instance
                          .subscribeToUnreadCount(userChat.chatId),
                      builder: (context, unreadSnap) {
                        final unreadCount = unreadSnap.data ?? 0;
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              lastMessage != null
                                  ? _formatTime(lastMessage.createdAt)
                                  : '',
                              style: TextStyle(
                                color: unreadCount > 0
                                    ? const Color(0xFF8C8C8C)
                                    : const Color(0xFFAAAAAA),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (userChat.pinned)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Icon(
                                      Icons.push_pin,
                                      size: 14,
                                      color: Color(0xFF8E8E93),
                                    ),
                                  ),
                                if (userChat.muted)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Icon(
                                      Icons.volume_off,
                                      size: 14,
                                      color: Color(0xFF8E8E93),
                                    ),
                                  ),
                                if (unreadCount > 0)
                                  Container(
                                    constraints: const BoxConstraints(
                                        minWidth: 22, minHeight: 22),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 2),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: userChat.muted
                                          ? const Color(0xFFB0B0B0)
                                          : const Color(0xFFF04D57),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      unreadCount > 99 ? '99+' : '$unreadCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  )
                                else
                                  const SizedBox(height: 22),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAvatar() {
    final effective = _effectiveChat;
    if (effective.type == ChatType.dm && effective.peerUid != null) {
      return StreamBuilder<PresenceStatus>(
        stream: PresenceService.instance
            .subscribeToUserPresence(effective.peerUid!),
        builder: (context, snapshot) {
          final isOnline = snapshot.data?.online ?? false;
          return FutureBuilder<ChatUser?>(
            future: UserRepository.instance.getUser(effective.peerUid!),
            builder: (context, userSnapshot) {
              final peerUser = userSnapshot.data;
              final avatarUrl = peerUser?.avatarUrl;
              return _avatarShell(
                isOnline: isOnline,
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFECECEC),
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? Text(
                          _getInitials(peerUser?.name ?? effective.title ?? '?'),
                          style: const TextStyle(
                            color: Color(0xFF2E2E2E),
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
              );
            },
          );
        },
      );
    }

    return _avatarShell(
      isOnline: true,
      child: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Image.asset(
            'assets/logo/rcc2.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _avatarShell({required Widget child, required bool isOnline}) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(1.3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE9B23A), width: 1.2),
          ),
          child: child,
        ),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: const Color(0xFF2DD65B),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLastMessage(LastMessage? lastMessage) {
    if (lastMessage == null) {
      return const Text(
        'No messages',
        maxLines: null,
        overflow: TextOverflow.visible,
      );
    }

    String text;

    switch (lastMessage.type) {
      case 'image':
        text = '📷 Photo';
        break;
      case 'file':
        text = '📎 File';
        break;
      case 'audio':
        text = '🎵 Voice message';
        break;
      case 'video':
        text = '🎬 Video';
        break;
      default:
        text = lastMessage.text;
    }

    return Text(
      text,
      maxLines: null,
      overflow: TextOverflow.visible,
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  void _showChatActions(BuildContext context) {
    HapticFeedback.mediumImpact();

    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset position = box.localToGlobal(Offset.zero);
    final Size size = box.size;

    final RelativeRect menuPosition = RelativeRect.fromLTRB(
      position.dx + size.width / 2 - 100,
      position.dy + size.height,
      position.dx + size.width / 2 + 100,
      position.dy,
    );

    showMenu<String>(
      context: context,
      position: menuPosition,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      items: [
        PopupMenuItem<String>(
          value: 'pin',
          height: 48,
          child: Row(
            children: [
              Icon(
                userChat.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: const Color(0xFF8E8E93),
                size: 22,
              ),
              const SizedBox(width: 14),
              Text(
                userChat.pinned ? 'Unpin' : 'Pin',
                style: const TextStyle(
                  color: Color(0xFF2C2C2E),
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'mute',
          height: 48,
          child: Row(
            children: [
              Icon(
                userChat.muted ? Icons.volume_up : Icons.volume_off,
                color: const Color(0xFF8E8E93),
                size: 22,
              ),
              const SizedBox(width: 14),
              Text(
                userChat.muted ? 'Unmute' : 'Mute',
                style: const TextStyle(
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
      if (value == null) return;
      switch (value) {
        case 'pin':
          ChatRepository.instance.togglePin(
            userChat.chatId,
            !userChat.pinned,
          );
          break;
        case 'mute':
          ChatRepository.instance.toggleMute(
            userChat.chatId,
            !userChat.muted,
          );
          break;
      }
    });
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes == 1) return '1 min ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours == 1) return '1 hour ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';

    return '${local.day}/${local.month}/${local.year}';
  }
}

class _ChatSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onClear;

  const _ChatSearchBar({
    required this.controller,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.isNotEmpty;
        return TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Search by name, email, or file number',
            hintStyle: const TextStyle(
              color: Color(0xFF9A9A9A),
              fontWeight: FontWeight.w500,
            ),
            prefixIcon:
                const Icon(Icons.search_rounded, color: Color(0xFF8E8E8E)),
            suffixIcon: hasText
                ? IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      controller.clear();
                      onClear();
                    },
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFF8E8E8E), size: 20),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.fromLTRB(0, 13, 12, 13),
          ),
          style: const TextStyle(
            color: Color(0xFF1F1F1F),
            fontWeight: FontWeight.w500,
          ),
          textInputAction: TextInputAction.search,
        );
      },
    );
  }
}

/// Inline user tile for global search results shown in chat list
class _InlineUserTile extends StatelessWidget {
  final ChatUser user;
  final VoidCallback onTap;

  const _InlineUserTile({
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primaryBlackLight,
            backgroundImage:
                user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
            child: user.avatarUrl == null
                ? Text(
                    _getInitials(user.name),
                    style: const TextStyle(
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          StreamBuilder<PresenceStatus>(
            stream: PresenceService.instance.subscribeToUserPresence(user.uid),
            builder: (context, snapshot) {
              final isOnline = snapshot.data?.online ?? false;
              if (!isOnline) return const SizedBox.shrink();
              return Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      title: Text(
        limitChatDisplayName(user.name),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: user.email != null
          ? Text(
              user.email!,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            )
          : null,
      trailing: const Icon(Icons.message_rounded,
          color: AppColors.primaryColor, size: 22),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class _SecondaryChatBar extends StatelessWidget {
  final VoidCallback onMessagesTap;

  const _SecondaryChatBar({required this.onMessagesTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 62,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/newapp/newicon/chat-round-line_svgrepo.com.png',
                width: 23,
                height: 23,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                'Chats',
                style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onMessagesTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFFFFFF),
                side: const BorderSide(color: Color(0xFFF4C542), width: 1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                minimumSize: const Size(0, 24),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.star, size: 16, color: Color(0xFFF4C542)),
              label: const Text(
                'Massages',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupQuickItem extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _GroupQuickItem({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: SizedBox(
          width: 88,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(1.3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: const Color(0xFFE9B23A), width: 1.2),
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Image.asset(
                      'assets/logo/rcc2.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Flexible(
                child: Text(
                  limitChatDisplayName(label),
                  maxLines: 2,
                  softWrap: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
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

/// Tab button for Groups / Support toggle
class _TopTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TopTab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white.withOpacity(0.45),
            fontSize: isActive ? 20 : 17,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Bubble item for support departments
class _SupportGroupQuickItem extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _SupportGroupQuickItem({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: SizedBox(
          width: 88,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(1.3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: const Color(0xFFE9B23A), width: 1.2),
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Image.asset(
                      'assets/logo/rcc2.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Flexible(
                child: Text(
                  limitChatDisplayName(label),
                  maxLines: 2,
                  softWrap: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
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
