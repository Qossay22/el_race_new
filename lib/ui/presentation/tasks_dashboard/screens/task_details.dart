import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:el_race/ui/presentation/todo_list/data/todo_model.dart';
import 'package:el_race/ui/presentation/todo_list/data/task_member_model.dart';
import 'package:el_race/ui/presentation/todo_list/services/todo_firebase_service.dart';
import 'package:el_race/data/services/task_notification_service.dart';
import 'package:el_race/ui/presentation/todo_list/services/team_members_api_service.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:el_race/ui/presentation/my_documents/screens/attachment_viewer_screen.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:el_race/report_module/data/provider/reports_provider.dart';
import 'package:el_race/report_module/data/models/report_model.dart';
import 'package:el_race/report_module/presentation/screens/report_detail/report_detail.dart'
    as report_detail;

class TaskDetailsScreen extends StatefulWidget {
  static const routeName = '/task-details';

  final TodoModel? task;
  final String? taskId;

  const TaskDetailsScreen({Key? key, this.task, this.taskId}) : super(key: key);

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  bool _isRecording = false;
  bool _isLoading = true;
  bool _isSendingComment = false;
  bool _isLoadingMemberPhotos = false;
  TodoModel? _task;
  List<Map<String, dynamic>> _comments = [];
  final TextEditingController _commentController = TextEditingController();

  Map<int, String> _memberPhotoById = {};

  // Audio recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;

