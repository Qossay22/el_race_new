import 'dart:async';

import 'package:flutter/material.dart';

/// Signals that critical app initialization is done.
final Completer<void> appInitCompleter = Completer<void>();

/// Global navigator key used across the app.
final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
