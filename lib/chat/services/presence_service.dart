import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

import '../repositories/user_repository.dart';

/// Service for managing user presence and typing indicators
/// using Firebase Realtime Database.
///
/// Realtime Database structure:
/// - presence/{uid}: { online: bool, lastChanged: serverTimestamp }
/// - typing/{chatId}/{uid}: { typing: true, timestamp: serverTimestamp }
class PresenceService {
  static PresenceService? _instance;
  static PresenceService get instance => _instance ??= PresenceService._();

  PresenceService._();

  final FirebaseDatabase _database = FirebaseDatabase.instance;
  StreamSubscription? _connectionSubscription;
  String? _currentUid;
  bool _isOnline = false;

  // Typing debounce timer
  Timer? _typingTimer;
  String? _currentTypingChatId;
  static const Duration _typingTimeout = Duration(seconds: 3);

  /// Initialize presence for a user. Call after Firebase auth.
  Future<void> initialize(String uid) async {
    _currentUid = uid;

    // Listen to connection state
    _connectionSubscription?.cancel();
    _connectionSubscription =
        _database.ref('.info/connected').onValue.listen((event) {
      final connected = event.snapshot.value as bool? ?? false;
      if (connected && _currentUid != null) {
        _setupPresence(_currentUid!);
      }
    });

    // Set initial presence
    await _setOnline();
  }

  /// Setup presence with onDisconnect handler
  Future<void> _setupPresence(String uid) async {
    final presenceRef = _database.ref('presence/$uid');

    // Set onDisconnect to mark offline when connection is lost
    await presenceRef.onDisconnect().set({
      'online': false,
      'lastChanged': ServerValue.timestamp,
    });

    // Set current status as online
    await presenceRef.set({
      'online': true,
      'lastChanged': ServerValue.timestamp,
    });

    _isOnline = true;
  }

  /// Manually set user as online (e.g., on app resume)
  Future<void> _setOnline() async {
    if (_currentUid == null) return;

    try {
      final presenceRef = _database.ref('presence/$_currentUid');
      await presenceRef.set({
        'online': true,
        'lastChanged': ServerValue.timestamp,
      });
      _isOnline = true;
    } catch (e) {
      print('❌ PresenceService: Error setting online: $e');
    }
  }

  /// Set user as offline (e.g., on app pause/logout)
  Future<void> setOffline() async {
    if (_currentUid == null) return;

    try {
      final presenceRef = _database.ref('presence/$_currentUid');
      await presenceRef.set({
        'online': false,
        'lastChanged': ServerValue.timestamp,
      });
      _isOnline = false;
    } catch (e) {
      print('❌ PresenceService: Error setting offline: $e');
    }
  }

  /// Called when app lifecycle changes
  Future<void> onAppLifecycleChanged(bool isActive) async {
    if (isActive) {
      await _setOnline();
    } else {
      await setOffline();
    }
  }

