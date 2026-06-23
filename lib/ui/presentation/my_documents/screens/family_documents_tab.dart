import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:file_picker/file_picker.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

/// Family Documents Tab
/// Shows folder categories (Emirates ID, Birth Certificates, etc.)
/// Tapping a folder opens a grid of individual document cards.
class FamilyDocumentsTab extends StatefulWidget {
  const FamilyDocumentsTab({
    super.key,
    required this.isActive,
    required this.documents,
    required this.statTotal,
    required this.statRequested,
    required this.statExpiringSoon,
    required this.statExpired,
    required this.selectedDocType,
    required this.recentActivities,
    this.isLoading = false,
    this.onDocTypeSelected,
    this.onOpenDocument,
    this.onChangeDocument,
    this.onAddDocument,
    this.onAddNewRequest,
    this.onInlineFormVisibilityChanged,
  });

  final bool isActive;
  final List<Map<String, dynamic>> documents;
  final String statTotal;
  final String statRequested;
  final String statExpiringSoon;
  final String statExpired;
  final String? selectedDocType;
  final List<Map<String, dynamic>> recentActivities;
  final bool isLoading;
  final ValueChanged<String?>? onDocTypeSelected;
  final Future<void> Function(Map<String, dynamic> document)? onOpenDocument;
  final Future<void> Function(Map<String, dynamic> document)? onChangeDocument;
  final VoidCallback? onAddDocument;
  final VoidCallback? onAddNewRequest;
  final ValueChanged<bool>? onInlineFormVisibilityChanged;

  @override
  State<FamilyDocumentsTab> createState() => _FamilyDocumentsTabState();
}

class _InlineCaseOption {
  const _InlineCaseOption({
    required this.key,
    required this.label,
    required this.docs,
  });

  final String key;
  final String label;
  final List<_InlineDocRequirement> docs;
}

class _InlineDocRequirement {
  const _InlineDocRequirement({
    required this.field,
    required this.label,
    required this.type,
  });

  final String field;
  final String label;
  final String type;
}

class _InlineNationalityOption {
  const _InlineNationalityOption({required this.id, required this.name});

  final int id;
  final String name;
}

class _InlinePickedFile {
  const _InlinePickedFile({required this.path, required this.filename});

  final String path;
  final String filename;
}

class _FamilyDocumentsTabState extends State<FamilyDocumentsTab> {
  // Currently selected folder (null = show folders list)
  String? _selectedFolder;
  bool _folderSelectedByUser = false;
  DateTime _lastActivatedAt = DateTime.fromMillisecondsSinceEpoch(0);
  final PageController _folderPageController =
      PageController(viewportFraction: 0.82);
  final PageController _statsPageController =
      PageController(viewportFraction: 0.355);

  // Inline add-request form state (same screen, no separate route)
  bool _showInlineRequestForm = false;
  String? _inlineFormReturnDocType;
  bool _inlineInitLoading = false;
  bool _inlineSubmitting = false;
  String? _inlineInitError;

  String? _inlineRelationship;
  String? _inlineCaseKey;
  int? _inlineNationalityId;
  DateTime? _inlineDob;
  String? _expandedDocField;

  final TextEditingController _inlineNameController = TextEditingController();
  final TextEditingController _inlineDobController = TextEditingController();

  final Map<String, _InlinePickedFile> _inlinePickedFiles =
      <String, _InlinePickedFile>{};
  final Map<String, DateTime> _inlineDocExpiryDates = <String, DateTime>{};
  List<_InlineCaseOption> _inlineCaseOptions = const <_InlineCaseOption>[];
  List<_InlineNationalityOption> _inlineNationalities =
      const <_InlineNationalityOption>[];
  List<_InlineDocRequirement> _inlineRequiredDocs =
      const <_InlineDocRequirement>[];

