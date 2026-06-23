/// Chat Module Integration Guide
/// 
/// This file demonstrates how to integrate the chat module with your existing
/// backend login flow. It provides examples for different integration points.
/// 
/// DO NOT import this file directly - copy the relevant snippets to your codebase.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import the chat module
import '../chat.dart';

// ============================================================================
// EXAMPLE 1: Integration in SignInBloc after successful backend login
// ============================================================================

/// Add this method to your SignInBloc class:
/// 
/// ```dart
/// FutureOr<void> signInMethod(SignInET event, Emitter<SignInState> emit) async {
///   // ... existing login code ...
///   
///   if (loginResponseModel.result?.success == true) {
///     // Existing code: save login response
///     await userRepo.setLoginResponse(loginResponseModel);
///     await userRepo.setISLoggedIn(true);
///     
///     // NEW: Initialize chat after login
///     await _initializeChat(loginResponseModel);
///     
///     emit(InitialSignedInST(loginResponse: loginResponseModel));
///   }
/// }
/// 
/// Future<void> _initializeChat(LoginResponseModel loginResponse) async {
///   try {
///     // Convert login response to JSON for ChatUserSession
///     final loginJson = loginResponse.toJson();
///     
///     // Create chat session from login response
///     // NOTE: Your backend needs to add firebase_custom_token and firebase_uid
///     // to the login response for this to work fully
///     final session = ChatUserSession.fromLoginResponse(loginJson);
///     
///     if (!session.isChatAvailable) {
///       print('ℹ️ Chat not available - firebase_custom_token not provided');
///       return;
///     }
///     
///     // Setup Firebase chat
///     final result = await FirebaseChatAuthService.instance
///         .setupAfterBackendLogin(session);
///     
///     if (result.success && result.chatEnabled) {
///       print('✅ Chat initialized successfully');
///       // Initialize lifecycle observer for presence
///       ChatLifecycleObserver.instance.initialize();
///     } else {
///       print('⚠️ Chat setup failed: ${result.error}');
///     }
///   } catch (e) {
///     print('❌ Error initializing chat: $e');
///     // Don't rethrow - chat failure shouldn't block login
///   }
/// }
/// ```

// ============================================================================
// EXAMPLE 2: Standalone helper class for chat initialization
// ============================================================================

/// Helper class to manage chat initialization
class ChatInitializer {
  static final ChatInitializer _instance = ChatInitializer._();
  static ChatInitializer get instance => _instance;
  
  ChatInitializer._();

  bool _isInitialized = false;
  ChatSetupResult? _lastResult;

  bool get isInitialized => _isInitialized;
  bool get isChatEnabled => _lastResult?.chatEnabled ?? false;
  String? get roleChatId => _lastResult?.roleChatId;

  /// Initialize chat from stored login response.
  /// Call this after app startup if user is already logged in.
  Future<ChatSetupResult?> initializeFromStoredSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loginJson = prefs.getString('loginResponse');
      
      if (loginJson == null || loginJson.isEmpty) {
        print('ℹ️ ChatInitializer: No stored login response');
        return null;
      }

      final decoded = jsonDecode(loginJson) as Map<String, dynamic>;
      return await initializeFromLoginResponse(decoded);
    } catch (e) {
      print('❌ ChatInitializer: Error loading stored session: $e');
      return null;
    }
  }

  /// Initialize chat from login response JSON.
  /// Call this immediately after successful backend login.
  Future<ChatSetupResult> initializeFromLoginResponse(
    Map<String, dynamic> loginResponseJson,
  ) async {
    try {
      final session = ChatUserSession.fromLoginResponse(loginResponseJson);
      
      if (!session.isChatAvailable) {
        _lastResult = ChatSetupResult.disabled(
          'Firebase custom token not provided by backend',
        );
        return _lastResult!;
      }

      _lastResult = await FirebaseChatAuthService.instance
          .setupAfterBackendLogin(session);

      if (_lastResult!.success && _lastResult!.chatEnabled) {
        _isInitialized = true;
        ChatLifecycleObserver.instance.initialize();
        
        // Request notification permissions
        await FirebaseChatAuthService.instance.requestNotificationPermissions();
      }

      return _lastResult!;
    } catch (e) {
      _lastResult = ChatSetupResult.failed(e.toString());
      return _lastResult!;
    }
  }

  /// Cleanup on logout
  Future<void> cleanup() async {
    try {
      ChatLifecycleObserver.instance.dispose();
      await FirebaseChatAuthService.instance.signOut();
      _isInitialized = false;
      _lastResult = null;
    } catch (e) {
      print('❌ ChatInitializer: Error during cleanup: $e');
    }
  }
}

// ============================================================================
// EXAMPLE 3: Integration in main.dart for app startup
// ============================================================================

/// Add this to your main.dart after Firebase initialization:
/// 
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   
///   // ... existing initialization ...
///   await Firebase.initializeApp();
///   
///   // ... other initialization ...
///   
///   // Initialize chat if user is already logged in
///   if (SharedPref.isUserAuthenticated()) {
///     await ChatInitializer.instance.initializeFromStoredSession();
///   }
///   
///   runApp(MyApp());
/// }
/// ```

// ============================================================================
// EXAMPLE 4: Using chat features in your UI
// ============================================================================

/// Example widget showing chat list
class ChatListExample extends StatelessWidget {
  const ChatListExample({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseChatAuthService.instance.currentUid;
    if (uid == null) {
      return const Center(child: Text('Not logged in'));
    }

    return StreamBuilder<List<UserChat>>(
      stream: ChatRepository.instance.subscribeToUserChats(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final chats = snapshot.data ?? [];
        if (chats.isEmpty) {
          return const Center(child: Text('No chats yet'));
        }

        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index];
            return ListTile(
              title: Text(chat.title ?? 'Chat'),
              subtitle: Text(chat.type.name),
              trailing: Text(
                '${chat.updatedAt.hour}:${chat.updatedAt.minute.toString().padLeft(2, '0')}',
              ),
              onTap: () {
                // Navigate to chat screen
                // Navigator.push(context, MaterialPageRoute(
                //   builder: (context) => ChatScreen(chatId: chat.chatId),
                // ));
              },
            );
          },
        );
      },
    );
  }
}

