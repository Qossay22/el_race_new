import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../chat/chat.dart';
import '../../chat/services/chat_notification_service.dart';
import '../../resources/app_colors.dart';
import '../../core/utils/shared_pref.dart';
import '../widgets/header_widget.dart';
import 'chat_user_profile_screen.dart';
import 'chat_group_profile_screen.dart';
import 'screens/sign_zone_picker_screen.dart';
import 'chat_display_utils.dart';
import 'widgets/message_bubble.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/typing_indicator.dart';

/// Chat screen for viewing and sending messages
class ChatScreen extends StatefulWidget {
  final String chatId;
  final String title;
  final ChatType chatType;
  final String? peerUid;
  final String? supportUserUid; // For support chats: the external user's UID
  final String?
      supportGroupTitle; // For support chats: the group title (e.g. "HR")
  final String? initialMessageId;
  final DateTime? initialMessageCreatedAt;
  final String? initialMessageSenderId;
  final String? initialMessageType;
  final String? initialMessageText;
  final String? initialMessageFileName;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.title,
    required this.chatType,
    this.peerUid,
    this.supportUserUid,
    this.supportGroupTitle,
    this.initialMessageId,
    this.initialMessageCreatedAt,
    this.initialMessageSenderId,
    this.initialMessageType,
    this.initialMessageText,
    this.initialMessageFileName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  String? _currentUid;
  bool _isRecording = false;
  Timer? _typingTimer;

  /// Peer user info (cached for avatar)
  ChatUser? _peerUser;

  /// Resolved header title (from chat doc / peer profile).
  late String _headerTitle;

  /// Messages stream — recreatable if the chat doc is created after first open
  late Stream<List<Message>> _messagesStream;

  /// Whether the stream has had an error (needs reconnect after first send)
  bool _streamErrored = false;

  /// Support chat state
  bool get _isSupportChat => widget.chatType == ChatType.support;
  bool get _isExternalUser =>
      _isSupportChat && widget.supportUserUid == _currentUid;

  /// Cache of member names for support chat (uid -> name)
  final Map<String, String> _memberNames = {};

  /// Starred message IDs (live from Firestore)
  Set<String> _starredIds = {};
  StreamSubscription? _starredSub;

  /// Reply state (WhatsApp-style)
  Message? _replyingTo;

  /// Optimistic (pending) messages — shown with clock icon until Firestore confirms
  final List<Message> _pendingMessages = [];

  /// Jump/highlight target when opened from starred messages.
  String? _targetMessageId;
  String? _highlightedMessageId;
  final Map<String, GlobalKey> _messageKeys = {};
  int _jumpRetryCount = 0;
  static const int _maxJumpRetries = 24;
  bool _isJumpInProgress = false;
  bool _isResolvingTargetMessage = false;
  Message? _resolvedTargetMessage;
  List<Message> _latestFirestoreMessages = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentUid = FirebaseAuth.instance.currentUser?.uid;
    _messagesStream = ChatRepository.instance.subscribeToMessages(
      widget.chatId,
      pageSize: widget.initialMessageId != null
          ? 1000
          : ChatRepository.defaultPageSize,
    );
    _targetMessageId = widget.initialMessageId;
    _headerTitle = limitChatDisplayName(widget.title);
    _markAsRead();
    _loadPeerUser();
    _resolveHeaderTitle();
    _messageController.addListener(_onTextChanged);

    // Set this chat as active to suppress notifications
    ChatNotificationService.instance.setActiveChatId(widget.chatId);
    // Cancel any pending notifications for this chat
    ChatNotificationService.instance.cancelNotificationsForChat(widget.chatId);