  bool _isTruthy(dynamic value) {
    if (value == true || value == 1) return true;
    final normalized = (value ?? '').toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  bool _looksLikeFamilyDocument(Map<String, dynamic> doc) {
    if (doc['_isFamily'] == true) return true;
    if (_isTruthy(doc['is_family']) || _isTruthy(doc['family'])) return true;

    for (final key in const [
      'family_member',
      'family_member_name',
      'family_member_label',
      'relation',
    ]) {
      final value = (doc[key] ?? '').toString().trim();
      if (value.isNotEmpty && value != '-') return true;
    }

    final type = (doc['title'] ?? doc['document_type'] ?? doc['type'] ?? '')
        .toString()
        .toLowerCase();
    final name = (doc['name'] ?? '').toString().toLowerCase();
    return type.contains('family') || name.contains('family');
  }

  List<Map<String, dynamic>> _liveFamilyDocuments() {
    final docs = widget.documents;
    if (docs.isEmpty) return const [];

    // Parent already scopes family-tab data; keep all tagged family records.
    if (widget.isActive && docs.every((doc) => doc['_isFamily'] == true)) {
      return docs;
    }

    return docs.where(_looksLikeFamilyDocument).toList(growable: false);
  }

  String _normalizeFolderName(String value) {
    return value.trim().toLowerCase();
  }

  String _folderNameFromLiveDoc(Map<String, dynamic> doc) {
    for (final candidate in [
      doc['title'],
      doc['document_type'],
      doc['type'],
      doc['name']
    ]) {
      final value = (candidate ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return 'Family Documents';
  }

  List<Map<String, dynamic>> _effectiveFolders(
      List<Map<String, dynamic>> liveDocs) {
    if (liveDocs.isEmpty) return const [];

    final grouped = <String, Map<String, dynamic>>{};
    for (final doc in liveDocs) {
      final folderName = _folderNameFromLiveDoc(doc);
      final key = _normalizeFolderName(folderName);
      final entry = grouped[key];
      if (entry == null) {
        grouped[key] = {
          'name': folderName,
          '_count': 1,
        };
      } else {
        entry['_count'] = ((entry['_count'] as int?) ?? 0) + 1;
      }
    }

    final result = grouped.values.toList(growable: false);
    result.sort((a, b) => (a['name'] as String)
        .toLowerCase()
        .compareTo((b['name'] as String).toLowerCase()));
    return result;
  }

  List<Map<String, dynamic>> _documentsForSelectedFolder(
      List<Map<String, dynamic>> liveDocs) {
    final selectedFolder = _selectedFolder;
    if (selectedFolder == null) return const [];

    if (liveDocs.isEmpty) return const [];

    final selectedKey = _normalizeFolderName(selectedFolder);
    return liveDocs
        .where((doc) =>
            _normalizeFolderName(_folderNameFromLiveDoc(doc)) == selectedKey)
        .toList(growable: false);
  }

  String _normalizeToken(dynamic value) {
    return (value ?? '')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Map<String, dynamic>? _extractResultMap(dynamic decoded) {
    if (decoded is! Map) return null;

    if (decoded['result'] is Map) {
      return Map<String, dynamic>.from(decoded['result'] as Map);
    }

    if (decoded['status'] != null || decoded['data'] != null) {
      return Map<String, dynamic>.from(decoded);
    }

    return null;
  }

  String _backendFamilyMemberValue(String? relationship) {
    final normalized = (relationship ?? '').trim().toLowerCase();
    if (normalized == 'spouse') return 'spouse';
    if (normalized == 'child') return 'child';
    return '';
  }

  Future<void> _pickDate({
    required ValueChanged<DateTime> onPicked,
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: firstDate ?? now.subtract(const Duration(days: 365 * 80)),
      lastDate: lastDate ?? DateTime(now.year + 50),
    );
    if (picked != null) {
      onPicked(picked);
    }
  }

  void _clearFolderNavigationState() {
    _selectedFolder = null;
    _folderSelectedByUser = false;
  }

  Future<void> _openInlineRequestForm() async {
    final returnDocType = widget.selectedDocType ?? 'requested';
    widget.onInlineFormVisibilityChanged?.call(true);
    setState(() {
      _inlineFormReturnDocType = returnDocType;
      _showInlineRequestForm = true;
      _clearFolderNavigationState();
      _inlineRelationship = 'spouse';
      _inlineCaseKey = null;
      _inlineNationalityId = null;
      _inlineDob = null;
      _expandedDocField = null;
      _inlineInitError = null;
      _inlineCaseOptions = const <_InlineCaseOption>[];
      _inlineNationalities = const <_InlineNationalityOption>[];
      _inlineRequiredDocs = const <_InlineDocRequirement>[];
      _inlinePickedFiles.clear();
      _inlineDocExpiryDates.clear();
      _inlineNameController.clear();
      _inlineDobController.clear();
    });

    await _loadInlineInit('spouse');
  }

  void _closeInlineRequestForm({bool restoreFilter = true}) {
    final returnDocType = _inlineFormReturnDocType;
    widget.onInlineFormVisibilityChanged?.call(false);
    setState(() {
      _showInlineRequestForm = false;
      _inlineFormReturnDocType = null;
      _expandedDocField = null;
      _clearFolderNavigationState();
    });

    if (!restoreFilter || returnDocType == null) return;
    if (widget.selectedDocType != returnDocType) {
      widget.onDocTypeSelected?.call(returnDocType);
    }
  }

  Future<void> _onInlineRelationshipChanged(String? value) async {
    if (value == null || value == _inlineRelationship) return;

    setState(() {
      _inlineRelationship = value;
      _inlineCaseKey = null;
      _inlineNationalityId = null;
      _expandedDocField = null;
      _inlineInitError = null;
      _inlineCaseOptions = const <_InlineCaseOption>[];
      _inlineNationalities = const <_InlineNationalityOption>[];
      _inlineRequiredDocs = const <_InlineDocRequirement>[];
      _inlinePickedFiles.clear();
      _inlineDocExpiryDates.clear();
    });

    await _loadInlineInit(value);
  }

  Future<void> _loadInlineInit(String relationship) async {
    if (_inlineInitLoading) return;
    final familyMember = _backendFamilyMemberValue(relationship);
    if (familyMember.isEmpty) return;

    setState(() {
      _inlineInitLoading = true;
      _inlineInitError = null;
    });

    try {
      final token = SharedPref.getLoginData().result?.token ?? '';
      if (token.isEmpty) {
        setState(() {
          _inlineInitError = 'Session expired. Please login again.';
        });
        return;
      }

      final response = await http.post(
        Uri.parse('https://erp.elrace.com/api/family_insurance/init'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'params': {
            'family_member': familyMember,
          },
        }),
      );

      if (response.statusCode != 200) {
        setState(() {
          _inlineInitError = 'Failed to load request setup.';
        });
        return;
      }

      final decoded = jsonDecode(response.body);
      final result = _extractResultMap(decoded);
      if (result == null) {
        setState(() {
          _inlineInitError = 'Invalid setup response.';
        });
        return;
      }

      final statusToken = _normalizeToken(result['status']);
      if (!(statusToken == 'success' ||
          statusToken == 'ok' ||
          statusToken == 'true')) {
        setState(() {
          _inlineInitError =
              (result['message'] ?? 'Failed to load request setup.').toString();
        });
        return;
      }

      final data = (result['data'] is Map)
          ? Map<String, dynamic>.from(result['data'] as Map)
          : <String, dynamic>{};

      final casesRaw = (data['medical_request_cases'] is List)
          ? (data['medical_request_cases'] as List)
          : const [];
      final nationalitiesRaw = (data['nationalities'] is List)
          ? (data['nationalities'] as List)
          : const [];

      final parsedCases = <_InlineCaseOption>[];
      for (final item in casesRaw) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final caseKey = (map['case_key'] ?? '').toString().trim();
        final caseLabel = (map['case_label'] ?? caseKey).toString().trim();
        if (caseKey.isEmpty) continue;

        final docs = <_InlineDocRequirement>[];
        final docsRaw = (map['required_documents'] is List)
            ? (map['required_documents'] as List)
            : const [];
        for (final doc in docsRaw) {
          if (doc is! Map) continue;
          final d = Map<String, dynamic>.from(doc);
          final field = (d['field'] ?? '').toString().trim();
          if (field.isEmpty) continue;
          docs.add(
            _InlineDocRequirement(
              field: field,
              label: (d['label'] ?? field).toString().trim(),
              type: (d['type'] ?? '').toString().trim(),
            ),
          );
        }

        parsedCases.add(
          _InlineCaseOption(key: caseKey, label: caseLabel, docs: docs),
        );
      }

      final parsedNationalities = <_InlineNationalityOption>[];
      for (final item in nationalitiesRaw) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final id = int.tryParse((map['id'] ?? '').toString());
        final name = (map['name'] ?? '').toString().trim();
        if (id == null || name.isEmpty) continue;
        parsedNationalities.add(_InlineNationalityOption(id: id, name: name));
      }

      setState(() {
        _inlineCaseOptions = parsedCases;
        _inlineNationalities = parsedNationalities;
        _inlineCaseKey = parsedCases.isNotEmpty ? parsedCases.first.key : null;
        _inlineNationalityId = parsedNationalities.isNotEmpty
            ? parsedNationalities.first.id
            : null;
      });

      _syncInlineRequiredDocs();
    } catch (_) {
      setState(() {
        _inlineInitError = 'Failed to load request setup.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _inlineInitLoading = false;
        });
      }
    }
  }

