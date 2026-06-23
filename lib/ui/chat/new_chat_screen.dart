import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../chat/models/chat.dart';
import '../../chat/models/chat_user.dart';
import '../../chat/repositories/chat_repository.dart';
import '../../chat/repositories/user_repository.dart';
import '../../chat/services/presence_service.dart';
import '../../resources/app_colors.dart';
import 'chat_display_utils.dart';
import 'chat_screen.dart';

/// Screen for searching users and starting a new DM chat
class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<ChatUser> _searchResults = [];
  List<Chat> _availableGroups = []; // Role groups available for support chat
  List<Chat> _filteredGroups = []; // Filtered by search query
  bool _isSearching = false;
  String _errorMessage = '';
  Timer? _debounce;

  String? _currentUid;
  ChatUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid;
    _loadCurrentUser();
    _searchController.addListener(_onSearchChanged);

    // Auto-focus search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  Future<void> _loadCurrentUser() async {
    if (_currentUid != null) {
      _currentUser = await UserRepository.instance.getUser(_currentUid!);
    }
    // Load available groups for support chat
    _loadAvailableGroups();
  }

  Future<void> _loadAvailableGroups() async {
    try {
      final groups = await ChatRepository.instance.getAvailableSupportGroups();
      if (mounted) {
        setState(() {
          _availableGroups = groups;
          _filteredGroups = groups;
        });
      }
    } catch (e) {
      print('⚠️ NewChatScreen: Error loading available groups: $e');
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch();
    });
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _filteredGroups = _availableGroups;
        _errorMessage = '';
      });
      return;
    }

    if (query.length < 2 && !RegExp(r'^\d+$').hasMatch(query)) {
      setState(() {
        _searchResults = [];
        _filteredGroups = _availableGroups
            .where((g) => (g.title ?? '').toLowerCase().contains(query))
            .toList();
        _errorMessage = 'Enter at least 2 characters to search';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = '';
    });

    try {
      final result = await UserRepository.instance
          .searchUsers(query: query)
          .timeout(const Duration(seconds: 15));

      // Filter out current user
      final filteredResults =
          result.users.where((u) => u.uid != _currentUid).toList();

      // Filter groups by search query
      final matchingGroups = _availableGroups
          .where((g) => (g.title ?? '').toLowerCase().contains(query))
          .toList();

      if (!mounted) return;
      setState(() {
        _searchResults = filteredResults;
        _filteredGroups = matchingGroups;
        _isSearching = false;
        if (filteredResults.isEmpty && matchingGroups.isEmpty) {
          _errorMessage = 'No results found';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _errorMessage = 'Search error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Chat'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search by name, email, or file number...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _errorMessage = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchController.text.isEmpty) {
      // Show available groups when not searching
      if (_availableGroups.isNotEmpty) {
        return _buildGroupsAndEmptyState();
      }
      return _buildEmptyState();
    }

    if (_errorMessage.isNotEmpty &&
        _searchResults.isEmpty &&
        _filteredGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Groups section
        if (_filteredGroups.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Departments',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.grey[600],
              ),
            ),
          ),
          ..._filteredGroups.map((group) => _GroupSupportTile(
                group: group,
                onTap: () => _startSupportChat(group),
              )),
          if (_searchResults.isNotEmpty)
            const Divider(height: 16, indent: 16, endIndent: 16),
        ],
        // Users section
        if (_searchResults.isNotEmpty) ...[
          if (_filteredGroups.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                'Users',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ..._searchResults.map((user) => _UserListTile(
                user: user,
                onTap: () => _startChat(user),
              )),
        ],
      ],
    );
  }

  Widget _buildGroupsAndEmptyState() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            'Contact Department',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey[600],
            ),
          ),
        ),
        ..._availableGroups.map((group) => _GroupSupportTile(
              group: group,
              onTap: () => _startSupportChat(group),
            )),
        const SizedBox(height: 24),
        Center(
          child: Column(
            children: [
              Icon(Icons.person_search, size: 60, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Or search for a user',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(
            'Search for a user',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You can search by name, email, or file number',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

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

      // Pop loading dialog
      if (mounted) Navigator.of(context).pop();

      // Navigate to chat screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              title: group.title ?? 'Group ${group.roleId}',
              chatType: ChatType.support,
            ),
          ),
        );
      }
    } catch (e) {
      // Pop loading dialog
      if (mounted) Navigator.of(context).pop();

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

  Future<void> _startChat(ChatUser user) async {
    if (_currentUid == null) {
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
      final existing =
          await ChatRepository.instance.findExistingDmForUser(user);
      final resolvedUser = existing == null
          ? await UserRepository.instance.resolveCanonicalChatUser(user)
          : await UserRepository.instance.getUser(existing.peerUid) ?? user;

      final chatId = existing?.chatId ??
          await ChatRepository.instance.createOrGetDmChat(
            otherUid: resolvedUser.uid,
            otherName: resolvedUser.name,
            currentUserName: _currentUser?.name ?? 'User',
            otherRoleId: resolvedUser.roleId,
            otherBranchId: resolvedUser.branchId,
            otherCompanyId: resolvedUser.companyId,
            currentUserRoleId: _currentUser?.roleId,
            currentUserBranchId: _currentUser?.branchId,
            currentUserCompanyId: _currentUser?.companyId,
          );

      // Pop loading dialog
      if (mounted) Navigator.of(context).pop();

      // Navigate to chat screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
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
    } catch (e) {
      // Pop loading dialog
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _UserListTile extends StatelessWidget {
  final ChatUser user;
  final VoidCallback onTap;

  const _UserListTile({
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
          // Online indicator
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
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user.email != null)
            Text(
              user.email!,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          Row(
            children: [
              Icon(Icons.work_outline, size: 12, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                'Role: ${user.roleId}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              if (user.branchId != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.location_on_outlined,
                    size: 12, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  'Branch: ${user.branchId}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ],
          ),
        ],
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.message, color: AppColors.primaryColor),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

/// Tile for department groups available for support chat
class _GroupSupportTile extends StatelessWidget {
  final Chat group;
  final VoidCallback onTap;

  const _GroupSupportTile({
    required this.group,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(1.3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE9B23A), width: 1.2),
        ),
        child: CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primaryColor.withOpacity(0.1),
          child: const Icon(
            Icons.support_agent_rounded,
            color: AppColors.primaryColor,
            size: 26,
          ),
        ),
      ),
      title: Text(
        limitChatDisplayName(group.title ?? 'Group ${group.roleId}'),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'Contact department',
        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        color: AppColors.primaryColor,
        size: 18,
      ),
    );
  }
}
