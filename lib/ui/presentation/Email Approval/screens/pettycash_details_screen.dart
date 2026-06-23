import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/Email%20Approval/widgets/approval_action_buttons.dart';
import 'package:el_race/ui/presentation/my_documents/screens/attachment_viewer_screen.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class PettyCashDetailsScreen extends StatefulWidget {
  final String requestId;
  final String type;
  final Map<String, dynamic>? initialData;

  const PettyCashDetailsScreen({
    super.key,
    required this.requestId,
    required this.type,
    this.initialData,
  });

  @override
  State<PettyCashDetailsScreen> createState() => _PettyCashDetailsScreenState();
}

class _PettyCashDetailsScreenState extends State<PettyCashDetailsScreen> {
  bool _isLoading = true;
  String _error = '';
  final PageController _linesPageController = PageController();
  int _currentLinesPage = 0;

  Map<String, dynamic> _formData = const {};
  List<dynamic> _attachmentIds = const [];

  String _safe(dynamic v, {String fallback = ''}) {
    if (v == null) return fallback;
    if (v == false || v == true) return fallback;
    final s = v.toString();
    if (s.isEmpty) return fallback;
    final lower = s.toLowerCase();
    if (lower == 'false' || lower == 'true' || lower == 'null') return fallback;
    return s;
  }

  String _pick(List<dynamic> values, {String fallback = ''}) {
    for (final v in values) {
      final s = _safe(v);
      if (s.isNotEmpty) return s;
    }
    return fallback;
  }

  String _displayOrNA(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? 'N/A' : normalized;
  }

  String _normalizeApiComment(String value) {
    final v = value.trim();
    if (v.isEmpty) return '';
    final lower = v.toLowerCase();
    if (lower == 'no comments' ||
        lower == 'no comment' ||
        lower == 'n/a' ||
        lower == 'na' ||
        lower == '-' ||
        lower == '--') {
      return '';
    }
    return v;
  }

