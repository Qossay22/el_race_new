import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/My_task/screens/report_detail/camera_screen.dart';
import 'package:el_race/ui/presentation/PettyCash/PettyCashAddExpense.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class PettyCashDraftSummaryScreen extends StatefulWidget {
  final String title;
  final String expenseType;
  final IconData titleIcon;

  const PettyCashDraftSummaryScreen({
    super.key,
    required this.title,
    required this.expenseType,
    required this.titleIcon,
  });

  @override
  State<PettyCashDraftSummaryScreen> createState() =>
      _PettyCashDraftSummaryScreenState();
}

class _PettyCashDraftSummaryScreenState
    extends State<PettyCashDraftSummaryScreen> {
  final NumberFormat _amountFormat = NumberFormat('#,##0.##');
  final List<File> _draftAttachments = [];

  bool _isLoading = true;
  bool _isSubmitting = false;
  String _error = '';
  double _totalBalance = 0;
  double _totalDraftAmount = 0;
  bool _canBeSubmit = false;
  List<_DraftExpense> _draftExpenses = const [];

  @override
  void initState() {
    super.initState();
    _fetchDraftSummary();
  }

  int? _resolveHolderId() {
    final loginData = SharedPref.getLoginData();
    final modeledHolderId = loginData.result?.data?.holder_id;
    if (modeledHolderId != null) {
      return modeledHolderId;
    }

    final loginJson = SharedPref.sharedPreferences.getString('loginResponse') ??
        SharedPref.sharedPreferences.getString('LOGIN_RESPONSE');
    if (loginJson == null || loginJson.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(loginJson) as Map<String, dynamic>;
      final result = decoded['result'];
      if (result is! Map<String, dynamic>) {
        return null;
      }

      final data = result['data'];
      if (data is! Map<String, dynamic>) {
        return null;
      }

      final rawHolderId = data['holder_id'];
      if (rawHolderId is int) {
        return rawHolderId;
      }
      return int.tryParse(rawHolderId?.toString() ?? '');
    } catch (_) {
      return null;
    }
  }

  int? _resolveOperatingUnitId() {
    final loginData = SharedPref.getLoginData();
    final modeled = loginData.result?.data?.default_operating_unit_id;
    if (modeled != null) return modeled;

    final loginJson = SharedPref.sharedPreferences.getString('loginResponse') ??
        SharedPref.sharedPreferences.getString('LOGIN_RESPONSE');
    if (loginJson == null || loginJson.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(loginJson) as Map<String, dynamic>;
      final result = decoded['result'];
      if (result is! Map<String, dynamic>) return null;
      final data = result['data'];
      if (data is! Map<String, dynamic>) return null;
      final raw = data['default_operating_unit_id'];
      if (raw is int) return raw;
      return int.tryParse(raw?.toString() ?? '');
    } catch (_) {
      return null;
    }
  }

  String _resolveRequestedBy() {
    final data = SharedPref.getLoginData().result?.data;
    final values = [
      data?.emp_name,
      data?.name,
      data?.username,
    ];
    for (final v in values) {
      final s = (v ?? '').toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '-';
  }

  List<int> _resolveExpenseLineIds() {
    return _draftExpenses
        .map((e) => e.id)
        .where((id) => id > 0)
        .toList(growable: false);
  }

  String _submitTypeValue() {
    return widget.expenseType.toLowerCase().trim() == 'fleet'
        ? 'fleet'
        : 'others';
  }

  Future<String> _buildAttachmentBase64() async {
    if (_draftAttachments.isEmpty) return '';

    final first = _draftAttachments.first;
    if (!await first.exists()) return '';

    try {
      final bytes = await first.readAsBytes();
      return base64Encode(bytes);
    } catch (_) {
      return '';
    }
  }

  dynamic _firstOf(dynamic value) {
    if (value is List && value.isNotEmpty) return value.first;
    return value;
  }

  String _pickString(Map<String, dynamic> map, List<String> keys,
      {String fallback = ''}) {
    for (final key in keys) {
      final raw = map[key];
      final value = _firstOf(raw)?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'false') {
        return value;
      }
    }
    return fallback;
  }

  int? _pickInt(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final raw = _firstOf(map[key]);
      if (raw is int) return raw;
      final parsed = int.tryParse(raw?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  List<_OperatingUnitOption> _parseOperatingUnits(
    Map<String, dynamic> data,
    Map<String, dynamic> result,
  ) {
    final raw = data['operating_units'] ??
        data['operating_unit_ids'] ??
        data['operatingUnits'] ??
        result['operating_units'] ??
        result['operating_unit_ids'] ??
        result['operatingUnits'];

    if (raw is! List) return const <_OperatingUnitOption>[];

    final options = <_OperatingUnitOption>[];
    for (final item in raw) {
      int? id;
      String name = '';

      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        id = _pickInt(map, ['id', 'operating_unit_id', 'unit_id', 'value']);
        name = _pickString(
          map,
          ['name', 'display_name', 'operating_unit', 'label'],
        );
      } else if (item is List && item.isNotEmpty) {
        final rawId = item.first;
        id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
        if (item.length > 1) {
          name = item[1]?.toString().trim() ?? '';
        }
      }

      if (id != null && !options.any((option) => option.id == id)) {
        options.add(_OperatingUnitOption(
          id: id,
          name: name.isEmpty ? 'Operating Unit $id' : name,
        ));
      }
    }

    return List.unmodifiable(options);
  }

  Future<_SubmitPreviewData> _callSubmitPreview() async {
    final token = SharedPref.getLoginData().result?.token;
    if (token == null || token.isEmpty) {
      throw Exception('Authentication token is missing');
    }

    final holderId = _resolveHolderId();
    if (holderId == null) {
      throw Exception('Petty cash holder is missing');
    }

    final expenseLineIds = _resolveExpenseLineIds();
    if (expenseLineIds.isEmpty) {
      throw Exception('No expense lines found to submit');
    }

    final attachmentData = await _buildAttachmentBase64();

    final payload = {
      'jsonrpc': '2.0',
      'params': {
        'expense_line_ids': expenseLineIds,
        'holder_id': holderId,
        'type': _submitTypeValue(),
        'attachment_data': attachmentData,
      },
    };

    final response = await http.post(
      Uri.parse('https://erp.elrace.com/api/submit_expense_preview'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Preview failed: HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final result = decoded['result'];
    if (result is! Map<String, dynamic>) {
      throw Exception('Invalid preview response');
    }
    if (result['status']?.toString().toLowerCase() != 'success') {
      throw Exception(result['message']?.toString() ?? 'Preview failed');
    }

    final data = result['data'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(result['data'] as Map)
        : <String, dynamic>{};

    final resolvedAttachmentIds =
        data['attachment_ids'] ?? result['attachment_ids'];
    final resolvedExpenseIds = data['expense_line_ids'] ?? expenseLineIds;
    final resolvedOperatingUnitId =
        _pickInt(data, ['operating_unit_id']) ?? _resolveOperatingUnitId();
    final operatingUnits = _parseOperatingUnits(data, result);
    final selectedOperatingUnitId = operatingUnits.any(
      (unit) => unit.id == resolvedOperatingUnitId,
    )
        ? resolvedOperatingUnitId
        : (operatingUnits.isNotEmpty
            ? operatingUnits.first.id
            : resolvedOperatingUnitId);

    final submitDate = _pickString(
      data,
      ['submit_date', 'submission_date', 'date', 'create_date'],
      fallback: DateTime.now().toIso8601String(),
    );
    final holder = _pickString(
      data,
      ['petty_cash_holder', 'holder_name', 'holder', 'pettycash_holder'],
      fallback: _resolveSheetTitle(),
    );
    final requestedBy = _pickString(
      data,
      ['requested_by', 'request_by', 'employee_name'],
      fallback: _resolveRequestedBy(),
    );
    final company = _pickString(
      data,
      ['company', 'company_name'],
      fallback: 'RCC',
    );
    final batch = _pickString(
      data,
      ['petty_cash_batch', 'batch_name', 'sheet_name'],
      fallback: _resolveSheetTitle(),
    );
    final pettyType = _pickString(
      data,
      ['petty_cash_type', 'type', 'expense_type'],
      fallback: widget.expenseType == 'fleet' ? 'Transportations' : 'Others',
    );

    return _SubmitPreviewData(
      submitDate: submitDate,
      pettyCashHolder: holder,
      requestedBy: requestedBy,
      company: company,
      pettyCashBatch: batch,
      pettyCashType: pettyType,
      expenseLineIds: resolvedExpenseIds,
      holderId: holderId,
      operatingUnitId: selectedOperatingUnitId,
      operatingUnits: operatingUnits,
      attachmentIds: resolvedAttachmentIds,
      hasAttachments: _draftAttachments.isNotEmpty,
    );
  }

  Future<void> _submitExpense(
    _SubmitPreviewData preview, {
    required int? operatingUnitId,
  }) async {
    final token = SharedPref.getLoginData().result?.token;
    if (token == null || token.isEmpty) {
      throw Exception('Authentication token is missing');
    }

    if (operatingUnitId == null) {
      throw Exception('operating_unit_id is missing');
    }

    if (preview.attachmentIds == null) {
      throw Exception('attachment_ids is missing from preview response');
    }

    final payload = {
      'jsonrpc': '2.0',
      'params': {
        'expense_line_ids': preview.expenseLineIds,
        'holder_id': preview.holderId,
        'operating_unit_id': operatingUnitId,
        'attachment_ids': preview.attachmentIds,
      },
    };

    final response = await http.post(
      Uri.parse('https://erp.elrace.com/api/submit_expense'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Submit failed: HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final result = decoded['result'];
    if (result is! Map<String, dynamic>) {
      throw Exception('Invalid submit response');
    }

    if (result['status']?.toString().toLowerCase() != 'success') {
      throw Exception(result['message']?.toString() ?? 'Submit failed');
    }
  }

  Future<bool> _showSubmitConfirmationPopup(_SubmitPreviewData preview) async {
    double sliderValue = 0.5;
    bool submitting = false;
    int? selectedOperatingUnitId = preview.operatingUnitId;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: !submitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> confirmSubmit() async {
              if (submitting) return;
              if (selectedOperatingUnitId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select operating unit')),
                );
                setDialogState(() => sliderValue = 0.5);
                return;
              }
              setDialogState(() => submitting = true);
              try {
                await _submitExpense(
                  preview,
                  operatingUnitId: selectedOperatingUnitId,
                );
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop(true);
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(e.toString())),
                );
                setDialogState(() {
                  submitting = false;
                  sliderValue = 0.5;
                });
              }
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ─── title (fixed, not scrolled) ───
                      Text(
                        'Confirmation massage',
                        style: GoogleFonts.poppins(
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111111),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // ─── scrollable fields ───
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _PreviewFieldCard(
                                  label: 'Submit Date',
                                  value: _formatDate(preview.submitDate)),
                              const SizedBox(height: 10),
                              _PreviewFieldCard(
                                  label: 'Petty cash holder',
                                  value: preview.pettyCashHolder),
                              const SizedBox(height: 10),
                              _PreviewFieldCard(
                                  label: 'Requested By',
                                  value: preview.requestedBy),
                              const SizedBox(height: 10),
                              _PreviewFieldCard(
                                label: 'Company',
                                valueWidget: Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Text('HCN',
                                              style: GoogleFonts.poppins(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.w700)),
                                          const SizedBox(width: 8),
                                          Icon(
                                            preview.company
                                                    .toUpperCase()
                                                    .contains('HCN')
                                                ? Icons.check_box
                                                : Icons.check_box_outline_blank,
                                            color: const Color(0xFF6C4AB6),
                                            size: 18,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Text('RCC',
                                              style: GoogleFonts.poppins(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.w700)),
                                          const SizedBox(width: 8),
                                          Icon(
                                            !preview.company
                                                    .toUpperCase()
                                                    .contains('HCN')
                                                ? Icons.check_box
                                                : Icons.check_box_outline_blank,
                                            color: const Color(0xFF6C4AB6),
                                            size: 18,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              _PreviewFieldCard(
                                  label: 'Petty Cash Batch',
                                  value: preview.pettyCashBatch),
                              const SizedBox(height: 10),
                              _PreviewFieldCard(
                                  label: 'Petty cash type',
                                  value: preview.pettyCashType),
                              const SizedBox(height: 10),
                              _PreviewFieldCard(
                                label: 'Operating Unit',
                                valueWidget: preview.operatingUnits.isEmpty
                                    ? Text(
                                        selectedOperatingUnitId?.toString() ??
                                            '-',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF111111),
                                        ),
                                      )
                                    : Column(
                                        children:
                                            preview.operatingUnits.map((unit) {
                                          final selected =
                                              selectedOperatingUnitId == unit.id;
                                          return InkWell(
                                            onTap: submitting
                                                ? null
                                                : () => setDialogState(
                                                      () =>
                                                          selectedOperatingUnitId =
                                                              unit.id,
                                                    ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 6),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    selected
                                                        ? Icons
                                                            .radio_button_checked
                                                        : Icons
                                                            .radio_button_unchecked,
                                                    color: selected
                                                        ? const Color(
                                                            0xFF6C4AB6)
                                                        : const Color(
                                                            0xFF8A8A8A),
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          unit.name,
                                                          style:
                                                              GoogleFonts.poppins(
                                                            fontSize: 15,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: const Color(
                                                                0xFF111111),
                                                          ),
                                                        ),
                                                        Text(
                                                          unit.id.toString(),
                                                          style:
                                                              GoogleFonts.poppins(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color: const Color(
                                                                0xFF8A8A8A),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(growable: false),
                                      ),
                              ),
                              const SizedBox(height: 10),
                              InkWell(
                                onTap: preview.hasAttachments
                                    ? () => _showSelectedAttachmentsPreview()
                                    : null,
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 13),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F3F3),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: const Color(0xFF9D9D9D)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.attach_file_rounded,
                                          color: Color(0xFF111111), size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'View Attachments',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF111111),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                          ),
                        ),
                      ),
                      // ─── confirm/cancel (fixed at bottom) ───
                      Text(
                        'Are you sure you want to Submit ?',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111111),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F3F3),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFF8F8F8F)),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Text('No',
                                    style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFCC2424))),
                                Text('Yes',
                                    style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0E9F57))),
                              ],
                            ),
                            SliderTheme(
                              data: SliderTheme.of(ctx).copyWith(
                                trackHeight: 36,
                                activeTrackColor: Colors.transparent,
                                inactiveTrackColor: Colors.transparent,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 22),
                                overlayShape: SliderComponentShape.noOverlay,
                                thumbColor: const Color(0xFFD1D1D1),
                              ),
                              child: Slider(
                                min: 0,
                                max: 1,
                                value: sliderValue,
                                onChanged: submitting
                                    ? null
                                    : (v) =>
                                        setDialogState(() => sliderValue = v),
                                onChangeEnd: submitting
                                    ? null
                                    : (v) {
                                        if (v >= 0.9) {
                                          confirmSubmit();
                                        } else if (v <= 0.1) {
                                          Navigator.of(ctx).pop(false);
                                        } else {
                                          setDialogState(
                                              () => sliderValue = 0.5);
                                        }
                                      },
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (submitting)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    return result == true;
  }

  Future<void> _showSelectedAttachmentsPreview() async {
    if (_draftAttachments.isEmpty) return;

    final single = _draftAttachments.length == 1 ? _draftAttachments.first : null;
    final singleExt = single == null
        ? ''
        : single.path.split('.').last.toLowerCase();

    if (single != null && singleExt == 'pdf') {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _LocalFileViewerScreen(
            file: single,
            title: single.path.split(Platform.pathSeparator).last,
            isPdf: true,
            isImage: false,
          ),
        ),
      );
      return;
    }

    try {
      final pdfBytes = await _buildAttachmentsPdf();
      if (!mounted) return;
      if (pdfBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No image attachments to preview as PDF')),
        );
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _GeneratedAttachmentsPdfViewer(pdfBytes: pdfBytes),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to prepare PDF preview')),
      );
    }
  }

  Future<Uint8List?> _buildAttachmentsPdf() async {
    final doc = pw.Document();
    var hasPages = false;

    for (final file in _draftAttachments) {
      if (!await file.exists()) continue;

      final ext = file.path.split('.').last.toLowerCase();
      final isImage = <String>{'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'}
          .contains(ext);
      if (!isImage) continue;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) continue;

      final image = pw.MemoryImage(bytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(16),
          build: (_) => pw.Center(
            child: pw.Image(image, fit: pw.BoxFit.contain),
          ),
        ),
      );
      hasPages = true;
    }

    if (!hasPages) return null;
    return doc.save();
  }

  Future<void> _onPrimaryActionTap() async {
    if (_isSubmitting) return;

    if (!_canBeSubmit) {
      _openAddExpenseDialog();
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final preview = await _callSubmitPreview();
      final confirmed = await _showSubmitConfirmationPopup(preview);
      if (confirmed && mounted) {
        _draftAttachments.clear();
        await _fetchDraftSummary();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense sheet submitted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _fetchDraftSummary() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final token = SharedPref.getLoginData().result?.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token is missing');
      }

      final holderId = _resolveHolderId();
      debugPrint('DraftSummary holderId: $holderId');
      debugPrint('DraftSummary type: ${widget.expenseType}');
      if (holderId == null) {
        throw Exception('Petty cash holder_id is missing from login data');
      }

      final payload = <String, dynamic>{
        'jsonrpc': '2.0',
        'params': <String, dynamic>{
          'holder_id': holderId,
          'type': widget.expenseType,
        },
      };

      debugPrint('DraftSummary request: ${jsonEncode(payload)}');

      final response = await http.post(
        Uri.parse('https://erp.elrace.com/api/draft_summary'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      debugPrint('DraftSummary statusCode: ${response.statusCode}');
      debugPrint('DraftSummary body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Failed to load draft summary: ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final result = decoded['result'];
      if (result is! Map<String, dynamic>) {
        throw Exception('Invalid draft summary response');
      }

      final data = (result['data'] is Map<String, dynamic>)
          ? result['data'] as Map<String, dynamic>
          : result;

      final rawExpenses = data['draft_expenses'];
      final expenses = rawExpenses is List
          ? rawExpenses
              .whereType<Map>()
              .map((item) =>
                  _DraftExpense.fromJson(Map<String, dynamic>.from(item)))
              .toList(growable: false)
          : const <_DraftExpense>[];

      if (!mounted) return;
      setState(() {
        _totalBalance = _toDouble(data['total_balance']);
        _totalDraftAmount = _toDouble(data['total_draft_amount']);
        _canBeSubmit = data['can_be_submit'] == true;
        _draftExpenses = expenses;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('DraftSummary fetch error: $e');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatAmount(num value) {
    return _amountFormat.format(value);
  }

  String _formatDate(String rawDate) {
    final normalized = rawDate.trim();
    if (normalized.isEmpty) return '';

    final parsed = DateTime.tryParse(normalized.replaceFirst(' ', 'T'));
    if (parsed == null) return normalized;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(parsed.year, parsed.month, parsed.day);
    final diff = today.difference(targetDay).inDays;
    final time = DateFormat('HH:mm').format(parsed);

    if (diff == 0) return 'Today · $time';
    if (diff == 1) return 'Yesterday · $time';
    return '${DateFormat('dd/MM/yyyy').format(parsed)} · $time';
  }

  String _resolveSheetTitle() {
    if (_draftExpenses.isEmpty) return 'RCC PC 1';

    final title = _draftExpenses.first.sheetTitle.trim();
    if (title.isNotEmpty) {
      return title;
    }

    return widget.expenseType == 'fleet' ? 'Transportation' : 'Miscellaneous';
  }

  Future<void> _addCameraAttachment() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CustomCameraScreen(onePicture: false),
      ),
    );

    if (!mounted) return;
    if (result is List<XFile> && result.isNotEmpty) {
      setState(() {
        _draftAttachments.addAll(result.map((file) => File(file.path)));
      });
    }
  }

  Future<void> _scanDocumentAttachment() async {
    try {
      final pictures = await CunningDocumentScanner.getPictures(
        noOfPages: 20,
        isGalleryImportAllowed: true,
      );

      if (!mounted) return;
      if (pictures == null || pictures.isEmpty) return;

      setState(() {
        _draftAttachments.addAll(pictures.map((path) => File(path)));
      });
    } on PlatformException {
      return;
    }
  }

  void _showAttachmentSourcePicker() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            width: 260,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF5B5E63).withOpacity(0.96),
                  const Color(0xFF3F4247).withOpacity(0.96),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachmentSourceTile(
                  icon: Icons.camera_alt_outlined,
                  label: 'camera',
                  onTap: () {
                    Navigator.pop(context);
                    _addCameraAttachment();
                  },
                ),
                _AttachmentSourceTile(
                  icon: Icons.document_scanner_outlined,
                  label: 'scan',
                  onTap: () {
                    Navigator.pop(context);
                    _scanDocumentAttachment();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openAddExpenseDialog() {
    final normalizedType =
        widget.expenseType.toLowerCase().trim() == 'fleet' ? 'fleet' : 'other';

    Navigator.of(context)
        .push<bool>(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.20),
        pageBuilder: (_, __, ___) =>
            PettyCashAddExpense(fixedExpenseType: normalizedType),
        transitionsBuilder: (_, animation, __, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          final scale = Tween<double>(begin: 0.98, end: 1.0).animate(fade);
          return FadeTransition(
            opacity: fade,
            child: ScaleTransition(scale: scale, child: child),
          );
        },
      ),
    )
        .then((value) {
      if (value == true) {
        _fetchDraftSummary();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const HeaderWidget(),
      body: Column(
        children: [
          Container(
            height: 74,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.14),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.titleIcon,
                    size: 33, color: const Color(0xFF111111)),
                const SizedBox(width: 12),
                Text(
                  widget.title,
                  style: GoogleFonts.poppins(
                    fontSize: widget.title.length > 12 ? 19 : 23,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111111),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _fetchDraftSummary,
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFA6A6A6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'total ${_draftExpenses.length}',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: _showAttachmentSourcePicker,
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFF161616),
                                  width: 1.3,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.attach_file_rounded,
                                    size: 20,
                                    color: Color(0xFF111111),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Add Attachments',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF111111),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Balance ${_formatAmount(_totalBalance)}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF9A9A9A),
                              ),
                            ),
                          ),
                          Text(
                            _canBeSubmit
                                ? 'Ready to submit'
                                : 'Submission blocked',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _canBeSubmit
                                  ? const Color(0xFF129A59)
                                  : const Color(0xFF9A9A9A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.only(top: 120),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_error.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 80),
                          child: Column(
                            children: [
                              Text(
                                'Failed to load draft expenses',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF141414),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF8E8E8E),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _fetchDraftSummary,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      else if (_draftExpenses.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 110),
                          child: Column(
                            children: [
                              Text(
                                'No draft expenses',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF171717),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Start adding ${widget.expenseType == 'fleet' ? 'transportation' : 'miscellaneous'} expenses.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF8E8E8E),
                                ),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        _buildHeaderCard(),
                        const SizedBox(height: 22),
                        ..._draftExpenses.map(_buildExpenseRow),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 20,
                  child: Center(
                    child: InkWell(
                      onTap: _onPrimaryActionTap,
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        width: 246,
                        height: 54,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: LinearGradient(
                            colors: _canBeSubmit
                                ? const [Color(0xFF1ACA6C), Color(0xFF0E9E57)]
                                : const [Color(0xFF767A80), Color(0xFF5C6066)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _canBeSubmit ? 'SUBMIT' : '+ ADD EXPENSE',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.4,
                                ),
                              ),
                      ),
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

  Widget _buildHeaderCard() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: const BoxDecoration(
            color: Color(0xFFBABABA),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Image.asset(
              'assets/png/Bill.png',
              width: 28,
              height: 28,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _resolveSheetTitle(),
                maxLines: null,
                overflow: TextOverflow.visible,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(_draftExpenses.first.rawDate),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF9A9A9A),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '-${_formatAmount(_totalDraftAmount)}',
          style: GoogleFonts.poppins(
            fontSize: 23,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFFF1123),
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseRow(_DraftExpense expense) {
    return Padding(
      padding: const EdgeInsets.only(left: 35, bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 38),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  maxLines: null,
                  overflow: TextOverflow.visible,
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(expense.rawDate),
                  maxLines: null,
                  overflow: TextOverflow.visible,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF9A9A9A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '-${_formatAmount(expense.amount)}',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFFF1123),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftExpense {
  final int id;
  final String title;
  final String sheetTitle;
  final String rawDate;
  final double amount;

  const _DraftExpense({
    required this.id,
    required this.title,
    required this.sheetTitle,
    required this.rawDate,
    required this.amount,
  });

  factory _DraftExpense.fromJson(Map<String, dynamic> json) {
    String pickString(List<dynamic> candidates, {String fallback = ''}) {
      for (final candidate in candidates) {
        final value = (candidate ?? '').toString().trim();
        if (value.isNotEmpty && value.toLowerCase() != 'false') {
          return value;
        }
      }
      return fallback;
    }

    double toDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString().replaceAll(',', '') ?? '') ?? 0;
    }

    return _DraftExpense(
      id: ((json['id'] ?? json['line_id'] ?? json['expense_line_id']) as num?)
              ?.toInt() ??
          int.tryParse(
              (json['id'] ?? json['line_id'] ?? json['expense_line_id'])
                      ?.toString() ??
                  '') ??
          0,
      title: pickString([
        json['expense_type_label'],
        json['label'],
        json['name'],
        json['description'],
        json['display_name'],
        json['expense_name'],
      ], fallback: 'Expense'),
      sheetTitle: pickString([
        json['sheet_name'],
        json['petty_cash_name'],
        json['holder_name'],
        json['batch_name'],
        json['summary_name'],
      ]),
      rawDate: pickString([
        json['last_update'],
        json['create_date'],
        json['date'],
        json['datetime'],
      ]),
      amount: toDouble(
          json['amount'] ?? json['total_amount'] ?? json['unit_amount']),
    );
  }
}

class _PreviewFieldCard extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;

  const _PreviewFieldCard({
    required this.label,
    this.value,
    this.valueWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF9D9D9D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFB0B0B0),
            ),
          ),
          const SizedBox(height: 4),
          valueWidget ??
              Text(
                (value ?? '-').trim().isEmpty ? '-' : value!,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111111),
                ),
              ),
        ],
      ),
    );
  }
}

