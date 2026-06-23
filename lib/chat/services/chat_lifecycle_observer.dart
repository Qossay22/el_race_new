import 'package:flutter/material.dart';

import 'presence_service.dart';
import 'firebase_chat_auth_service.dart';

/// App lifecycle observer for managing chat presence.
/// 
/// Add this to WidgetsBinding in your app's initialization:
/// ```dart
/// WidgetsBinding.instance.addObserver(ChatLifecycleObserver.instance);
/// ```
/// 
/// Or use with WidgetsBindingObserver mixin in your root widget.
class ChatLifecycleObserver extends WidgetsBindingObserver {
  static ChatLifecycleObserver? _instance;
  static ChatLifecycleObserver get instance => 
      _instance ??= ChatLifecycleObserver._();
  
  ChatLifecycleObserver._();

  bool _isRegistered = false;
  bool _isEnabled = false;

  /// Initialize and register the observer.
  /// Call this after chat setup is complete.
  void initialize() {
    if (_isRegistered) return;
    
    WidgetsBinding.instance.addObserver(this);
    _isRegistered = true;
    _isEnabled = true;
    
    print('✅ ChatLifecycleObserver: Registered');
  }

  /// Enable/disable presence tracking.
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  /// Dispose and unregister the observer.
  void dispose() {
    if (!_isRegistered) return;
    
    WidgetsBinding.instance.removeObserver(this);
    _isRegistered = false;
    _isEnabled = false;
    
    print('✅ ChatLifecycleObserver: Unregistered');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isEnabled) return;
    
    // Only process if chat auth is setup
    if (!FirebaseChatAuthService.instance.isSetupComplete) return;

    switch (state) {
      case AppLifecycleState.resumed:
        // App is visible and responding to user input
        print('📱 ChatLifecycleObserver: App resumed - setting online');
        PresenceService.instance.onAppLifecycleChanged(true);
        break;
        
      case AppLifecycleState.inactive:
        // App is inactive but still visible (e.g., phone call overlay)
        // Don't change presence here to avoid flickering
        break;
        
      case AppLifecycleState.paused:
        // App is not visible
        print('📱 ChatLifecycleObserver: App paused - setting offline');
        PresenceService.instance.onAppLifecycleChanged(false);
        break;
        
      case AppLifecycleState.detached:
        // App is still hosted but detached from any views
        print('📱 ChatLifecycleObserver: App detached - setting offline');
        PresenceService.instance.onAppLifecycleChanged(false);
        break;
        
      case AppLifecycleState.hidden:
        // App is hidden (iOS-specific in some cases)
        print('📱 ChatLifecycleObserver: App hidden - setting offline');
        PresenceService.instance.onAppLifecycleChanged(false);
        break;
    }
  }
}

/// Mixin for StatefulWidget that handles chat lifecycle.
/// 
/// Use this in your root app widget or main scaffold:
/// ```dart
/// class _MyAppState extends State<MyApp> with ChatLifecycleMixin {
///   @override
///   Widget build(BuildContext context) {
///     return MaterialApp(...);
///   }
/// }
/// ```
mixin ChatLifecycleMixin<T extends StatefulWidget> on State<T>, WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!FirebaseChatAuthService.instance.isSetupComplete) return;

    switch (state) {
      case AppLifecycleState.resumed:
        PresenceService.instance.onAppLifecycleChanged(true);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        PresenceService.instance.onAppLifecycleChanged(false);
        break;
      case AppLifecycleState.inactive:
        // Don't change on inactive to avoid flickering
        break;
    }
  }
}
