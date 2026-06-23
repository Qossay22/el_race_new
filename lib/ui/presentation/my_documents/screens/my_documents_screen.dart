import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:file_picker/file_picker.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:el_race/utils/api_logger.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

import '../../../widgets/custom_slider_button.dart';
import 'attachment_viewer_screen.dart';
import 'family_insurance_request_screen.dart';
import 'family_documents_tab.dart';
import 'company_documents_tab.dart';
import 'share_documents_tab.dart';

const String _familyTaggedDocumentIdsKey = 'my_documents_family_tagged_ids_v1';

Set<int> _loadTaggedDocumentIds(String key) {
  try {
    final raw = SharedPref.preferences.getPreferenceString(key);
    if (raw.trim().isEmpty) return <int>{};

    final decoded = jsonDecode(raw);
    if (decoded is! List) return <int>{};

    return decoded
        .map((e) => int.tryParse(e.toString()))
        .whereType<int>()
        .toSet();
  } catch (_) {
    return <int>{};
  }
}

Future<void> _saveTaggedDocumentIds(String key, Set<int> ids) async {
  await SharedPref.preferences
      .setPreferencesString(key, jsonEncode(ids.toList(growable: false)));
}

Future<void> _tagDocumentAsFamily(int id) async {
  final ids = _loadTaggedDocumentIds(_familyTaggedDocumentIdsKey);
  ids.add(id);
  await _saveTaggedDocumentIds(_familyTaggedDocumentIdsKey, ids);
}

class MyDocumentsScreen extends StatefulWidget {
  const MyDocumentsScreen({
    super.key,
  });

  @override
  State<MyDocumentsScreen> createState() => _MyDocumentsScreenState();
}

class _MyDocumentsScreenState extends State<MyDocumentsScreen> {
  /// 0 = My Documents, 1 = Family Documents, 2 = Company Documents, 3 = Share Documents
  int currentIndex = 0;
  int _companyTabVersion = 0;
  int _shareTabVersion = 0;
  List<Map<String, dynamic>> documents = [];
  bool _loading = false;
  String? _error;
  String _statTotal = '-';
  String _statRequested = '-';
  String _statExpiringSoon = '-';
  String _statExpired = '-';
  String? _activeMyDocType;
  String? _activeFamilyDocType;
  bool _familyInlineFormOpen = false;
  List<Map<String, dynamic>> _familyRecentActivities = [];

  // Search state
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  final bool _showSearch = false;
  String _query = '';
  double? _edgeSwipeStartX;
  bool _isHandlingEdgeSwipeBack = false;
  int _documentsFetchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _fetchMyDocuments();

    _searchController.addListener(() {
      final text = _searchController.text.trim();
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        setState(() {
          _query = text.toLowerCase();
        });
        _fetchMyDocuments(keyword: text);
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  bool _isTruthy(dynamic value) {
    if (value == true || value == 1) return true;
    final normalized = (value ?? '').toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  bool _hasFamilyMemberContext(Map<String, dynamic> map) {
    for (final key in const [
      'family_member',
      'family_member_name',
      'family_member_label',
      'relation',
    ]) {
      final value = (map[key] ?? '').toString().trim();
      if (value.isNotEmpty && value != '-' && value.toLowerCase() != 'false') {
        return true;
      }
    }
    return false;
  }

  bool _isFamilyDoc(Map<String, dynamic> raw) {
    final map = raw;
    if (_isTruthy(map['is_family']) || _isTruthy(map['family'])) return true;
    if (_hasFamilyMemberContext(map)) return true;

    final typeStr =
        (map['type'] ?? map['document_type'] ?? map['category'] ?? '')
            .toString()
            .toLowerCase();
    final titleStr = (map['title'] ?? '').toString().toLowerCase();
    final nameStr = (map['name'] ?? '').toString().toLowerCase();
    return typeStr.contains('family') ||
        titleStr.contains('family') ||
        nameStr.contains('family');
  }

  void _inheritFamilyMemberFields(
    Map<String, dynamic> doc,
    Map<String, dynamic> member,
    String memberName,
    String memberRelation,
  ) {
    doc['is_family'] = true;
    if ((doc['family_member_name'] ?? '').toString().trim().isEmpty &&
        memberName.isNotEmpty) {
      doc['family_member_name'] = memberName;
    }
    if ((doc['family_member'] ?? '').toString().trim().isEmpty &&
        memberRelation.isNotEmpty) {
      doc['family_member'] = memberRelation;
    }
    if ((doc['relation'] ?? '').toString().trim().isEmpty &&
        memberRelation.isNotEmpty) {
      doc['relation'] = memberRelation;
    }
    if ((doc['person_name'] ?? '').toString().trim().isEmpty &&
        memberName.isNotEmpty) {
      doc['person_name'] = memberName;
    }
    if ((doc['family_member_label'] ?? '').toString().trim().isEmpty) {
      final label = (member['family_member_label'] ?? memberRelation).toString();
      if (label.isNotEmpty) {
        doc['family_member_label'] = label;
      }
    }
    if ((doc['nationality'] ?? '').toString().trim().isEmpty) {
      final nationality = member['nationality'] ??
          member['family_member_nationality_id'] ??
          member['nationality_name'];
      if (nationality != null && nationality.toString().trim().isNotEmpty) {
        doc['nationality'] = nationality;
      }
    }
    if ((doc['birth_date'] ?? '').toString().trim().isEmpty) {
      final birthDate = member['birth_date'] ?? member['family_member_dob'];
      if (birthDate != null && birthDate.toString().trim().isNotEmpty) {
        doc['birth_date'] = birthDate;
      }
    }
  }

  List<dynamic> _flattenFamilyMemberGroups(List<dynamic> members) {
    final flattened = <dynamic>[];
    for (final memberRaw in members) {
      if (memberRaw is! Map) continue;
      final member = Map<String, dynamic>.from(memberRaw);
      final memberName = (member['family_member_name'] ??
              member['person_name'] ??
              member['name'] ??
              '')
          .toString()
          .trim();
      final memberRelation = (member['relation'] ??
              member['family_member'] ??
              member['family_member_label'] ??
              '')
          .toString()
          .trim();
      final docs = member['documents'];

      if (docs is List && docs.isNotEmpty) {
        for (final docRaw in docs) {
          if (docRaw is! Map) continue;
          final doc = Map<String, dynamic>.from(docRaw);
          _inheritFamilyMemberFields(doc, member, memberName, memberRelation);
          flattened.add(doc);
        }
      } else {
        _inheritFamilyMemberFields(member, member, memberName, memberRelation);
        flattened.add(member);
      }
    }
    return flattened;
  }

  void _debugPrintLong(String message) {
    if (!kDebugMode) return;
    const chunkSize = 800;
    for (var i = 0; i < message.length; i += chunkSize) {
      final end =
          (i + chunkSize < message.length) ? i + chunkSize : message.length;
      debugPrint(message.substring(i, end));
    }
  }

  void _debugFamilyLog(String title, [Object? payload]) {
    if (!kDebugMode) return;
    debugPrint('');
    debugPrint('================ FAMILY DOCUMENTS :: $title ================');
    if (payload != null) {
      if (payload is String) {
        _debugPrintLong(payload);
      } else {
        try {
          _debugPrintLong(const JsonEncoder.withIndent('  ').convert(payload));
        } catch (_) {
          _debugPrintLong(payload.toString());
        }
      }
    }
    debugPrint('============================================================');
  }

  dynamic _firstAttachmentIdFrom(dynamic attachmentIds) {
    if (attachmentIds is List && attachmentIds.isNotEmpty) {
      final first = attachmentIds.first;
      if (first is Map) {
        return first['attachment_id'] ?? first['id'] ?? first['attachmentId'];
      }
      return first;
    }
    if (attachmentIds is Map) {
      return attachmentIds['attachment_id'] ??
          attachmentIds['id'] ??
          attachmentIds['attachmentId'];
    }
    return null;
  }

  int? _firstAttachmentIdAsInt(Map<String, dynamic> document) {
    final raw = _firstAttachmentIdFrom(document['attachment_ids']);
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  Future<Map<String, dynamic>> _fetchAttachmentDetails(
      {required int attachmentId}) async {
    final token = SharedPref.getLoginData().result?.token ?? '';
    final url = Uri.parse('https://erp.elrace.com/api/get_attachment_details');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'params': {
        'attachment_id': attachmentId,
      },
    });

    // Backend expects GET (with JSON body) for this endpoint.
    final request = http.Request('GET', url)
      ..headers.addAll(headers)
      ..body = body;
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw Exception(
        'Failed to parse attachment details (HTTP ${response.statusCode}). '
        'Body: ${response.body.substring(0, response.body.length < 400 ? response.body.length : 400)}',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        decoded is Map
            ? (decoded['error']?.toString() ??
                decoded['result']?['message']?.toString() ??
                'Failed to load attachment details (HTTP ${response.statusCode})')
            : 'Failed to load attachment details (HTTP ${response.statusCode})',
      );
    }

    if (decoded is! Map) {
      throw Exception('Invalid attachment details response');
    }

    final result = decoded['result'];
    if (result == null || result['status'] != 'success') {
      throw Exception(
        result?['message']?.toString() ??
            decoded['error']?.toString() ??
            'Failed to load attachment details',
      );
    }

    final data = result['data'];
    if (data is! Map) {
      throw Exception('Invalid attachment details response');
    }

    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> _openDocumentAttachment(Map<String, dynamic> document) async {
    final attachmentId = _firstAttachmentIdAsInt(document);
    if (attachmentId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No attachment available for this document')),
      );
      return;
    }

    if (!mounted) return;
    var loaderVisible = true;
    void dismissLoader() {
      if (!loaderVisible) return;
      loaderVisible = false;
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final details = await _fetchAttachmentDetails(attachmentId: attachmentId);
      final publicUrl = (details['public_url'] ?? '').toString();
      final name =
          (details['attachment_name'] ?? document['name'] ?? 'Attachment')
              .toString();
      final type = (details['attachment_type'] ?? '').toString().toLowerCase();

      if (publicUrl.isEmpty) {
        throw Exception('Attachment URL is empty');
      }

      dismissLoader();
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AttachmentViewerScreen(
            publicUrl: publicUrl,
            title: name,
            attachmentType: type,
          ),
        ),
      );
    } catch (e) {
      dismissLoader();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _debugPrintBodyPreview(String body, {int maxChars = 4000}) {
    if (!kDebugMode) return;
    if (body.length <= maxChars) {
      _debugPrintLong(body);
      return;
    }
    _debugPrintLong(body.substring(0, maxChars));
    debugPrint('... (truncated, length=${body.length})');
  }

  Future<void> _debugPrintDocumentTapApi(Map<String, dynamic> document) async {
    if (!kDebugMode) return;

    debugPrint('=========== MY DOCUMENT (TAP) START ===========');
    debugPrint('Doc id: ${document['id']}');
    _debugPrintLong(jsonEncode(document));

    final attachmentId = _firstAttachmentIdFrom(document['attachment_ids']);
    if (attachmentId == null) {
      debugPrint('No attachment_ids found for this document.');
      debugPrint('============ MY DOCUMENT (TAP) END ============');
      return;
    }

    final token = SharedPref.getLoginData().result?.token ?? '';
    final url = Uri.parse('https://erp.elrace.com/api/get_attachment_details');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'params': {
        'attachment_id': attachmentId,
      },
    });