  void _syncInlineRequiredDocs() {
    final selected = _inlineCaseOptions.where((c) => c.key == _inlineCaseKey);
    final docs = <_InlineDocRequirement>[];
    if (selected.isNotEmpty) {
      docs.addAll(selected.first.docs);
    }

    final relation = (_inlineRelationship ?? '').toLowerCase();
    if (relation == 'spouse' &&
        !docs.any((d) => d.field == 'marriage_certificate_file')) {
      docs.add(
        const _InlineDocRequirement(
          field: 'marriage_certificate_file',
          label: 'Marriage Certificate',
          type: 'pdf',
        ),
      );
    }
    if (relation == 'child' &&
        !docs.any((d) => d.field == 'birth_certificate_file')) {
      docs.add(
        const _InlineDocRequirement(
          field: 'birth_certificate_file',
          label: 'Birth Certificate(English Version)',
          type: 'pdf',
        ),
      );
    }

    setState(() {
      _inlineRequiredDocs = docs;
      if (_expandedDocField != null &&
          !docs.any((d) => d.field == _expandedDocField)) {
        _expandedDocField = null;
      }
    });
  }

  Future<void> _pickInlineDocFile(String field,
      {required bool imageOnly}) async {
    final extensions = imageOnly
        ? const ['jpg', 'jpeg', 'png']
        : const ['pdf', 'jpg', 'jpeg', 'png'];

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.single;
    if (picked.path == null) return;

    setState(() {
      _inlinePickedFiles[field] =
          _InlinePickedFile(path: picked.path!, filename: picked.name);
    });
  }

  bool _validateInlineBeforeSubmit() {
    if ((_inlineRelationship ?? '').isEmpty) {
      _showInlineSnack('Please select relationship.');
      return false;
    }
    if ((_inlineCaseKey ?? '').isEmpty) {
      _showInlineSnack('Please select document type to update.');
      return false;
    }
    if (_inlineNameController.text.trim().isEmpty) {
      _showInlineSnack('Please enter full name.');
      return false;
    }
    if (_inlineDob == null) {
      _showInlineSnack('Please select date of birth.');
      return false;
    }
    if (_inlineNationalityId == null) {
      _showInlineSnack('Please select nationality.');
      return false;
    }

    for (final req in _inlineRequiredDocs) {
      if (_inlinePickedFiles[req.field] == null) {
        _showInlineSnack('Please attach ${req.label}.');
        return false;
      }
    }

    return true;
  }