  /// Subscribe to a user's presence status
  Stream<PresenceStatus> subscribeToUserPresence(String uid) {
    return _database.ref('presence/$uid').onValue.map((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) {
        return PresenceStatus(online: false);
      }
      return PresenceStatus(
        online: data['online'] ?? false,
        lastChanged: data['lastChanged'] != null
            ? DateTime.fromMillisecondsSinceEpoch(data['lastChanged'] as int)
            : null,
      );
    });
  }

  /// Set typing status in a chat
  Future<void> setTyping(String chatId, bool isTyping) async {
    if (_currentUid == null) return;

    final typingRef = _database.ref('typing/$chatId/$_currentUid');

    // Cancel existing timer
    _typingTimer?.cancel();

    if (isTyping) {
      // Set typing to true
      await typingRef.set(true);
      _currentTypingChatId = chatId;

      // Auto-clear after timeout
      _typingTimer = Timer(_typingTimeout, () {
        _clearTyping(chatId);
      });
    } else {
      await _clearTyping(chatId);
    }
  }

  Future<void> _clearTyping(String chatId) async {
    if (_currentUid == null) return;

    try {
      final typingRef = _database.ref('typing/$chatId/$_currentUid');
      await typingRef.remove();
      if (_currentTypingChatId == chatId) {
        _currentTypingChatId = null;
      }
    } catch (e) {
      // Ignore errors when clearing typing
    }
  }

  /// Subscribe to typing status in a chat
  /// Returns a stream of UIDs that are currently typing
  Stream<Set<String>> subscribeToTyping(String chatId) {
    return _database.ref('typing/$chatId').onValue.map((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return <String>{};

      // Filter out current user and only include true values
      return data.entries
          .where((e) => e.value == true && e.key != _currentUid)
          .map((e) => e.key as String)
          .toSet();
    }).handleError((error) {
      // Silently ignore permission errors - typing is not critical
      debugPrint('Typing subscription error (ignored): $error');
      return <String>{};
    });
  }

  /// Subscribe to typing status with user names
  /// Returns a stream of TypingInfo with user names
  Stream<TypingInfo> subscribeToTypingWithNames(String chatId) {
    return subscribeToTyping(chatId)
        .switchMap<TypingInfo>(
      (typingUids) => Stream.fromFuture(_resolveTypingInfo(typingUids)),
    )
        .onErrorReturnWith((error, _) {
      debugPrint('Typing with names error (ignored): $error');
      return TypingInfo.empty();
    });
  }

  Future<TypingInfo> _resolveTypingInfo(Set<String> typingUids) async {
    if (typingUids.isEmpty) {
      return TypingInfo.empty();
    }

    final names = <String>[];
    for (final uid in typingUids) {
      final user = await UserRepository.instance.getUser(uid);
      if (user == null) continue;

      final trimmed = user.name.trim();
      if (trimmed.isEmpty) continue;

      // Get first name only for cleaner display
      names.add(trimmed.split(RegExp(r'\s+')).first);
    }

    return TypingInfo(
      typingUids: typingUids.toList(),
      typingNames: names,
      isTyping: names.isNotEmpty,
    );
  }

  /// Clean up resources
  Future<void> dispose() async {
    _typingTimer?.cancel();
    _connectionSubscription?.cancel();

    if (_currentTypingChatId != null && _currentUid != null) {
      await _clearTyping(_currentTypingChatId!);
    }

    await setOffline();
    _currentUid = null;
  }

  /// Get current user UID
  String? get currentUid => _currentUid;

  /// Check if currently marked as online
  bool get isOnline => _isOnline;
}

/// Presence status for a user
class PresenceStatus {
  final bool online;
  final DateTime? lastChanged;

  PresenceStatus({
    required this.online,
    this.lastChanged,
  });

  /// Get human-readable last seen text
  String get lastSeenText {
    if (online) return 'Online';
    if (lastChanged == null) return 'Offline';

    final now = DateTime.now();
    final diff = now.difference(lastChanged!);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${lastChanged!.day}/${lastChanged!.month}/${lastChanged!.year}';
  }

  @override
  String toString() =>
      'PresenceStatus(online: $online, lastChanged: $lastChanged)';
}

/// Typing information including user names
class TypingInfo {
  final List<String> typingUids;
  final List<String> typingNames;
  final bool isTyping;

  TypingInfo({
    required this.typingUids,
    required this.typingNames,
    required this.isTyping,
  });

  factory TypingInfo.empty() => TypingInfo(
        typingUids: [],
        typingNames: [],
        isTyping: false,
      );

  /// Get formatted text for display in chat list
  /// Returns "Ahmed is typing..." or "Ahmed and Mohamed are typing..."
  String get displayText {
    if (typingNames.isEmpty) return '';

    if (typingNames.length == 1) {
      return '${typingNames[0]} is typing...';
    }

    if (typingNames.length == 2) {
      return '${typingNames[0]} and ${typingNames[1]} are typing...';
    }

    return '${typingNames[0]} and ${typingNames.length - 1} others are typing...';
  }

  @override
  String toString() =>
      'TypingInfo(uids: $typingUids, names: $typingNames, isTyping: $isTyping)';
}