    try {
      final request = http.Request('GET', url)
        ..headers.addAll(headers)
        ..body = body;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('----- get_attachment_details RESPONSE -----');
      debugPrint('Status: ${response.statusCode}');
      _debugPrintBodyPreview(response.body);
      debugPrint('-----------------------------------------');
    } catch (e) {
      debugPrint('❌ get_attachment_details failed: $e');
    } finally {
      debugPrint('============ MY DOCUMENT (TAP) END ============');
    }
  }

  String? _normalizeDocType(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    if (value.isEmpty || value == 'all') return null;
    if (value == 'expiry_soon' || value == 'expired' || value == 'requested') {
      return value;
    }
    return null;
  }

  String _normalizeToken(dynamic value) {
    return (value ?? '')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Map<String, dynamic> _buildRecentActivityItem(Map<String, dynamic> map) {
    final stateRaw = (map['state'] ?? map['status'] ?? '').toString();
    final state = stateRaw.trim().toLowerCase();
    final name = (map['name'] ?? map['document_type'] ?? 'Document').toString();
    final member = (map['family_member'] ?? '').toString();
    final whenRaw =
        (map['request_date'] ?? map['create_date'] ?? map['write_date'] ?? '')
            .toString();

    return {
      'title': member.trim().isEmpty ? name : '$name ($member)',
      'state': state,
      'time': whenRaw,
    };
  }

  Future<void> _fetchFamilyRecentActivities() async {
    try {
      final token = SharedPref.getLoginData().result?.token ?? '';
      if (token.isEmpty) return;

      final url =
          Uri.parse('https://erp.elrace.com/api/get_employee_documents');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final body = jsonEncode({
        'jsonrpc': '2.0',
        'params': {
          'family_only': true,
          'doc_type': 'requested',
        },
      });

      _debugFamilyLog('RECENT ACTIVITY REQUEST', {
        'url': url.toString(),
        'method': 'POST',
        'headers': {
          ...headers,
          'Authorization': headers['Authorization'] != null ? 'Bearer ***' : '',
        },
        'body': jsonDecode(body),
      });

      final response = await http.post(url, headers: headers, body: body);
      _debugFamilyLog('RECENT ACTIVITY RAW RESPONSE', {
        'statusCode': response.statusCode,
        'body': response.body,
      });
      if (response.statusCode != 200) return;

      final decoded = jsonDecode(response.body);
      final result = (decoded is Map && decoded['result'] is Map)
          ? Map<String, dynamic>.from(decoded['result'] as Map)
          : (decoded is Map && decoded['status'] != null)
              ? Map<String, dynamic>.from(decoded)
              : <String, dynamic>{};
      final statusToken = _normalizeToken(result['status']);
      if (!(statusToken == 'success' ||
          statusToken == 'ok' ||
          statusToken == 'true')) {
        return;
      }

      final rawData = result['data'];
      final rawGroups = _extractDocumentGroups(rawData, familyOnly: true);
      if (rawGroups.isEmpty) return;

      final items = <Map<String, dynamic>>[];
      for (final raw in rawGroups) {
        if (raw is! Map) continue;
        final group = Map<String, dynamic>.from(raw);
        final nestedDocs = group['documents'];
        if (nestedDocs is List && nestedDocs.isNotEmpty) {
          for (final docRaw in nestedDocs) {
            if (docRaw is! Map) continue;
            items.add(
              _buildRecentActivityItem(Map<String, dynamic>.from(docRaw)),
            );
          }
        } else {
          items.add(_buildRecentActivityItem(group));
        }
      }

      _debugFamilyLog('RECENT ACTIVITY PARSED', {
        'count': items.length,
        'firstItem': items.isNotEmpty ? items.first : null,
      });

      if (!mounted) return;
      setState(() {
        _familyRecentActivities = items;
      });
    } catch (_) {
      // Keep UI stable if activity endpoint parsing fails.
    }
  }

  Future<void> _fetchMyDocuments({String? keyword, String? docType}) async {
    final fetchGeneration = ++_documentsFetchGeneration;
    final bool familyOnly = currentIndex == 1;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = SharedPref.getLoginData().result?.token ?? '';
      final url =
          Uri.parse('https://erp.elrace.com/api/get_employee_documents');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // Determine family_only based on currentIndex (0 = personal, 1 = family)
      final normalizedDocType = _normalizeDocType(
        docType ?? (familyOnly ? _activeFamilyDocType : _activeMyDocType),
      );
      final familyTaggedIds =
          _loadTaggedDocumentIds(_familyTaggedDocumentIdsKey);

      final Map<String, dynamic> params = {
        'family_only': familyOnly,
        if (normalizedDocType != null) 'doc_type': normalizedDocType,
      };

      final body = jsonEncode({'jsonrpc': '2.0', 'params': params});

      // 📤 Log Request
      ApiLogger.logRequest(
        endpoint: url.toString(),
        method: 'POST',
        headers: headers,
        body: body,
      );

      final startTime = DateTime.now();
      if (familyOnly) {
        _debugFamilyLog('DOCUMENTS REQUEST', {
          'url': url.toString(),
          'method': 'POST',
          'keyword': keyword,
          'params': params,
        });
      }

      final response = await http.post(url, headers: headers, body: body);
      final duration = DateTime.now().difference(startTime);

      if (familyOnly) {
        _debugFamilyLog('DOCUMENTS RAW RESPONSE', {
          'statusCode': response.statusCode,
          'durationMs': duration.inMilliseconds,
          'body': response.body,
        });
      }

      if (kDebugMode && familyOnly && normalizedDocType == 'requested') {
        debugPrint('======== FAMILY REQUESTED API START ========');
        debugPrint('URL: ${url.toString()}');
        debugPrint('Method: POST');
        debugPrint(
            'Headers: {Content-Type: application/json, Accept: application/json, Authorization: Bearer ***}');
        debugPrint('Body: $body');
        debugPrint('Status: ${response.statusCode}');
        _debugPrintLong(response.body);
        debugPrint('========= FAMILY REQUESTED API END =========');
      }

      if (kDebugMode) {
        debugPrint('=========== MY DOCUMENTS API RESPONSE START ===========');
        debugPrint('URL: $url');
        debugPrint('Status: ${response.statusCode}');
        _debugPrintLong(response.body);
        debugPrint('============ MY DOCUMENTS API RESPONSE END ============');
      }

      final data = jsonDecode(response.body);
      final resultEnvelope = (data is Map && data['result'] is Map)
          ? Map<String, dynamic>.from(data['result'] as Map)
          : (data is Map && data['status'] != null)
              ? Map<String, dynamic>.from(data)
              : <String, dynamic>{};
      final statusToken = _normalizeToken(resultEnvelope['status']);

      // 📥 Log Response
      ApiLogger.logResponse(
        endpoint: url.toString(),
        statusCode: response.statusCode,
        responseBody: data,
        duration: duration,
      );

      if (kDebugMode) {
        debugPrint('🔍 ====== MY DOCUMENTS PARSED JSON ======');
        _debugPrintLong(jsonEncode(data));
        debugPrint('🔍 ======================================');
      }

      if (response.statusCode == 200 &&
          (statusToken == 'success' ||
              statusToken == 'ok' ||
              statusToken == 'true')) {
        var resultData = resultEnvelope['data'];
        var clientSideFamilyFilter = false;
        var list = _extractDocumentGroups(
          resultData,
          familyOnly: familyOnly,
        );

        if (familyOnly && list.isEmpty) {
          final fallbackBody = jsonEncode({
            'jsonrpc': '2.0',
            'params': {
              'family_only': false,
              if (normalizedDocType != null) 'doc_type': normalizedDocType,
            },
          });
          final fallbackResponse =
              await http.post(url, headers: headers, body: fallbackBody);
          if (fallbackResponse.statusCode == 200) {
            final fallbackDecoded = jsonDecode(fallbackResponse.body);
            final fallbackEnvelope =
                (fallbackDecoded is Map && fallbackDecoded['result'] is Map)
                    ? Map<String, dynamic>.from(
                        fallbackDecoded['result'] as Map)
                    : (fallbackDecoded is Map &&
                            fallbackDecoded['status'] != null)
                        ? Map<String, dynamic>.from(fallbackDecoded)
                        : <String, dynamic>{};
            final fallbackStatus =
                _normalizeToken(fallbackEnvelope['status']);
            if (fallbackStatus == 'success' ||
                fallbackStatus == 'ok' ||
                fallbackStatus == 'true') {
              resultData = fallbackEnvelope['data'];
              list = _extractDocumentGroups(
                resultData,
                familyOnly: true,
              );
              if (list.isNotEmpty) {
                clientSideFamilyFilter = true;
              }
            }
          }
        }

        if (!mounted || fetchGeneration != _documentsFetchGeneration) return;

        if (kDebugMode) {
          debugPrint('📄 My Documents: total=${list.length}');
          for (var i = 0; i < list.length; i++) {
            _debugPrintLong('📄 Document $i: ${jsonEncode(list[i])}');
          }
        }
        String resolveIcon(String type, String name) {
          var icon = 'assets/png/other-documetns-icon.png';
          final t = type.toLowerCase();
          final n = name.toLowerCase();

          if (t.contains('pdf')) {
            icon = 'assets/png/pdf-icon.png';
          } else if (t.contains('certificate') || t.contains('cert')) {
            icon = 'assets/png/certificate-icon.png';
          } else if (t.contains('contract')) {
            icon = 'assets/png/contract-icon.png';
          } else if (t.contains('passport')) {
            icon = 'assets/png/passport.png';
          } else if (t.contains('emirates') ||
              t.contains('id') ||
              n.contains('emirates') ||
              n.contains('eid')) {
            icon = 'assets/png/emitates_id.png';
          } else if (t.contains('driving') ||
              t.contains('license') ||
              n.contains('driving') ||
              n.contains('license')) {
            icon = 'assets/png/driving_license.png';
          } else if (t.contains('insurance') || n.contains('insurance')) {
            icon = 'assets/png/personal-icon.png';
          } else if (t.contains('labor') || t.contains('labour')) {
            icon = 'assets/png/labor-cards-icon.png';
          } else if (t.contains('personal') || t.contains('profile')) {
            icon = 'assets/png/personal-icon.png';
          }

          return icon;
        }

        final mapped = <Map<String, dynamic>>[];

        for (final raw in list) {
          if (raw is! Map) continue;

          final group = Map<String, dynamic>.from(raw as Map);
          final groupType =
              (group['document_type'] ?? group['type'] ?? '-').toString();
          final groupDocs = group['documents'];

          if (groupDocs is List && groupDocs.isNotEmpty) {
            for (final docRaw in groupDocs) {
              if (docRaw is! Map) continue;
              final map = Map<String, dynamic>.from(docRaw as Map);

              final type =
                  (map['document_type'] ?? map['type'] ?? groupType).toString();
              final name = (map['name'] ?? '-').toString();
              final docIdInt = int.tryParse((map['id'] ?? '').toString());

              final resolvedIsFamily = clientSideFamilyFilter
                  ? (_isFamilyDoc(group) ||
                      _isFamilyDoc(map) ||
                      (docIdInt != null &&
                          familyTaggedIds.contains(docIdInt)))
                  : (familyOnly ||
                      _isFamilyDoc(group) ||
                      _isFamilyDoc(map) ||
                      (docIdInt != null &&
                          familyTaggedIds.contains(docIdInt)));

              mapped.add({
                'id': map['id'],
                'icon': resolveIcon(type, name),
                'title': type.toUpperCase(),
                'name': name,
                'issue_date': map['issue_date'],
                'expiry_date': map['expiry_date'],
                'description': map['description'],
                'attachment_ids': map['attachment_ids'] ??
                    (map['attachment_id'] != null
                        ? [
                            {
                              'attachment_id': map['attachment_id'],
                            }
                          ]
                        : []),
                'state': map['state'],
                'request_date': map['request_date'],
                'is_family': map['is_family'],
                'family_member': map['family_member'],
                'family_member_label': map['family_member_label'],
                'relation': map['relation'],
                'person_name': map['person_name'] ??
                    map['family_member_name'] ??
                    map['family_member'] ??
                    map['employee'],
                'family_member_name': map['family_member_name'],
                'passport_no': map['passport_no'] ?? map['passport_number'],
                'eid_no': map['eid_no'] ?? map['emirates_id_no'],
                'nationality': map['nationality'] ??
                    map['family_member_nationality_id'] ??
                    map['nationality_name'],
                'birth_date': map['birth_date'] ?? map['family_member_dob'],
                'passport_expiry_date':
                    map['passport_expiry_date'] ?? map['expiry_date'],
                'eid_expiry_date': map['eid_expiry_date'] ?? map['expiry_date'],
                'photo': map['photo'],
                'image_url': map['image_url'],
                'avatar': map['avatar'],
                '_isFamily': resolvedIsFamily,
              });
            }
          } else {
            final map = group;
            final type =
                (map['document_type'] ?? map['type'] ?? groupType).toString();
            final name = (map['name'] ?? '-').toString();
            final docIdInt = int.tryParse((map['id'] ?? '').toString());

            final resolvedIsFamily = clientSideFamilyFilter
                ? (_isFamilyDoc(group) ||
                    _isFamilyDoc(map) ||
                    (docIdInt != null && familyTaggedIds.contains(docIdInt)))
                : (familyOnly ||
                    _isFamilyDoc(group) ||
                    _isFamilyDoc(map) ||
                    (docIdInt != null && familyTaggedIds.contains(docIdInt)));

            mapped.add({
              'id': map['id'],
              'icon': resolveIcon(type, name),
              'title': type.toUpperCase(),
              'name': name,
              'issue_date': map['issue_date'],
              'expiry_date': map['expiry_date'],
              'description': map['description'],
              'attachment_ids': map['attachment_ids'] ??
                  (map['attachment_id'] != null
                      ? [
                          {
                            'attachment_id': map['attachment_id'],
                          }
                        ]
                      : []),
              'state': map['state'],
              'request_date': map['request_date'],
              'is_family': map['is_family'],
              'family_member': map['family_member'],
              'family_member_label': map['family_member_label'],
              'relation': map['relation'],
              'person_name': map['person_name'] ??
                  map['family_member_name'] ??
                  map['family_member'] ??
                  map['employee'],
              'family_member_name': map['family_member_name'],
              'passport_no': map['passport_no'] ?? map['passport_number'],
              'eid_no': map['eid_no'] ?? map['emirates_id_no'],
              'nationality': map['nationality'] ??
                  map['family_member_nationality_id'] ??
                  map['nationality_name'],
              'birth_date': map['birth_date'] ?? map['family_member_dob'],
              'passport_expiry_date':
                  map['passport_expiry_date'] ?? map['expiry_date'],
              'eid_expiry_date': map['eid_expiry_date'] ?? map['expiry_date'],
              'photo': map['photo'],
              'image_url': map['image_url'],
              'avatar': map['avatar'],
              '_isFamily': resolvedIsFamily,
            });
          }
        }

        // Apply search filter if keyword is provided
        final filteredMapped = keyword != null && keyword.trim().isNotEmpty
            ? mapped.where((d) {
                final title = (d['title'] ?? '').toString().toLowerCase();
                final name = (d['name'] ?? '').toString().toLowerCase();
                final searchTerm = keyword.toLowerCase();
                return title.contains(searchTerm) || name.contains(searchTerm);
              }).toList()
            : mapped;

        final strictVisibleMapped = familyOnly
            ? filteredMapped.where((d) => d['_isFamily'] == true).toList()
            : filteredMapped.where((d) => d['_isFamily'] != true).toList();

        // Fallback: if strict client-side tagging hides all docs but API returned
        // items, keep server-filtered data visible to avoid false empty states.
        final visibleMapped = strictVisibleMapped.isNotEmpty
            ? strictVisibleMapped
            : filteredMapped;

        final stats = _buildDocumentsStats(
          resultEnvelope: resultEnvelope,
          resultData: resultData,
          visibleDocs: visibleMapped,
        );

        if (familyOnly) {
          _debugFamilyLog('DOCUMENTS PARSED SUMMARY', {
            'docType': normalizedDocType,
            'mappedTotal': mapped.length,
            'visibleTotal': visibleMapped.length,
            'clientSideFamilyFilter': clientSideFamilyFilter,
            'stats': stats,
            'firstVisible':
                visibleMapped.isNotEmpty ? visibleMapped.first : null,
          });
        }

        if (!mounted || fetchGeneration != _documentsFetchGeneration) return;

        setState(() {
          documents = visibleMapped;
          _statTotal = stats['total'] ?? '-';
          _statRequested = stats['requested'] ?? '-';
          _statExpiringSoon = stats['expiringSoon'] ?? '-';
          _statExpired = stats['expired'] ?? '-';
          if (familyOnly) {
            _activeFamilyDocType = normalizedDocType;
          } else {
            _activeMyDocType = normalizedDocType;
          }
          _loading = false;
        });

        if (familyOnly) {
          unawaited(_fetchFamilyRecentActivities());
        }
      } else {
        if (!mounted || fetchGeneration != _documentsFetchGeneration) return;
        setState(() {
          _error = resultEnvelope['message']?.toString() ??
              (data is Map ? data['error']?.toString() : null) ??
              'Failed to load documents';
          _loading = false;
        });
      }
    } catch (e, stackTrace) {
      // ❌ Log Error
      ApiLogger.logError(
        endpoint: 'https://erp.elrace.com/api/get_employee_documents',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted || fetchGeneration != _documentsFetchGeneration) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<dynamic> _extractDocumentGroups(
    dynamic resultData, {
    bool familyOnly = false,
  }) {
    if (resultData is List) return resultData;
    if (resultData is Map) {
      final map = Map<String, dynamic>.from(resultData);

      if (familyOnly) {
        final scopedFamilyMembers = map['family_members'];
        if (scopedFamilyMembers is List && scopedFamilyMembers.isNotEmpty) {
          return _flattenFamilyMemberGroups(scopedFamilyMembers);
        }

        final scopedFamilyDocs = map['family_documents'] ?? map['family'];
        if (scopedFamilyDocs is List && scopedFamilyDocs.isNotEmpty) {
          return scopedFamilyDocs;
        }
      }

      final direct = map['documents'];
      if (direct is List && direct.isNotEmpty) return direct;

      final familyMembers = map['family_members'];
      if (familyMembers is List && familyMembers.isNotEmpty) {
        return _flattenFamilyMemberGroups(familyMembers);
      }

      final familyDocs = map['family_documents'] ?? map['family'];
      if (familyDocs is List && familyDocs.isNotEmpty) return familyDocs;

      final groups = map['groups'];
      if (groups is List && groups.isNotEmpty) return groups;

      final items = map['items'];
      if (items is List && items.isNotEmpty) return items;

      if (direct is List) return direct;
      if (groups is List) return groups;
      if (items is List) return items;
    }
    return const [];
  }

  String _countOrDash(dynamic value) {
    if (value == null || value == false) return '-';
    if (value is num) return value.toInt().toString();
    final parsed = int.tryParse(value.toString().trim());
    return parsed == null ? '-' : parsed.toString();
  }

  dynamic _pickCountFromMaps(
      List<Map<String, dynamic>> maps, List<String> keys) {
    for (final map in maps) {
      for (final key in keys) {
        if (map.containsKey(key) && map[key] != null && map[key] != false) {
          return map[key];
        }
      }
    }
    return null;
  }

  Map<String, String> _buildDocumentsStats({
    required Map<String, dynamic> resultEnvelope,
    required dynamic resultData,
    required List<Map<String, dynamic>> visibleDocs,
  }) {
    final envelopeSummary = resultEnvelope['summary'] is Map<String, dynamic>
        ? resultEnvelope['summary'] as Map<String, dynamic>
        : (resultEnvelope['summary'] is Map
            ? Map<String, dynamic>.from(resultEnvelope['summary'] as Map)
            : <String, dynamic>{});

    final envelopeCounters = resultEnvelope['counters'] is Map<String, dynamic>
        ? resultEnvelope['counters'] as Map<String, dynamic>
        : (resultEnvelope['counters'] is Map
            ? Map<String, dynamic>.from(resultEnvelope['counters'] as Map)
            : <String, dynamic>{});

    final primary = resultData is Map<String, dynamic>
        ? resultData
        : (resultData is Map
            ? Map<String, dynamic>.from(resultData)
            : <String, dynamic>{});
    final counters = primary['counters'] is Map<String, dynamic>
        ? primary['counters'] as Map<String, dynamic>
        : <String, dynamic>{};
    final summary = primary['summary'] is Map<String, dynamic>
        ? primary['summary'] as Map<String, dynamic>
        : <String, dynamic>{};

    final totalRaw = _pickCountFromMaps(
      [envelopeSummary, envelopeCounters, primary, counters, summary],
      ['total', 'total_count', 'documents_count'],
    );
    final requestedRaw = _pickCountFromMaps(
      [envelopeSummary, envelopeCounters, primary, counters, summary],
      ['requested', 'requested_count', 'pending_count'],
    );
    final expiringSoonRaw = _pickCountFromMaps(
      [envelopeSummary, envelopeCounters, primary, counters, summary],
      ['expiring_soon', 'expiringSoon', 'expiring_soon_count'],
    );
    final expiredRaw = _pickCountFromMaps(
      [envelopeSummary, envelopeCounters, primary, counters, summary],
      ['expired', 'expired_count'],
    );

    final now = DateTime.now();
    var expiringSoonComputed = 0;
    var expiredComputed = 0;
    var hasDateData = false;
    for (final doc in visibleDocs) {
      final raw = doc['expiry_date'];
      if (raw == null || raw == false) continue;
      final s = raw.toString().trim();
      if (s.isEmpty) continue;
      final parsed = DateTime.tryParse(s);
      if (parsed == null) continue;
      hasDateData = true;
      final days = parsed.difference(now).inDays;
      if (days < 0) {
        expiredComputed++;
      } else if (days <= 30) {
        expiringSoonComputed++;
      }
    }

    return {
      'total': totalRaw != null
          ? _countOrDash(totalRaw)
          : visibleDocs.length.toString(),
      'requested': _countOrDash(requestedRaw),
      'expiringSoon': expiringSoonRaw != null
          ? _countOrDash(expiringSoonRaw)
          : (hasDateData ? expiringSoonComputed.toString() : '-'),
      'expired': expiredRaw != null
          ? _countOrDash(expiredRaw)
          : (hasDateData ? expiredComputed.toString() : '-'),
    };
  }

  List<Map<String, dynamic>> _filteredDocs() {
    // Documents are already filtered by family_only from API
    // Just return them as is since filtering happens server-side
    return documents;
  }

  String _toTitleCase(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w.length == 1
            ? w.toUpperCase()
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  String _formatCardDate(dynamic raw) {
    if (raw == null || raw == false) return '-';
    final s = raw.toString().trim();
    if (s.isEmpty) return '-';
    try {
      final date = DateTime.parse(s);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (_) {
      return '-';
    }
  }

  Widget _buildDocumentsSummaryCard() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F4),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: const Color(0xFFD9D9D9)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCell(
                    label: 'Total',
                    value: _statTotal,
                    selected: _activeMyDocType == null,
                    onTap: () {
                      final keyword = _searchController.text.trim();
                      unawaited(_fetchMyDocuments(
                        keyword: keyword.isEmpty ? null : keyword,
                        docType: null,
                      ));
                    },
                  ),
                ),
                Container(
                    width: 1, height: 64.h, color: const Color(0xFFD1D1D1)),
                Expanded(
                  child: _buildSummaryCell(
                    label: 'Expiring Soon',
                    value: _statExpiringSoon,
                    dotColor: const Color(0xFFF0B321),
                    selected: _activeMyDocType == 'expiry_soon',
                    onTap: () {
                      final keyword = _searchController.text.trim();
                      unawaited(_fetchMyDocuments(
                        keyword: keyword.isEmpty ? null : keyword,
                        docType: 'expiry_soon',
                      ));
                    },
                  ),
                ),
              ],
            ),
            Container(height: 1, color: const Color(0xFFD1D1D1)),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCell(
                    label: 'Requested',
                    value: _statRequested,
                    selected: _activeMyDocType == 'requested',
                    onTap: () {
                      final keyword = _searchController.text.trim();
                      unawaited(_fetchMyDocuments(
                        keyword: keyword.isEmpty ? null : keyword,
                        docType: 'requested',
                      ));
                    },
                  ),
                ),
                Container(
                    width: 1, height: 64.h, color: const Color(0xFFD1D1D1)),
                Expanded(
                  child: _buildSummaryCell(
                    label: 'Expired',
                    value: _statExpired,
                    dotColor: const Color(0xFFC62828),
                    selected: _activeMyDocType == 'expired',
                    onTap: () {
                      final keyword = _searchController.text.trim();
                      unawaited(_fetchMyDocuments(
                        keyword: keyword.isEmpty ? null : keyword,
                        docType: 'expired',
                      ));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCell({
    required String label,
    required String value,
    Color? dotColor,
    bool selected = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(10.w, 8.h, 10.w, 7.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (dotColor != null) ...[
                    Container(
                      width: 7.w,
                      height: 7.w,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 4.w),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF262626),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 20.sp,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111111),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _myDocFilterMeta(String docType) {
    switch (docType) {
      case 'expiry_soon':
        return {
          'label': 'Expired soon',
          'value': _statExpiringSoon,
          'background': const Color(0xFF8B2AB3),
          'labelColor': Colors.white,
          'valueColor': Colors.white,
          'icon': Icons.access_time_rounded,
          'iconColor': Colors.white,
          'forceRedBorder': true,
        };
      case 'requested':
        return {
          'label': 'Requested',
          'value': _statRequested,
          'background': const Color(0xFFF6CC1B),
          'labelColor': Colors.black,
          'valueColor': Colors.black,
          'icon': Icons.assignment_outlined,
          'iconColor': Colors.black,
          'forceRedBorder': false,
        };
      case 'expired':
      default:
        return {
          'label': 'Expired',
          'value': _statExpired,
          'background': const Color(0xFFE2F3E9),
          'labelColor': const Color(0xFFBA1719),
          'valueColor': const Color(0xFFBA1719),
          'icon': Icons.error_outline_rounded,
          'iconColor': const Color(0xFFBA1719),
          'forceRedBorder': true,
        };
    }
  }

  Widget _buildMyFilteredMode(String docType) {
    final meta = _myDocFilterMeta(docType);
    final forceRedBorder = meta['forceRedBorder'] == true;
    final isExpiredSection = docType == 'expired';

    if (docType == 'requested') {
      return _buildMyRequestedFilteredMode(meta);
    }

    return ListView(
      padding: EdgeInsets.only(left: 12.w, right: 12.w, top: 14.h, bottom: 8.h),
      children: [
        Container(
          height: 96.h,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: meta['background'] as Color,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    meta['icon'] as IconData,
                    size: 32.sp,
                    color: meta['iconColor'] as Color,
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    meta['label'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: meta['labelColor'] as Color,
                    ),
                  ),
                ],
              ),
              Text(
                (meta['value'] ?? '-').toString(),
                style: GoogleFonts.poppins(
                  fontSize: 44.sp,
                  fontWeight: FontWeight.w700,
                  color: meta['valueColor'] as Color,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: _filteredDocs().length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12.w,
            mainAxisSpacing: 6.h,
            mainAxisExtent: 270.h,
          ),
          itemBuilder: (context, index) {
            final item = _filteredDocs()[index];
            final iconPath =
                (item['icon'] ?? 'assets/png/other-documetns-icon.png')
                    .toString();
            final rawName = (item['name'] ?? '').toString().trim();
            final rawType = (item['title'] ?? '').toString().trim();
            final typeLabel = _toTitleCase(rawType.replaceAll('_', ' '));
            final nameLabel = _toTitleCase(rawName.replaceAll('_', ' '));
            final displayName =
                _isMeaningfulDocLabel(nameLabel) ? nameLabel : typeLabel;
            final cardDateRaw =
                (item['expiry_date'] != null && item['expiry_date'] != false)
                    ? item['expiry_date']
                    : item['issue_date'];
            final date = _formatCardDate(cardDateRaw);
            final isRedBorderCard = forceRedBorder;
            final cardIconHeight = isRedBorderCard ? 78.h : 90.h;
            final gapAfterIcon = isRedBorderCard ? 6.h : 8.h;
            final gapBeforeButton = isRedBorderCard ? 2.h : 8.h;

            return GestureDetector(
              onTap: () {
                if (kDebugMode) {
                  unawaited(_debugPrintDocumentTapApi(item));
                }
                unawaited(_openDocumentAttachment(item));
              },
              onLongPress: () {
                _showDocumentDetailsDialog(context, item);
              },
              child: Padding(
                padding: EdgeInsets.only(bottom: isRedBorderCard ? 8.h : 0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24.r),
                    border: Border.all(
                      color: isRedBorderCard
                          ? const Color(0xFFBA1719)
                          : const Color(0xffD9D9D9),
                      width: isRedBorderCard ? 2 : 1,
                    ),
                    color: Colors.white,
                  ),
                  child: Padding(
                    padding: isExpiredSection
                        ? EdgeInsets.symmetric(horizontal: 8.w, vertical: 7.h)
                        : EdgeInsets.all(10.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: cardIconHeight,
                          child: Image.asset(
                            iconPath,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.insert_drive_file_outlined,
                              size: 44.sp,
                              color: const Color(0xff949494),
                            ),
                          ),
                        ),
                        SizedBox(height: gapAfterIcon),
                        Text(
                          displayName,
                          textAlign: TextAlign.center,
                          maxLines: null,
                          overflow: TextOverflow.visible,
                          style: GoogleFonts.poppins(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          date,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                            color: isRedBorderCard
                                ? const Color(0xFFBA1719)
                                : const Color(0xff949494),
                          ),
                        ),
                        if (isRedBorderCard) ...[
                          SizedBox(height: gapBeforeButton),
                          GestureDetector(
                            onTap: () {
                              unawaited(_showChangeDocumentDialog(
                                  item, DocumentDialogType.my));
                            },
                            child: Container(
                              constraints: BoxConstraints(minHeight: 24.h),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFF1B1F26),
                                    Color(0xFF717171)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 12.w,
                                    height: 12.w,
                                    child: Image.asset(
                                      'assets/newapp/newicon/change_document_icon.png',
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Icon(
                                        Icons.swap_horiz_rounded,
                                        color: Colors.white,
                                        size: 12.sp,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    'Change',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  String _requestedDocName(Map<String, dynamic> item) {
    final rawName = (item['name'] ?? '').toString().trim();
    final rawType =
        (item['title'] ?? item['document_type'] ?? '').toString().trim();
    final typeLabel = _toTitleCase(rawType.replaceAll('_', ' '));
    final nameLabel = _toTitleCase(rawName.replaceAll('_', ' '));
    return _isMeaningfulDocLabel(nameLabel) ? nameLabel : typeLabel;
  }

  String _documentNameForChange(Map<String, dynamic> item) {
    final rawName = (item['name'] ?? '').toString().trim();
    final rawType =
        (item['title'] ?? item['document_type'] ?? item['type'] ?? '')
            .toString()
            .trim();
    final typeLabel = _toTitleCase(rawType.replaceAll('_', ' '));
    final nameLabel = _toTitleCase(rawName.replaceAll('_', ' '));
    if (_isMeaningfulDocLabel(nameLabel)) return nameLabel;
    if (_isMeaningfulDocLabel(typeLabel)) return typeLabel;
    return 'Document';
  }

  Future<void> _showChangeDocumentDialog(
    Map<String, dynamic> item,
    DocumentDialogType type,
  ) async {
    await _showDocumentDialogByType(
      type,
      fixedDocumentType: _documentNameForChange(item),
    );
  }

  String _requestedIdNumber(Map<String, dynamic> item) {
    for (final key in [
      'id_number',
      'eid_no',
      'emirates_id_no',
      'emirates_id',
      'passport_no',
      'passport_number',
    ]) {
      final v = (item[key] ?? '').toString().trim();
      if (v.isNotEmpty && v.toLowerCase() != 'null') return v;
    }
    return '--------';
  }

  String _requestedFromLabel(Map<String, dynamic> item) {
    for (final key in [
      'from',
      'source',
      'source_doc_type',
      'request_source',
      'origin_doc_type',
    ]) {
      final v = (item[key] ?? '').toString().trim();
      if (v.isNotEmpty && v.toLowerCase() != 'null') {
        return _toTitleCase(v.replaceAll('_', ' '));
      }
    }

    final state = (item['state'] ?? '').toString().trim().toLowerCase();
    if (state.contains('expire')) return 'Expired';
    return '';
  }

  String _requestedFileName(Map<String, dynamic> item) {
    for (final key in [
      'attachment_filename',
      'file_name',
      'attachment_name',
      'name',
    ]) {
      final v = (item[key] ?? '').toString().trim();
      if (v.isNotEmpty && v.toLowerCase() != 'null') return v;
    }
    return 'Attachment';
  }

  Widget _buildMyRequestedFilteredMode(Map<String, dynamic> meta) {
    final docs = _filteredDocs();

    return ListView(
      padding: EdgeInsets.only(left: 12.w, right: 12.w, top: 14.h, bottom: 8.h),
      children: [
        Container(
          height: 96.h,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: meta['background'] as Color,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    meta['icon'] as IconData,
                    size: 30.sp,
                    color: meta['iconColor'] as Color,
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    meta['label'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: meta['labelColor'] as Color,
                    ),
                  ),
                ],
              ),
              Text(
                (meta['value'] ?? '-').toString(),
                style: GoogleFonts.poppins(
                  fontSize: 44.sp,
                  fontWeight: FontWeight.w700,
                  color: meta['valueColor'] as Color,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        GestureDetector(
          onTap: () {
            unawaited(_showDocumentDialogByType(DocumentDialogType.my));
          },
          child: Container(
            height: 58.h,
            decoration: BoxDecoration(
              color: const Color(0xFFE8E8E8),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: const Color(0xFFADADAD), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.badge_outlined,
                    size: 22.sp, color: const Color(0xFF757575)),
                SizedBox(width: 8.w),
                Text(
                  'Add New Documents',
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF7A7A7A),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 12.h),
        if (docs.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: _buildEmptyState(
              icon: Icons.folder_off_rounded,
              title: 'No Requested Documents',
              subtitle: 'There are no requested documents to display.',
            ),
          )
        else
          ...docs.map((item) {
            final docName = _requestedDocName(item);
            final idNo = _requestedIdNumber(item);
            final dateRaw =
                (item['expiry_date'] != null && item['expiry_date'] != false)
                    ? item['expiry_date']
                    : item['issue_date'];
            final expiryDate = _formatCardDate(dateRaw);
            final source = _requestedFromLabel(item);
            final iconPath =
                (item['icon'] ?? 'assets/png/other-documetns-icon.png')
                    .toString();
            final fileName = _requestedFileName(item);

            return Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: GestureDetector(
                onTap: () {
                  if (kDebugMode) {
                    unawaited(_debugPrintDocumentTapApi(item));
                  }
                  unawaited(_openDocumentAttachment(item));
                },
                onLongPress: () {
                  _showDocumentDetailsDialog(context, item);
                },
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDADADA),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Documents Name | $docName',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'ID number | $idNo',
                              style: GoogleFonts.poppins(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(height: 3.h),
                            Text(
                              'Expiry date | $expiryDate',
                              style: GoogleFonts.poppins(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFBA1719),
                              ),
                            ),
                            if (source.isNotEmpty) ...[
                              SizedBox(height: 3.h),
                              RichText(
                                text: TextSpan(
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black,
                                  ),
                                  children: [
                                    const TextSpan(text: 'from | '),
                                    TextSpan(
                                      text: source,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFF0B321),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Container(
                        width: 128.w,
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDEDED),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Column(
                          children: [
                            Image.asset(
                              iconPath,
                              width: 34.w,
                              height: 34.w,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.insert_drive_file_outlined,
                                size: 30.sp,
                                color: const Color(0xFF1AAE78),
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              fileName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 10.5.sp,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF2E2E2E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  bool _isMeaningfulDocLabel(String value) {
    final v = value.trim();
    if (v.isEmpty) return false;
    if (v.toLowerCase() == 'n/a') return false;
    // Avoid showing pure numeric IDs as the main label.
    if (RegExp(r'^\d+$').hasMatch(v)) return false;
    // Require at least one letter (Latin or Arabic).
    return RegExp(r'[A-Za-z\u0600-\u06FF]').hasMatch(v);
  }

  Widget _buildInlineSearchField() {
    return Container(
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/png/bg_atten.png'),
          fit: BoxFit.none,
        ),
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(29.w),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha((0.2 * 255).toInt()),
            blurRadius: 4,
            spreadRadius: 2,
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Find document',
          prefixIcon: Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.search, size: 18, color: appFontColor),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
      child: Column(
        children: [
          Icon(
            icon,
            size: 42.sp,
            color: const Color(0xFF3B4352),
          ),
          SizedBox(height: 6.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF3B4352),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF7B8290),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  // @override
  // void initState() {
  //   super.initState();
  //   Future.delayed(const Duration(seconds: 5), () {
  //     if (mounted) showBabyGirlPopup(context);
  //   });
  // }

  final List<Map<String, dynamic>> notificationType = [
    {
      'icon': 'assets/png/folder.png',
      'icon_unfocus': 'assets/png/folder_unfocus.png',
      'title': translate('home.documents'),
    },
    {
      'icon': 'assets/png/family_focus.png',
      'icon_unfocus': 'assets/png/family.png',
      'title': translate('home.family_document'),
    },
    {
      'icon': 'assets/newapp/newicon/for_company document.png',
      'icon_unfocus': 'assets/newapp/newicon/for_company document.png',
      'title': 'Company Documents',
    },
    {
      'icon': 'assets/newapp/newicon/for_shared_document.png',
      'icon_unfocus': 'assets/newapp/newicon/for_shared_document.png',
      'title': 'Share Documents',
    },
  ];

  String get _currentTitle {
    switch (currentIndex) {
      case 0:
        return translate('home.documents').toUpperCase();
      case 1:
        return 'FAMILY DOCUMENT';
      case 2:
        return 'COMPANY DOCUMENTS';
      case 3:
        return 'SHARE DOCUMENTS';
      default:
        return 'DOCUMENTS';
    }
  }

  void _onEdgeSwipeStart(DragStartDetails details) {
    if (!Platform.isIOS) return;
    _edgeSwipeStartX = details.globalPosition.dx;
    _isHandlingEdgeSwipeBack = false;
  }

  Future<void> _onEdgeSwipeUpdate(DragUpdateDetails details) async {
    if (!Platform.isIOS || _isHandlingEdgeSwipeBack) return;
    final startX = _edgeSwipeStartX;
    if (startX == null) return;

    final deltaX = details.globalPosition.dx - startX;
    if (deltaX < 72) return;

    _isHandlingEdgeSwipeBack = true;
    await Navigator.of(context).maybePop();
  }

  void _onEdgeSwipeEnd(DragEndDetails details) {
    _edgeSwipeStartX = null;
    _isHandlingEdgeSwipeBack = false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // If Family tab has an active stats filter, clear it first and stay
        // on Family tab (do not jump to My Documents tab).
        if (currentIndex == 0 && _activeMyDocType != null) {
          setState(() {
            _activeMyDocType = null;
            _loading = true;
            _error = null;
          });

          final keyword = _searchController.text.trim();
          unawaited(
            _fetchMyDocuments(
              keyword: keyword.isEmpty ? null : keyword,
              docType: null,
            ),
          );
          return false;
        }

        if (currentIndex == 1 &&
            _activeFamilyDocType != null &&
            !_familyInlineFormOpen) {
          setState(() {
            _activeFamilyDocType = null;
            _loading = true;
            _error = null;
          });

          final keyword = _searchController.text.trim();
          unawaited(
            _fetchMyDocuments(
              keyword: keyword.isEmpty ? null : keyword,
              docType: null,
            ),
          );
          return false;
        }

        // For Company/Share tabs, allow normal pop to previous screen.
        return true;
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.white,
            appBar: const HeaderWidget(),
            body: Column(
              children: [
                const SizedBox(height: 5),
                Center(
                  child: Text(
                    _currentTitle,
                    style: GoogleFonts.poppins(
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w600,
                      color: appFontColor,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // ── Tab Bar ──
                SizedBox(
                  height: 55.w,
                  child: ListView.separated(
                    padding: const EdgeInsets.only(left: 10, right: 10),
                    itemCount: notificationType.length,
                    physics: const BouncingScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final isSelected = index == currentIndex;
                      final item = notificationType[index];
                      final shouldTintIcon = index == 2 || index == 3;

                      final String displayIcon = isSelected
                          ? item['icon'] as String
                          : item['icon_unfocus'] as String;

                      return InkWell(
                        onTap: () {
                          if (currentIndex == index) {
                            final keyword = _searchController.text.trim();

                            if (index == 0 && _activeMyDocType != null) {
                              setState(() {
                                _activeMyDocType = null;
                                _loading = true;
                                _error = null;
                              });
                              unawaited(
                                _fetchMyDocuments(
                                  keyword: keyword.isEmpty ? null : keyword,
                                  docType: null,
                                ),
                              );
                              return;
                            }

                            if (index == 1 && _activeFamilyDocType != null) {
                              setState(() {
                                _activeFamilyDocType = null;
                                _loading = true;
                                _error = null;
                              });
                              unawaited(
                                _fetchMyDocuments(
                                  keyword: keyword.isEmpty ? null : keyword,
                                  docType: null,
                                ),
                              );
                              return;
                            }

                            // Re-open tab root screens for nested tabs.
                            if (index == 2) {
                              setState(() {
                                _companyTabVersion++;
                              });
                              return;
                            }
                            if (index == 3) {
                              setState(() {
                                _shareTabVersion++;
                              });
                              return;
                            }

                            return;
                          }
                          final shouldFetchDocs = index == 0 || index == 1;
                          final previousIndex = currentIndex;

                          setState(() {
                            // Always reset nested section state when navigating
                            // between top filters/tabs so each section opens
                            // at its main page.
                            if (previousIndex == 2) {
                              _companyTabVersion++;
                            }
                            if (previousIndex == 3) {
                              _shareTabVersion++;
                            }

                            currentIndex = index;

                            if (index == 2) {
                              _companyTabVersion++;
                            }
                            if (index == 3) {
                              _shareTabVersion++;
                            }

                            if (shouldFetchDocs) {
                              if (index == 0) {
                                _activeMyDocType = null;
                              }
                              if (index == 1) {
                                _activeFamilyDocType = null;
                              }
                              _loading = true;
                              _error = null;
                              if (index == 1) {
                                // Prevent temporary old/fallback folder flash
                                // while family documents are loading.
                                documents = [];
                              }
                            }
                          });

                          // Keep My/Family lists in sync with selected tab source.
                          if (shouldFetchDocs) {
                            final keyword = _searchController.text.trim();
                            unawaited(
                              _fetchMyDocuments(
                                keyword: keyword.isEmpty ? null : keyword,
                                docType:
                                    index == 1 ? _activeFamilyDocType : null,
                              ),
                            );
                          }
                        },
                        child: Container(
                          alignment: Alignment.center,
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? appFontColor : greyText2,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.black.withAlpha((0.1 * 255).toInt()),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                displayIcon,
                                height: 25.w,
                                color: shouldTintIcon
                                    ? (isSelected ? Colors.white : Colors.black)
                                    : null,
                                colorBlendMode:
                                    shouldTintIcon ? BlendMode.srcIn : null,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                (item['title'] as String).toUpperCase(),
                                style: GoogleFonts.poppins(
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF1A237E),
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(width: 10),
                  ),
                ),
                SizedBox(height: 8.h),
                // ── Tab Content ──
                Expanded(
                  child: currentIndex == 0
                      ? _buildMyDocumentsContent()
                      : IndexedStack(
                          index: currentIndex - 1,
                          children: [
                            FamilyDocumentsTab(
                              isActive: currentIndex == 1,
                              isLoading: currentIndex == 1 && _loading,
                              documents: documents,
                              statTotal: _statTotal,
                              statRequested: _statRequested,
                              statExpiringSoon: _statExpiringSoon,
                              statExpired: _statExpired,
                              selectedDocType: _activeFamilyDocType,
                              recentActivities: _familyRecentActivities,
                              onDocTypeSelected: (docType) {
                                setState(() {
                                  _activeFamilyDocType = docType;
                                  if (docType != null) {
                                    _loading = true;
                                    _error = null;
                                  }
                                });
                                final keyword = _searchController.text.trim();
                                unawaited(
                                  _fetchMyDocuments(
                                    keyword: keyword.isEmpty ? null : keyword,
                                    docType: docType,
                                  ),
                                );
                              },
                              onInlineFormVisibilityChanged: (isOpen) {
                                if (_familyInlineFormOpen == isOpen) return;
                                setState(() {
                                  _familyInlineFormOpen = isOpen;
                                });
                              },
                              onOpenDocument: _openDocumentAttachment,
                              onChangeDocument: (document) =>
                                  _showChangeDocumentDialog(
                                      document, DocumentDialogType.family),
                              onAddDocument: () {
                                _showDocumentDialogByType(
                                    DocumentDialogType.family);
                              },
                              onAddNewRequest: () {
                                unawaited(() async {
                                  final result =
                                      await Navigator.of(context).push<bool>(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const FamilyInsuranceRequestScreen(),
                                    ),
                                  );

                                  if (result == true && mounted) {
                                    final keyword =
                                        _searchController.text.trim();
                                    await _fetchMyDocuments(
                                      keyword: keyword.isEmpty ? null : keyword,
                                      docType: _activeFamilyDocType,
                                    );
                                  }
                                }());
                              },
                            ),
                            CompanyDocumentsTab(
                              key: ValueKey('company_docs_$_companyTabVersion'),
                              onAddDocument: () {
                                _showDocumentDialogByType(
                                    DocumentDialogType.company);
                              },
                              onOpenDocument: _openDocumentAttachment,
                            ),
                            ShareDocumentsTab(
                              key: ValueKey('share_docs_$_shareTabVersion'),
                              onOpenDocument: _openDocumentAttachment,
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          if (Platform.isIOS)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 28,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: _onEdgeSwipeStart,
                onHorizontalDragUpdate: _onEdgeSwipeUpdate,
                onHorizontalDragEnd: _onEdgeSwipeEnd,
                onHorizontalDragCancel: () {
                  _edgeSwipeStartX = null;
                  _isHandlingEdgeSwipeBack = false;
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Builds the original "My Documents" personal documents content.
  Widget _buildMyDocumentsContent() {
    if ((_activeMyDocType == 'expired' ||
            _activeMyDocType == 'expiry_soon' ||
            _activeMyDocType == 'requested') &&
        !_loading &&
        _error == null) {
      return _buildMyFilteredMode(_activeMyDocType!);
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              _buildDocumentsSummaryCard(),
              SizedBox(height: 10.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: GestureDetector(
                  onTap: () {
                    unawaited(_showDocumentDialogByType(DocumentDialogType.my));
                  },
                  child: Container(
                    height: 58.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14.r),
                      border:
                          Border.all(color: const Color(0xFFADADAD), width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.badge_outlined,
                            size: 22.sp, color: const Color(0xFF757575)),
                        SizedBox(width: 8.w),
                        Text(
                          'Add New Documents',
                          style: GoogleFonts.poppins(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF7A7A7A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                Center(
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredDocs().length,
                    itemBuilder: (context, index) {
                      final item = _filteredDocs()[index];
                      bool isExpired = false;
                      if (item['expiry_date'] != null &&
                          item['expiry_date'] != false) {
                        try {
                          final expiryDate =
                              DateTime.parse(item['expiry_date'].toString());
                          isExpired = expiryDate.isBefore(DateTime.now());
                        } catch (e) {
                          isExpired = false;
                        }
                      }

                      return GestureDetector(
                        onTap: () {
                          if (kDebugMode) {
                            unawaited(_debugPrintDocumentTapApi(item));
                          }
                          unawaited(_openDocumentAttachment(item));
                        },
                        onLongPress: () {
                          _showDocumentDetailsDialog(context, item);
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.topCenter,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30.18),
                                border: Border.all(
                                  color: isExpired
                                      ? const Color(0xFFBA1719)
                                      : const Color(0xffD9D9D9),
                                  width: isExpired ? 2 : 1,
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: 10.h,
                                  horizontal: 10.w,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      height: 90.h,
                                      width: double.infinity,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Center(
                                              child: Image.asset(
                                                item['icon'],
                                                width: double.infinity,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 10.h),
                                    Builder(builder: (context) {
                                      final rawName = (item['name'] ?? '')
                                          .toString()
                                          .trim();
                                      final rawType = (item['title'] ?? '')
                                          .toString()
                                          .trim();
                                      final typeLabel = _toTitleCase(
                                        rawType.replaceAll('_', ' '),
                                      );
                                      final nameLabel = _toTitleCase(
                                        rawName.replaceAll('_', ' '),
                                      );
                                      final displayName =
                                          _isMeaningfulDocLabel(nameLabel)
                                              ? nameLabel
                                              : typeLabel;
                                      final cardDateRaw =
                                          (item['expiry_date'] != null &&
                                                  item['expiry_date'] != false)
                                              ? item['expiry_date']
                                              : item['issue_date'];
                                      final date = _formatCardDate(cardDateRaw);
                                      final dateColor = isExpired
                                          ? const Color(0xFFBA1719)
                                          : const Color(0xff949494);

                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            displayName,
                                            textAlign: TextAlign.center,
                                            maxLines: null,
                                            overflow: TextOverflow.visible,
                                            style: GoogleFonts.poppins(
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: .10,
                                              color: Colors.black,
                                            ),
                                          ),
                                          SizedBox(height: 4.h),
                                          Text(
                                            date,
                                            textAlign: TextAlign.center,
                                            maxLines: null,
                                            overflow: TextOverflow.visible,
                                            style: GoogleFonts.poppins(
                                              fontSize: 10.sp,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: .10,
                                              color: dateColor,
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 0,
                      childAspectRatio: 0.9,
                    ),
                  ),
                ),
              SizedBox(height: 20.h),
            ],
          ),
        ),
      ],
    );
  }

  void showDocumentDialog(BuildContext context) async {
    final type = currentIndex == 1
        ? DocumentDialogType.family
        : currentIndex == 2
            ? DocumentDialogType.company
            : DocumentDialogType.my;
    _showDocumentDialogByType(type);
  }

  Future<void> _showDocumentDialogByType(
    DocumentDialogType type, {
    String? fixedDocumentType,
  }) async {
    final result = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: DocumentDialog(
            type: type,
            fixedDocumentType: fixedDocumentType,
          ),
        );
      },
    );

    // If document was added successfully, refresh the list
    if (result == true) {
      print('🔄 Refreshing documents list...');
      if (type == DocumentDialogType.company) {
        setState(() {
          _companyTabVersion++;
        });
      } else {
        await _fetchMyDocuments();
      }
    }
  }

  void _showDocumentDetailsDialog(
      BuildContext context, Map<String, dynamic> document) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final hasAttachment = _firstAttachmentIdAsInt(document) != null;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      document['icon'] ?? 'assets/png/other-documetns-icon.png',
                      width: 40,
                      height: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        (document['title'] ?? '-').toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff191F52),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Document Name
                _buildInfoRow(
                  icon: Icons.description,
                  label: 'Name',
                  value: (document['name'] ?? '-').toString(),
                  color: Colors.blue,
                ),
                const SizedBox(height: 12),

                // ID Number
                if (document['id_number'] != null &&
                    document['id_number'] != false)
                  _buildInfoRow(
                    icon: Icons.numbers,
                    label: 'ID Number',
                    value: document['id_number'].toString(),
                    color: Colors.green,
                  ),
                if (document['id_number'] != null &&
                    document['id_number'] != false)
                  const SizedBox(height: 12),

                // Issue Date
                if (document['issue_date'] != null &&
                    document['issue_date'] != false)
                  _buildInfoRow(
                    icon: Icons.calendar_today,
                    label: 'Issue Date',
                    value: _formatDate(document['issue_date'].toString()),
                    color: Colors.purple,
                  ),
                if (document['issue_date'] != null &&
                    document['issue_date'] != false)
                  const SizedBox(height: 12),

                // Expiry Date
                if (document['expiry_date'] != null &&
                    document['expiry_date'] != false)
                  _buildInfoRow(
                    icon: Icons.event,
                    label: 'Expiry Date',
                    value: _formatDate(document['expiry_date'].toString()),
                    color: _isExpired(document['expiry_date'].toString())
                        ? const Color(0xFFBA1719)
                        : Colors.orange,
                  ),
                if (document['expiry_date'] != null &&
                    document['expiry_date'] != false)
                  const SizedBox(height: 20),

                // View Attachment Button
                if (hasAttachment)
                  Center(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF191F52),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        unawaited(_openDocumentAttachment(document));
                      },
                      icon: const Icon(Icons.attach_file, color: Colors.white),
                      label: Text(
                        'VIEW ATTACHMENT',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                if (!hasAttachment)
                  const Center(
                    child: Text(
                      'No attachment available',
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  bool _isExpired(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return date.isBefore(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  Widget _buildDialogContent(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Transform.rotate(
                angle: -0.8, // in radians (not degrees)
                child: const Icon(
                  Icons.attachment,
                  color: Colors.black,
                  size: 24,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "ATTACHMENTS",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                  //letterSpacing: 1.2,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 🔸 LPO No
          Row(
            children: [
              const Icon(Icons.tag, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Text(
                "LPO NO",
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 🔸 Vendor Name
          Row(
            children: [
              const Icon(Icons.handshake, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                "VENDOR NAME",
                style: GoogleFonts.poppins(
                  color: Colors.blue,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 🔸 Project Name
          Row(
            children: [
              const Icon(Icons.business_center, color: Colors.black, size: 20),
              const SizedBox(width: 8),
              Text(
                "PROJECT NAME",
                style: GoogleFonts.poppins(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // 🔘 Button
          Center(
            child: SizedBox(
              width: 180,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF191F52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Transform.rotate(
                      angle: -0.8, // in radians (not degrees)
                      child: const Icon(
                        Icons.attachment,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "VIEW ATTACHMENT",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
//   void showBabyGirlPopup(BuildContext context) {
//     showDialog(
//       context: context,
//       barrierDismissible: true,
//       barrierColor: Colors.black.withAlpha((0.5 * 255).toInt()),
//       builder: (BuildContext context) {
//         return Dialog(
//           backgroundColor: Colors.white.withAlpha((0.95 * 255).toInt()),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(28),
//           ),
//           child: Padding(
//             padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 const Text(
//                   "🎉 Congratulations ✨",
//                   style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.w800,
//                     color: Colors.black,
//                   ),
//                   textAlign: TextAlign.center,
//                 ),
//                 const SizedBox(height: 10),
//                 const Text(
//                   "Congratulations to",
//                   style: TextStyle(fontSize: 13, color: Colors.black),
//                   textAlign: TextAlign.center,
//                 ),
//                 const SizedBox(height: 5),
//                 const Text(
//                   "Eng. Hassan Abuebied",
//                   style: TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.black,
//                   ),
//                   textAlign: TextAlign.center,
//                 ),
//                 const SizedBox(height: 14),
//                 const Text(
//                   "on the arrival of his baby girl! 🎀✨ Wishing her a life filled with love, joy, and endless blessings. May she bring happiness and prosperity to the family! 💖👶🏼",
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     fontSize: 13,
//                     height: 1.5,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 Image.asset(
//                   'assets/png/Baby_girl.png',
//                   height: 80,
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
}

enum DocumentDialogType {
  my,
  family,
  company,
}

class DocumentDialog extends StatefulWidget {
  const DocumentDialog({super.key, required this.type, this.fixedDocumentType});

  final DocumentDialogType type;
  final String? fixedDocumentType;

  @override
  State<DocumentDialog> createState() => _DocumentDialogState();
}

class _DocumentDialogState extends State<DocumentDialog> {
  static const List<String> _fallbackTypes = [
    'Passport',
    'Labor Card',
    'Medical Insurance',
    'Emirates ID',
    'photo',
    'CV',
    'Certifications',
  ];

  // Safety fallback based on backend-provided document_types response.
  static const Map<String, int> _knownTypeIdsByNormalizedName = {
    'passport': 1,
    'emiratesid': 2,
    'laborcard': 3,
    'medicalinsurance': 4,
    'drivinglicense': 6,
    'visa': 10,
    'noc': 11,
    'contract': 89,
    'universitycertificate': 93,
    'cv': 94,
    'residence': 147,
    'photo': 172,
    'pension': 175,
    'family': 176,
  };

  final TextEditingController _idController = TextEditingController();
  DateTime? _expiryDate;
  String? _selectedType;
  final List<String> _types = <String>[];
  final Map<String, int> _documentTypeIds = <String, int>{};
  String? _attachedFileName;
  String? _attachedFilePath;
  bool _isUploading = false;
  bool _isLoadingTypes = false;

  bool get _showIdAndExpiry => widget.type != DocumentDialogType.company;
  bool get _familyOnly => widget.type == DocumentDialogType.family;
  bool get _hasFixedDocumentType =>
      (widget.fixedDocumentType ?? '').trim().isNotEmpty;
  String get _fixedDocumentType => (widget.fixedDocumentType ?? '').trim();

  String get _dialogTitle {
    if (_hasFixedDocumentType) return 'Change Documents';

    switch (widget.type) {
      case DocumentDialogType.family:
        return 'Family Documents';
      case DocumentDialogType.company:
        return 'Company Documents';
      case DocumentDialogType.my:
      default:
        return 'My Documents';
    }
  }

  @override
  void initState() {
    super.initState();
    if (_hasFixedDocumentType) {
      _selectedType = _fixedDocumentType;
      _types.add(_fixedDocumentType);
    }

    if (widget.type == DocumentDialogType.company) {
      if (_hasFixedDocumentType) return;
      _types.addAll(_fallbackTypes);
      _selectedType = _types.isNotEmpty ? _types.first : null;
    } else {
      unawaited(_loadDocumentTypes());
    }
  }

  void _addDocumentTypeFromRaw(
    dynamic raw,
    List<String> names,
    Map<String, int> idsByName,
  ) {
    if (raw is String) {
      final name = raw.trim();
      if (name.isNotEmpty && !names.contains(name)) {
        names.add(name);
      }
      return;
    }

    if (raw is! Map) return;

    final map = Map<String, dynamic>.from(raw as Map);
    final name = (map['name'] ??
            map['document_type'] ??
            map['type'] ??
            map['label'] ??
            '')
        .toString()
        .trim();
    if (name.isEmpty) return;

    if (!names.contains(name)) {
      names.add(name);
    }

    final idRaw = map['id'] ?? map['document_type_id'] ?? map['type_id'];
    final id = int.tryParse((idRaw ?? '').toString());
    if (id != null) {
      idsByName[name] = id;
    }
  }

  Future<void> _loadDocumentTypes() async {
    if (_isLoadingTypes) return;
    if (mounted) {
      setState(() => _isLoadingTypes = true);
    }

    try {
      final token = SharedPref.getLoginData().result?.token ?? '';
      if (token.isEmpty) return;

      final url = Uri.parse('https://erp.elrace.com/api/document_types');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final body = jsonEncode({
        'jsonrpc': '2.0',
        'params': {
          'family_only': _familyOnly,
        },
      });

      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode != 200) return;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return;

      final result = (decoded['result'] is Map)
          ? Map<String, dynamic>.from(decoded['result'] as Map)
          : (decoded['status'] != null)
              ? Map<String, dynamic>.from(decoded)
              : <String, dynamic>{};
      final statusToken = _normalizeToken(result['status']);
      if (!(statusToken == 'success' ||
          statusToken == 'ok' ||
          statusToken == 'true')) {
        return;
      }

      final names = <String>[];
      final idsByName = <String, int>{};
      final data = result['data'];

      if (data is List) {
        for (final item in data) {
          _addDocumentTypeFromRaw(item, names, idsByName);
        }
      } else if (data is Map) {
        for (final entry in data.entries) {
          final key = entry.key.toString().trim();
          final value = entry.value;

          if (value is Map || value is String) {
            _addDocumentTypeFromRaw(value, names, idsByName);
            continue;
          }

          final keyAsId = int.tryParse(key);
          final valueText = (value ?? '').toString().trim();
          final valueAsId = int.tryParse(valueText);

          if (keyAsId != null && valueText.isNotEmpty) {
            if (!names.contains(valueText)) {
              names.add(valueText);
            }
            idsByName[valueText] = keyAsId;
            continue;
          }

          if (valueAsId != null && key.isNotEmpty) {
            if (!names.contains(key)) {
              names.add(key);
            }
            idsByName[key] = valueAsId;
          }
        }
      }

      if (!mounted || names.isEmpty) return;
      setState(() {
        if (!_hasFixedDocumentType) {
          _types
            ..clear()
            ..addAll(names);
        }
        _documentTypeIds
          ..clear()
          ..addAll(idsByName);

        if (_hasFixedDocumentType) {
          _selectedType = _fixedDocumentType;
        } else if (_selectedType == null || !_types.contains(_selectedType)) {
          _selectedType = _types.first;
        }
      });
    } catch (e) {
      debugPrint('Failed to load document types: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTypes = false;
          if (_hasFixedDocumentType) {
            _selectedType = _fixedDocumentType;
            if (_types.isEmpty) {
              _types.add(_fixedDocumentType);
            }
            return;
          }
          if (_types.isEmpty) {
            _types.addAll(_fallbackTypes);
          }
          if (_selectedType == null && _types.isNotEmpty) {
            _selectedType = _types.first;
          } else if (_selectedType != null &&
              _types.isNotEmpty &&
              !_types.contains(_selectedType)) {
            _selectedType = _types.first;
          }
        });
      }
    }
  }

  int? _findDocumentTypeIdLocally(String selectedType) {
    if (selectedType.trim().isEmpty) return null;

    final direct = _documentTypeIds[selectedType];
    if (direct != null) return direct;

    final selectedToken = _normalizeToken(selectedType);
    for (final entry in _documentTypeIds.entries) {
      if (_normalizeToken(entry.key) == selectedToken) {
        return entry.value;
      }
    }

    // Fallback when dropdown is available but ids map is temporarily empty.
    final known = _knownTypeIdsByNormalizedName[selectedToken];
    if (known != null) return known;

    return null;
  }

  Future<int?> _resolveDocumentTypeId(String selectedType) async {
    var id = _findDocumentTypeIdLocally(selectedType);
    if (id != null) return id;

    // Try refreshing types once in case dropdown data arrived without ids.
    await _loadDocumentTypes();
    id = _findDocumentTypeIdLocally(selectedType);
    if (id != null) return id;

    // Final fallback: query API directly and resolve by normalized name.
    try {
      final token = SharedPref.getLoginData().result?.token ?? '';
      if (token.isEmpty) return null;

      final url = Uri.parse('https://erp.elrace.com/api/document_types');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final body = jsonEncode({
        'jsonrpc': '2.0',
        'params': {
          'family_only': _familyOnly,
        },
      });

      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;

      final result = (decoded['result'] is Map)
          ? Map<String, dynamic>.from(decoded['result'] as Map)
          : (decoded['status'] != null)
              ? Map<String, dynamic>.from(decoded)
              : <String, dynamic>{};
      final statusToken = _normalizeToken(result['status']);
      if (!(statusToken == 'success' ||
          statusToken == 'ok' ||
          statusToken == 'true')) {
        return null;
      }

      final names = <String>[];
      final idsByName = <String, int>{};
      final data = result['data'];

      if (data is List) {
        for (final item in data) {
          _addDocumentTypeFromRaw(item, names, idsByName);
        }
      } else if (data is Map) {
        for (final entry in data.entries) {
          final key = entry.key.toString().trim();
          final value = entry.value;

          if (value is Map || value is String) {
            _addDocumentTypeFromRaw(value, names, idsByName);
            continue;
          }

          final keyAsId = int.tryParse(key);
          final valueText = (value ?? '').toString().trim();
          final valueAsId = int.tryParse(valueText);

          if (keyAsId != null && valueText.isNotEmpty) {
            if (!names.contains(valueText)) {
              names.add(valueText);
            }
            idsByName[valueText] = keyAsId;
            continue;
          }

          if (valueAsId != null && key.isNotEmpty) {
            if (!names.contains(key)) {
              names.add(key);
            }
            idsByName[key] = valueAsId;
          }
        }
      }

      if (idsByName.isNotEmpty && mounted) {
        setState(() {
          _documentTypeIds
            ..clear()
            ..addAll(idsByName);
          if (names.isNotEmpty) {
            _types
              ..clear()
              ..addAll(names);
            if (_selectedType == null || !_types.contains(_selectedType)) {
              _selectedType = _types.first;
            }
          }
        });
      }

      return _findDocumentTypeIdLocally(selectedType);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now,
      firstDate: now.subtract(const Duration(days: 365 * 50)),
      lastDate: DateTime(now.year + 50),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Colors.blueGrey, // header background
            onPrimary: Colors.white, // header text
            onSurface: Colors.black, // body text
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _attachedFileName = result.files.single.name;
          _attachedFilePath = result.files.single.path;
        });
      }
    } catch (e) {
      print('Error picking file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting file: $e')),
      );
    }
  }

  String _normalizeToken(dynamic value) {
    return (value ?? '')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  bool _isUploadSuccess(dynamic decodedBody) {
    if (decodedBody is! Map) return false;

    final result = decodedBody['result'];
    if (result is! Map) return false;

    final statusRaw = result['status'];
    final successRaw = result['success'];

    final statusToken = _normalizeToken(statusRaw);
    if (statusToken == 'success' ||
        statusToken == 'ok' ||
        statusToken == 'true') {
      return true;
    }

    if (successRaw is bool) return successRaw;
    final successToken = _normalizeToken(successRaw);
    return successToken == '1' ||
        successToken == 'true' ||
        successToken == 'success';
  }

  String _safeAttachmentFilename({
    required String selectedType,
    String? pickedName,
    String? pickedPath,
  }) {
    final direct = (pickedName ?? '').trim();
    if (direct.isNotEmpty) return direct;

    final path = (pickedPath ?? '').trim();
    final fileNameFromPath =
        path.isNotEmpty ? path.split(Platform.pathSeparator).last : '';
    if (fileNameFromPath.isNotEmpty) return fileNameFromPath;

    final normalizedType = selectedType.trim().isEmpty
        ? 'document'
        : selectedType.trim().replaceAll(RegExp(r'\s+'), '_').toLowerCase();
    return '$normalizedType.pdf';
  }

  String _extractUploadMessage(dynamic decodedBody) {
    if (decodedBody is! Map) return 'Upload failed';

    final result = decodedBody['result'];
    if (result is Map) {
      final message = result['message']?.toString();
      if (message != null && message.trim().isNotEmpty) {
        return message.trim();
      }
    }

    final error = decodedBody['error'];
    if (error is Map) {
      final errorData = error['data'];
      if (errorData is Map) {
        final dataMessage = errorData['message']?.toString();
        if (dataMessage != null && dataMessage.trim().isNotEmpty) {
          return dataMessage.trim();
        }

        final debugText = errorData['debug']?.toString() ?? '';
        final parsedDebugMessage =
            _extractValidationMessageFromDebug(debugText);
        if (parsedDebugMessage.isNotEmpty) {
          return parsedDebugMessage;
        }
      }

      final errorMessage = error['message']?.toString();
      if (errorMessage != null && errorMessage.trim().isNotEmpty) {
        return errorMessage.trim();
      }
    }

    return 'Upload failed';
  }

  String _extractValidationMessageFromDebug(String debugText) {
    final text = debugText.trim();
    if (text.isEmpty) return '';

    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    for (final line in lines.reversed) {
      if (line.startsWith('ValidationError:')) {
        return line.replaceFirst('ValidationError:', '').trim();
      }
      if (line.startsWith('Exception:')) {
        return line.replaceFirst('Exception:', '').trim();
      }
    }

    return '';
  }

  int? _extractUploadedDocumentId(dynamic decodedBody) {
    if (decodedBody is! Map) return null;
    final result = decodedBody['result'];
    if (result is! Map) return null;

    final raw = result['document_id'] ?? result['id'] ?? result['record_id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  String _targetCollectionLabel() {
    switch (widget.type) {
      case DocumentDialogType.family:
        return 'Family Documents';
      case DocumentDialogType.company:
        return 'Company Documents';
      case DocumentDialogType.my:
      default:
        return 'My Documents';
    }
  }

  List<Map<String, dynamic>> _extractDocumentMaps(List<dynamic> rawGroups) {
    final docs = <Map<String, dynamic>>[];

    for (final groupRaw in rawGroups) {
      if (groupRaw is! Map) continue;
      final group = Map<String, dynamic>.from(groupRaw);

      final nested = group['documents'];
      if (nested is List && nested.isNotEmpty) {
        for (final item in nested) {
          if (item is Map) {
            docs.add(Map<String, dynamic>.from(item));
          }
        }
      } else {
        docs.add(group);
      }
    }

    return docs;
  }

  String _attachmentSignature(dynamic attachmentIds) {
    if (attachmentIds is List && attachmentIds.isNotEmpty) {
      final values = attachmentIds
          .map((e) {
            if (e is Map) {
              return (e['attachment_id'] ?? e['id'] ?? e['attachmentId'])
                  .toString();
            }
            return e.toString();
          })
          .where((e) => e.trim().isNotEmpty)
          .toList(growable: false)
        ..sort();
      return values.join(',');
    }

    if (attachmentIds is Map) {
      return (attachmentIds['attachment_id'] ??
              attachmentIds['id'] ??
              attachmentIds['attachmentId'] ??
              '')
          .toString();
    }

    return (attachmentIds ?? '').toString();
  }

  Set<String> _buildDocumentFingerprints(List<dynamic> rawGroups) {
    final docs = _extractDocumentMaps(rawGroups);
    final fingerprints = <String>{};

    for (final doc in docs) {
      final id = (doc['id'] ?? '').toString();
      final type = _normalizeToken(doc['document_type'] ?? doc['type']);
      final name = _normalizeToken(doc['name']);
      final idNumber = _normalizeToken(doc['id_number']);
      final attachment = _normalizeToken(
        _attachmentSignature(doc['attachment_ids']) +
            (doc['attachment_name'] ?? doc['attachment_filename'] ?? '')
                .toString(),
      );
      final updatedAt = _normalizeToken(
        doc['write_date'] ?? doc['updated_at'] ?? doc['create_date'],
      );

      fingerprints.add('$id|$type|$name|$idNumber|$attachment|$updatedAt');
    }

    return fingerprints;
  }

  Future<Set<String>?> _snapshotDocumentsBeforeUpload({
    required String token,
  }) async {
    final url = Uri.parse('https://erp.elrace.com/api/get_employee_documents');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final familyOnly = widget.type == DocumentDialogType.family;
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'params': {
        'family_only': familyOnly,
      },
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final result = (decoded['result'] is Map)
          ? Map<String, dynamic>.from(decoded['result'] as Map)
          : (decoded['status'] != null)
              ? Map<String, dynamic>.from(decoded)
              : <String, dynamic>{};
      final statusToken = _normalizeToken(result['status']);
      if (!(statusToken == 'success' ||
          statusToken == 'ok' ||
          statusToken == 'true')) {
        return null;
      }

      final dataList = result['data'];
      if (dataList is! List) return null;

      return _buildDocumentFingerprints(dataList);
    } catch (_) {
      return null;
    }
  }

  bool _containsUploadedDocument(
    List<dynamic> rawGroups, {
    required String selectedType,
    required String idNumber,
    required String attachmentFileName,
    int? uploadedDocumentId,
  }) {
    final selectedTypeToken = _normalizeToken(selectedType);
    final idNumberToken = _normalizeToken(idNumber);
    final attachmentToken = _normalizeToken(attachmentFileName);

    for (final groupRaw in rawGroups) {
      if (groupRaw is! Map) continue;
      final group = Map<String, dynamic>.from(groupRaw);

      final dynamic nested = group['documents'];
      final docs = <Map<String, dynamic>>[];
      if (nested is List && nested.isNotEmpty) {
        for (final item in nested) {
          if (item is Map) {
            docs.add(Map<String, dynamic>.from(item));
          }
        }
      } else {
        docs.add(group);
      }

      for (final doc in docs) {
        final docId = int.tryParse((doc['id'] ?? '').toString());
        if (uploadedDocumentId != null && docId == uploadedDocumentId) {
          return true;
        }

        final typeToken = _normalizeToken(doc['document_type'] ?? doc['type']);
        final nameToken = _normalizeToken(doc['name']);
        final idToken = _normalizeToken(doc['id_number']);
        final attachmentNameToken = _normalizeToken(
          doc['attachment_name'] ??
              doc['attachment_filename'] ??
              doc['file_name'],
        );

        final typeMatch = selectedTypeToken.isEmpty
            ? true
            : (typeToken == selectedTypeToken ||
                typeToken.contains(selectedTypeToken) ||
                selectedTypeToken.contains(typeToken));

        final idMatch = idNumberToken.isEmpty
            ? true
            : (idToken == idNumberToken || nameToken == idNumberToken);

        final attachmentMatch = attachmentToken.isEmpty
            ? false
            : (attachmentNameToken == attachmentToken ||
                attachmentNameToken.contains(attachmentToken));

        if ((typeMatch && idMatch) || attachmentMatch) {
          return true;
        }
      }
    }

    return false;
  }

  Future<bool> _verifyDocumentAdded({
    required String token,
    required String selectedType,
    required String idNumber,
    required String attachmentFileName,
    int? uploadedDocumentId,
    Set<String>? beforeFingerprints,
  }) async {
    final url = Uri.parse('https://erp.elrace.com/api/get_employee_documents');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final bool familyOnly = widget.type == DocumentDialogType.family;
    final scopesToCheck = <bool>[familyOnly];

    for (var attempt = 0; attempt < 3; attempt++) {
      for (final scope in scopesToCheck) {
        final body = jsonEncode({
          'jsonrpc': '2.0',
          'params': {
            'family_only': scope,
          },
        });

        try {
          final response = await http.post(url, headers: headers, body: body);
          if (response.statusCode == 200) {
            final decoded = jsonDecode(response.body);
            if (decoded is! Map) continue;

            final result = (decoded['result'] is Map)
                ? Map<String, dynamic>.from(decoded['result'] as Map)
                : (decoded['status'] != null)
                    ? Map<String, dynamic>.from(decoded)
                    : <String, dynamic>{};
            final statusToken = _normalizeToken(result['status']);
            final statusOk = statusToken == 'success' ||
                statusToken == 'ok' ||
                statusToken == 'true';
            final dataList = result['data'];
            if (statusOk && dataList is List) {
              final afterFingerprints = _buildDocumentFingerprints(dataList);
              if (beforeFingerprints != null && beforeFingerprints.isNotEmpty) {
                final hasDelta = afterFingerprints.any(
                    (fingerprint) => !beforeFingerprints.contains(fingerprint));
                if (hasDelta) {
                  return true;
                }
              }

              final found = _containsUploadedDocument(
                dataList,
                selectedType: selectedType,
                idNumber: idNumber,
                attachmentFileName: attachmentFileName,
                uploadedDocumentId: uploadedDocumentId,
              );
              if (found) {
                return true;
              }
            }
          }
        } catch (_) {
          // Retry a couple of times to allow backend processing delay.
        }
      }

      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 600 * (attempt + 1)));
      }
    }

    return false;
  }

  Future<void> _submit() async {
    // Validate required fields
    final id = _idController.text.trim();
    final selectedType = (_selectedType ?? '').trim();
    if (selectedType.isEmpty) {
      debugPrint('⛔ Upload stopped: selectedType is empty');
      _sliderKey.currentState?.resetSlider();
      _showErrorDialog('Please select document type.');
      return;
    }
    if (_showIdAndExpiry && id.isEmpty) {
      debugPrint('⛔ Upload stopped: ID number is empty');
      _sliderKey.currentState?.resetSlider();
      _showErrorDialog('Please fill in ID number.');
      return;
    }
    if ((_attachedFilePath ?? '').isEmpty) {
      debugPrint('⛔ Upload stopped: attachment path is empty');
      _sliderKey.currentState?.resetSlider();
      _showErrorDialog('Please attach a file.');
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final token = SharedPref.getLoginData().result?.token ?? '';
      final url =
          Uri.parse('https://erp.elrace.com/api/upload_employee_document');

      // Debug: Check values before sending
      print('🔍 Debug - selectedType: "$selectedType"');
      print('🔍 Debug - id: "$id"');

      if (token.isEmpty) {
        print('❌ Error: auth token is empty!');
        debugPrint('⛔ Upload stopped: auth token is empty');
        _sliderKey.currentState?.resetSlider();
        _showErrorDialog('Session expired. Please login again.');
        return;
      }

      final beforeFingerprints =
          await _snapshotDocumentsBeforeUpload(token: token);

      if (selectedType.isEmpty) {
        print('❌ Error: selectedType is null or empty!');
        debugPrint('⛔ Upload stopped: selectedType became empty unexpectedly');
        return;
      }

      final documentTypeId = await _resolveDocumentTypeId(selectedType);
      debugPrint(
          '🔎 Resolved documentTypeId for "$selectedType": $documentTypeId');
      debugPrint(
          '🔎 Current document type map size: ${_documentTypeIds.length}');
      if (documentTypeId == null) {
        debugPrint('⛔ Upload stopped: could not resolve document_type_id');
        _sliderKey.currentState?.resetSlider();
        _showErrorDialog(
          'document_type_id is missing for "$selectedType". Please refresh document types and try again.',
        );
        return;
      }

      // Read file and convert to base64
      final file = File(_attachedFilePath!);
      debugPrint('📎 Upload file path: ${file.path}');
      final bytes = await file.readAsBytes();
      final base64File = base64Encode(bytes);
      debugPrint('📎 Upload file size bytes: ${bytes.length}');

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final attachmentFilename = _safeAttachmentFilename(
        selectedType: selectedType,
        pickedName: _attachedFileName,
        pickedPath: _attachedFilePath,
      );
      debugPrint('📎 attachment_filename used: $attachmentFilename');

      final params = <String, dynamic>{
        'name': selectedType,
        'description': 'Uploaded from mobile app',
        'attachment': base64File,
        'attachment_filename': attachmentFilename,
        'family_only': _familyOnly,
      };

      params['document_type_id'] = documentTypeId;

      final selectedDate = _expiryDate?.toIso8601String().split('T')[0];
      if (selectedDate != null && selectedDate.isNotEmpty) {
        params['issue_date'] = selectedDate;
        params['expiry_date'] = selectedDate;
      }

      final body = jsonEncode({
        'jsonrpc': '2.0',
        'id': null,
        'params': params,
      });

      print('📤 Uploading document...');
      final safeDebugParams = Map<String, dynamic>.from(params);
      if (safeDebugParams.containsKey('attachment')) {
        final len = safeDebugParams['attachment']?.toString().length ?? 0;
        safeDebugParams['attachment'] = '[base64 omitted, length=$len]';
      }
      print('📦 Request params: ${jsonEncode(safeDebugParams)}');
      debugPrint('🚀 Upload HTTP POST started: ${url.toString()}');
      final response = await http.post(url, headers: headers, body: body);
      final data = jsonDecode(response.body);

      print('📥 Upload response: ${response.body}');

      final isSuccess = response.statusCode == 200 && _isUploadSuccess(data);
      if (!isSuccess) {
        final errorMessage = _extractUploadMessage(data);
        if (mounted) {
          _sliderKey.currentState?.resetSlider();
          _showErrorDialog(errorMessage);
        }
        return;
      }

      final uploadedDocumentId = _extractUploadedDocumentId(data);
      if (widget.type == DocumentDialogType.family &&
          uploadedDocumentId != null) {
        await _tagDocumentAsFamily(uploadedDocumentId);
      }

      final appearsInList = await _verifyDocumentAdded(
        token: token,
        selectedType: selectedType,
        idNumber: id,
        attachmentFileName: _attachedFileName ?? '',
        uploadedDocumentId: uploadedDocumentId,
        beforeFingerprints: beforeFingerprints,
      );

      if (!appearsInList) {
        if (mounted) {
          _sliderKey.currentState?.resetSlider();
          _showErrorDialog(
            'Upload response was successful, but the document did not appear in ${_targetCollectionLabel()}. Please try again.',
          );
        }
        return;
      }

      print('✅ Document uploaded and verified in list!');
      if (mounted) {
        _showSuccessDialog(message: _extractUploadMessage(data));
      }
    } catch (e) {
      print('❌ Upload error: $e');
      if (mounted) {
        _sliderKey.currentState?.resetSlider();
        _showErrorDialog('An error occurred while uploading the document.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _showSuccessDialog({String? message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Success'),
        content: Text(message?.trim().isNotEmpty == true
            ? message!.trim()
            : 'Document uploaded successfully!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // Close dialog
              Navigator.of(context)
                  .pop(true); // Close DocumentDialog and refresh
            },
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    // Keep the current dialog open; show an error dialog over it.
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Upload Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  final GlobalKey<CustomSliderButtonState> _sliderKey = GlobalKey();
  Future<void> _submitExpense() async {
    await _submit();
  }

  @override
  Widget build(BuildContext context) {
    final expiryText = _expiryDate == null
        ? 'Expiry date'
        : DateFormat.yMMMd().format(_expiryDate!);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 18.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22.r),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF717171),
                const Color(0xFF1B1F26).withOpacity(0.72),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 30.h,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: Text(
                        _dialogTitle,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16.sp,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -6.w,
                      top: -4.h,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(false),
                        borderRadius: BorderRadius.circular(18.r),
                        child: Container(
                          width: 30.w,
                          height: 30.w,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: const Color(0xFF1B1F26),
                            size: 22.sp,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                  height: _hasFixedDocumentType
                      ? 6.h
                      : (_showIdAndExpiry ? 14.h : 28.h)),

              // Document type dropdown (hidden when a fixed type is pre-selected).
              if (!_hasFixedDocumentType)
                _buildPillField(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton2<String>(
                      value: _selectedType,
                      isExpanded: true,
                      hint: Center(
                        child: Text(
                          _isLoadingTypes && _types.isEmpty
                              ? 'Loading document types...'
                              : 'document type',
                          style: GoogleFonts.poppins(
                            color: Colors.grey,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      items: _types
                          .map(
                            (t) => DropdownMenuItem<String>(
                              value: t,
                              child: Center(
                                child: Text(
                                  t,
                                  overflow: TextOverflow.visible,
                                  style: GoogleFonts.poppins(
                                    color: Colors.black87,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _isLoadingTypes && _types.isEmpty
                          ? null
                          : (v) => setState(() => _selectedType = v),
                      // Keep the pill container as the button background.
                      buttonStyleData: ButtonStyleData(
                        height: 30.h,
                        padding: EdgeInsets.symmetric(horizontal: 4.w),
                        decoration:
                            const BoxDecoration(color: Colors.transparent),
                      ),
                      iconStyleData: const IconStyleData(
                        icon: Icon(Icons.keyboard_arrow_down_rounded),
                        iconSize: 20,
                        iconEnabledColor: Colors.grey,
                      ),
                      dropdownStyleData: DropdownStyleData(
                        maxHeight: 260.h,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16.r),
                          color: Colors.white,
                        ),
                        offset: const Offset(0, -4),
                        scrollbarTheme: ScrollbarThemeData(
                          radius: const Radius.circular(40),
                          thickness: WidgetStateProperty.all(6),
                          thumbVisibility: WidgetStateProperty.all(true),
                        ),
                      ),
                      menuItemStyleData: MenuItemStyleData(
                        height: 44.h,
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
                      ),
                    ),
                  ),
                ),
              SizedBox(
                  height: _hasFixedDocumentType
                      ? 0
                      : (_showIdAndExpiry ? 14.h : 40.h)),

              if (_showIdAndExpiry) ...[
                SizedBox(height: 10.h),
                _buildPillField(
                  child: TextField(
                    controller: _idController,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      color: Colors.black87,
                    ),
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    decoration: InputDecoration(
                      hintText: 'ID Number',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 1.0,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                  ),
                ),
                SizedBox(height: 10.h),
                GestureDetector(
                  onTap: _pickDate,
                  child: _buildPillField(
                    child: Row(
                      children: [
                        Expanded(
                          child: Center(
                            child: Text(
                              expiryText,
                              style: GoogleFonts.poppins(
                                fontSize: 12.sp,
                                color: _expiryDate == null
                                    ? Colors.grey
                                    : Colors.black87,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              SizedBox(height: 14.h),

              InkWell(
                onTap: _pickFile,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.cloud_upload_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _attachedFileName == null
                              ? 'Attach  Files'
                              : _attachedFileName!,
                          maxLines: null,
                          overflow: TextOverflow.visible,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14.sp,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Container(
                      height: 1.2,
                      width: 120.w,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 12.h),

              CustomSliderButton(
                key: _sliderKey,
                onSlideComplete: _submitExpense,
                loginResponseModel: SharedPref.getLoginData(),
                enableProgressColor: false,
                idleGradient: const LinearGradient(
                  colors: [Color(0xFFF2F2F2), Color(0xFFE6E6E6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                completedGradient: const LinearGradient(
                  colors: [Color(0xFFBDBDBD), Color(0xFFB0B0B0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                idleBorderColor: Color(0x00000000),
                completedBorderColor: Color(0x00000000),
                idleLabelColor: Color(0xFF8A8A8A),
                completedLabelColor: Color(0xFF4A4A4A),
                idleHandleColor: Color(0xFF4A4A4A),
                completedHandleColor: Color(0xFF4A4A4A),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillField({required Widget child}) {
    return Container(
      height: 30.h,
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
      ),
      child: Center(child: child),
    );
  }
}