  Future<void> _submitInlineRequest() async {
    if (_inlineSubmitting) return;
    if (!_validateInlineBeforeSubmit()) return;

    setState(() {
      _inlineSubmitting = true;
    });

    try {
      final token = SharedPref.getLoginData().result?.token ?? '';
      if (token.isEmpty) {
        _showInlineSnack('Session expired. Please login again.');
        return;
      }

      final params = <String, dynamic>{
        'family_member': _backendFamilyMemberValue(_inlineRelationship),
        'medical_request_case': _inlineCaseKey,
        'family_member_name': _inlineNameController.text.trim(),
        'family_member_dob': DateFormat('yyyy-MM-dd').format(_inlineDob!),
        'family_member_nationality_id': _inlineNationalityId,
      };

      for (final req in _inlineRequiredDocs) {
        final picked = _inlinePickedFiles[req.field];
        if (picked == null) continue;

        final bytes = await File(picked.path).readAsBytes();
        params[req.field] = base64Encode(bytes);
        params[req.field.replaceFirst('_file', '_filename')] = picked.filename;

        final expiry = _inlineDocExpiryDates[req.field];
        if (expiry != null) {
          params[req.field.replaceFirst('_file', '_expiry_date')] =
              DateFormat('yyyy-MM-dd').format(expiry);
        }
      }

      final response = await http.post(
        Uri.parse('https://erp.elrace.com/api/family_insurance/submit'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'params': params,
        }),
      );

      final decoded = jsonDecode(response.body);
      final result = _extractResultMap(decoded);
      final statusToken = _normalizeToken(result?['status']);
      final isOk = response.statusCode == 200 &&
          (statusToken == 'success' ||
              statusToken == 'ok' ||
              statusToken == 'true');

      if (!isOk) {
        final message = (result?['message'] ??
                (decoded is Map ? decoded['message'] : null) ??
                'Failed to submit request.')
            .toString();
        _showInlineSnack(message);
        return;
      }

      _showInlineSnack('Request submitted successfully.');
      _closeInlineRequestForm(restoreFilter: false);
      widget.onDocTypeSelected?.call('requested');
    } catch (_) {
      _showInlineSnack('Failed to submit request.');
    } finally {
      if (mounted) {
        setState(() {
          _inlineSubmitting = false;
        });
      }
    }
  }

  void _showInlineSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(dynamic raw) {
    if (raw == null || raw == false || raw.toString().trim().isEmpty) return '';
    try {
      final date = DateTime.parse(raw.toString());
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (_) {
      return raw.toString();
    }
  }

  void _openFolder(String folderName) {
    if (!widget.isActive) return;

    // Prevent accidental immediate open right after switching to Family tab.
    if (DateTime.now().difference(_lastActivatedAt) <
        const Duration(milliseconds: 300)) {
      return;
    }

    setState(() {
      _selectedFolder = folderName;
      _folderSelectedByUser = true;
    });
    // TODO: Fetch real folder documents from API
    // _fetchFolderDocuments(folderName);
  }

  void _goBackToFolders() {
    setState(() {
      _selectedFolder = null;
      _folderSelectedByUser = false;
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _lastActivatedAt = DateTime.now();
    }
  }

  @override
  void dispose() {
    _folderPageController.dispose();
    _statsPageController.dispose();
    _inlineNameController.dispose();
    _inlineDobController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FamilyDocumentsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Always reset to folders when Family tab becomes active.
    if (!oldWidget.isActive && widget.isActive) {
      _selectedFolder = null;
      _folderSelectedByUser = false;
      _lastActivatedAt = DateTime.now();
      return;
    }

    // Reset to folders view whenever user leaves Family tab.
    if (oldWidget.isActive && !widget.isActive) {
      _clearFolderNavigationState();
      return;
    }

    // Entering/leaving stats filters should not resurrect an old folder page.
    if (oldWidget.selectedDocType != widget.selectedDocType) {
      _clearFolderNavigationState();
    }

    // If data changed and selected folder no longer exists, go back to folders.
    final selectedFolder = _selectedFolder;
    if (selectedFolder != null) {
      final currentFolders = _effectiveFolders(_liveFamilyDocuments())
          .map((folder) => _normalizeFolderName(folder['name'].toString()))
          .toSet();
      if (!currentFolders.contains(_normalizeFolderName(selectedFolder))) {
        _selectedFolder = null;
        _folderSelectedByUser = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (!widget.isActive) return true;

        if (_showInlineRequestForm) {
          _closeInlineRequestForm();
          return false;
        }

        // In filtered mode, back should clear filter first.
        if (widget.selectedDocType != null) {
          widget.onDocTypeSelected?.call(null);
          return false;
        }

        // In folder details mode, back should return to folders first.
        if (_selectedFolder != null && _folderSelectedByUser) {
          _goBackToFolders();
          return false;
        }

        return true;
      },
      child: Builder(
        builder: (context) {
          if (_showInlineRequestForm) {
            return _buildInlineRequestForm();
          }

          if (widget.isActive && widget.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final liveDocs = _liveFamilyDocuments();
          final selectedDocType = widget.selectedDocType;

          if (selectedDocType != null) {
            return _buildFilteredMode(liveDocs, selectedDocType);
          }

          final isFolderView = _selectedFolder != null && _folderSelectedByUser;

          return Navigator(
            pages: [
              MaterialPage(
                key: const ValueKey('family_folders'),
                child: _buildFoldersList(liveDocs),
              ),
              if (isFolderView)
                MaterialPage(
                  key: ValueKey('family_docs_$_selectedFolder'),
                  child: Builder(
                    builder: (pageContext) =>
                        _buildDocumentsList(pageContext, liveDocs),
                  ),
                ),
            ],
            onPopPage: (route, result) {
              if (!route.didPop(result)) return false;
              setState(() {
                _selectedFolder = null;
                _folderSelectedByUser = false;
              });
              return true;
            },
          );
        },
      ),
    );
  }

  bool _isExpiredDocument(Map<String, dynamic> doc) {
    final rawExpiry = doc['expiry_date'];
    if (rawExpiry == null || rawExpiry == false) return false;
    final parsed = DateTime.tryParse(rawExpiry.toString());
    if (parsed == null) return false;
    return parsed.isBefore(DateTime.now());
  }

  Map<String, dynamic> _selectedStatMeta(String docType) {
    switch (docType) {
      case 'expired':
        return {
          'label': 'Expired',
          'value': widget.statExpired,
          'background': const Color(0xFFE2F3E9),
          'labelColor': const Color(0xFFBA1719),
          'valueColor': const Color(0xFFBA1719),
          'icon': Icons.error_outline_rounded,
          'iconColor': const Color(0xFFBA1719),
        };
      case 'requested':
        return {
          'label': 'Requested',
          'value': widget.statRequested,
          'background': const Color(0xFFF6CC1B),
          'labelColor': Colors.black,
          'valueColor': Colors.black,
          'icon': Icons.assignment_outlined,
          'iconColor': Colors.black,
        };
      case 'expiry_soon':
        return {
          'label': 'Expired soon',
          'value': widget.statExpiringSoon,
          'background': const Color(0xFF8B2AB3),
          'labelColor': Colors.white,
          'valueColor': Colors.white,
          'icon': Icons.access_time_rounded,
          'iconColor': Colors.white,
        };
      default:
        return {
          'label': 'Total',
          'value': widget.statTotal,
          'background': const Color(0xFF2F6AD8),
          'labelColor': Colors.white,
          'valueColor': Colors.white,
          'icon': Icons.insert_drive_file_outlined,
          'iconColor': Colors.white,
        };
    }
  }

  Widget _buildFilteredMode(
      List<Map<String, dynamic>> liveDocs, String selectedDocType) {
    if (selectedDocType == 'requested') {
      return _buildRequestedMode(liveDocs);
    }

    final meta = _selectedStatMeta(selectedDocType);
    final forceRedBorder =
        selectedDocType == 'expired' || selectedDocType == 'expiry_soon';

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
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      meta['icon'] as IconData,
                      size: 32.sp,
                      color: meta['iconColor'] as Color,
                    ),
                    SizedBox(width: 10.w),
                    Flexible(
                      child: Text(
                        meta['label'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 30.sp / 2,
                          fontWeight: FontWeight.w700,
                          color: meta['labelColor'] as Color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                (meta['value'] ?? '-').toString(),
                style: GoogleFonts.poppins(
                  fontSize: 88.sp / 2,
                  fontWeight: FontWeight.w700,
                  color: meta['valueColor'] as Color,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        if (liveDocs.isEmpty)
          _buildEmptyState(
            icon: Icons.folder_off_rounded,
            title: 'No Documents',
            subtitle: 'There are no documents for this filter.',
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: liveDocs.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
              mainAxisExtent: 270.h,
            ),
            itemBuilder: (context, index) {
              final doc = liveDocs[index];
              final iconPath =
                  (doc['icon'] ?? 'assets/png/other-documetns-icon.png')
                      .toString();
              final title = (doc['title'] ?? '').toString();
              final name = (doc['name'] ?? '').toString();
              final isExpired = _isExpiredDocument(doc);
              final useRedBorder = forceRedBorder || isExpired;

              return GestureDetector(
                onTap: () {
                  if (widget.onOpenDocument != null) {
                    unawaited(widget.onOpenDocument!(doc));
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24.r),
                    border: Border.all(
                      color: useRedBorder
                          ? const Color(0xFFBA1719)
                          : const Color(0xffD9D9D9),
                      width: useRedBorder ? 2 : 1,
                    ),
                    color: Colors.white,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(10.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 90.h,
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
                        SizedBox(height: 8.h),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF727272),
                            letterSpacing: 1.0,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          maxLines: null,
                          overflow: TextOverflow.visible,
                          style: GoogleFonts.poppins(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        if (useRedBorder) ...[
                          SizedBox(height: 8.h),
                          GestureDetector(
                            onTap: () {
                              final callback = widget.onChangeDocument;
                              if (callback != null) {
                                unawaited(callback(doc));
                              }
                            },
                            child: Container(
                              constraints: BoxConstraints(minHeight: 24.h),
                              padding: EdgeInsets.symmetric(
                                horizontal: 10.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFF1B1F26),
                                    Color(0xFF717171),
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
              );
            },
          ),
      ],
    );
  }

  String _requestedPersonName(Map<String, dynamic> doc) {
    for (final key in [
      'person_name',
      'family_member_name',
      'name',
      'employee',
      'family_member',
      'title',
    ]) {
      final value = (doc[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return 'Family Member';
  }

  String _requestedRelation(Map<String, dynamic> doc) {
    final raw = (doc['relation'] ??
            doc['family_member_label'] ??
            doc['family_member'] ??
            '')
        .toString()
        .trim();
    if (raw.isEmpty) return 'Family';

    final low = raw.toLowerCase();
    if (low == 'spouse') return 'Spouse';
    if (low == 'wife') return 'Spouse';
    if (low.contains('daughter') || low.contains('female')) return 'Daughter';
    if (low.contains('son') || low.contains('male')) return 'Son';
    if (low.startsWith('child_') || low == 'child') return 'Son';

    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .where((e) => e.isNotEmpty)
        .map((e) => '${e[0].toUpperCase()}${e.substring(1)}')
        .join(' ');
  }

  Color _relationColor(String relation) {
    final low = relation.toLowerCase();
    if (low.contains('spouse')) return const Color(0xFF1EA7E1);
    if (low.contains('son')) return const Color(0xFFF2A100);
    if (low.contains('daughter')) return const Color(0xFF5B39D6);
    return const Color(0xFF1EA7E1);
  }

  String _stringField(Map<String, dynamic> doc, List<String> keys,
      {String fallback = '-'}) {
    for (final key in keys) {
      final value = (doc[key] ?? '').toString().trim();
      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return fallback;
  }

  String _requestedPassportNo(Map<String, dynamic> doc) => _stringField(
        doc,
        const ['passport_no', 'passport_number', 'passport'],
      );

  String _requestedEidNo(Map<String, dynamic> doc) => _stringField(
        doc,
        const ['eid_no', 'emirates_id_no', 'eid_number', 'emirates_id'],
      );

  String _requestedNationality(Map<String, dynamic> doc) => _stringField(
        doc,
        const [
          'nationality',
          'family_member_nationality',
          'family_member_nationality_id',
          'nationality_name'
        ],
      );

  String _requestedBirthDate(Map<String, dynamic> doc) {
    final raw = _stringField(
      doc,
      const ['birth_date', 'family_member_dob', 'dob'],
      fallback: '',
    );
    if (raw.isEmpty) return '-';
    return _formatDate(raw);
  }

  String _requestedPassportExpiry(Map<String, dynamic> doc) {
    final raw = _stringField(
      doc,
      const ['passport_expiry_date', 'passport_expiry', 'expiry_date'],
      fallback: '',
    );
    if (raw.isEmpty) return '-';
    return _formatDate(raw);
  }

  String _requestedEidExpiry(Map<String, dynamic> doc) {
    final raw = _stringField(
      doc,
      const [
        'eid_expiry_date',
        'emirates_id_expiry_date',
        'eid_expiry',
        'expiry_date'
      ],
      fallback: '',
    );
    if (raw.isEmpty) return '-';
    return _formatDate(raw);
  }

  String? _requestedPhoto(Map<String, dynamic> doc) {
    for (final key in ['photo', 'image_url', 'avatar', 'image']) {
      final value = (doc[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  Widget _buildRequestedSummaryCard() {
    return Container(
      height: 96.h,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF6CC1B),
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
              Image.asset(
                'assets/newapp/newicon/document_requested.png',
                width: 30.w,
                height: 30.w,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.assignment_outlined,
                  size: 30.sp,
                  color: Colors.black,
                ),
              ),
              SizedBox(width: 10.w),
              Text(
                'Requested',
                style: GoogleFonts.poppins(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          Text(
            widget.statRequested,
            style: GoogleFonts.poppins(
              fontSize: 44.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddNewRequestCard() {
    return GestureDetector(
      onTap: () {
        unawaited(_openInlineRequestForm());
      },
      child: Container(
        height: 64.h,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: const Color(0xFFBEBEBE), width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_add,
              size: 24.sp,
              color: const Color(0xFF8C8C8C),
            ),
            SizedBox(width: 8.w),
            Text(
              'Add New Request',
              style: GoogleFonts.poppins(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF777777),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestedCard(Map<String, dynamic> doc) {
    final personName = _requestedPersonName(doc);
    final relation = _requestedRelation(doc);
    final relationColor = _relationColor(relation);
    final passportNo = _requestedPassportNo(doc);
    final eidNo = _requestedEidNo(doc);
    final nationality = _requestedNationality(doc);
    final birthDate = _requestedBirthDate(doc);
    final passportExpiry = _requestedPassportExpiry(doc);
    final eidExpiry = _requestedEidExpiry(doc);
    final photo = _requestedPhoto(doc);

    return GestureDetector(
      onTap: () {
        if (widget.onOpenDocument != null) {
          unawaited(widget.onOpenDocument!(doc));
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: const Color(0xFFD1D1D1),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 21.r,
                  backgroundColor: const Color(0xFFE7E7E7),
                  backgroundImage: photo != null ? NetworkImage(photo) : null,
                  child: photo == null
                      ? Text(
                          personName.isEmpty
                              ? 'F'
                              : personName[0].toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF5F5F5F),
                          ),
                        )
                      : null,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        personName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        relation,
                        style: GoogleFonts.poppins(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: relationColor,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                _requestedExpiryColumn(passportExpiry, eidExpiry),
              ],
            ),
            SizedBox(height: 10.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _requestedInfoRow('Passport No', passportNo),
                      SizedBox(height: 6.h),
                      _requestedInfoRow('EID No', eidNo),
                      SizedBox(height: 6.h),
                      _requestedInfoRow('Nationality', nationality),
                      SizedBox(height: 6.h),
                      _requestedInfoRow('Birth date', birthDate),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _requestedInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 94.w,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ),
        Text(
          '|',
          style: GoogleFonts.poppins(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        SizedBox(width: 6.w),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  Widget _requestedExpiryColumn(String passportExpiry, String eidExpiry) {
    final hasPassport = passportExpiry.trim().isNotEmpty;
    final hasEid = eidExpiry.trim().isNotEmpty;
    if (!hasPassport && !hasEid) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (hasPassport)
          _requestedExpiryText(passportExpiry, rightAligned: true),
        if (hasPassport && hasEid) SizedBox(height: 2.h),
        if (hasEid) _requestedExpiryText(eidExpiry, rightAligned: true),
      ],
    );
  }

  Widget _requestedExpiryText(String dateText, {bool rightAligned = false}) {
    return Text(
      'Expiry date | $dateText',
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.fade,
      textAlign: rightAligned ? TextAlign.right : TextAlign.start,
      style: GoogleFonts.poppins(
        fontSize: 12.sp,
        fontWeight: FontWeight.w600,
        color: const Color(0xFFCC3A3A),
      ),
    );
  }

  Widget _buildRequestedMode(List<Map<String, dynamic>> docs) {
    return ListView(
      padding: EdgeInsets.only(left: 12.w, right: 12.w, top: 14.h, bottom: 8.h),
      children: [
        _buildRequestedSummaryCard(),
        SizedBox(height: 12.h),
        _buildAddNewRequestCard(),
        SizedBox(height: 12.h),
        if (docs.isEmpty)
          _buildEmptyState(
            icon: Icons.folder_off_rounded,
            title: 'No Requested Documents',
            subtitle: 'There are no family document requests yet.',
          )
        else
          ...docs.map((doc) => Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: _buildRequestedCard(doc),
              )),
      ],
    );
  }

  String _docDisplayLabel(_InlineDocRequirement req) {
    if (req.field == 'e_visa_file' &&
        _inlineCaseKey == 'visit_to_resident_visa') {
      return 'E-Visa with Changed Status';
    }

    const customLabels = <String, String>{
      'emirates_id_file': 'Emirates ID',
      'passport_copy_file': 'Passport Copy',
      'marriage_certificate_file': 'Marriage Certificate',
      'resident_cancellation_file': 'Previous Resident Cancellation',
      'coc_file': 'COC',
      'e_visa_file': 'E-Visa',
      'changed_status_file': 'Changed Status',
      'entry_stamp_file': 'Entry Stamp',
      'birth_certificate_file': 'Birth Certificate(English Version)',
      'visit_visa_file': 'Visit Visa',
    };

    final fromMap = customLabels[req.field];
    if (fromMap != null) return fromMap;
    if (req.label.trim().isNotEmpty) return req.label.trim();
    return req.field.replaceAll('_', ' ').replaceAll(' file', '');
  }

  Widget _buildInlineRequestForm() {
    final docsToShow = _inlineRequiredDocs
        .where((d) => d.field != 'photo_file')
        .toList(growable: false);

    return ListView(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 12.h),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: _closeInlineRequestForm,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: const Color(0xFF1A237E),
            tooltip: 'Back to requested',
          ),
        ),
        Container(
          color: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
          child: Column(
            children: [
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onTap: () =>
                          _pickInlineDocFile('photo_file', imageOnly: true),
                      child: Container(
                        width: 105.w,
                        height: 105.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE2E2E2),
                          border: Border.all(
                            color: const Color(0xFFC8C8C8),
                            width: 1.2,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Icon(
                          Icons.add_a_photo_outlined,
                          size: 28.sp,
                          color: const Color(0xFF837D70),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 22.w,
                        height: 22.w,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF6CC1B),
                          shape: BoxShape.circle,
                        ),
                        child:
                            Icon(Icons.edit, size: 11.sp, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 18.h),
              Row(
                children: [
                  Icon(Icons.person_outline_rounded,
                      size: 15.sp, color: const Color(0xFF6A6A6A)),
                  SizedBox(width: 6.w),
                  Text(
                    'Basic Information',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF6A6A6A),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              _inlineLabel('Full Name'),
              _inlineTextField(
                controller: _inlineNameController,
                hint: 'Enter name',
              ),
              SizedBox(height: 10.h),
              _inlineLabel('Relationship'),
              _inlineDropdown<String>(
                value: _inlineRelationship,
                hint: 'Select',
                items: const [
                  DropdownMenuItem(value: 'child', child: Text('Child')),
                  DropdownMenuItem(value: 'spouse', child: Text('Spouse')),
                ],
                onChanged: (v) => unawaited(_onInlineRelationshipChanged(v)),
              ),
              SizedBox(height: 10.h),
              _inlineLabel('Nationality'),
              _inlineDropdown<int>(
                value: _inlineNationalityId,
                hint: _inlineInitLoading ? 'Loading...' : 'e.g. Emirati',
                items: _inlineNationalities
                    .map(
                      (n) => DropdownMenuItem<int>(
                        value: n.id,
                        child: Text(n.name),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (v) => setState(() => _inlineNationalityId = v),
              ),
              SizedBox(height: 10.h),
              _inlineLabel('Date of Birth'),
              _inlineTextField(
                controller: _inlineDobController,
                hint: 'mm/dd/yyyy',
                readOnly: true,
                onTap: () async {
                  await _pickDate(
                    initialDate: _inlineDob,
                    firstDate: DateTime(DateTime.now().year - 100),
                    lastDate: DateTime.now(),
                    onPicked: (d) {
                      setState(() {
                        _inlineDob = d;
                        _inlineDobController.text =
                            DateFormat('MM/dd/yyyy').format(d);
                      });
                    },
                  );
                },
              ),
              SizedBox(height: 10.h),
              _inlineLabel('Document Type To Update'),
              _inlineDropdown<String>(
                value: _inlineCaseKey,
                hint: _inlineInitLoading ? 'Loading...' : 'Select',
                items: _inlineCaseOptions
                    .map((c) => DropdownMenuItem<String>(
                          value: c.key,
                          child: Text(c.label),
                        ))
                    .toList(growable: false),
                onChanged: (v) {
                  setState(() {
                    _inlineCaseKey = v;
                  });
                  _syncInlineRequiredDocs();
                },
              ),
              if ((_inlineInitError ?? '').isNotEmpty) ...[
                SizedBox(height: 8.h),
                Text(
                  _inlineInitError!,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFBA1719),
                    fontSize: 11.sp,
                  ),
                ),
              ],
              SizedBox(height: 10.h),
              ...docsToShow.map(
                (req) => Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: _buildInlineDocAccordionItem(req),
                ),
              ),
              SizedBox(height: 6.h),
              SizedBox(
                width: double.infinity,
                height: 46.h,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF6CC1B),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  onPressed: _inlineSubmitting ? null : _submitInlineRequest,
                  child: _inlineSubmitting
                      ? SizedBox(
                          width: 20.w,
                          height: 20.w,
                          child:
                              const CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_add_alt_1, size: 18.sp),
                            SizedBox(width: 6.w),
                            Text(
                              'Add Family Member',
                              style: GoogleFonts.poppins(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _inlineLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: 4.h, left: 3.w),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            color: const Color(0xFF2B2B2B),
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _inlineTextField({
    required TextEditingController controller,
    required String hint,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      style:
          GoogleFonts.poppins(fontSize: 12.sp, color: const Color(0xFF303030)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(
          fontSize: 11.sp,
          color: const Color(0xFF9A9A9A),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        filled: true,
        fillColor: const Color(0xFFD6D6D8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _inlineDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFD6D6D8),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(
            hint,
            style: GoogleFonts.poppins(
              fontSize: 11.sp,
              color: const Color(0xFF9A9A9A),
            ),
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          style: GoogleFonts.poppins(
            fontSize: 12.sp,
            color: const Color(0xFF2F2F2F),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildInlineDocAccordionItem(_InlineDocRequirement req) {
    final label = _docDisplayLabel(req);
    final expanded = _expandedDocField == req.field;
    final picked = _inlinePickedFiles[req.field];
    final expiry = _inlineDocExpiryDates[req.field];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFD6D6D8),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12.r),
            onTap: () {
              setState(() {
                _expandedDocField = expanded ? null : req.field;
              });
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF222222),
                      ),
                    ),
                  ),
                  Container(
                    width: 18.w,
                    height: 18.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF1E73FF), width: 1.4),
                    ),
                    child: picked == null
                        ? const SizedBox.shrink()
                        : Center(
                            child: Container(
                              width: 10.w,
                              height: 10.w,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1E73FF),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                  ),
                  SizedBox(width: 8.w),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF6E7683),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
              child: Column(
                children: [
                  _inlineLabel('Expiry Date'),
                  _inlineTextField(
                    controller: TextEditingController(
                      text: expiry == null
                          ? ''
                          : DateFormat('MM/dd/yyyy').format(expiry),
                    ),
                    hint: 'mm/dd/yyyy',
                    readOnly: true,
                    onTap: () async {
                      await _pickDate(
                        initialDate: _inlineDocExpiryDates[req.field],
                        onPicked: (d) {
                          setState(() {
                            _inlineDocExpiryDates[req.field] = d;
                          });
                        },
                      );
                    },
                  ),
                  SizedBox(height: 10.h),
                  InkWell(
                    onTap: () => _pickInlineDocFile(
                      req.field,
                      imageOnly: req.type.toLowerCase() == 'image',
                    ),
                    borderRadius: BorderRadius.circular(10.r),
                    child: Container(
                      width: 160.w,
                      padding: EdgeInsets.symmetric(
                          horizontal: 10.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD6D6D8),
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: const Color(0xFFE8DED7),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.cloud_upload_outlined,
                              color: Color(0xFF6A6A6A)),
                          SizedBox(height: 2.h),
                          Text(
                            picked == null ? 'Attach Files' : picked.filename,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 11.sp,
                              color: const Color(0xFF383838),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLiveDocumentsList(
      BuildContext pageContext, List<Map<String, dynamic>> docs) {
    return Column(
      children: [
        Padding(
          padding:
              EdgeInsets.only(left: 8.w, right: 20.w, top: 8.h, bottom: 8.h),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(pageContext).pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: const Color(0xFF27304E),
                tooltip: 'Back to folders',
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30.18),
                    border: Border.all(color: const Color(0xffD9D9D9)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 13.5.w, vertical: 8.5.h),
                    child: Text(
                      '${_selectedFolder ?? 'Documents'}  |  ${docs.length + 1}',
                      maxLines: null,
                      overflow: TextOverflow.visible,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        fontStyle: FontStyle.italic,
                        letterSpacing: .10,
                        color: const Color(0xff949494),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: docs.length + 1,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
              childAspectRatio: 0.75,
            ),
            itemBuilder: (context, index) {
              if (index == 0) {
                return GestureDetector(
                  onTap: () => widget.onAddDocument?.call(),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: const Color(0xffD9D9D9)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.note_add_outlined,
                          size: 48.sp,
                          color: const Color(0xff949494),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Add New',
                          style: GoogleFonts.poppins(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w400,
                            fontStyle: FontStyle.italic,
                            color: const Color(0xff949494),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final doc = docs[index - 1];
              final iconPath =
                  (doc['icon'] ?? 'assets/png/other-documetns-icon.png')
                      .toString();
              final docName =
                  (doc['name'] ?? doc['title'] ?? 'Document').toString();
              final expiryDateText = _formatDate(doc['expiry_date']);
              final issueDateText = _formatDate(doc['issue_date']);
              final dateText =
                  expiryDateText.isNotEmpty ? expiryDateText : issueDateText;

              var isExpired = false;
              final rawExpiry = doc['expiry_date'];
              if (rawExpiry != null && rawExpiry != false) {
                try {
                  final expiry = DateTime.parse(rawExpiry.toString());
                  isExpired = expiry.isBefore(DateTime.now());
                } catch (_) {
                  isExpired = false;
                }
              }

              return GestureDetector(
                onTap: () {
                  if (widget.onOpenDocument != null) {
                    unawaited(widget.onOpenDocument!(doc));
                  }
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: isExpired
                              ? const Color(0xFFBA1719)
                              : const Color(0xffD9D9D9),
                          width: isExpired ? 2 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(10.w),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  if (isExpired)
                                    Padding(
                                      padding: EdgeInsets.only(top: 2.h),
                                      child: SizedBox(
                                        width: 22.w,
                                        height: 22.w,
                                        child: Image.asset(
                                          'assets/newapp/newicon/pencil_7754138 1.png',
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) => Icon(
                                            Icons.edit,
                                            size: 18.sp,
                                            color: const Color(0xFFBA1719),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (isExpired) SizedBox(height: 4.h),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12.r),
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
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              docName,
                              textAlign: TextAlign.center,
                              maxLines: null,
                              overflow: TextOverflow.visible,
                              style: GoogleFonts.poppins(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                            if (dateText.isNotEmpty) ...[
                              SizedBox(height: 2.h),
                              Text(
                                dateText,
                                textAlign: TextAlign.center,
                                maxLines: null,
                                style: GoogleFonts.poppins(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w400,
                                  color: isExpired
                                      ? const Color(0xFFBA1719)
                                      : const Color(0xff949494),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
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

  // ── Folders Grid (Main view) ──
  Widget _buildFoldersList(List<Map<String, dynamic>> liveDocs) {
    final folders = _effectiveFolders(liveDocs);

    return ListView(
      padding: EdgeInsets.only(left: 6.w, right: 6.w, top: 16.h, bottom: 4.h),
      children: [
        _buildSummaryCards(),
        SizedBox(height: 12.h),
        if (folders.isEmpty)
          _buildEmptyState(
            icon: Icons.folder_off_rounded,
            title: 'No Family Documents',
            subtitle:
                'There are no family documents yet. Tap Add Document to create the first one.',
          )
        else ...[
          SizedBox(
            height: 220.h,
            child: PageView.builder(
              controller: _folderPageController,
              padEnds: false,
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index];
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.w),
                  child: GestureDetector(
                    onTap: () => _openFolder(folder['name'].toString()),
                    child: _buildFolderCard(folder),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 14.h),
        ],
        Text(
          'RECENT ACTIVITY',
          style: GoogleFonts.poppins(
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: const Color(0xFF7C7C7C),
          ),
        ),
        SizedBox(height: 10.h),
        ..._buildRecentActivityTiles(),
      ],
    );
  }

  Widget _buildSummaryCards() {
    final cards = [
      {
        'label': 'Total',
        'value': widget.statTotal,
        'docType': null,
        'background': const Color(0xFF2F6AD8),
        'valueColor': Colors.white,
        'labelColor': Colors.white,
        'icon': 'assets/newapp/newicon/document_total.com.png',
      },
      {
        'label': 'Requested',
        'value': widget.statRequested,
        'docType': 'requested',
        'background': const Color(0xFFF6CC1B),
        'valueColor': Colors.black,
        'labelColor': Colors.black,
        'icon': 'assets/newapp/newicon/document_requested.png',
      },
      {
        'label': 'Expired',
        'value': widget.statExpired,
        'docType': 'expired',
        'background': const Color(0xFFE2F3E9),
        'valueColor': const Color(0xFFBA1719),
        'labelColor': const Color(0xFFBA1719),
        'icon': 'assets/newapp/newicon/document_Expired.png',
      },
      {
        'label': 'Expired soon',
        'value': widget.statExpiringSoon,
        'docType': 'expiry_soon',
        'background': const Color(0xFF8B2AB3),
        'valueColor': Colors.white,
        'labelColor': Colors.white,
        'icon': '',
        'useClockIcon': true,
      },
    ];

    Widget card({
      required String label,
      required String value,
      required Color color,
      required Color labelColor,
      required String? docType,
      required String iconPath,
      bool useClockIcon = false,
      Color valueColor = Colors.black,
    }) {
      final selected = widget.selectedDocType == docType ||
          (docType == null && widget.selectedDocType == null);
      return GestureDetector(
        onTap: docType == null
            ? null
            : () => widget.onDocTypeSelected?.call(docType),
        child: Container(
          height: 138.h,
          width: 156.w,
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 28.sp / 2,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                    height: 1,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 62.sp / 2,
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                    height: 1,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomLeft,
                child: useClockIcon
                    ? Icon(
                        Icons.access_time_rounded,
                        size: 30.sp,
                        color: Colors.white,
                      )
                    : Image.asset(
                        iconPath,
                        width: 30.w,
                        height: 30.w,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.insert_drive_file_outlined,
                          size: 30.sp,
                          color: labelColor,
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 138.h,
          child: PageView.builder(
            controller: _statsPageController,
            padEnds: false,
            itemCount: cards.length,
            itemBuilder: (context, index) {
              final item = cards[index];
              return Padding(
                padding:
                    EdgeInsets.only(left: index == 0 ? 0 : 6.w, right: 6.w),
                child: card(
                  label: item['label'] as String,
                  value: item['value'] as String,
                  color: item['background'] as Color,
                  labelColor: item['labelColor'] as Color,
                  docType: item['docType'] as String?,
                  iconPath: item['icon'] as String,
                  useClockIcon: (item['useClockIcon'] as bool?) ?? false,
                  valueColor: item['valueColor'] as Color,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _buildRecentActivityTiles() {
    if (widget.recentActivities.isEmpty) {
      return [
        _buildEmptyState(
          icon: Icons.history_toggle_off_rounded,
          title: 'No Recent Activity',
          subtitle: 'There are no requested family document activities yet.',
        ),
      ];
    }

    String relative(String raw) {
      if (raw.trim().isEmpty) return '';
      final parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
      if (parsed == null) return raw;
      final diff = DateTime.now().difference(parsed);
      if (diff.inMinutes < 1) return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    }

    return widget.recentActivities.take(6).map((item) {
      final title = (item['title'] ?? '').toString();
      final state = (item['state'] ?? '').toString().toLowerCase();
      final time = relative((item['time'] ?? '').toString());
      final accepted = state.contains('approve') || state.contains('accept');
      final rejected = state.contains('reject') || state.contains('cancel');

      final dotColor = accepted
          ? const Color(0xFF13A65D)
          : rejected
              ? const Color(0xFFCA1122)
              : const Color(0xFF13A65D);

      return Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          children: [
            Container(
              width: 15.w,
              height: 15.w,
              decoration:
                  BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF222222),
                ),
              ),
            ),
            SizedBox(width: 10.w),
            Text(
              time,
              style: GoogleFonts.poppins(
                fontSize: 11.sp,
                color: const Color(0xFF595959),
              ),
            ),
          ],
        ),
      );
    }).toList(growable: false);
  }

  Widget _buildFolderCard(Map<String, dynamic> folder) {
    return SizedBox(
      height: 260.h,
      child: Stack(
        children: [
          // Folder image background
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.r),
              child: Image.asset(
                'assets/newapp/filedoc.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Folder name label at top-right
          Positioned(
            top: 8.h,
            right: 35.w,
            child: Text(
              folder['name'],
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Documents Grid (Inside folder view) ──
  Widget _buildDocumentsList(
      BuildContext pageContext, List<Map<String, dynamic>> liveDocs) {
    final docs = _documentsForSelectedFolder(liveDocs);
    if (liveDocs.isNotEmpty) {
      return _buildLiveDocumentsList(pageContext, docs);
    }

    return Column(
      children: [
        // Back button + Files count
        Padding(
          padding:
              EdgeInsets.only(left: 8.w, right: 20.w, top: 8.h, bottom: 8.h),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(pageContext).pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: const Color(0xFF27304E),
                tooltip: 'Back to folders',
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30.18),
                    border: Border.all(color: const Color(0xffD9D9D9)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 13.5.w, vertical: 8.5.h),
                    child: Text(
                      '${_selectedFolder ?? 'Documents'}  |  ${docs.length + 1}',
                      maxLines: null,
                      overflow: TextOverflow.visible,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        fontStyle: FontStyle.italic,
                        letterSpacing: .10,
                        color: const Color(0xff949494),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Documents grid
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: docs.length + 1, // +1 for add card
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
              childAspectRatio: 0.75,
            ),
            itemBuilder: (context, index) {
              if (index == 0) {
                // Add new document card
                return GestureDetector(
                  onTap: () {
                    widget.onAddDocument?.call();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: const Color(0xffD9D9D9)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.note_add_outlined,
                          size: 48.sp,
                          color: const Color(0xff949494),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Add New',
                          style: GoogleFonts.poppins(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w400,
                            fontStyle: FontStyle.italic,
                            color: const Color(0xff949494),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final doc = docs[index - 1];
              final bool isEditable = doc['is_editable'] == true;

              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: isEditable
                        ? const Color(0xFFBA1719)
                        : const Color(0xffD9D9D9),
                    width: isEditable ? 2 : 1,
                  ),
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(10.w),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Thumbnail
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12.r),
                              child: Image.asset(
                                doc['thumbnail'],
                                fit: BoxFit.contain,
                                width: double.infinity,
                              ),
                            ),
                          ),
                          SizedBox(height: 6.h),
                          // Document name
                          Text(
                            doc['name'] ?? '',
                            textAlign: TextAlign.center,
                            maxLines: null,
                            overflow: TextOverflow.visible,
                            style: GoogleFonts.poppins(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                          // Person name
                          if ((doc['person_name'] ?? '').isNotEmpty) ...[
                            SizedBox(height: 2.h),
                            Text(
                              doc['person_name'],
                              textAlign: TextAlign.center,
                              maxLines: null,
                              overflow: TextOverflow.visible,
                              style: GoogleFonts.poppins(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xff949494),
                              ),
                            ),
                          ],
                          // Date
                          if (_formatDate(doc['expiry_date']).isNotEmpty) ...[
                            SizedBox(height: 2.h),
                            Text(
                              _formatDate(doc['expiry_date']),
                              textAlign: TextAlign.center,
                              maxLines: null,
                              style: GoogleFonts.poppins(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w400,
                                color: isEditable
                                    ? const Color(0xFFBA1719)
                                    : const Color(0xff949494),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Edit icon for editable docs
                    if (isEditable)
                      Positioned(
                        top: 8.h,
                        right: 8.w,
                        child: Container(
                          padding: EdgeInsets.all(4.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.edit,
                            size: 14.sp,
                            color: appFontColor,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