class _OperatingUnitOption {
  final int id;
  final String name;

  const _OperatingUnitOption({
    required this.id,
    required this.name,
  });
}

class _LocalFileViewerScreen extends StatelessWidget {
  const _LocalFileViewerScreen({
    required this.file,
    required this.title,
    required this.isPdf,
    required this.isImage,
  });

  final File file;
  final String title;
  final bool isPdf;
  final bool isImage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title, overflow: TextOverflow.ellipsis),
      ),
      body: isPdf
          ? SfPdfViewer.file(
              file,
              canShowPaginationDialog: true,
              canShowScrollHead: true,
              canShowScrollStatus: true,
            )
          : isImage
              ? InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.file(
                      file,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text('Failed to load image'),
                      ),
                    ),
                  ),
                )
              : const Center(
                  child: Text('Unsupported file type'),
                ),
    );
  }
}

class _GeneratedAttachmentsPdfViewer extends StatelessWidget {
  const _GeneratedAttachmentsPdfViewer({
    required this.pdfBytes,
  });

  final Uint8List pdfBytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Attachments'),
      ),
      body: SfPdfViewer.memory(
        pdfBytes,
        canShowPaginationDialog: true,
        canShowScrollHead: true,
        canShowScrollStatus: true,
      ),
    );
  }
}

class _SubmitPreviewData {
  final String submitDate;
  final String pettyCashHolder;
  final String requestedBy;
  final String company;
  final String pettyCashBatch;
  final String pettyCashType;
  final dynamic expenseLineIds;
  final int holderId;
  final int? operatingUnitId;
  final List<_OperatingUnitOption> operatingUnits;
  final dynamic attachmentIds;
  final bool hasAttachments;

  const _SubmitPreviewData({
    required this.submitDate,
    required this.pettyCashHolder,
    required this.requestedBy,
    required this.company,
    required this.pettyCashBatch,
    required this.pettyCashType,
    required this.expenseLineIds,
    required this.holderId,
    required this.operatingUnitId,
    required this.operatingUnits,
    required this.attachmentIds,
    required this.hasAttachments,
  });
}

class _AttachmentSourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AttachmentSourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: SizedBox(
        width: 92,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 34, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
