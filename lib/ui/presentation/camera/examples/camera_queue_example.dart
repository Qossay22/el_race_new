/// Example: Using ImageQueueService in Camera Screens
///
/// This example shows how to integrate the ImageQueueService
/// for fast multi-photo capture with background processing

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/image_queue_service.dart';

/// Quick Integration Example
///
/// 1. Initialize service in your state:
/// ```dart
/// final ImageQueueService _imageQueueService = ImageQueueService();
/// StreamSubscription<int>? _queueCountSubscription;
/// int _pendingImagesCount = 0;
/// ```
///
/// 2. Subscribe to updates in initState:
/// ```dart
/// _queueCountSubscription = _imageQueueService.queueCount.listen((count) {
///   setState(() => _pendingImagesCount = count);
/// });
/// ```
///
/// 3. Add photos to queue (instant):
/// ```dart
/// Future<void> _takePicture() async {
///   final file = await _controller!.takePicture();
///
///   await _imageQueueService.addImageToQueue(
///     imagePath: file.path,
///     currentDate: DateFormat('dd/MM/yyyy').format(DateTime.now()),
///     currentTime: DateFormat('hh:mm a').format(DateTime.now()),
///     logoBytes: _logoBytes, // optional
///   );
///
///   // User can take another photo immediately!
/// }
/// ```
///
/// 4. Show UI feedback:
/// ```dart
/// if (_pendingImagesCount > 0)
///   Text('$_pendingImagesCount photos processing...')
/// ```
///
/// 5. Clean up in dispose:
/// ```dart
/// @override
/// void dispose() {
///   _queueCountSubscription?.cancel();
///   super.dispose();
/// }
/// ```

class CameraQueueExample extends StatefulWidget {
  const CameraQueueExample({super.key});

  @override
  State<CameraQueueExample> createState() => _CameraQueueExampleState();
}

class _CameraQueueExampleState extends State<CameraQueueExample> {
  final ImageQueueService _imageQueueService = ImageQueueService();
  StreamSubscription<int>? _queueCountSub;
  StreamSubscription<ProcessingStatus>? _statusSub;

  int _pendingCount = 0;
  String _statusText = '';

  @override
  void initState() {
    super.initState();

    // Listen to queue count
    _queueCountSub = _imageQueueService.queueCount.listen((count) {
      setState(() => _pendingCount = count);
    });

    // Listen to processing status
    _statusSub = _imageQueueService.processingStatus.listen((status) {
      setState(() => _statusText = status.progressText);
    });
  }

  @override
  void dispose() {
    _queueCountSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Status indicator
          if (_pendingCount > 0 || _statusText.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.blue,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_imageQueueService.isProcessing)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    _statusText.isNotEmpty
                        ? _statusText
                        : '$_pendingCount photos in queue',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),

          // Camera preview and capture button here...
        ],
      ),
    );
  }
}