  // Audio playback
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingCommentId;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadTask();
    _setupAudioPlayer();
    _loadMemberPhotos();
  }

  int? _extractLeadingId(String text) {
    final match = RegExp(r'^\s*(\d+)').firstMatch(text.trim());
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  String _initialsForDisplayName(String name) {
    final cleaned = name.replaceFirst(RegExp(r'^\s*\d+\s*'), '').trim();
    final parts =
        cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String? _photoUrlForDisplayName(String name) {
    final id = _extractLeadingId(name);
    if (id == null) return null;
    return _memberPhotoById[id];
  }

  Future<void> _loadMemberPhotos() async {
    if (_isLoadingMemberPhotos) return;
    setState(() => _isLoadingMemberPhotos = true);

    try {
      final members = await TeamMembersApiService.instance.getTeamMembers();
      final map = <int, String>{};
      for (final m in members) {
        final url = m.image?.trim();
        if (url != null && url.isNotEmpty) {
          map[m.id] = url;
        }
      }
      if (!mounted) return;
      setState(() => _memberPhotoById = map);
    } catch (_) {
      // ignore (fallback to initials)
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingMemberPhotos = false);
    }
  }

  Widget _buildAvatarForName(String name, {double size = 34}) {
    final url = _photoUrlForDisplayName(name);
    final initials = _initialsForDisplayName(name);

    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.grey[200],
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
      );
    }

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.grey[300],
      child: Text(
        initials,
        style: GoogleFonts.poppins(
          fontSize: size >= 40 ? 16 : 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  /// Build avatar for comment with direct photo URL
  Widget _buildCommentAvatar(String name, String? photoUrl,
      {double size = 40}) {
    final initials = _initialsForDisplayName(name);

    // First try the direct photo URL from comment
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.grey[200],
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (_, __) {},
      );
    }

    // Fallback to member photo lookup by name
    final memberUrl = _photoUrlForDisplayName(name);
    if (memberUrl != null && memberUrl.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.grey[200],
        backgroundImage: NetworkImage(memberUrl),
        onBackgroundImageError: (_, __) {},
      );
    }

    // Default to initials
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.grey[300],
      child: Text(
        initials,
        style: GoogleFonts.poppins(
          fontSize: size >= 40 ? 16 : 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  void _setupAudioPlayer() {
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _playingCommentId = null;
            _isPlaying = false;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ==================== AUDIO RECORDING ====================

  Future<void> _startRecording() async {
    try {
      // Request microphone permission explicitly
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Microphone permission is required for voice comments'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () => openAppSettings(),
            ),
          ),
        );
        return;
      }

      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/voice_comment_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _recordingPath = path;
        _recordingDuration = Duration.zero;
      });

      // Update duration every second
      _updateRecordingDuration();

      print('✅ Started recording: $path');
    } catch (e) {
      print('❌ Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to start recording: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _updateRecordingDuration() async {
    while (_isRecording) {
      await Future.delayed(Duration(seconds: 1));
      if (_isRecording && mounted) {
        setState(() {
          _recordingDuration += Duration(seconds: 1);
        });
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);

      if (path != null) {
        print('✅ Recording saved: $path');
        // Show confirmation dialog
        _showVoiceCommentDialog(path);
      }
    } catch (e) {
      print('❌ Error stopping recording: $e');
      setState(() => _isRecording = false);
    }
  }

  Future<void> _cancelRecording() async {
    try {
      await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _recordingPath = null;
        _recordingDuration = Duration.zero;
      });
    } catch (e) {
      print('❌ Error cancelling recording: $e');
      setState(() => _isRecording = false);
    }
  }

  void _showVoiceCommentDialog(String audioPath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Voice Comment',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic, size: 48, color: Colors.green),
            SizedBox(height: 12),
            Text(
              'Recording: ${_formatDuration(_recordingDuration)}',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              'Send this voice comment?',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Delete the recording
              File(audioPath).deleteSync();
              Navigator.pop(context);
            },
            child:
                Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _sendVoiceComment(audioPath);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child:
                Text('Send', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendVoiceComment(String audioPath) async {
    if (_task?.firebaseId == null) return;

    setState(() => _isSendingComment = true);
    try {
      // Upload audio to Firebase Storage
      final file = File(audioPath);
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('voice_comments')
          .child(_task!.firebaseId!)
          .child(fileName);

      // Set metadata to ensure content type is audio
      final metadata = SettableMetadata(
        contentType: 'audio/mp4',
        customMetadata: {
          'uploaded_by': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
          'task_id': _task!.firebaseId!,
        },
      );

      await storageRef.putFile(file, metadata);
      final audioUrl = await storageRef.getDownloadURL();

      // Add comment with audio URL
      await TodoFirebaseService.instance.addVoiceComment(
        _task!.firebaseId!,
        audioUrl,
        _formatDuration(_recordingDuration),
        ownerUid: _task!.ownerUid,
      );

      // Delete local file
      file.deleteSync();

      await _loadComments();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Voice comment sent!'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      print('❌ Error sending voice comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to send voice comment'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingComment = false;
          _recordingPath = null;
          _recordingDuration = Duration.zero;
        });
      }
    }
  }

  Future<void> _playVoiceComment(String commentId, String audioUrl) async {
    try {
      if (_playingCommentId == commentId && _isPlaying) {
        await _audioPlayer.pause();
        setState(() => _isPlaying = false);
      } else {
        setState(() => _playingCommentId = commentId);
        await _audioPlayer.setUrl(audioUrl);
        await _audioPlayer.play();
      }
    } catch (e) {
      print('❌ Error playing voice comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to play audio'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _stopPlayback() async {
    await _audioPlayer.stop();
    setState(() {
      _playingCommentId = null;
      _isPlaying = false;
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _loadTask() async {
    if (widget.task != null) {
      setState(() {
        _task = widget.task;
        _isLoading = false;
      });
      _loadComments();
      if (_task != null) {
        unawaited(
          TodoFirebaseService.instance.ensureRecipientFirebaseUids(_task!),
        );
      }
    } else if (widget.taskId != null) {
      try {
        final task =
            await TodoFirebaseService.instance.getTodoById(widget.taskId!);
        if (mounted) {
          setState(() {
            _task = task;
            _isLoading = false;
          });
          _loadComments();
          if (_task != null) {
            unawaited(
              TodoFirebaseService.instance.ensureRecipientFirebaseUids(_task!),
            );
          }
        }
      } catch (e) {
        print('❌ Error loading task: $e');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadComments() async {
    if (_task?.firebaseId == null) return;
    try {
      final comments = await TodoFirebaseService.instance.getComments(
        _task!.firebaseId!,
        ownerUid: _task!.ownerUid,
      );
      if (mounted) {
        setState(() => _comments = comments);
      }
    } catch (e) {
      print('❌ Error loading comments: $e');
    }
  }

  Future<void> _sendComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _task?.firebaseId == null) return;

    setState(() => _isSendingComment = true);
    try {
      await TodoFirebaseService.instance.addComment(
        _task!.firebaseId!,
        content,
        ownerUid: _task!.ownerUid,
      );
      _commentController.clear();
      await _loadComments();
    } catch (e) {
      print('❌ Error sending comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to send comment'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSendingComment = false);
    }
  }

  Future<void> _toggleMemberCompletion(
      TaskMember member, bool isAssigned) async {
    if (_task?.firebaseId == null) return;

    final newStatus = !member.isCompleted;

    try {
      await TodoFirebaseService.instance.updateMemberStatus(
        _task!.firebaseId!,
        member.name,
        newStatus,
        isAssigned: isAssigned,
        ownerUid: _task!.ownerUid,
      );

      // Reload task to get updated data
      await _loadTask();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus
                ? '${member.firstName} marked as complete'
                : '${member.firstName} marked as incomplete',
          ),
          backgroundColor: newStatus ? Colors.green : Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ Error updating member status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to update status'),
            backgroundColor: Colors.red),
      );
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('HH:mm').format(date);
  }

  String _formatCommentTime(dynamic timestamp) {
    if (timestamp == null) return '-';
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return '-';
    }
    return '${DateFormat('HH:mm').format(date)}\n${DateFormat('dd/MM/yyyy').format(date)}';
  }

  /// Get first name from full name
  String _getFirstName(String? fullName) {
    if (fullName == null || fullName.isEmpty) return '';
    final parts = fullName.split(' ');
    return parts.first;
  }

  /// Get initials from name
  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return 'U';
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: const HeaderWidget(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_task == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: const HeaderWidget(),
        body: Center(
          child: Text(
            'Task not found',
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    final task = _task!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const HeaderWidget(),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(20.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      "assets/png/Tasks.svg",
                      height: 24.w,
                      width: 24.w,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'TASK DETAILS',
                      style: GoogleFonts.poppins(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w500,
                        color: appFontColor,
                      ),
                      overflow: TextOverflow.visible,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const SizedBox(height: 20),

                // Task Title
                Text(
                  task.title.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),

                // Description Section
                if (task.description != null && task.description!.isNotEmpty)
                  _buildBorderedFieldWithLabel(
                    label: 'Description',
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        task.description ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                if (task.description != null && task.description!.isNotEmpty)
                  const SizedBox(height: 20),

                // Dates Section
                _buildDatesSection(task),
                const SizedBox(height: 20),

                // Task Department
                if (task.department != null)
                  _buildBorderedFieldWithLabel(
                    label: 'Task\nDepartment',
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        task.department ?? '-',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                if (task.department != null) const SizedBox(height: 20),

                // Linked Report Section
                if (task.reportId != null && task.reportId!.isNotEmpty)
                  _buildLinkedReportSection(task.reportId!),
                if (task.reportId != null && task.reportId!.isNotEmpty)
                  const SizedBox(height: 20),

                // Task Progress Section
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.grey[300]!, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 12),

                      // Progress Bar
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: task.progress,
                                child: Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Color(0xFF4CAF50),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            '${task.progressText} complete',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),

                      // Last Updated Info
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Builder(
                            builder: (context) {
                              final raw = task.assignedToName ?? '';
                              final names = raw
                                  .split(',')
                                  .map((e) => e.trim())
                                  .where((e) => e.isNotEmpty)
                                  .toList();

                              final displayNames = names.isNotEmpty
                                  ? names
                                  : <String>['Unassigned'];

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: displayNames
                                    .map(
                                      (name) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8),
                                        child: Row(
                                          children: [
                                            _buildAvatarForName(name, size: 36),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                name,
                                                maxLines: null,
                                                overflow: TextOverflow.visible,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                              );
                            },
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Last updated at',
                                  maxLines: null,
                                  overflow: TextOverflow.visible,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                              Text(
                                _formatTime(task.updatedAt),
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 2),
                          Text(
                            _formatDate(task.updatedAt),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // Attachments Section
                _buildSectionLabel('Attachments'),
                SizedBox(height: 12),
                if (task.attachments != null && task.attachments!.isNotEmpty)
                  _buildAttachmentsList(task.attachments!)
                else
                  Text(
                    'No attachments',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                const SizedBox(height: 20),

                // Assigned Members
                _buildSectionLabel('Assigned Members'),
                const SizedBox(height: 12),
                if (task.assignedMembers != null &&
                    task.assignedMembers!.isNotEmpty)
                  _buildTaskMembersList(task.assignedMembers!, isAssigned: true)
                else if (task.assignedToName != null &&
                    task.assignedToName!.isNotEmpty)
                  _buildMembersList(task.assignedToName!.split(', '))
                else
                  Text(
                    'No members assigned',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                const SizedBox(height: 20),

                // Following By
                _buildSectionLabel('Followed UP'),
                const SizedBox(height: 12),
                if (task.followedUpBy != null && task.followedUpBy!.isNotEmpty)
                  _buildTaskMembersList(task.followedUpBy!, isAssigned: false)
                else if (task.followers != null && task.followers!.isNotEmpty)
                  _buildMembersList(task.followers!)
                else
                  Text(
                    'No followers',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                const SizedBox(height: 20),

                // Comments Section
                _buildSectionLabel('Comments'),
                const SizedBox(height: 12),
                if (_comments.isNotEmpty)
                  ..._comments
                      .map((comment) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildCommentItem(comment),
                          ))
                      .toList()
                else
                  Text(
                    'No comments yet',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                const SizedBox(height: 50),

                // Write Comment Field
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: InputDecoration(
                            hintText: 'Write a comment',
                            hintStyle: GoogleFonts.poppins(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                          ),
                          style: GoogleFonts.poppins(
                            color: Colors.black87,
                            fontSize: 14,
                          ),
                          onSubmitted: (_) => _sendComment(),
                        ),
                      ),
                      // Recording indicator or mic button
                      if (_isRecording)
                        Row(
                          children: [
                            // Recording duration
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle,
                                      size: 8, color: Colors.red),
                                  SizedBox(width: 4),
                                  Text(
                                    _formatDuration(_recordingDuration),
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 4),
                            // Cancel button
                            GestureDetector(
                              onTap: _cancelRecording,
                              child: Container(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.close,
                                    size: 24, color: Colors.grey[600]),
                              ),
                            ),
                            // Stop & Send button
                            GestureDetector(
                              onTap: _stopRecording,
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.stop,
                                    size: 20, color: Colors.white),
                              ),
                            ),
                          ],
                        )
                      else
                        GestureDetector(
                          onTap: _startRecording,
                          child: Container(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.mic_none_rounded,
                              size: 26,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      SizedBox(width: 4),
                      if (!_isRecording)
                        GestureDetector(
                          onTap: _isSendingComment ? null : _sendComment,
                          child: Container(
                            padding: EdgeInsets.all(8),
                            child: _isSendingComment
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : SvgPicture.asset(
                                    'assets/png/send.svg',
                                    width: 24,
                                    height: 24,
                                    color: Colors.grey[600],
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // Completed Button
                Center(
                  child: SizedBox(
                    width: 180,
                    height: 45,
                    child: ElevatedButton(
                      onPressed:
                          task.isCompleted ? null : () => _toggleComplete(task),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            task.isCompleted ? Colors.grey : Color(0xFF4CAF50),
                        disabledBackgroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        task.isCompleted ? 'COMPLETED ✓' : 'MARK COMPLETE',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 30),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleComplete(TodoModel task) async {
    // Prevent toggling if already completed
    if (task.isCompleted) {
      return;
    }

    try {
      final updatedTask = task.copyWith(
        isCompleted: true,
        updatedAt: DateTime.now(),
      );
      await TodoFirebaseService.instance.updateTodo(updatedTask);
      setState(() {
        _task = updatedTask;
      });

      // Fire task-completed notification
      try {
        await TaskNotificationService().showTaskCompletedNotification(
          taskId: task.firebaseId ?? '',
          taskTitle: task.title,
        );
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Task marked as complete!',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Error updating task: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update task: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildDatesSection(TodoModel task) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Start Date
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'START DATE',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(task.startDate),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey[300],
          ),
          // End Date
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'END DATE',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(task.dueDate),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMembersList(List<String> members) {
    final cleaned = members.where((m) => m.trim().isNotEmpty).toList();
    if (cleaned.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: cleaned
            .map(
              (name) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _buildMemberChip(name),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTaskMembersList(List<TaskMember> members,
      {required bool isAssigned}) {
    if (members.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: members
            .map(
              (member) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _buildTaskMemberChip(member, isAssigned: isAssigned),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTaskMemberChip(TaskMember member, {required bool isAssigned}) {
    return InkWell(
      onTap: () => _toggleMemberCompletion(member, isAssigned),
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        children: [
          _buildAvatarForName(member.name, size: 44),
          if (member.isCompleted)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMemberChip(String name) {
    final trimmed = name.trim();

    return _buildAvatarForName(trimmed, size: 44);
  }

  Widget _buildTaskMemberRow(TaskMember member, {required bool isAssigned}) {
    return InkWell(
      onTap: () => _toggleMemberCompletion(member, isAssigned),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[200]!, width: 1),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          member.isCompleted ? Colors.green : Colors.grey[300]!,
                      width: 2,
                    ),
                    color: Colors.grey[200],
                  ),
                  child: Center(
                    child: Text(
                      member.initials,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ),
                if (member.isCompleted)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check,
                          size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                    maxLines: null,
                    overflow: TextOverflow.visible,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    member.isCompleted ? 'Completed' : 'Pending',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color:
                          member.isCompleted ? Colors.green : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              member.isCompleted
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: member.isCompleted ? Colors.green : Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberRow(String name) {
    final trimmed = name.trim();
    final firstName = trimmed.split(' ').first;
    final parts = trimmed.split(' ').where((p) => p.isNotEmpty).toList();
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : (trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[300]!, width: 2),
              color: Colors.grey[200],
            ),
            child: Center(
              child: Text(
                initials,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              trimmed,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
              maxLines: null,
              overflow: TextOverflow.visible,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            firstName,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            maxLines: null,
            overflow: TextOverflow.visible,
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsList(List<String> attachments) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: attachments
          .map((attachment) => InkWell(
                onTap: () => _openAttachment(attachment),
                borderRadius: BorderRadius.circular(20),
                child: Chip(
                  label: Text(
                    attachment,
                    style: GoogleFonts.poppins(fontSize: 12),
                    overflow: TextOverflow.visible,
                  ),
                  avatar: Icon(Icons.attach_file, size: 16, color: Colors.blue),
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  deleteIcon:
                      Icon(Icons.open_in_new, size: 16, color: Colors.blue),
                  onDeleted: () => _openAttachment(attachment),
                ),
              ))
          .toList(),
    );
  }

  String _attachmentDisplayName(String attachment) {
    final trimmed = attachment.trim();
    if (trimmed.isEmpty) return 'Attachment';

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        return Uri.decodeComponent(uri.pathSegments.last);
      }
    }

    return trimmed.split('/').last.split(Platform.pathSeparator).last;
  }

  Future<void> _openAttachment(String attachment) async {
    final trimmed = attachment.trim();
    if (trimmed.isEmpty) return;

    try {
      String? publicUrl;

      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        publicUrl = trimmed;
      } else if (_task?.firebaseId != null) {
        final candidates = <String>{
          trimmed,
          trimmed.split('/').last,
          trimmed.split(Platform.pathSeparator).last,
        };

        for (final candidate in candidates) {
          if (candidate.isEmpty) continue;
          try {
            final storageRef = FirebaseStorage.instance
                .ref()
                .child('tasks/${_task!.firebaseId}/attachments/$candidate');
            publicUrl = await storageRef.getDownloadURL();
            break;
          } catch (_) {}
        }
      }

      if (publicUrl == null || publicUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Attachment not found. It may not have been uploaded.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AttachmentViewerScreen(
            publicUrl: publicUrl!,
            title: _attachmentDisplayName(trimmed),
          ),
        ),
      );
    } catch (e) {
      print('❌ Error opening attachment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Unable to open attachment')),
        );
      }
    }
  }

  Widget _buildSectionLabel(String label) {
    final parts = label.split('\n');

    if (parts.length > 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            parts[0],
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          Text(
            parts[1],
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      );
    } else {
      return Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      );
    }
  }

  Widget _buildBorderedFieldWithLabel(
      {required String label, required Widget child}) {
    final parts = label.split('\n');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (parts.length > 1) ...[
            Text(
              parts[0],
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[500],
              ),
            ),
            Text(
              parts[1],
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ] else ...[
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildLinkedReportSection(String reportId) {
    return FutureBuilder<ReportModel?>(
      future: _fetchReportById(reportId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: Colors.blue.withOpacity(0.3), width: 1.5),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Loading linked report...',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        final report = snapshot.data;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.link, size: 18, color: Colors.blue[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Linked',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
              Text(
                'Report',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: report != null ? () => _openLinkedReport(report) : null,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.description_outlined,
                          color: Colors.blue[700],
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report?.name ?? 'Report #$reportId',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              maxLines: null,
                              overflow: TextOverflow.visible,
                            ),
                            if (report != null)
                              Text(
                                'Created: ${DateFormat('dd MMM yyyy').format(report.createdAt)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.blue[400],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<ReportModel?> _fetchReportById(String reportId) async {
    try {
      final reportsProvider =
          Provider.of<ReportProvider>(context, listen: false);
      // Search in cached reports first
      for (var report in reportsProvider.reports) {
        if (report.id == reportId) {
          return report;
        }
      }
      // If not found, return null (report might have been deleted)
      return null;
    } catch (e) {
      print('❌ Error fetching report: $e');
      return null;
    }
  }

  void _openLinkedReport(ReportModel report) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => report_detail.ReportDetailScreen(
          report: report,
          folderName: '', // Will be loaded inside the screen
        ),
      ),
    );
  }

  Widget _buildTaskItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool isCompleted,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 24),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentIcon(IconData icon, Color color) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF8BC6EC), Color(0xFF9599E2)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }

  Widget _buildAddButton() {
    return Column(
      children: [
        DottedBorder(
          borderType: BorderType.Circle,
          color: Colors.black,
          strokeWidth: 2,
          dashPattern: [6, 4],
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Icon(Icons.add, size: 25, color: Colors.black),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Add',
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildMemberAvatar(String name) {
    // Get first name only
    final firstName = name.split(' ').first;
    // Get initials (first letters of first and last name)
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : (name.isNotEmpty ? name[0].toUpperCase() : '');

    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey[300]!, width: 2),
            color: Colors.grey[200],
          ),
          child: Center(
            child: Text(
              initials,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 60,
          child: Text(
            firstName,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.visible,
            maxLines: null,
          ),
        ),
      ],
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> commentData) {
    final name = commentData['author_name'] as String? ?? 'Unknown';
    final content = commentData['content'] as String? ?? '';
    final time = _formatCommentTime(commentData['created_at']);
    final type = commentData['type'] as String? ?? 'text';
    final audioUrl = commentData['audio_url'] as String?;
    final commentId = commentData['id'] as String? ?? '';
    final duration = commentData['duration'] as String? ?? '00:00';
    final authorPhoto = commentData['author_photo'] as String?;

    final displayName = name.isNotEmpty ? name : 'Unknown';
    final isVoice = type == 'voice' && audioUrl != null;
    final isCurrentlyPlaying = _playingCommentId == commentId && _isPlaying;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCommentAvatar(displayName, authorPhoto, size: 40),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.visible,
                    ),
                  ),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
              SizedBox(height: 4),
              if (isVoice)
                // Voice comment with play button
                GestureDetector(
                  onTap: () => _playVoiceComment(commentId, audioUrl),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isCurrentlyPlaying
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isCurrentlyPlaying
                            ? Colors.green
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCurrentlyPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          size: 28,
                          color: isCurrentlyPlaying
                              ? Colors.green
                              : Colors.grey[600],
                        ),
                        SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Voice Message',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              duration,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        if (isCurrentlyPlaying) ...[
                          SizedBox(width: 12),
                          SizedBox(
                            width: 60,
                            child: LinearProgressIndicator(
                              backgroundColor: Colors.grey[300],
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.green),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                // Text comment
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