  String _formatAmount(dynamic value) {
    final raw = _safe(value);
    if (raw.trim().isEmpty) return '0';
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.\-]'), '');
    final parsed = double.tryParse(cleaned);
    if (parsed == null) return '0';
    if (parsed % 1 == 0) {
      return NumberFormat('#,##0', 'en_US').format(parsed);
    }
    return NumberFormat('#,##0.##', 'en_US').format(parsed);
  }

  String _formatDate(dynamic value) {
    final raw = _safe(value);
    if (raw.trim().isEmpty) return 'N/A';
    final normalized = raw.contains(' ') ? raw.replaceFirst(' ', 'T') : raw;
    final parsed = DateTime.tryParse(normalized) ?? DateTime.tryParse(raw);
    if (parsed == null) return _displayOrNA(raw);
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  bool _isInvalidImageValue(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'false' || normalized == 'null') {
      return true;
    }

    if (normalized.endsWith('/false') ||
        normalized.contains('/image/false') ||
        normalized.contains('employee/image/false')) {
      return true;
    }

    return false;
  }

  String _pickImage(List<dynamic> values) {
    for (final value in values) {
      final candidate = _safe(value);
      if (candidate.isEmpty) continue;
      if (_isInvalidImageValue(candidate)) continue;
      return candidate;
    }
    return '';
  }

  String _normalizeImageUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || _isInvalidImageValue(trimmed)) return '';

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    if (trimmed.startsWith('/')) {
      return 'https://erp.elrace.com$trimmed';
    }

    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      return 'https://erp.elrace.com/public/employee/image/$trimmed';
    }

    if (trimmed.startsWith('public/') || trimmed.startsWith('employee/')) {
      return 'https://erp.elrace.com/$trimmed';
    }

    return trimmed;
  }

  Widget _buildAvatar(String imageData, {required double iconSize}) {
    final trimmed = imageData.trim();
    if (trimmed.isEmpty) {
      return Icon(
        Icons.person,
        color: const Color(0xFF6B6B6B),
        size: iconSize,
      );
    }

    final normalizedUrl = _normalizeImageUrl(trimmed);
    final isUrl = normalizedUrl.startsWith('http://') ||
        normalizedUrl.startsWith('https://');
    if (isUrl) {
      final token = SharedPref.getLoginData().result?.token;
      final headers = <String, String>{
        'Accept': 'image/*,*/*;q=0.8',
      };
      if (_safe(token).isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      return Image.network(
        normalizedUrl,
        fit: BoxFit.cover,
        headers: headers,
        errorBuilder: (_, __, ___) => Icon(
          Icons.person,
          color: const Color(0xFF6B6B6B),
          size: iconSize,
        ),
      );
    }

    try {
      String base64String = trimmed;
      if (trimmed.contains('base64,')) {
        base64String = trimmed.split('base64,')[1];
      }
      final bytes = base64Decode(base64String);
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(
          Icons.person,
          color: const Color(0xFF6B6B6B),
          size: iconSize,
        ),
      );
    } catch (_) {
      return Icon(
        Icons.person,
        color: const Color(0xFF6B6B6B),
        size: iconSize,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _formData = Map<String, dynamic>.from(widget.initialData!);
      final maybeAttachments = _formData['attachment_ids'];
      if (maybeAttachments is List) {
        _attachmentIds = maybeAttachments;
      }
    }
    _fetchPettyCashDetails();
  }

  @override
  void dispose() {
    _linesPageController.dispose();
    super.dispose();
  }

  Future<void> _fetchPettyCashDetails() async {
    final token = SharedPref.getLoginData().result?.token;
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final url = Uri.parse('https://erp.elrace.com/api/get_petty_cash_details');
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'params': {
        'petty_cash_id': int.tryParse(widget.requestId),
      },
    });

    print('══════════ [PETTYCASH] API REQUEST ══════════');
    print('[PETTYCASH] URL: $url');
    print('[PETTYCASH] METHOD: GET');
    print(
        '[PETTYCASH] HEADERS: ${headers.map((k, v) => MapEntry(k, k == "Authorization" ? "Bearer ***" : v))}');
    print('[PETTYCASH] BODY: $body');
    print('═════════════════════════════════════════════');

    try {
      final request = http.Request('GET', url)
        ..headers.addAll(headers)
        ..body = body;

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      print('══════════ [PETTYCASH] API RESPONSE ══════════');
      print('[PETTYCASH] STATUS: ${response.statusCode}');
      print('[PETTYCASH] BODY: ${response.body}');
      print('══════════════════════════════════════════════');

      final data = jsonDecode(response.body);

      if (data['result'] != null) {
        final result = data['result'] as Map;
        final rawFormData = result['data'] as Map? ?? {};
        final formData = _normalizePettyCashFormData(
          Map<String, dynamic>.from(rawFormData),
        );
        final attachmentList = result['attachment_ids'] as List? ??
            (formData['attachment_ids'] as List? ?? []);

        _logApiCompatibilityIssues(formData);

        print('[PETTYCASH] PARSED formData keys: ${formData.keys.toList()}');
        print('[PETTYCASH] PARSED formData: $formData');
        print('[PETTYCASH] PARSED attachmentIds: $attachmentList');
        print('[PETTYCASH] COMMENT CANDIDATES: ${jsonEncode({
              'api_comment': formData['api_comment'],
              'comment': formData['comment'],
              'comments': formData['comments'],
              'note': formData['note'],
              'notes': formData['notes'],
              'remark': formData['remark'],
              'remarks': formData['remarks'],
              'description': formData['description'],
              'manager_comment': formData['manager_comment'],
              'approver_comment': formData['approver_comment'],
              'reviewer_comment': formData['reviewer_comment'],
              'request_comment': formData['request_comment'],
              'employee_comment': formData['employee_comment'],
            })}');

        setState(() {
          final merged = Map<String, dynamic>.from(_formData);
          merged.addAll(Map<String, dynamic>.from(formData));
          _formData = merged;
          _attachmentIds = attachmentList;
          _isLoading = false;
        });
      } else {
        print(
            '[PETTYCASH] ERROR: result is null. Full response: ${response.body}');
        setState(() {
          _isLoading = false;
          if (_formData.isEmpty) {
            _error = 'Failed to load Petty Cash details';
          }
        });
      }
    } catch (e) {
      print('══════════ [PETTYCASH] API ERROR ══════════');
      print('[PETTYCASH] EXCEPTION: $e');
      print('═══════════════════════════════════════════');
      setState(() {
        _isLoading = false;
        if (_formData.isEmpty) {
          _error = e.toString();
        }
      });
    }
  }

  Map<String, dynamic> _normalizePettyCashFormData(
    Map<String, dynamic> raw,
  ) {
    final normalized = Map<String, dynamic>.from(raw);

    final formViewRaw = raw['form_view'];
    if (formViewRaw is Map) {
      normalized.addAll(Map<String, dynamic>.from(formViewRaw));
    }

    final tableViewRaw = raw['table_view'];
    if (tableViewRaw is List) {
      normalized['lines'] = tableViewRaw
          .whereType<Map>()
          .map((line) =>
              _normalizePettyCashLine(Map<String, dynamic>.from(line)))
          .toList();
    } else if (normalized['lines'] is List) {
      final lines = normalized['lines'] as List;
      normalized['lines'] = lines
          .whereType<Map>()
          .map((line) =>
              _normalizePettyCashLine(Map<String, dynamic>.from(line)))
          .toList();
    }

    normalized['request_no'] = _pick([
      normalized['request_no'],
      normalized['pettycash_no'],
      normalized['petty_cash_no'],
      normalized['name'],
      normalized['ref_no'],
    ]);

    normalized['pettycash_holder'] = _pick([
      normalized['pettycash_holder'],
      normalized['holder_name'],
      normalized['holder'],
    ]);

    final holderRaw =
        raw['pettycash_holder'] ?? raw['holder'] ?? raw['holder_name'];
    if (holderRaw is Map) {
      final holderMap = Map<String, dynamic>.from(holderRaw);
      normalized['holder_name'] = _pick([
        holderMap['name'],
        holderMap['holder_name'],
        holderMap['employee_name'],
        holderMap['emp_name'],
        normalized['holder_name'],
        normalized['pettycash_holder'],
      ]);
      normalized['holder_image'] = _pick([
        holderMap['holder_image_url'],
        holderMap['emp_image_url'],
        holderMap['image_emp'],
        holderMap['employee_image'],
        holderMap['image'],
        holderMap['avatar'],
        holderMap['photo'],
        holderMap['id'],
        normalized['holder_image'],
      ]);
      normalized['pettycash_holder'] = _pick([
        normalized['holder_name'],
        normalized['pettycash_holder'],
      ]);
    }

    normalized['requester_name'] = _pick([
      normalized['requester_name'],
      normalized['requester'],
      normalized['emp_name'],
      normalized['employee_name'],
      normalized['employee'],
    ]);

    normalized['pettycash_limit'] = _pick([
      normalized['pettycash_limit'],
      normalized['limit'],
      normalized['limit_amount'],
      normalized['amount'],
      normalized['total_amount'],
    ]);

    normalized['total'] = _pick([
      normalized['total'],
      normalized['total_amount'],
      normalized['amount_total'],
      normalized['amount'],
    ]);

    // Keep a unified, API-driven comment field for UI + approve/reject payload.
    normalized['api_comment'] = _normalizeApiComment(_pick([
      normalized['api_comment'],
      normalized['comment'],
      normalized['comments'],
      normalized['note'],
      normalized['notes'],
      normalized['remark'],
      normalized['remarks'],
      normalized['description'],
      normalized['manager_comment'],
      normalized['approver_comment'],
      normalized['reviewer_comment'],
      normalized['request_comment'],
      normalized['employee_comment'],
    ]));

    return normalized;
  }

  Map<String, dynamic> _normalizePettyCashLine(Map<String, dynamic> line) {
    final normalizedLine = Map<String, dynamic>.from(line);

    normalizedLine['description'] = _pick([
      normalizedLine['description'],
      normalizedLine['name'],
      normalizedLine['remarks'],
      normalizedLine['project'],
    ]);

    normalizedLine['amount'] = _pick([
      normalizedLine['amount'],
      normalizedLine['price'],
      normalizedLine['subtotal'],
      normalizedLine['unit_price'],
    ]);

    normalizedLine['date'] = _pick([
      normalizedLine['date'],
      normalizedLine['expense_date'],
      normalizedLine['line_date'],
    ]);

    return normalizedLine;
  }

  void _logApiCompatibilityIssues(Map<String, dynamic> formData) {
    final requiredAny = <String, List<String>>{
      'requestNo': [
        'request_no',
        'pettycash_no',
        'petty_cash_no',
        'name',
        'ref_no'
      ],
      'pettycashLimit': ['pettycash_limit', 'limit', 'limit_amount', 'amount'],
      'pettycashHolder': ['pettycash_holder', 'holder_name', 'holder'],
      'requester': [
        'requester_name',
        'requester',
        'emp_name',
        'employee_name',
        'employee'
      ],
      'total': ['total', 'total_amount', 'amount_total', 'amount'],
    };

    for (final entry in requiredAny.entries) {
      final hasValue = entry.value.any((k) {
        final v = formData[k];
        final s = _safe(v);
        return s.isNotEmpty;
      });
      if (!hasValue) {
        debugPrint(
          '⚠️ [PETTYCASH][API_COMPAT] Missing ${entry.key}. Expected one of: ${entry.value.join(', ')}',
        );
      }
    }

    final lines = formData['lines'];
    if (lines != null && lines is List && lines.isNotEmpty) {
      final firstLine = lines.first;
      if (firstLine is Map) {
        final lineMap = Map<String, dynamic>.from(firstLine);
        final hasDescription = _safe(lineMap['description']).isNotEmpty ||
            _safe(lineMap['name']).isNotEmpty;
        final hasAmount = _safe(lineMap['amount']).isNotEmpty ||
            _safe(lineMap['price']).isNotEmpty ||
            _safe(lineMap['subtotal']).isNotEmpty;
        if (!hasDescription) {
          debugPrint(
            '⚠️ [PETTYCASH][API_COMPAT] Line item description missing. Expected: description or name',
          );
        }
        if (!hasAmount) {
          debugPrint(
            '⚠️ [PETTYCASH][API_COMPAT] Line item amount missing. Expected: amount or price or subtotal',
          );
        }
      }
    }
  }

  /// Extracts a plain integer attachment ID from whatever shape the item is.
  int? _extractAttachmentId(dynamic item) {
    if (item is int) return item;
    if (item is Map) {
      final raw = item['attachment_id'] ?? item['id'] ?? item['attachmentId'];
      if (raw is int) return raw;
      return int.tryParse(raw?.toString() ?? '');
    }
    return int.tryParse(item?.toString() ?? '');
  }

  /// Tries to extract a human-readable filename from an attachment item.
  String _extractAttachmentHintName(dynamic item, {int fallbackIndex = 0}) {
    if (item is Map) {
      for (final key in ['name', 'attachment_name', 'filename', 'file_name']) {
        final v = item[key]?.toString().trim() ?? '';
        if (v.isNotEmpty &&
            v.toLowerCase() != 'false' &&
            v.toLowerCase() != 'null' &&
            v.toLowerCase() != 'attachment_id') {
          return v;
        }
      }
    }
    // Fall back to petty cash request name + index
    final reqName = _safe(_formData['name']);
    if (reqName.isNotEmpty) {
      return '$reqName${fallbackIndex > 0 ? ' (${fallbackIndex + 1})' : ''}';
    }
    return 'Attachment${fallbackIndex > 0 ? ' ${fallbackIndex + 1}' : ''}';
  }

  Future<Map<String, dynamic>> _fetchAttachmentDetails(int attachmentId) async {
    final token = SharedPref.getLoginData().result?.token ?? '';
    const endpoint = 'https://erp.elrace.com/api/get_attachment_details';
    final url = Uri.parse(endpoint);
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final bodyMap = {
      'jsonrpc': '2.0',
      'params': {'attachment_id': attachmentId},
    };
    final bodyJson = jsonEncode(bodyMap);

    // ── curl log ──────────────────────────────────────────────────────
    debugPrint(
      "curl -X GET '$endpoint' "
      "-H 'Content-Type: application/json' "
      "-H 'Accept: application/json' "
      "-H 'Authorization: Bearer $token' "
      "--data '${bodyJson.replaceAll("'", "'\\''")}'",
    );

    final request = http.Request('GET', url)
      ..headers.addAll(headers)
      ..body = bodyJson;
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    debugPrint(
        '══════ [PETTYCASH] get_attachment_details ($attachmentId) ══════');
    debugPrint('STATUS: ${response.statusCode}');
    debugPrint('BODY: ${response.body}');
    debugPrint(
        '═══════════════════════════════════════════════════════════════');

    final decoded = jsonDecode(response.body) as Map;
    final result = decoded['result'] as Map?;

    if (result == null || result['status'] != 'success') {
      throw Exception(
        result?['message']?.toString() ??
            decoded['error']?.toString() ??
            'Failed to load attachment (HTTP ${response.statusCode})',
      );
    }

    final data = result['data'];
    if (data is! Map) throw Exception('Invalid attachment details response');
    return Map<String, dynamic>.from(data);
  }

  Future<void> _openSingleAttachment(int attachmentId,
      {String hintName = ''}) async {
    bool loaderVisible = true;
    void dismissLoader() {
      if (!loaderVisible) return;
      loaderVisible = false;
      if (mounted && Navigator.canPop(context)) Navigator.of(context).pop();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final details = await _fetchAttachmentDetails(attachmentId);
      dismissLoader();

      final publicUrl = (details['public_url'] ?? '').toString().trim();

      // Prefer attachment_name from API, but fall back to petty cash request
      // name if the API returns a raw field key like "attachment_id".
      final rawName = (details['attachment_name'] ?? '').toString().trim();
      final looksLikeKey = rawName.isEmpty ||
          rawName.toLowerCase() == 'attachment_id' ||
          rawName.toLowerCase() == 'false' ||
          rawName.toLowerCase() == 'null';
      final fallbackName = hintName.isNotEmpty
          ? hintName
          : _safe(_formData['name'], fallback: 'Petty Cash Attachment');
      final fileName = looksLikeKey ? fallbackName : rawName;

      if (publicUrl.isEmpty) {
        throw Exception('Attachment URL is empty');
      }

      final attachmentType =
          (details['attachment_type'] ?? '').toString().trim();

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AttachmentViewerScreen(
            publicUrl: publicUrl,
            title: fileName,
            attachmentType: attachmentType.isNotEmpty ? attachmentType : null,
          ),
        ),
      );
    } catch (e) {
      dismissLoader();
      if (!mounted) return;
      Fluttertoast.showToast(
        msg: e.toString(),
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.black,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _viewAttachment() async {
    if (_attachmentIds.isEmpty) return;

    // Collect valid integer IDs
    // Build (id, hintName) pairs
    final items = _attachmentIds
        .asMap()
        .entries
        .map((e) {
          final id = _extractAttachmentId(e.value);
          if (id == null) return null;
          final name =
              _extractAttachmentHintName(e.value, fallbackIndex: e.key);
          return (id: id, name: name);
        })
        .whereType<({int id, String name})>()
        .toList();

    if (items.isEmpty) {
      Fluttertoast.showToast(
        msg: 'No valid attachment IDs found.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.black,
        textColor: Colors.white,
      );
      return;
    }

    // If only one attachment, open directly
    if (items.length == 1) {
      await _openSingleAttachment(items.first.id, hintName: items.first.name);
      return;
    }

    // Multiple attachments — let user pick
    if (!mounted) return;
    final picked = await showModalBottomSheet<({int id, String name})>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 14.w, 16.w, 4.w),
              child: Text(
                'Select Attachment',
                style: GoogleFonts.poppins(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Divider(),
            ...items.map((item) => ListTile(
                  leading: const Icon(Icons.picture_as_pdf_rounded),
                  title: Text(
                    item.name,
                    style: GoogleFonts.poppins(fontSize: 13.sp),
                  ),
                  onTap: () => Navigator.of(ctx).pop(item),
                )),
            SizedBox(height: 8.w),
          ],
        ),
      ),
    );

    if (picked != null) {
      await _openSingleAttachment(picked.id, hintName: picked.name);
    }
  }

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding:
          padding ?? EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFF9F9F9F), width: 1),
      ),
      child: child,
    );
  }

  Widget _label(String text, {TextAlign? align, double? size}) {
    return Text(
      text,
      textAlign: align,
      style: GoogleFonts.poppins(
        fontSize: size ?? 11.sp,
        fontWeight: FontWeight.w700,
        color: const Color(0xFFB4B4B4),
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _value(String text,
      {double? size, FontWeight? weight, Color? color, TextAlign? align}) {
    return Text(
      _displayOrNA(text),
      textAlign: align,
      style: GoogleFonts.poppins(
        fontSize: size ?? 14.sp,
        fontWeight: weight ?? FontWeight.w700,
        color: color ?? const Color(0xFF0E0E0E),
        letterSpacing: 0.1,
      ),
      maxLines: 2,
      overflow: TextOverflow.visible,
    );
  }

  Widget _lineItemTile({
    required String description,
    required String lineDate,
    required String amount,
    required bool showDivider,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _value(description, size: 11.sp, weight: FontWeight.w700),
                  SizedBox(height: 6.w),
                  _label(_formatDate(lineDate), size: 8.sp),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            _value(
              _formatAmount(amount),
              size: 11.sp,
              weight: FontWeight.w700,
              color: const Color(0xFF15A98A),
            ),
          ],
        ),
        if (showDivider) ...[
          SizedBox(height: 10.w),
          const Divider(
            color: Color(0xFFD2D2D2),
            height: 1,
          ),
          SizedBox(height: 10.w),
        ],
      ],
    );
  }

  List<List<dynamic>> _chunkLines(List<dynamic> source, int chunkSize) {
    if (source.isEmpty) return const [];
    final chunks = <List<dynamic>>[];
    for (int i = 0; i < source.length; i += chunkSize) {
      final end =
          (i + chunkSize < source.length) ? i + chunkSize : source.length;
      chunks.add(source.sublist(i, end));
    }
    return chunks;
  }

  @override
  Widget build(BuildContext context) {
    final requestNo = _pick([
      _formData['request_no'],
      _formData['pettycash_no'],
      _formData['petty_cash_no'],
      _formData['name'],
      _formData['ref_no'],
    ], fallback: widget.requestId);

    final requester = _pick([
      _formData['requester_name'],
      _formData['requester'],
      _formData['emp_name'],
      _formData['employee_name'],
      _formData['employee'],
    ]);

    final pettycashHolder = _pick([
      _formData['pettycash_holder'],
      _formData['holder_name'],
      _formData['holder'],
    ]);

    final pettycashLimit = _pick([
      _formData['pettycash_limit'],
      _formData['limit'],
      _formData['limit_amount'],
      _formData['amount'],
    ]);

    final projectName = _pick([
      _formData['project_name'],
      _formData['project_title'],
      _formData['project'],
    ]);

    final date = _pick([
      _formData['date'],
      _formData['request_date'],
      _formData['req_date'],
    ]);

    final employeeTitle = _pick([
      _formData['job_title'],
      _formData['job_position'],
      _formData['department'],
      _formData['section'],
    ]);

    final employeeImage = _pickImage([
      _formData['emp_image_url'],
      _formData['image_emp'],
      _formData['employee_image'],
      _formData['emp_image'],
      _formData['employee_img'],
      _formData['image'],
      _formData['avatar'],
      _formData['photo'],
      _formData['profile_image'],
    ]);

    final holderImage = _pickImage([
      _formData['holder_image_url'],
      _formData['pettycash_holder_image_url'],
      _formData['pettycash_holder_image'],
      _formData['holder_image'],
      _formData['holder_img'],
      _formData['pettycash_holder_avatar'],
      (_formData['pettycash_holder'] is Map)
          ? (_formData['pettycash_holder'] as Map)['image_emp']
          : null,
      (_formData['holder'] is Map)
          ? (_formData['holder'] as Map)['image_emp']
          : null,
      (_formData['holder_name'] is Map)
          ? (_formData['holder_name'] as Map)['image_emp']
          : null,
      _formData['image_emp'],
    ]);

    final lines = _formData['lines'] as List? ?? [];
    final linePages = _chunkLines(lines, 6);
    final safePageIndex = linePages.isEmpty
        ? 0
        : _currentLinesPage.clamp(0, linePages.length - 1) as int;
    final currentPageLineCount =
        linePages.isEmpty ? 1 : linePages[safePageIndex].length;
    final dividerCount =
        currentPageLineCount > 0 ? currentPageLineCount - 1 : 0;
    final lineSliderHeight = linePages.isNotEmpty
        ? (24.w + (currentPageLineCount * 38.w) + (dividerCount * 19.w))
            .clamp(84.w, 460.w)
        : 84.w;
    final hasAttachments = _attachmentIds.isNotEmpty;
    final apiComment = _normalizeApiComment(_pick([
      _formData['api_comment'],
      _formData['comment'],
      _formData['comments'],
      _formData['note'],
      _formData['notes'],
      _formData['remark'],
      _formData['remarks'],
      _formData['description'],
      _formData['manager_comment'],
      _formData['approver_comment'],
      _formData['reviewer_comment'],
      _formData['request_comment'],
      _formData['employee_comment'],
    ]));
    final requestDateLabel = _formatDate(date);

    final userId =
        SharedPref.getLoginData().result?.data?.uid?.toString() ?? '';

    final pillWidth = 156.7.w;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: HeaderWidget(),
      body: SafeArea(
        top: false,
        child: (_isLoading && _formData.isEmpty)
            ? const Center(child: CircularProgressIndicator())
            : _error.isNotEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Text(
                        _error,
                        style: GoogleFonts.poppins(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      if (_isLoading && _formData.isNotEmpty)
                        const LinearProgressIndicator(
                          backgroundColor: Color(0xFFE0E0E0),
                          color: Color(0xFF0A3887),
                          minHeight: 3,
                        ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                              horizontal: 18.w, vertical: 10.w),
                          child: Column(
                            children: [
                              SizedBox(height: 8.w),
                              Text(
                                'Petty cash',
                                style: GoogleFonts.poppins(
                                  fontSize: 33.sp / 2,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF0E0E0E),
                                ),
                              ),
                              SizedBox(height: 14.w),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 92.w,
                                    height: 92.w,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      border: Border.all(
                                        color: const Color(0xFFDADADA),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: _buildAvatar(
                                        employeeImage,
                                        iconSize: 42.w,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(left: 12.w),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _displayOrNA(requester),
                                            style: GoogleFonts.poppins(
                                              fontSize: 18.sp,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF181818),
                                            ),
                                          ),
                                          if (employeeTitle.trim().isNotEmpty)
                                            Padding(
                                              padding:
                                                  EdgeInsets.only(top: 2.w),
                                              child: Text(
                                                employeeTitle,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 15.sp,
                                                  fontWeight: FontWeight.w500,
                                                  color:
                                                      const Color(0xFF888888),
                                                ),
                                              ),
                                            ),
                                          SizedBox(height: 8.w),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 6.w,
                                                    vertical: 5.w,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFC9C9C9),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20.r),
                                                  ),
                                                  child: FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Text(
                                                      requestNo,
                                                      maxLines: 1,
                                                      textAlign:
                                                          TextAlign.center,
                                                      style:
                                                          GoogleFonts.poppins(
                                                        fontSize: 13.sp,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: const Color(
                                                            0xFF1E1E1E),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 8.w),
                                              Expanded(
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 6.w,
                                                    vertical: 5.w,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFF2EA6DE),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20.r),
                                                  ),
                                                  child: FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Text(
                                                      requestDateLabel,
                                                      maxLines: 1,
                                                      textAlign:
                                                          TextAlign.center,
                                                      style:
                                                          GoogleFonts.poppins(
                                                        fontSize: 13.sp,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: const Color(
                                                            0xFF1E1E1E),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 14.w),
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14.r),
                                  border: Border.all(
                                      color: const Color(0xFF9E9E9E), width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 12.w, vertical: 8.w),
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                              color: Color(0xFFE2E2E2),
                                              width: 1),
                                        ),
                                      ),
                                      child: Text(
                                        'Petty cash holder',
                                        style: GoogleFonts.poppins(
                                          fontSize: 15.sp,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF5A5A5A),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 12.w, vertical: 10.w),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 34.w,
                                            height: 34.w,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white,
                                              border: Border.all(
                                                color: const Color(0xFFDADADA),
                                                width: 1,
                                              ),
                                            ),
                                            child: ClipOval(
                                              child: _buildAvatar(
                                                holderImage,
                                                iconSize: 18.w,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8.w),
                                          Expanded(
                                            child: Text(
                                              _displayOrNA(pettycashHolder),
                                              style: GoogleFonts.poppins(
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF111111),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 12.w),
                              SizedBox(
                                height: lineSliderHeight,
                                child: linePages.isNotEmpty
                                    ? PageView.builder(
                                        controller: _linesPageController,
                                        itemCount: linePages.length,
                                        onPageChanged: (index) {
                                          if (!mounted) return;
                                          setState(() {
                                            _currentLinesPage = index;
                                          });
                                        },
                                        itemBuilder: (context, pageIndex) {
                                          final pageLines =
                                              linePages[pageIndex];
                                          return _card(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                for (int i = 0;
                                                    i < pageLines.length;
                                                    i++)
                                                  () {
                                                    final lineMap =
                                                        pageLines[i] as Map? ??
                                                            {};
                                                    final description = _pick([
                                                      lineMap['description'],
                                                      lineMap['name'],
                                                      projectName,
                                                    ],
                                                        fallback:
                                                            'Project name');
                                                    final lineDate = _pick([
                                                      lineMap['date'],
                                                      lineMap['line_date'],
                                                      date,
                                                    ]);
                                                    final amount = _pick([
                                                      lineMap['amount'],
                                                      lineMap['price'],
                                                      lineMap['subtotal'],
                                                      pettycashLimit,
                                                    ]);

                                                    return _lineItemTile(
                                                      description: description,
                                                      lineDate: lineDate,
                                                      amount: amount,
                                                      showDivider: i <
                                                          pageLines.length - 1,
                                                    );
                                                  }(),
                                              ],
                                            ),
                                          );
                                        },
                                      )
                                    : _card(
                                        child: _lineItemTile(
                                          description:
                                              _displayOrNA(projectName),
                                          lineDate: date,
                                          amount: pettycashLimit,
                                          showDivider: false,
                                        ),
                                      ),
                              ),
                              SizedBox(height: 8.w),
                              if (linePages.length > 1)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    for (int i = 0; i < linePages.length; i++)
                                      Container(
                                        width: 8.w,
                                        height: 8.w,
                                        margin: EdgeInsets.symmetric(
                                            horizontal: 5.w),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: i == _currentLinesPage
                                              ? const Color(0xFF919191)
                                              : Colors.transparent,
                                          border: Border.all(
                                            color: const Color(0xFF9D9D9D),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                  ],
                                )
                              else
                                SizedBox(height: 8.w),
                              SizedBox(height: 10.w),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(8.w),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14.r),
                                  border: Border.all(
                                      color: const Color(0xFF9E9E9E), width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Comment',
                                          style: GoogleFonts.poppins(
                                            fontSize: 15.sp,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF5A5A5A),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '${apiComment.characters.length}/50',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFFA8A8A8),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 6.w),
                                    Container(
                                      width: double.infinity,
                                      constraints:
                                          BoxConstraints(minHeight: 38.w),
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 10.w, vertical: 8.w),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF4F4F4),
                                        borderRadius:
                                            BorderRadius.circular(10.r),
                                        border: Border.all(
                                            color: const Color(0xFFDADADA),
                                            width: 1),
                                      ),
                                      child: Text(
                                        apiComment,
                                        maxLines: null,
                                        overflow: TextOverflow.visible,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF3B3B3B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (hasAttachments) ...[
                                SizedBox(height: 16.w),
                                SizedBox(
                                  width: 0.88.sw,
                                  child: InkWell(
                                    onTap: _viewAttachment,
                                    borderRadius: BorderRadius.circular(14.r),
                                    child: Container(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 13.w),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(14.r),
                                        gradient: const LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Color(0xFF777B84),
                                            Color(0xFF63676F),
                                          ],
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.attach_file_rounded,
                                            color: Colors.white,
                                            size: 20.sp,
                                          ),
                                          SizedBox(width: 6.w),
                                          Text(
                                            'View Attachments',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              SizedBox(height: 14.w),
                            ],
                          ),
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 18.w, vertical: 8.w),
                          child: Container(
                            width: 394.w,
                            height: 79.16.w,
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            decoration: BoxDecoration(
                              color: const Color.fromRGBO(176, 176, 176, 0.7),
                              borderRadius: BorderRadius.circular(30.r),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color.fromRGBO(0, 0, 0, 0.25),
                                  blurRadius: 25,
                                  offset: Offset(0, 5),
                                )
                              ],
                            ),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: ApprovalActionButtons(
                                  requestId: widget.requestId,
                                  type: widget.type,
                                  userIds: [userId],
                                  variant: ApprovalActionButtonsVariant.pill,
                                  showHrApproveConfirmation: true,
                                  useProvidedComment: true,
                                  commentProvider: () => apiComment,
                                  pillWidth: pillWidth,
                                  pillHeight: 39.18.w,
                                  pillSpacing: 40.2.w,
                                  pillBorderRadius:
                                      BorderRadius.circular(113.r),
                                  pillTextStyle: GoogleFonts.afacad(
                                    fontSize: 26.4.sp,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class PettyCashSeeMoreScreen extends StatelessWidget {
  final String requestId;
  final String type;
  final String userId;
  final List<dynamic> lines;
  final String projectName;
  final String date;

  const PettyCashSeeMoreScreen({
    super.key,
    required this.requestId,
    required this.type,
    required this.userId,
    required this.lines,
    required this.projectName,
    required this.date,
  });

  String _safe(dynamic v, {String fallback = ''}) {
    if (v == null) return fallback;
    if (v == false || v == true) return fallback;
    final s = v.toString();
    if (s.isEmpty) return fallback;
    final lower = s.toLowerCase();
    if (lower == 'false' || lower == 'true' || lower == 'null') return fallback;
    return s;
  }

  String _pick(List<dynamic> values, {String fallback = ''}) {
    for (final v in values) {
      final s = _safe(v);
      if (s.isNotEmpty) return s;
    }
    return fallback;
  }

  String _displayOrNA(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? 'N/A' : normalized;
  }

  String _formatAmount(dynamic value) {
    final raw = _safe(value);
    if (raw.trim().isEmpty) return '0';
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.\-]'), '');
    final parsed = double.tryParse(cleaned);
    if (parsed == null) return '0';
    if (parsed % 1 == 0) {
      return NumberFormat('#,##0', 'en_US').format(parsed);
    }
    return NumberFormat('#,##0.##', 'en_US').format(parsed);
  }

  String _formatDate(dynamic value) {
    final raw = _safe(value);
    if (raw.trim().isEmpty) return 'N/A';
    final normalized = raw.contains(' ') ? raw.replaceFirst(' ', 'T') : raw;
    final parsed = DateTime.tryParse(normalized) ?? DateTime.tryParse(raw);
    if (parsed == null) return _displayOrNA(raw);
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  Widget _value(String text,
      {double? size, FontWeight? weight, Color? color, TextAlign? align}) {
    return Text(
      _displayOrNA(text),
      textAlign: align,
      style: GoogleFonts.poppins(
        fontSize: size ?? 14.sp,
        fontWeight: weight ?? FontWeight.w700,
        color: color ?? const Color(0xFF0E0E0E),
        letterSpacing: 0.1,
      ),
      maxLines: 2,
      overflow: TextOverflow.visible,
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 11.sp,
        fontWeight: FontWeight.w700,
        color: const Color(0xFFB4B4B4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pillWidth =
        ((MediaQuery.of(context).size.width - 96.w) / 2).clamp(110.w, 150.w);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: const HeaderWidget(),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.w),
                child: Column(
                  children: [
                    SizedBox(height: 4.w),
                    Text(
                      'PETTYCASH DETAILS',
                      style: GoogleFonts.poppins(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0E0E0E),
                        letterSpacing: 0.6,
                      ),
                    ),
                    SizedBox(height: 10.w),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                          horizontal: 16.w, vertical: 14.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F4F4),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                            color: const Color(0xFF9F9F9F), width: 1),
                      ),
                      child: Column(
                        children: [
                          if (lines.isNotEmpty)
                            ...lines.asMap().entries.map((entry) {
                              final i = entry.key;
                              final lineMap = (entry.value as Map?) ?? {};
                              final description = _pick([
                                lineMap['description'],
                                lineMap['name'],
                                projectName,
                              ], fallback: 'Item');
                              final lineDate = _pick([
                                lineMap['date'],
                                lineMap['line_date'],
                                date,
                              ]);
                              final amount = _pick([
                                lineMap['amount'],
                                lineMap['price'],
                                lineMap['subtotal'],
                              ]);

                              return Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _value(description,
                                                size: 14.sp,
                                                weight: FontWeight.w700),
                                            SizedBox(height: 6.w),
                                            _label(_formatDate(lineDate)),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      _value(
                                        _formatAmount(amount),
                                        size: 14.sp,
                                        weight: FontWeight.w700,
                                        color: const Color(0xFF15A98A),
                                      ),
                                    ],
                                  ),
                                  if (i < lines.length - 1) ...[
                                    SizedBox(height: 10.w),
                                    const Divider(
                                      color: Color(0xFFD2D2D2),
                                      height: 1,
                                    ),
                                    SizedBox(height: 10.w),
                                  ],
                                ],
                              );
                            })
                          else
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _value(projectName,
                                          size: 14.sp, weight: FontWeight.w700),
                                      SizedBox(height: 6.w),
                                      _label(_formatDate(date)),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                _value(
                                  _formatAmount(''),
                                  size: 14.sp,
                                  weight: FontWeight.w700,
                                  color: const Color(0xFF15A98A),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
                border: Border(
                  top: BorderSide(color: Color(0xFFD4D4D4), width: 1),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 38.w, vertical: 10.w),
                  child: ApprovalActionButtons(
                    requestId: requestId,
                    type: type,
                    userIds: [userId],
                    variant: ApprovalActionButtonsVariant.pill,
                    showHrApproveConfirmation: true,
                    pillWidth: pillWidth,
                    pillHeight: 36.w,
                    pillSpacing: 24.w,
                    pillBorderRadius: BorderRadius.circular(20.r),
                    pillTextStyle: GoogleFonts.poppins(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
