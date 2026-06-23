/// Chat module for WhatsApp-like messaging functionality.
/// 
/// ## Quick Start
/// 
/// ```dart
/// // After backend login success:
/// await ChatModuleHelper.instance.initializeFromLoginResponse(
///   loginResponse.toJson(),
/// );
/// 
/// // On app startup (if already logged in):
/// if (SharedPref.isUserAuthenticated()) {
///   await ChatModuleHelper.instance.restoreFromStoredSession();
/// }
/// 
/// // On logout:
/// await ChatModuleHelper.instance.cleanup();
/// ```
/// 
/// ## Key Components
/// 
/// - **ChatModuleHelper**: Main entry point for chat initialization
/// - **FirebaseChatAuthService**: Handles Firebase authentication and setup
/// - **ChatRepository**: Chat and message operations
/// - **UserRepository**: User profile and search operations
/// - **PresenceService**: Online/offline status and typing indicators
/// - **VoiceRecorderService**: Voice message recording
/// 
/// ## Data Models
/// 
/// - **ChatUserSession**: Backend login response for chat setup
/// - **ChatUser**: User profile stored in Firestore
/// - **Chat**: Chat document (DM or group)
/// - **Message**: Message in a chat
/// - **UserChat**: User's chat list entry
/// 
/// ## Backend Requirements
/// 
/// Your backend login response must include:
/// - `firebase_uid`: Format "odoo_{odoo_user_id}"
/// - `firebase_custom_token`: Generated using Firebase Admin SDK
/// - `role_id`: For role-based chat groups (optional but recommended)

library chat;

// Main helper
export 'chat_module_helper.dart';

// Models
export 'models/models.dart';

// Repositories
export 'repositories/repositories.dart';

// Services
export 'services/services.dart';
