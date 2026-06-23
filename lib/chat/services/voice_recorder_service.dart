import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

/// Service for recording voice messages.
class VoiceRecorderService {
  static VoiceRecorderService? _instance;
  static VoiceRecorderService get instance => 
      _instance ??= VoiceRecorderService._();
  
  VoiceRecorderService._();

  final AudioRecorder _recorder = AudioRecorder();
  final Uuid _uuid = const Uuid();
  
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  String? _currentRecordingPath;
  Timer? _maxDurationTimer;

  // Configuration
  static const int maxDurationSeconds = 120; // 2 minutes max
  static const int minDurationMs = 500; // Minimum 0.5 seconds

  /// Check if currently recording
  bool get isRecording => _isRecording;

  /// Get current recording duration in milliseconds
  int get recordingDurationMs {
    if (!_isRecording || _recordingStartTime == null) return 0;
    return DateTime.now().difference(_recordingStartTime!).inMilliseconds;
  }

  /// Check and request microphone permission
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Check if microphone permission is granted
  Future<bool> hasPermission() async {
    return await Permission.microphone.isGranted;
  }

  /// Start recording a voice message
  Future<bool> startRecording() async {
    if (_isRecording) {
      print('⚠️ VoiceRecorder: Already recording');
      return false;
    }

    // Check permission
    if (!await _recorder.hasPermission()) {
      print('❌ VoiceRecorder: No microphone permission');
      return false;
    }

    try {
      // Generate file path
      final directory = await getTemporaryDirectory();
      final fileName = 'voice_${_uuid.v4()}.m4a';
      _currentRecordingPath = '${directory.path}/$fileName';

      // Configure and start recording
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc, // AAC encoding
          bitRate: 128000, // 128 kbps
          sampleRate: 44100, // 44.1 kHz
          numChannels: 1, // Mono
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      _recordingStartTime = DateTime.now();

      // Set max duration timer
      _maxDurationTimer?.cancel();
      _maxDurationTimer = Timer(
        const Duration(seconds: maxDurationSeconds),
        () async {
          print('⚠️ VoiceRecorder: Max duration reached, stopping...');
          await stopRecording();
        },
      );

      print('🎙️ VoiceRecorder: Started recording to $_currentRecordingPath');
      return true;
    } catch (e) {
      print('❌ VoiceRecorder: Error starting recording: $e');
      _isRecording = false;
      _currentRecordingPath = null;
      _recordingStartTime = null;
      return false;
    }
  }

  /// Stop recording and return the recorded file
  Future<VoiceRecordingResult?> stopRecording() async {
    if (!_isRecording) {
      print('⚠️ VoiceRecorder: Not recording');
      return null;
    }

    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;

    try {
      final path = await _recorder.stop();
      final durationMs = recordingDurationMs;
      
      _isRecording = false;
      _recordingStartTime = null;

      if (path == null || path.isEmpty) {
        print('❌ VoiceRecorder: No file path returned');
        return null;
      }

      final file = File(path);
      if (!await file.exists()) {
        print('❌ VoiceRecorder: File does not exist: $path');
        return null;
      }

      // Check minimum duration
      if (durationMs < minDurationMs) {
        print('⚠️ VoiceRecorder: Recording too short (${durationMs}ms), deleting...');
        await file.delete();
        return VoiceRecordingResult(
          file: null,
          durationMs: durationMs,
          isTooShort: true,
        );
      }

      final fileSize = await file.length();
      print('🎙️ VoiceRecorder: Stopped recording - ${durationMs}ms, ${fileSize} bytes');

      return VoiceRecordingResult(
        file: file,
        durationMs: durationMs,
        isTooShort: false,
      );
    } catch (e) {
      print('❌ VoiceRecorder: Error stopping recording: $e');
      _isRecording = false;
      _recordingStartTime = null;
      return null;
    }
  }

  /// Cancel recording without saving
  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;

    try {
      final path = await _recorder.stop();
      
      // Delete the file
      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          print('🎙️ VoiceRecorder: Cancelled and deleted recording');
        }
      }
    } catch (e) {
      print('❌ VoiceRecorder: Error cancelling recording: $e');
    } finally {
      _isRecording = false;
      _recordingStartTime = null;
      _currentRecordingPath = null;
    }
  }

  /// Get recording amplitude stream (for visualization)
  Stream<double> get amplitudeStream {
    // Note: record package provides amplitude, but we need to convert it
    return Stream.periodic(const Duration(milliseconds: 100))
        .asyncMap((_) async {
      if (!_isRecording) return 0.0;
      try {
        final amplitude = await _recorder.getAmplitude();
        // Convert dB to 0-1 range (typical dB range is -160 to 0)
        final normalized = (amplitude.current + 160) / 160;
        return normalized.clamp(0.0, 1.0);
      } catch (_) {
        return 0.0;
      }
    });
  }

  /// Dispose resources
  Future<void> dispose() async {
    await cancelRecording();
    await _recorder.dispose();
  }
}

/// Result of a voice recording
class VoiceRecordingResult {
  final File? file;
  final int durationMs;
  final bool isTooShort;

  VoiceRecordingResult({
    required this.file,
    required this.durationMs,
    required this.isTooShort,
  });

  bool get isValid => file != null && !isTooShort;

  String get durationText {
    final seconds = (durationMs / 1000).floor();
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