    // Defer non-critical loads so messages render first
    Future.microtask(() {
      if (!mounted) return;

      // Load member names for support chats (group members see real names)
      if (_isSupportChat && !_isExternalUser) {
        _loadSupportChatMemberNames();
      }

      // Subscribe to starred message IDs
      _starredSub =
          ChatRepository.instance.subscribeToStarredMessageIds().listen((ids) {
        if (mounted) setState(() => _starredIds = ids);
      });
    });
  }

  Future<void> _resolveHeaderTitle() async {
    try {
      if (widget.chatType == ChatType.dm && widget.peerUid != null) {
        final peer = await UserRepository.instance.getUser(widget.peerUid!);
        if (peer?.name.trim().isNotEmpty == true) {
          if (mounted) {
            setState(() => _headerTitle = limitChatDisplayName(peer!.name));
          }
          return;
        }
      }

      final chatDoc = await ChatRepository.instance.getChat(widget.chatId);
      final indexChat = UserChat(
        chatId: widget.chatId,
        type: widget.chatType,
        title: widget.title,
        peerUid: widget.peerUid,
        supportGroupTitle: widget.supportGroupTitle,
        roleId: chatDoc?.roleId,
        updatedAt: DateTime.now(),
      );
      final resolved = ChatRepository.instance.resolveUserChatDisplayTitle(
        indexChat,
        chatDoc: chatDoc,
      );
      if (mounted && resolved.trim().isNotEmpty) {
        setState(() => _headerTitle = limitChatDisplayName(resolved));
      }
    } catch (e) {
      print('⚠️ ChatScreen: Error resolving header title: $e');
    }
  }

  /// Pre-load peer user for fast avatar rendering
  Future<void> _loadPeerUser() async {
    if (widget.peerUid == null) return;
    final user = await UserRepository.instance.getUser(widget.peerUid!);
    if (mounted && user != null) {
      setState(() => _peerUser = user);
    }
  }

  /// Load member names for support chat so group members see who sent what
  Future<void> _loadSupportChatMemberNames() async {
    try {
      final members =
          await ChatRepository.instance.getChatMembers(widget.chatId);
      final uids = members.map((m) => m.uid).toList();
      final users = await UserRepository.instance.getUsersByIds(uids);
      if (mounted) {
        setState(() {
          for (final user in users) {
            _memberNames[user.uid] = user.name;
          }
        });
      }
    } catch (e) {
      print('⚠️ ChatScreen: Error loading support chat member names: $e');
    }
  }

  /// Get display name for a sender in support chat
  String _getSupportSenderName(String senderId) {
    if (_isExternalUser) {
      // External user: all non-self messages show group name
      if (senderId == _currentUid) return 'You';
      return limitChatDisplayName(
        widget.supportGroupTitle ?? widget.title,
      );
    } else {
      // Group member: show real names
      if (senderId == _currentUid) return 'You';
      if (senderId == widget.supportUserUid) {
        return limitChatDisplayName(widget.title);
      }
      return limitChatDisplayName(
        _memberNames[senderId] ?? 'Team member',
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _starredSub?.cancel();
    PresenceService.instance.setTyping(widget.chatId, false);

    // Clear active chat when leaving
    ChatNotificationService.instance.setActiveChatId(null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _markAsRead();
    }
  }

  void _markAsRead() {
    ChatRepository.instance.markChatRead(widget.chatId);
  }

  void _onTextChanged() {
    if (_messageController.text.isNotEmpty) {
      PresenceService.instance.setTyping(widget.chatId, true);

      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () {
        PresenceService.instance.setTyping(widget.chatId, false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryColor,
      appBar: const HeaderWidget(),
      body: SafeArea(
        top: false,
        bottom: false,
        child: ChatIdProvider(
          chatId: widget.chatId,
          child: Column(
            children: [
              _buildGlassTopHeader(),
              Expanded(
                child: Container(
                  color: const Color(0xFFF2F2F2),
                  child: Stack(
                    children: [
                      Positioned.fill(child: _buildChatBackgroundPattern()),
                      _buildMessageList(),
                    ],
                  ),
                ),
              ),
              _buildTypingIndicator(),
              _buildReplyBar(),
              Container(
                color: Colors.white,
                padding: EdgeInsets.only(
                  bottom: (MediaQuery.of(context).padding.bottom / 2).clamp(0.0, 6.0),
                ),
                child: ChatInputBar(
                  controller: _messageController,
                  isLoading: false,
                  isRecording: _isRecording,
                  onSendText: _sendTextMessage,
                  onPickImage: _pickImage,
                  onPickGallery: _pickImagesFromGallery,
                  onPickFile: _pickFile,
                  onPickSignableDoc: _pickSignableDocument,
                  onStartRecording: _startRecording,
                  onStopRecording: _stopRecording,
                  onCancelRecording: _cancelRecording,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassTopHeader() {
    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            color: AppColors.primaryColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap:
                      (widget.chatType == ChatType.dm && widget.peerUid != null)
                          ? _openPeerProfile
                          : _openGroupProfile,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      _buildAvatar(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              limitChatDisplayName(_headerTitle),
                              style: const TextStyle(
                                fontSize: 17,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: null,
                              overflow: TextOverflow.visible,
                            ),
                            if (widget.chatType == ChatType.dm &&
                                widget.peerUid != null)
                              _buildPresenceStatus(),
                            if (_isSupportChat)
                              Text(
                                _isExternalUser
                                    ? 'Department Support'
                                    : 'Support Chat • ${limitChatDisplayName(widget.supportGroupTitle ?? "")}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_showsCallButton) _buildCallButton(),
              if (_showsGroupHeaderIcon) _buildGroupHeaderIcon(),
            ],
          ),
        ),
      ],
    );
  }

  bool get _isDirectChat =>
      widget.chatType == ChatType.dm && widget.peerUid != null;

  bool get _isGroupStyleChat =>
      widget.chatType == ChatType.group ||
      widget.chatType == ChatType.role ||
      widget.chatType == ChatType.support;

  bool get _showsCallButton => _isDirectChat;

  bool get _showsGroupHeaderIcon => _isGroupStyleChat;

  String? get _callTargetUid =>
      _isDirectChat ? widget.peerUid : null;

  Widget _buildCallButton() {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _onCallPressed,
          customBorder: const CircleBorder(),
          child: Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: SvgPicture.asset(
              'assets/svg/call-icon.svg',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupHeaderIcon() {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openGroupProfile,
          customBorder: const CircleBorder(),
          child: SvgPicture.asset(
            'assets/svg/group-icon.svg',
            width: 20,
            height: 20,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Future<void> _onCallPressed() async {
    final calleeUid = _callTargetUid;
    if (calleeUid == null) return;

    try {
      var user = await UserRepository.instance.getUser(calleeUid);
      if (user != null) {
        await UserRepository.instance
            .hydrateUserProfileFromEmployeeDirectory(user);
        user = await UserRepository.instance.getUser(calleeUid);
      }

      final phone = user?.phoneNumber?.trim();
      if (phone == null || phone.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone number not available')),
        );
        return;
      }

      final dialNumber = phone.replaceAll(RegExp(r'[^\d+#*]'), '');
      if (dialNumber.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid phone number')),
        );
        return;
      }

      final telUri = Uri(scheme: 'tel', path: dialNumber);
      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start phone call')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start phone call: $e')),
      );
    }
  }

  Widget _buildAvatar() {
    if (widget.chatType == ChatType.dm) {
      return StreamBuilder<PresenceStatus>(
        stream: widget.peerUid != null
            ? PresenceService.instance.subscribeToUserPresence(widget.peerUid!)
            : null,
        builder: (context, snapshot) {
          final isOnline = snapshot.data?.online ?? false;
          // Use FutureBuilder to always get the latest avatar from Firestore,
          // matching the chat list behavior exactly
          return FutureBuilder<ChatUser?>(
            future: widget.peerUid != null
                ? UserRepository.instance.getUser(widget.peerUid!)
                : null,
            builder: (context, userSnapshot) {
              final avatarUrl =
                  userSnapshot.data?.avatarUrl ?? _peerUser?.avatarUrl;
              return Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(1.3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFFE9B23A), width: 1.2),
                    ),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFFECECEC),
                      backgroundImage:
                          avatarUrl != null && avatarUrl.isNotEmpty
                              ? NetworkImage(avatarUrl)
                              : null,
                      child: avatarUrl == null || avatarUrl.isEmpty
                          ? Text(
                              _getInitials(
                                  userSnapshot.data?.name ?? widget.title),
                              style: const TextStyle(
                                color: Color(0xFF2E2E2E),
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
            },
          );
        },
      );
    }
    // Group / Role / Support chats — show the RCC logo (same as chat list)
    return Container(
      padding: const EdgeInsets.all(1.3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE9B23A), width: 1.2),
      ),
      child: CircleAvatar(
        radius: 22,
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

  Widget _buildPresenceStatus() {
    return StreamBuilder<PresenceStatus>(
      stream: PresenceService.instance.subscribeToUserPresence(widget.peerUid!),
      builder: (context, snapshot) {
        final status = snapshot.data;
        if (status == null) return const SizedBox.shrink();

        return Text(
          status.online ? 'Active now' : status.lastSeenText,
          style: TextStyle(
            fontSize: 12,
            color: status.online ? const Color(0xFF6BE483) : Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        );
      },
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<List<Message>>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('📨 StreamBuilder: ERROR — ${snapshot.error}');
          _streamErrored = true;
        }

        final bool isWaiting =
            snapshot.connectionState == ConnectionState.waiting;
        final bool hasPending = _pendingMessages.isNotEmpty;

        // Log every rebuild so we can trace
        debugPrint(
            '📨 StreamBuilder rebuild: state=${snapshot.connectionState}, '
            'firestoreCount=${snapshot.data?.length ?? 0}, '
            'pendingCount=${_pendingMessages.length}, '
            'hasError=${snapshot.hasError}');

        // Show loading ONLY if no Firestore data yet AND no pending messages
        if (isWaiting && !hasPending) {
          return const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF1D2449),
              ),
            ),
          );
        }

        // Merge Firestore messages with optimistic pending messages.
        final firestoreMessages = snapshot.data ?? [];
        _latestFirestoreMessages = firestoreMessages;
        _deduplicatePendingMessages(firestoreMessages);
        final bool hasResolvedTarget = _resolvedTargetMessage != null &&
            !_pendingMessages.any((m) => m.id == _resolvedTargetMessage!.id) &&
            !firestoreMessages.any((m) => m.id == _resolvedTargetMessage!.id);

        final messages = [
          if (hasResolvedTarget) _resolvedTargetMessage!,
          ..._pendingMessages,
          ...firestoreMessages,
        ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        debugPrint('📨 StreamBuilder: merged total=${messages.length} '
            '(${_pendingMessages.length} pending + ${firestoreMessages.length} firestore)');

        // Only show empty state AFTER we got real data (not while loading)
        if (messages.isEmpty && !isWaiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 60, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No messages yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start the conversation!',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ],
            ),
          );
        }

        if (messages.isEmpty) {
          return const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF1D2449),
              ),
            ),
          );
        }

        final children = List.generate(messages.length, (index) {
          final message = messages[index];
          final isMe = message.senderId == _currentUid;
          final key = _messageKeys.putIfAbsent(message.id, () => GlobalKey());

          // Check if we should show date header
          final showDateHeader = _shouldShowDateHeader(messages, index);

          // For support chats, determine sender display name
          String? senderDisplayName;
          if (_isSupportChat && !isMe) {
            senderDisplayName = _getSupportSenderName(message.senderId);
          }

          return Column(
            key: key,
            children: [
              if (showDateHeader) _buildDateHeader(message.createdAt),
              MessageBubble(
                message: message,
                isMe: isMe,
                isStarred: _starredIds.contains(message.id),
                isHighlighted: _highlightedMessageId == message.id,
                senderName: senderDisplayName,
                showSenderName: _isSupportChat && !isMe,
                onStar: _onStarMessage,
                onReply: _onReplyMessage,
                onForward: _onForwardMessage,
              ),
            ],
          );
        });

        _attemptInitialJumpAndHighlight(messages);

        return ListView(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          children: children,
        );
      },
    );
  }

  void _attemptInitialJumpAndHighlight(List<Message> messages) {
    final target = _targetMessageId;
    if (target == null ||
        _isJumpInProgress ||
        _jumpRetryCount >= _maxJumpRetries) {
      return;
    }

    print('🔎 STAR_JUMP[chat]: attempt initial jump '
        'chatId=${widget.chatId} target=$target '
        'messages=${messages.length} keys=${_messageKeys.length} '
        'resolved=${_resolvedTargetMessage?.id} retry=$_jumpRetryCount');

    final found = messages.any((m) => m.id == target);
    if (!found) {
      print('🔎 STAR_JUMP[chat]: target not in rendered list, resolving... '
          'target=$target chatId=${widget.chatId}');
      _resolveMissingTargetMessage(target);
      return;
    }

    _isJumpInProgress = true;
    _jumpRetryCount = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _jumpToTargetWithRetry(target);
    });
  }

  Future<void> _resolveMissingTargetMessage(String target) async {
    if (_isResolvingTargetMessage || !mounted || _targetMessageId != target) {
      return;
    }

    print('🔎 STAR_JUMP[chat]: resolve missing target start '
        'chatId=${widget.chatId} target=$target '
        'createdAt=${widget.initialMessageCreatedAt} '
        'sender=${widget.initialMessageSenderId} '
        'type=${widget.initialMessageType} '
        'file=${widget.initialMessageFileName} '
        'textLen=${widget.initialMessageText?.length ?? 0}');

    _isResolvingTargetMessage = true;
    try {
      final message =
          await ChatRepository.instance.findMessageForStarredNavigation(
        widget.chatId,
        messageId: target,
        createdAt: widget.initialMessageCreatedAt,
        senderId: widget.initialMessageSenderId,
        type: widget.initialMessageType,
        text: widget.initialMessageText,
        fileName: widget.initialMessageFileName,
      );
      if (!mounted || _targetMessageId != target) return;

      if (message == null) {
        print('❌ STAR_JUMP[chat]: resolve failed, no target found '
            'chatId=${widget.chatId} target=$target');
        setState(() {
          _targetMessageId = null;
          _resolvedTargetMessage = null;
        });
        return;
      }

      print('✅ STAR_JUMP[chat]: resolve success '
          'chatId=${widget.chatId} target=$target resolvedId=${message.id} '
          'resolvedType=${message.type.toJson()} resolvedAt=${message.createdAt}');

      setState(() {
        _resolvedTargetMessage = message;
        _targetMessageId = message.id;
      });
    } finally {
      _isResolvingTargetMessage = false;
    }
  }

  Future<void> _jumpToTargetWithRetry(String target) async {
    if (!mounted) return;

    final key = _messageKeys[target];
    final ctx = key?.currentContext;
    if (ctx == null) {
      print('⚠️ STAR_JUMP[chat]: target widget context missing '
          'chatId=${widget.chatId} target=$target retry=$_jumpRetryCount');
      await _scheduleJumpRetry(target);
      return;
    }

    print('🔎 STAR_JUMP[chat]: ensureVisible '
        'chatId=${widget.chatId} target=$target retry=$_jumpRetryCount');

    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 320),
      alignment: 0.5,
      curve: Curves.easeOutCubic,
    );

    print('✅ STAR_JUMP[chat]: jump completed '
        'chatId=${widget.chatId} target=$target');

    setState(() {
      _highlightedMessageId = target;
      _targetMessageId = null;
      _isJumpInProgress = false;
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (_highlightedMessageId == target) {
        setState(() => _highlightedMessageId = null);
      }
    });
  }

  Future<void> _scheduleJumpRetry(String target) async {
    _jumpRetryCount += 1;
    if (_jumpRetryCount >= _maxJumpRetries) {
      print('❌ STAR_JUMP[chat]: retries exhausted '
          'chatId=${widget.chatId} target=$target max=$_maxJumpRetries');
      if (mounted) {
        setState(() {
          _isJumpInProgress = false;
          _targetMessageId = null;
          _resolvedTargetMessage = null;
        });
      }
      return;
    }

    // If the target widget is off-screen it may not be built yet.
    // Progressively scroll toward older messages (reverse list => larger pixels)
    // so Flutter builds more children, then retry ensureVisible.
    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      final current = position.pixels;
      final max = position.maxScrollExtent;
      final step = (position.viewportDimension * 0.9).clamp(280.0, 1200.0);
      final next = (current + step).clamp(0.0, max);

      if (next > current) {
        print('🔎 STAR_JUMP[chat]: prebuild scroll '
            'chatId=${widget.chatId} target=$target '
            'from=${current.toStringAsFixed(1)} to=${next.toStringAsFixed(1)} '
            'max=${max.toStringAsFixed(1)}');
        await _scrollController.animateTo(
          next,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
        );
      }
    }

    print('⚠️ STAR_JUMP[chat]: scheduling retry '
        'chatId=${widget.chatId} target=$target retry=$_jumpRetryCount/$_maxJumpRetries');

    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToTargetWithRetry(target);
    });
  }

  Widget _buildChatBackgroundPattern() {
    final token = _watermarkToken();
    return IgnorePointer(
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2.4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: 30,
        itemBuilder: (context, index) {
          return Opacity(
            opacity: index.isEven ? 0.07 : 0.04,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                token,
                maxLines: null,
                overflow: TextOverflow.visible,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFBFC3C9),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _watermarkToken() {
    final loginData = SharedPref.getLoginDataOrNull();
    final empId = loginData?.result?.data?.emp_id;
    if (empId != null && empId.isNotEmpty) return empId;
    // fallback
    final raw = (_currentUid ?? widget.peerUid ?? widget.chatId).trim();
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isNotEmpty) {
      return digits.length > 4 ? digits.substring(digits.length - 4) : digits;
    }
    if (raw.length <= 4) return raw.toUpperCase();
    return raw.substring(raw.length - 4).toUpperCase();
  }

  bool _shouldShowDateHeader(List<Message> messages, int index) {
    if (index == messages.length - 1) return true;

    final current = messages[index].createdAt.toLocal();
    final previous = messages[index + 1].createdAt.toLocal();

    return current.day != previous.day ||
        current.month != previous.month ||
        current.year != previous.year;
  }

  Widget _buildDateHeader(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    String text;

    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      text = 'Today';
    } else if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day - 1) {
      text = 'Yesterday';
    } else {
      text = '${local.day}/${local.month}/${local.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return StreamBuilder<TypingInfo>(
      stream:
          PresenceService.instance.subscribeToTypingWithNames(widget.chatId),
      builder: (context, snapshot) {
        // Silently handle errors - typing is not critical
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final typingInfo = snapshot.data;

        if (typingInfo == null || !typingInfo.isTyping) {
          return const SizedBox.shrink();
        }

        return TypingIndicatorWidget(
          typingUserNames: typingInfo.typingNames,
          isGroupChat: widget.chatType != ChatType.dm,
        );
      },
    );
  }

  /// WhatsApp-style reply preview bar above input
  Widget _buildReplyBar() {
    if (_replyingTo == null) return const SizedBox.shrink();

    final message = _replyingTo!;
    final preview = message.getPreviewText();
    final isMyMessage = message.senderId == _currentUid;

    // Determine display name for the reply header
    String replyToName;
    if (isMyMessage) {
      replyToName = 'You';
    } else if (_isSupportChat) {
      replyToName = _getSupportSenderName(message.senderId);
    } else {
      replyToName = limitChatDisplayName(widget.title);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: const Color(0xFFDCE6E5).withValues(alpha: 0.7),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: isMyMessage
                  ? const Color(0xFF1D2449)
                  : const Color(0xFF2DD65B),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  replyToName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isMyMessage
                        ? const Color(0xFF1D2449)
                        : const Color(0xFF2DD65B),
                  ),
                  maxLines: null,
                  overflow: TextOverflow.visible,
                ),
                const SizedBox(height: 2),
                Text(
                  preview,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8E8E93),
                  ),
                  maxLines: null,
                  overflow: TextOverflow.visible,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _replyingTo = null),
            icon: const Icon(Icons.close, size: 20, color: Color(0xFF8E8E93)),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  /// Remove pending messages that already appeared in Firestore (dedup).
  /// Called from the StreamBuilder builder so duplicates are never shown.
  void _deduplicatePendingMessages(List<Message> firestoreMessages) {
    if (_pendingMessages.isEmpty || firestoreMessages.isEmpty) return;
    _pendingMessages.removeWhere((pending) {
      return firestoreMessages.any((fm) {
        if (fm.senderId != pending.senderId || fm.type != pending.type)
          return false;
        // For signable docs, match on fileName since text is null
        if (pending.type == MessageType.signableDoc) {
          return fm.fileName == pending.fileName;
        }
        return fm.text == pending.text;
      });
    });
  }

  /// Reconnect the messages stream if it previously errored
  /// (e.g. chat doc didn't exist yet, now created by _ensureDmChatExists).
  void _reconnectStreamIfNeeded() {
    if (_streamErrored && mounted) {
      _streamErrored = false;
      setState(() {
        _messagesStream =
            ChatRepository.instance.subscribeToMessages(widget.chatId);
      });
    }
  }

  Future<void> _sendTextMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Capture reply state before clearing
    final replyTo = _replyingTo != null
        ? ReplyTo(
            messageId: _replyingTo!.id,
            senderId: _replyingTo!.senderId,
            text: _replyingTo!.getPreviewText(),
            type: _replyingTo!.type.toJson(),
          )
        : null;

    _messageController.clear();
    setState(() => _replyingTo = null);
    PresenceService.instance.setTyping(widget.chatId, false);

    // Create optimistic message with 'sending' status (shows clock icon)
    final optimistic = Message(
      id: 'pending_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _currentUid ?? '',
      type: MessageType.text,
      text: text,
      createdAt: DateTime.now(),
      clientMsgId: '',
      replyTo: replyTo,
      status: MessageStatus.sending,
    );

    setState(() {
      _pendingMessages.insert(0, optimistic);
    });
    _scrollToBottom();

    try {
      await ChatRepository.instance
          .sendText(widget.chatId, text, replyTo: replyTo);
      // Don't remove optimistic here — the StreamBuilder merge
      // will auto-deduplicate once the Firestore snapshot arrives.
      _reconnectStreamIfNeeded();
    } catch (e) {
      // Mark as failed so user sees error icon
      if (mounted) {
        setState(() {
          final idx = _pendingMessages.indexWhere((m) => m.id == optimistic.id);
          if (idx >= 0) {
            _pendingMessages[idx] =
                optimistic.copyWith(status: MessageStatus.failed);
          }
        });
      }
      _showError('Failed to send message');
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );

      if (image == null) return;

      // Optimistic UI - scroll immediately
      _scrollToBottom();

      await ChatRepository.instance.sendImage(
        widget.chatId,
        File(image.path),
      );
      _reconnectStreamIfNeeded();
    } catch (e) {
      _showError('Failed to send image');
    }
  }

  Future<void> _pickImagesFromGallery() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        imageQuality: 70,
      );

      if (images.isEmpty) return;

      _scrollToBottom();

      for (final image in images) {
        await ChatRepository.instance.sendImage(
          widget.chatId,
          File(image.path),
        );
      }
      _reconnectStreamIfNeeded();
    } catch (e) {
      _showError('Failed to send image');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles();
      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.single.path!);

      // Optimistic UI - scroll immediately
      _scrollToBottom();

      await ChatRepository.instance.sendFile(
        widget.chatId,
        file,
        mimeType: result.files.single.extension,
      );
      _reconnectStreamIfNeeded();
    } catch (e) {
      _showError('Failed to send file');
    }
  }

  Future<void> _pickSignableDocument() async {
    try {
      // Pick PDF file only
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;

      // Navigate to sign zone picker
      if (!mounted) return;
      final pickerResult = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => SignZonePickerScreen(
            pdfFile: file,
            fileName: fileName,
          ),
        ),
      );

      if (pickerResult == null) {
        debugPrint('📝 SignableDoc: User cancelled sign zone picker');
        return;
      }

      debugPrint(
          '📝 SignableDoc: Got picker result, creating optimistic message...');
      final signZones = pickerResult['signZones'] as List<SignZone>;
      final pageCount = pickerResult['pageCount'] as int?;
      final fileSize = await file.length();

      // Create optimistic message with 'sending' status (shows upload indicator)
      final optimistic = Message(
        id: 'pending_${DateTime.now().millisecondsSinceEpoch}',
        senderId: _currentUid ?? '',
        type: MessageType.signableDoc,
        text: null,
        fileName: fileName,
        fileSize: fileSize,
        signZones: signZones,
        signStatus: SignStatus.pending,
        signExpiresInDays: 2,
        pageCount: pageCount,
        createdAt: DateTime.now(),
        clientMsgId: '',
        status: MessageStatus.sending,
        isUploading: true,
      );

      setState(() {
        _pendingMessages.insert(0, optimistic);
      });
      debugPrint('📝 SignableDoc: ✅ Optimistic message added! '
          'pendingMessages=${_pendingMessages.length}, '
          'fileName=$fileName, senderId=${_currentUid}');

      // Use post-frame callback to ensure scroll happens after layout
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });

      try {
        debugPrint('📝 SignableDoc: Starting upload...');
        // Send signable document (uploads PDF + writes to Firestore)
        await ChatRepository.instance.sendSignableDocument(
          widget.chatId,
          file,
          signZones: signZones,
          pageCount: pageCount,
        );
        debugPrint('📝 SignableDoc: ✅ Upload + Firestore write complete!');
        _reconnectStreamIfNeeded();
      } catch (e) {
        debugPrint('📝 SignableDoc: ❌ Upload failed: $e');
        // Mark as failed so user sees error icon
        if (mounted) {
          setState(() {
            final idx =
                _pendingMessages.indexWhere((m) => m.id == optimistic.id);
            if (idx >= 0) {
              _pendingMessages[idx] = optimistic.copyWith(
                status: MessageStatus.failed,
                isUploading: false,
              );
            }
          });
        }
        _showError('Failed to send document');
      }
    } catch (e) {
      _showError('Failed to pick document');
    }
  }

  Future<void> _startRecording() async {
    print('🎙️ ChatScreen: _startRecording called');

    final permission = await Permission.microphone.request();
    print('🎙️ ChatScreen: Microphone permission: ${permission.isGranted}');

    if (!permission.isGranted) {
      _showError('Please allow microphone permission');
      return;
    }

    final started = await VoiceRecorderService.instance.startRecording();
    print('🎙️ ChatScreen: Recording started: $started');

    if (started) {
      setState(() => _isRecording = true);
    } else {
      _showError('Failed to start recording');
    }
  }

  Future<void> _stopRecording() async {
    setState(() => _isRecording = false);

    final result = await VoiceRecorderService.instance.stopRecording();

    if (result == null) {
      _showError('Failed to save recording');
      return;
    }

    if (result.isTooShort) {
      _showError('Recording too short');
      return;
    }

    if (result.file != null) {
      // Optimistic UI - scroll immediately
      _scrollToBottom();

      try {
        await ChatRepository.instance.sendVoice(
          widget.chatId,
          result.file!,
          durationMs: result.durationMs,
        );
      } catch (e) {
        _showError('Failed to send voice message');
      }
    }
  }

  void _cancelRecording() async {
    await VoiceRecorderService.instance.cancelRecording();
    setState(() => _isRecording = false);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ── Message long-press actions ──

  void _onStarMessage(Message message) async {
    if (_highlightedMessageId != null) {
      setState(() => _highlightedMessageId = null);
    }

    // Pending messages don't exist in Firestore yet, so starring them stores
    // a non-canonical ID and breaks future jump-to-star behavior.
    Message canonical = message;
    if (message.id.startsWith('pending_')) {
      final createdAt = message.createdAt;
      final matches = _latestFirestoreMessages.where((m) {
        if (m.senderId != message.senderId || m.type != message.type) {
          return false;
        }
        if (message.type == MessageType.text &&
            (m.text ?? '') != (message.text ?? '')) {
          return false;
        }
        if ((message.type == MessageType.file ||
                message.type == MessageType.signableDoc) &&
            (m.fileName ?? '') != (message.fileName ?? '')) {
          return false;
        }
        final delta = m.createdAt.difference(createdAt).inSeconds.abs();
        return delta <= 20;
      }).toList()
        ..sort((a, b) =>
            a.createdAt.difference(createdAt).inMilliseconds.abs().compareTo(
                  b.createdAt.difference(createdAt).inMilliseconds.abs(),
                ));

      if (matches.isNotEmpty) {
        canonical = matches.first;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please wait a moment, then star this message again'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
    }

    final isCurrentlyStarred = _starredIds.contains(canonical.id);
    if (isCurrentlyStarred) {
      ChatRepository.instance.unstarMessage(canonical.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message unstarred'),
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      ChatRepository.instance.starMessage(widget.chatId, canonical);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message starred'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _onReplyMessage(Message message) {
    setState(() => _replyingTo = message);
    // Focus the text field
    // Delay slightly to ensure the reply bar is rendered first
    Future.delayed(const Duration(milliseconds: 100), () {
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  void _onForwardMessage(Message message) {
    // Show a bottom sheet to pick a chat to forward to
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const Text(
                  'Forward to...',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<UserChat>>(
                  stream: ChatRepository.instance
                      .subscribeToUserChats(_currentUid!),
                  builder: (ctx, snap) {
                    final chats = snap.data ?? [];
                    if (chats.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No chats available'),
                      );
                    }
                    return SizedBox(
                      height: 280,
                      child: ListView.builder(
                        itemCount: chats.length,
                        itemBuilder: (_, i) {
                          final chat = chats[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFECECEC),
                              child: Text(
                                _getInitials(chat.title ?? '?'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2E2E2E),
                                ),
                              ),
                            ),
                            title: Text(
                              limitChatDisplayName(chat.title ?? 'Chat'),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            onTap: () async {
                              Navigator.pop(sheetCtx);
                              try {
                                final text = message.getPreviewText();
                                await ChatRepository.instance.sendText(
                                  chat.chatId,
                                  text,
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Message forwarded'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted)
                                  _showError('Failed to forward message');
                              }
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openPeerProfile() {
    final peerUid = widget.peerUid;
    if (peerUid == null || widget.chatType != ChatType.dm) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatUserProfileScreen(
          chatId: widget.chatId,
          peerUid: peerUid,
          fallbackName: widget.title,
        ),
      ),
    );
  }

  void _openGroupProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatGroupProfileScreen(
          chatId: widget.chatId,
          title: widget.title,
          chatType: widget.chatType,
          supportGroupTitle: widget.supportGroupTitle,
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
