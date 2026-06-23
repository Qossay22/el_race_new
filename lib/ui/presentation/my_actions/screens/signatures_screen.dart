import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:el_race/ui/presentation/my_actions/data/my_actions_models.dart';
import 'package:el_race/ui/presentation/my_actions/data/my_actions_repository.dart';
import 'package:el_race/ui/presentation/my_documents/screens/attachment_viewer_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class SignaturesScreen extends StatefulWidget {
  const SignaturesScreen({super.key});

  @override
  State<SignaturesScreen> createState() => _SignaturesScreenState();
}

class _SignaturesScreenState extends State<SignaturesScreen> {
  final MyActionsRepository _repo = MyActionsRepository();
  late final Future<List<_SignatureFileItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchSignatureFiles();
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final s = value?.toString().trim() ?? '';
      if (s.isNotEmpty && s.toLowerCase() != 'null') return s;
    }
    return '';
  }

  bool _isSheetSignedStatus(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'signed' || normalized == 'approved';
  }

  String _formatDisplayDate(String? rawDate) {
    final input = (rawDate ?? '').trim();
    if (input.isEmpty) return '';

    final parsed = DateTime.tryParse(input);
    if (parsed == null) return input;
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  String _extractFileNameFromUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    final uri = _safeTryParseUri(trimmed);

    final queryCandidates = <String>[
      uri?.queryParameters['filename'] ?? '',
      uri?.queryParameters['file_name'] ?? '',
      uri?.queryParameters['name'] ?? '',
      uri?.queryParameters['download'] ?? '',
    ];
    for (final value in queryCandidates) {
      final v = value.trim();
      if (v.isNotEmpty) {
        return _safeDecodeUriComponent(v);
      }
    }

    final segments = uri?.pathSegments ?? const <String>[];
    if (segments.isEmpty) return '';
    for (int i = segments.length - 1; i >= 0; i--) {
      final raw = segments[i].trim();
      if (raw.isEmpty) continue;
      final decoded = _safeDecodeUriComponent(raw);
      if (_isBadFileName(decoded)) continue;
      return decoded;
    }

    // If URI parsing fails, use a defensive raw split fallback.
    final fallbackRaw = trimmed.split('?').first.split('/').last.trim();
    if (fallbackRaw.isNotEmpty && !_isBadFileName(fallbackRaw)) {
      return _safeDecodeUriComponent(fallbackRaw);
    }

    return '';
  }

  Uri? _safeTryParseUri(String raw) {
    try {
      return Uri.parse(raw);
    } catch (_) {
      // Attempt minimal sanitization for malformed percent-encoding.
      try {
        final sanitized = raw.replaceAll('%', '%25').replaceAll(' ', '%20');
        return Uri.parse(sanitized);
      } catch (_) {
        return null;
      }
    }
  }

  String _safeDecodeUriComponent(String value) {
    try {
      return Uri.decodeComponent(value);
    } catch (_) {
      return value;
    }
  }

  bool _isBadFileName(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    const blocked = <String>{
      'internal',
      'web',
      'content',
      'download',
      'binary',
      'file',
    };
    return blocked.contains(normalized);
  }

  _SignatureFileItem _toSignatureFileItem(MyActionItem item) {
    final link = (item.reportLink ?? '').trim();
    final fileNameFromUrl = _extractFileNameFromUrl(link);
    final rawItemName = item.name.trim();
    final displayName = fileNameFromUrl.isNotEmpty
        ? fileNameFromUrl
        : (!_isBadFileName(rawItemName) && rawItemName.isNotEmpty
            ? rawItemName
            : 'Signed Sheet #${item.id}.pdf');

    return _SignatureFileItem(
      id: item.id,
      fileName: displayName,
      displayDate: _formatDisplayDate(item.date),
      fileUrl: link,
      sortDate: DateTime.tryParse(item.date ?? ''),
    );
  }

  Future<List<_SignatureFileItem>> _fetchSignedFilesFromFirebase() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid.isEmpty) {
      return const <_SignatureFileItem>[];
    }

    try {
      final userChatsSnapshot = await FirebaseFirestore.instance
          .collection('userChats')
          .doc(currentUid)
          .collection('chats')
          .limit(200)
          .get();

      final files = <_SignatureFileItem>[];

      List<_SignatureFileItem> extractFromSnapshot(
        QuerySnapshot<Map<String, dynamic>> snapshot,
      ) {
        final extracted = <_SignatureFileItem>[];

        for (final msgDoc in snapshot.docs) {
          final data = msgDoc.data();
          final type = (data['type'] ?? '').toString().trim().toLowerCase();
          final signStatus =
              (data['sign_status'] ?? '').toString().trim().toLowerCase();
          final signedBy = (data['signed_by'] ?? '').toString().trim();
          final senderId = (data['sender_id'] ?? '').toString().trim();
          final mimeType =
              (data['mime_type'] ?? '').toString().trim().toLowerCase();

          final fileUrl = _firstNonEmpty([
            data['signed_pdf_url'],
            data['media_url'],
            data['file_url'],
            data['url'],
          ]);

          final rawFileName = (data['file_name'] ?? '').toString().trim();
          final fileNameFromUrl = _extractFileNameFromUrl(fileUrl);
          final effectiveName =
              rawFileName.isNotEmpty ? rawFileName : fileNameFromUrl;
          final lowerName = effectiveName.toLowerCase();
          final isPdf = mimeType.contains('pdf') || lowerName.endsWith('.pdf');

          final isSignedDoc = type == 'signable_doc' &&
              (signStatus == 'signed' || fileUrl.isNotEmpty);
          final isPdfFileMessage = type == 'file' && isPdf;
          final isMine = signedBy == currentUid || senderId == currentUid;

          if ((!isSignedDoc && !isPdfFileMessage) ||
              !isMine ||
              fileUrl.isEmpty) {
            continue;
          }

          final displayName =
              (!_isBadFileName(rawFileName) && rawFileName.isNotEmpty)
                  ? rawFileName
                  : (fileNameFromUrl.isNotEmpty
                      ? fileNameFromUrl
                      : 'Signed Sheet #${msgDoc.id}.pdf');

          final signedAt = (data['signed_at'] as Timestamp?)?.toDate() ??
              (data['created_at'] as Timestamp?)?.toDate();

          extracted.add(
            _SignatureFileItem(
              id: msgDoc.id.hashCode,
              fileName: displayName,
              displayDate: _formatDisplayDate(signedAt?.toIso8601String()),
              fileUrl: fileUrl,
              sortDate: signedAt,
            ),
          );
        }

        return extracted;
      }

      final futures = <Future<List<_SignatureFileItem>>>[];

      for (final userChatDoc in userChatsSnapshot.docs) {
        final chatId = userChatDoc.id;
        final chatRef = FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('messages');

        final signableFuture = chatRef
            .where('type', isEqualTo: 'signable_doc')
            .limit(80)
            .get()
            .then(extractFromSnapshot);

        final fileFuture = chatRef
            .where('type', isEqualTo: 'file')
            .limit(80)
            .get()
            .then(extractFromSnapshot);

        futures.add(signableFuture);
        futures.add(fileFuture);
      }

      final results = await Future.wait(futures);
      for (final batch in results) {
        files.addAll(batch);
      }

      debugPrint(
        'Signature Firebase source: chats=${userChatsSnapshot.docs.length}, files=${files.length}',
      );

      return files;
    } catch (e) {
      debugPrint('Firebase signed documents fetch failed: $e');
      return const <_SignatureFileItem>[];
    }
  }

  Future<List<_SignatureFileItem>> _fetchSignatureFiles() async {
    final apiItems = await _fetchSignatureItems();
    final apiFiles = apiItems.map(_toSignatureFileItem).toList(growable: false);
    final firebaseFiles = await _fetchSignedFilesFromFirebase();

    final merged = <String, _SignatureFileItem>{};

    for (final item in apiFiles) {
      if (item.fileUrl.trim().isEmpty) continue;
      merged['url-${item.fileUrl.trim()}'] = item;
    }

    for (final item in firebaseFiles) {
      if (item.fileUrl.trim().isEmpty) continue;
      merged['url-${item.fileUrl.trim()}'] = item;
    }

    final result = merged.values.toList(growable: false);
    result.sort((a, b) {
      final aDate = a.sortDate;
      final bDate = b.sortDate;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return result;
  }

  Future<void> _openSignatureFile(
    BuildContext context,
    _SignatureFileItem item,
  ) async {
    final rawUrl = item.fileUrl.trim();
    if (rawUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file URL available')),
      );
      return;
    }

    final uri = _safeTryParseUri(rawUrl);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid file URL')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttachmentViewerScreen(
          publicUrl: uri.toString(),
          title: item.fileName,
        ),
      ),
    );
  }

  Future<List<MyActionItem>> _fetchSignatureItems() async {
    List<MyActionItem> directSignatures = const <MyActionItem>[];
    List<MyActionItem> timesheets = const <MyActionItem>[];

    try {
      directSignatures =
          await _fetchAllMyActionsPages(MyActionsType.signatures);
    } catch (e) {
      debugPrint('Signatures API failed: $e');
    }

    try {
      timesheets = await _fetchAllMyActionsPages(MyActionsType.timesheet);
    } catch (e) {
      debugPrint('Timesheet API failed for signature merge: $e');
    }

    final signedSheets =
        timesheets.where((item) => _isSheetSignedStatus(item.status)).toList();

    final merged = <String, MyActionItem>{};

    for (final item in directSignatures) {
      final key = 'sig-${item.id}-${item.name}-${item.date ?? ''}';
      merged[key] = item;
    }

    for (final item in signedSheets) {
      final key = 'sheet-${item.id}-${item.name}-${item.date ?? ''}';
      merged[key] = item;
    }

    final list = merged.values.toList(growable: false);
    list.sort((a, b) => (b.date ?? '').compareTo(a.date ?? ''));
    return list;
  }

  Future<List<MyActionItem>> _fetchAllMyActionsPages(MyActionsType type) async {
    final items = <MyActionItem>[];
    var page = 1;
    const maxPages = 100;
    const pageSize = 10;

    while (page <= maxPages) {
      final pageItems = await _repo.fetchByType(
        type,
        page: page,
        perPage: pageSize,
      );
      items.addAll(pageItems);

      if (pageItems.length < pageSize) {
        break;
      }
      page++;
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      appBar: const HeaderWidget(),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<_SignatureFileItem>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(20.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off,
                          size: 60.w, color: const Color(0xFFB5B7C1)),
                      SizedBox(height: 16.h),
                      Text(
                        'Service not available',
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF5A5A5A),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'This feature is currently unavailable.\nPlease try again later.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 13.sp,
                          color: const Color(0xFF9AA0A6),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final fileItems = snapshot.data ?? const <_SignatureFileItem>[];

            if (fileItems.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.edit_document,
                      size: 80.w,
                      color: const Color(0xFFB5B7C1),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'No signatures found',
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF9AA0A6),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView(
              padding: EdgeInsets.only(top: 8.h, bottom: 80.h),
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/png/my-reports-frame.png',
                          width: 26.w,
                          height: 26.w,
                          fit: BoxFit.contain,
                          color: const Color(0xFFD21B2E),
                          colorBlendMode: BlendMode.srcIn,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'SIGNATURE',
                          style: GoogleFonts.poppins(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF101C36),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ...fileItems.map(
                  (item) => Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 7.h),
                    child: _SignatureFileCard(
                      item: item,
                      onTap: item.fileUrl.isNotEmpty
                          ? () => _openSignatureFile(context, item)
                          : null,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SignatureFileCard extends StatelessWidget {
  final _SignatureFileItem item;
  final VoidCallback? onTap;

  const _SignatureFileCard({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28.r),
      child: Container(
        height: 102.h,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(28.r),
          border: Border.all(color: const Color(0xFFA9A9A9), width: 1),
        ),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        child: Row(
          children: [
            Image.asset(
              'assets/newapp/pdf.png',
              width: 70.w,
              height: 70.w,
              fit: BoxFit.contain,
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.fileName.trim().isEmpty ? 'File Name' : item.fileName,
                    maxLines: null,
                    overflow: TextOverflow.visible,
                    style: GoogleFonts.poppins(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111111),
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    item.displayDate.isEmpty ? '-' : item.displayDate,
                    maxLines: null,
                    overflow: TextOverflow.visible,
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF232323),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignatureFileItem {
  final int id;
  final String fileName;
  final String displayDate;
  final String fileUrl;
  final DateTime? sortDate;

  const _SignatureFileItem({
    required this.id,
    required this.fileName,
    required this.displayDate,
    required this.fileUrl,
    this.sortDate,
  });
}