/// Example widget for starting a new DM
class NewDmExample extends StatelessWidget {
  final String otherUid;
  final String otherName;

  const NewDmExample({
    super.key,
    required this.otherUid,
    required this.otherName,
  });

  Future<void> _startDm(BuildContext context) async {
    try {
      final chatId = await ChatRepository.instance.createOrGetDmChat(
        otherUid: otherUid,
        otherName: otherName,
        currentUserName: 'Current User', // Get from session
      );

      // Navigate to chat screen
      print('Created/opened DM: $chatId');
      // Navigator.push(context, MaterialPageRoute(
      //   builder: (context) => ChatScreen(chatId: chatId),
      // ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start chat: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _startDm(context),
      child: Text('Chat with $otherName'),
    );
  }
}

/// Example widget for user search
class UserSearchExample extends StatefulWidget {
  const UserSearchExample({super.key});

  @override
  State<UserSearchExample> createState() => _UserSearchExampleState();
}

class _UserSearchExampleState extends State<UserSearchExample> {
  final _searchController = TextEditingController();
  List<ChatUser> _results = [];
  bool _isLoading = false;

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final result = await UserRepository.instance.searchUsers(query: query);
      setState(() {
        _results = result.users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search users...',
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: _search,
            ),
          ),
          onSubmitted: (_) => _search(),
        ),
        if (_isLoading)
          const CircularProgressIndicator()
        else
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final user = _results[index];
                return ListTile(
                  title: Text(user.name),
                  subtitle: Text(user.email ?? ''),
                  onTap: () {
                    // Start DM with this user
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// ============================================================================
// EXAMPLE 5: Sending messages
// ============================================================================

/// Example of sending different message types
class MessageSendingExample {
  final String chatId;

  MessageSendingExample(this.chatId);

  /// Send a text message
  Future<void> sendText(String text) async {
    try {
      await ChatRepository.instance.sendText(chatId, text);
    } catch (e) {
      print('Error sending text: $e');
    }
  }

  /// Send an image (use with image_picker)
  // Future<void> sendImage() async {
  //   final picker = ImagePicker();
  //   final pickedFile = await picker.pickImage(source: ImageSource.gallery);
  //   if (pickedFile == null) return;
  //   
  //   final file = File(pickedFile.path);
  //   await ChatRepository.instance.sendImage(chatId, file);
  // }

  /// Send a voice message
  Future<void> recordAndSendVoice() async {
    final recorder = VoiceRecorderService.instance;

    // Request permission
    if (!await recorder.requestPermission()) {
      print('Microphone permission denied');
      return;
    }

    // Start recording
    await recorder.startRecording();

    // Wait (in real app, this would be user-controlled)
    await Future.delayed(const Duration(seconds: 3));

    // Stop and send
    final result = await recorder.stopRecording();
    if (result != null && result.isValid) {
      await ChatRepository.instance.sendVoice(
        chatId,
        result.file!,
        durationMs: result.durationMs,
      );
    }
  }
}

// ============================================================================
// EXAMPLE 6: Presence and typing indicators
// ============================================================================

/// Example widget showing online status
class OnlineStatusExample extends StatelessWidget {
  final String userId;

  const OnlineStatusExample({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PresenceStatus>(
      stream: PresenceService.instance.subscribeToUserPresence(userId),
      builder: (context, snapshot) {
        final status = snapshot.data;
        return Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: status?.online == true ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(width: 4),
            Text(status?.lastSeenText ?? 'Offline'),
          ],
        );
      },
    );
  }
}

/// Example widget showing typing indicator
class TypingIndicatorExample extends StatelessWidget {
  final String chatId;

  const TypingIndicatorExample({super.key, required this.chatId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<String>>(
      stream: PresenceService.instance.subscribeToTyping(chatId),
      builder: (context, snapshot) {
        final typingUsers = snapshot.data ?? {};
        if (typingUsers.isEmpty) {
          return const SizedBox.shrink();
        }

        return const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            'typing...',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// BACKEND REQUIREMENTS
// ============================================================================

/// For the chat module to work fully, your backend needs to provide these
/// additional fields in the login response:
/// 
/// ```json
/// {
///   "result": {
///     "success": true,
///     "token": "your_backend_jwt",
///     "data": {
///       // ... existing fields ...
///       
///       // NEW REQUIRED FIELDS:
///       "firebase_uid": "odoo_123",  // Format: "odoo_{odoo_user_id}"
///       "firebase_custom_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
///       
///       // OPTIONAL FIELDS:
///       "role_id": 5,  // For role-based chat groups
///       "role_chat_id": "role_5",  // Optional specific chat ID
///       "avatar_url": "https://example.com/avatar.jpg"  // NOT base64!
///     }
///   }
/// }
/// ```
/// 
/// The firebase_custom_token should be generated by your backend using
/// Firebase Admin SDK:
/// 
/// ```python
/// # Python (Odoo backend)
/// import firebase_admin
/// from firebase_admin import auth
/// 
/// def generate_firebase_token(odoo_user_id, role_id=None):
///     uid = f"odoo_{odoo_user_id}"
///     custom_claims = {}
///     if role_id:
///         custom_claims['role_id'] = role_id
///     
///     token = auth.create_custom_token(uid, custom_claims)
///     return token.decode('utf-8')
/// ```
