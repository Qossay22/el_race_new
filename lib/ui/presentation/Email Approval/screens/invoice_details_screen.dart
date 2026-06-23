import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/Email%20Approval/widgets/approval_action_buttons.dart';
import 'package:el_race/ui/presentation/lpo/screens/lpo_pdf_viewer_screen.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:math' as math;

class InvoiceDetailsScreen extends StatefulWidget {
  final String requestId;
  final String type;
  final Map<String, dynamic>? initialData;

  const InvoiceDetailsScreen({
    super.key,
    required this.requestId,
    required this.type,
    this.initialData,
  });

  @override
  State<InvoiceDetailsScreen> createState() => _InvoiceDetailsScreenState();
}

class _InvoiceDetailsScreenState extends State<InvoiceDetailsScreen> {
  static const String _localFakeInvoiceRequestId = 'LOCAL_FAKE_INVOICE_001';
  bool _isLoading = true;
  String _error = '';

  Map<String, dynamic> _formData = const {};

  bool get _isLocalFakeRequest =>
      widget.requestId == _localFakeInvoiceRequestId;

  Map<String, dynamic> _buildLocalFakeInvoiceData() {
    return {
      'request_no': 'INV/1254/89585',
      'project_name': 'Project Name',
      'department': 'Department',
      'vendor_name': 'Al Ameen Interiors',
      'vendor_tags': ['Ceiling', 'Civil', 'Fitout', 'Label'],
      'work_order_no': '123345654874954652',
      'request_date': '2025-01-10',
      'material_type': 'Ceramic',
      'contract_lpo': 'RCC/LPO/1231215',
      'advance': '15000',
      'progress': '60000',
      'last_update': '2025-01-28',
      'retention': '-',
      'invoice_amount': '1000000',
      'completion': '85',
      'advance_percentage': '20%',
      'last_update_percentage': '30%',
      'retention_percentage': '10%',
      'comment': '',
      'client_photo_url': '',
      'attachment_ids': ['1'],
    };
  }

  @override
  void initState() {
    super.initState();
    if (_isLocalFakeRequest) {
      final fake = _buildLocalFakeInvoiceData();
      _formData = fake;
      _isLoading = false;
      return;
    }
    if (widget.initialData != null) {
      _formData = Map<String, dynamic>.from(widget.initialData!);
    }
    _fetchInvoiceDetails();
  }

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

  String _displayValue(dynamic raw, {String fallback = ''}) {
    if (raw == null || raw == false || raw == true) return fallback;

    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      return _pick([
        map['name'],
        map['display_name'],
        map['title'],
        map['value'],
        map['label'],
      ], fallback: fallback);
    }

    if (raw is List) {
      if (raw.length >= 2) {
        final second = _safe(raw[1], fallback: '');
        if (second.isNotEmpty) return second;
      }
      for (final item in raw) {
        final candidate = _displayValue(item);
        if (candidate.isNotEmpty) return candidate;
      }
      return fallback;
    }

    return _safe(raw, fallback: fallback);
  }

  String _displayOrDash(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? '-' : normalized;
  }

  String _normalizeImageUrl(String? rawUrl) {
    final value = (rawUrl ?? '').trim();
    if (value.isEmpty) return '';
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return value;
    if (value.startsWith('/')) return 'https://erp.elrace.com$value';
    return 'https://erp.elrace.com/$value';
  }

  String _formatDate(dynamic value) {
    final raw = _safe(value);
    if (raw.isEmpty) return '-';
    final normalized = raw.contains(' ') ? raw.replaceFirst(' ', 'T') : raw;
    final parsed = DateTime.tryParse(normalized) ?? DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  String _formatAmount(dynamic value) {
    final raw = _safe(value);
    if (raw.isEmpty) return '-';
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.\-]'), '');
    final parsed = double.tryParse(cleaned);
    if (parsed == null) return _displayOrDash(raw);
    if (parsed % 1 == 0) {
      return NumberFormat('#,##0', 'en_US').format(parsed);
    }
    return NumberFormat('#,##0.##', 'en_US').format(parsed);
  }

  double _parsePercent(dynamic value) {
    final raw = _safe(value);
    if (raw.isEmpty) return 0;
    final cleaned =
        raw.replaceAll('%', '').replaceAll(RegExp(r'[^0-9.\-]'), '');
    final parsed = double.tryParse(cleaned);
    if (parsed == null || parsed <= 0) return 0;
    if (parsed > 100) return 100;
    return parsed;
  }

  List<String> _extractTags(List<dynamic> candidates) {
    for (final raw in candidates) {
      if (raw == null || raw == false || raw == true) continue;

      if (raw is List) {
        final listTags = raw
            .map((e) => e.toString().trim())
            .map((e) => e
                .replaceAll('[', '')
                .replaceAll(']', '')
                .replaceAll('"', '')
                .replaceAll("'", '')
                .trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (listTags.isNotEmpty) return listTags;
        continue;
      }

      final str = raw.toString().trim();
      if (str.isEmpty) continue;
      final lower = str.toLowerCase();
      if (lower == 'null' || lower == 'false' || lower == 'true') continue;

      final parsed = str
          .split(RegExp(r'[,|]'))
          .map((e) => e.trim())
          .map((e) => e
              .replaceAll('[', '')
              .replaceAll(']', '')
              .replaceAll('"', '')
              .replaceAll("'", '')
              .trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (parsed.isNotEmpty) return parsed;
    }

    return const <String>[];
  }

  Future<void> _fetchInvoiceDetails() async {
    final token = SharedPref.getLoginData().result?.token;
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final url = Uri.parse('https://erp.elrace.com/api/get_invoice_details');
    final commentParam = _pick([
      _formData['comment'],
      widget.initialData?['comment'],
      _formData['note'],
      widget.initialData?['note'],
      _formData['description'],
      widget.initialData?['description'],
    ]);
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'params': {
        'invoice_id': int.tryParse(widget.requestId),
        'comment': commentParam,
      },
    });

    // cURL debug
    debugPrint('\n==== INVOICE DETAILS REQUEST ====');
    debugPrint('curl -X GET "$url" \\');
    headers.forEach((k, v) {
      final safe = k == 'Authorization' ? 'Bearer [TOKEN]' : v;
      debugPrint('  -H "$k: $safe" \\');
    });
    debugPrint('  -d \'$body\'');
    debugPrint('=========================\n');

    try {
      final request = http.Request('GET', url)
        ..headers.addAll(headers)
        ..body = body;

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      // raw response logging
      debugPrint(
          '\n==== INVOICE DETAILS RESPONSE (status: ${response.statusCode}) ====');
      final rawBody = response.body;
      const chunk = 800;
      for (var i = 0; i < rawBody.length; i += chunk) {
        debugPrint(rawBody.substring(
            i, i + chunk > rawBody.length ? rawBody.length : i + chunk));
      }
      debugPrint('=========================\n');

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to load invoice details: ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final result = (decoded['result'] as Map?)?['data'] as Map?;
      final formView =
          (result?['form_view'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};

      if (!mounted) return;
      setState(() {
        final merged = Map<String, dynamic>.from(_formData);
        merged.addAll(formView);
        _formData = merged;
        _isLoading = false;
        _error = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _viewAttachment() async {
    final invoiceId = int.tryParse(widget.requestId);
    if (invoiceId == null || invoiceId <= 0) {
      Fluttertoast.showToast(
        msg: 'Invalid invoice id.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.black,
        textColor: Colors.white,
      );
      return;
    }

    final token = SharedPref.getLoginData().result?.token;
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final data = {
      'jsonrpc': '2.0',
      'params': {
        'invoice_id': invoiceId,
      },
    };

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await http.post(
        Uri.parse('https://erp.elrace.com/api/invoice/report_url'),
        headers: headers,
        body: jsonEncode(data),
      );

      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (response.statusCode != 200) {
        Fluttertoast.showToast(
          msg: 'Failed to load PDF: HTTP ${response.statusCode}',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          backgroundColor: Colors.black,
          textColor: Colors.white,
        );
        return;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final result = decoded['result'] as Map?;
      final pdfUrl = result?['report_url']?.toString() ?? '';

      if (pdfUrl.isEmpty) {
        final error = decoded['error'] as Map?;
        final errorData = error?['data'] as Map?;
        Fluttertoast.showToast(
          msg: result?['message']?.toString() ??
              result?['error']?.toString() ??
              errorData?['message']?.toString() ??
              error?['message']?.toString() ??
              'Failed to retrieve PDF URL.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          backgroundColor: Colors.black,
          textColor: Colors.white,
        );
        return;
      }

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LpoPdfViewerScreen(
            pdfUrl: pdfUrl,
            title: 'Invoice ${_pick([
                  _formData['request_no'],
                  _formData['invoice_no_code'],
                  _formData['invoice_no'],
                  _formData['name'],
                ], fallback: widget.requestId)}',
          ),
        ),
      );
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      Fluttertoast.showToast(
        msg: 'Error: $e',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.black,
        textColor: Colors.white,
      );
    }
  }

  Widget _tagChip(String text, Color bg, Color fg) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.w),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 9.sp,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _simSectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFF9E9E9E), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.w),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E2E2), width: 1),
              ),
            ),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF5A5A5A),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildAvatar({required String imageUrl, required String name}) {
    final initials =
        name.trim().isEmpty ? 'IN' : name.trim().characters.first.toUpperCase();

    Widget placeholder() {
      return Container(
        color: const Color(0xFFE8EDF5),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: GoogleFonts.poppins(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF4A607A),
          ),
        ),
      );
    }

    if (imageUrl.isEmpty) {
      return ClipOval(child: placeholder());
    }

    return ClipOval(
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return placeholder();
        },
      ),
    );
  }

  Widget _buildInfoCell(String label, String value, {Color? valueColor}) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFA0A0A0),
            ),
          ),
          TextSpan(
            text: _displayOrDash(value),
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: valueColor ?? const Color(0xFF202020),
            ),
          ),
        ],
      ),
      maxLines: null,
      overflow: TextOverflow.visible,
    );
  }

  Widget _buildMetricRow({
    required String label,
    required String value,
    String? percentBadge,
    bool valueHighlighted = false,
  }) {
    final badgeText = _safe(percentBadge, fallback: '');

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.w),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE6E6E6), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFA0A0A0),
              ),
            ),
          ),
          SizedBox(
            width: 34.w,
            child: Center(
              child: badgeText.isEmpty || badgeText == '-'
                  ? const SizedBox.shrink()
                  : _buildMiniPercentBadge(badgeText),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            flex: 3,
            child: Text(
              _displayOrDash(value),
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: valueHighlighted
                    ? const Color(0xFFFF8A00)
                    : const Color(0xFF202020),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPercentBadge(String badgeText) {
    final parsed = _parsePercent(badgeText);
    final text = parsed > 0 ? '${parsed.round()}%' : _displayOrDash(badgeText);

    return Container(
      width: 26.w,
      height: 26.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF4F4F4), Color(0xFFD1D1D1)],
        ),
        border: Border.all(color: const Color(0xFFCBCBCB), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 2.5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 8.5.sp,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF151515),
          height: 1,
        ),
      ),
    );
  }

  Widget _buildCompletionDonut(double percent) {
    final p = percent.clamp(0, 100).toDouble();
    return SizedBox(
      width: 74.w,
      height: 74.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 64.w,
            height: 64.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: CustomPaint(
              painter: _PiePercentPainter(
                percent: p,
                fillColor: const Color(0xFFE58B47),
                baseColor: const Color(0xFFE2E2E2),
              ),
            ),
          ),
          Text(
            '${p.round()}%',
            style: GoogleFonts.poppins(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111111),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requestNo = _pick([
      _formData['request_no'],
      _formData['invoice_no_code'],
      _formData['invoice_no'],
      _formData['name'],
      _formData['ref_no'],
    ], fallback: widget.requestId);

    final projectName = _pick([
      _displayValue(_formData['project_name']),
      _displayValue(_formData['project_title']),
      _displayValue(_formData['project']),
      _displayValue(_formData['project_name_id']),
      _displayValue(_formData['project_id']),
      _displayValue(_formData['project_ref']),
      _displayValue(_formData['name']),
    ]);

    final department = _pick([
      _displayValue(_formData['department_id']),
      _displayValue(_formData['department']),
      _displayValue(_formData['section']),
      _displayValue(_formData['dept_name']),
      _displayValue(_formData['department_name']),
    ]);

    final requestDate = _formatDate(_pick([
      _formData['request_date'],
      _formData['create_date'],
      _formData['req_date'],
      _formData['invoice_date'],
      _formData['date_of_invoice'],
      _formData['date'],
    ]));

    final workOrderNo = _pick([
      _displayValue(_formData['work_order_no']),
      _displayValue(_formData['work_order_number']),
      _displayValue(_formData['wo_no']),
      _displayValue(_formData['wono']),
      _displayValue(_formData['wo_no#']),
      _displayValue(_formData['work_order_id']),
    ]);

    final vendorName = _pick([
      _displayValue(_formData['vendor_name']),
      _displayValue(_formData['vendor']),
      _displayValue(_formData['partner_name']),
      _displayValue(_formData['client_name']),
      _displayValue(_formData['supplier']),
      _displayValue(_formData['partner_id']),
      _displayValue(_formData['vendor_id']),
    ]);

    final invoiceAmount = _formatAmount(_pick([
      _formData['invoice_amount'],
      _formData['total_amount'],
      _formData['amount_total'],
      _formData['amount'],
      _formData['total'],
    ]));

    final completionRaw = _pick([
      _formData['completion'],
      _formData['completion_percentage'],
      _formData['completion_percent'],
    ], fallback: '0');
    final completionPercent = _parsePercent(completionRaw);

    final advance = _pick([_formData['advance']], fallback: '-');
    final progress = _pick([_formData['progress']], fallback: '-');
    final lastUpdate = _pick([_formData['last_update']], fallback: '-');
    final retention = _pick([_formData['retention']], fallback: '-');

    final advancePct = _pick([
      _formData['advance_percentage'],
      _formData['advance_percent'],
    ], fallback: '-');
    final progressPct = _pick([
      _formData['progress_percentage'],
      _formData['progress_percent'],
    ], fallback: '-');
    final lastUpdatePct = _pick([
      _formData['last_update_percentage'],
      _formData['last_update_percent'],
    ], fallback: '-');
    final retentionPct = _pick([
      _formData['retention_percentage'],
      _formData['retention_percent'],
    ], fallback: '-');

    final contractLpo = _pick([
      _displayValue(_formData['contract_lpo']),
      _displayValue(_formData['lpo_no']),
      _displayValue(_formData['lpo']),
      _displayValue(_formData['lpo_number']),
      _displayValue(_formData['contract']),
      _displayValue(_formData['contract_no']),
      _displayValue(_formData['contract_lpo_id']),
    ], fallback: '-');

    final vendorPhotoUrl = _normalizeImageUrl(_pick([
      _formData['client_photo_url'],
      _formData['vendor_photo_url'],
      _formData['partner_image_url'],
      _formData['image_url'],
      _formData['photo_url'],
    ]));

    final tags = _extractTags([
      _formData['vendor_tag'],
      _formData['vendor_tags'],
      _formData['tags'],
      _formData['tag_names'],
    ]).take(4).toList();

    final comment = _pick([
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
    ]);

    final canViewReport = int.tryParse(widget.requestId) != null;

    final userId =
        SharedPref.getLoginData().result?.data?.uid?.toString() ?? '';
    final pillWidth = 156.7.w;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const HeaderWidget(),
      body: SafeArea(
        top: false,
        child: _isLoading
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
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                              horizontal: 18.w, vertical: 10.w),
                          child: Column(
                            children: [
                              SizedBox(height: 8.w),
                              Text(
                                'Invoice',
                                style: GoogleFonts.poppins(
                                  fontSize: 16.sp,
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
                                      border: Border.all(
                                        color: const Color(0xFFC92626),
                                        width: 1,
                                      ),
                                    ),
                                    child: _buildAvatar(
                                      imageUrl: vendorPhotoUrl,
                                      name: vendorName,
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
                                            _displayOrDash(projectName),
                                            style: GoogleFonts.poppins(
                                              fontSize: 18.sp,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF181818),
                                            ),
                                          ),
                                          SizedBox(height: 2.w),
                                          Text(
                                            _displayOrDash(department),
                                            style: GoogleFonts.poppins(
                                              fontSize: 15.sp,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF888888),
                                            ),
                                          ),
                                          SizedBox(height: 8.w),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 10.w,
                                                vertical: 5.w),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFC9C9C9),
                                              borderRadius:
                                                  BorderRadius.circular(20.r),
                                            ),
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                _displayOrDash(requestNo),
                                                maxLines: 1,
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 13.sp,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      const Color(0xFF1E1E1E),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  _buildCompletionDonut(completionPercent),
                                ],
                              ),
                              SizedBox(height: 12.w),
                              _simSectionCard(
                                title: 'Invoice Info',
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 10.w,
                                                vertical: 8.w),
                                            child: _buildInfoCell(
                                              'W.O No#',
                                              workOrderNo,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          width: 1,
                                          height: 40.w,
                                          color: const Color(0xFFE6E6E6),
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 10.w,
                                                vertical: 8.w),
                                            child: _buildInfoCell(
                                              'Request Date',
                                              requestDate,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(
                                      height: 1,
                                      color: Color(0xFFE6E6E6),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 10.w, vertical: 8.w),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: _buildInfoCell(
                                              'Vendor',
                                              vendorName,
                                              valueColor:
                                                  const Color(0xFFFF8A00),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (tags.isNotEmpty) ...[
                                      const Divider(
                                        height: 1,
                                        color: Color(0xFFE6E6E6),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 10.w, vertical: 8.w),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Wrap(
                                            spacing: 8.w,
                                            runSpacing: 4.w,
                                            children: [
                                              for (int i = 0;
                                                  i < tags.length;
                                                  i++)
                                                _tagChip(
                                                  tags[i],
                                                  [
                                                    const Color(0xFFE1E4FF),
                                                    const Color(0xFFFCE6E6),
                                                    const Color(0xFFFFF1D8),
                                                    const Color(0xFFE1F5EC),
                                                  ][i % 4],
                                                  [
                                                    const Color(0xFF3F51E8),
                                                    const Color(0xFFD32F2F),
                                                    const Color(0xFFE08A00),
                                                    const Color(0xFF00A05A),
                                                  ][i % 4],
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              SizedBox(height: 12.w),
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14.r),
                                  border: Border.all(
                                      color: const Color(0xFF9E9E9E), width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    _buildMetricRow(
                                      label: 'Contract/Lpo',
                                      value: contractLpo,
                                      percentBadge: '-',
                                    ),
                                    _buildMetricRow(
                                      label: 'Advance',
                                      value: _formatAmount(advance),
                                      percentBadge: advancePct,
                                    ),
                                    _buildMetricRow(
                                      label: 'Progress',
                                      value: _formatAmount(progress),
                                      percentBadge: progressPct,
                                    ),
                                    _buildMetricRow(
                                      label: 'Last update',
                                      value: _formatDate(lastUpdate),
                                      percentBadge: lastUpdatePct,
                                    ),
                                    _buildMetricRow(
                                      label: 'Retention',
                                      value: _displayOrDash(retention),
                                      percentBadge: retentionPct,
                                    ),
                                    Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 10.w, vertical: 10.w),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Invoice Amount',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12.sp,
                                                fontWeight: FontWeight.w500,
                                                color: const Color(0xFFA0A0A0),
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _displayOrDash(invoiceAmount),
                                            style: GoogleFonts.poppins(
                                              fontSize: 30.sp / 2,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFFFF8A00),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 12.w),
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
                                      color:
                                          Colors.black.withValues(alpha: 0.08),
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
                                          '${comment.characters.length}/50',
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
                                        _displayOrDash(comment),
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
                              if (canViewReport) ...[
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
                              SizedBox(height: 20.w),
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

class _PiePercentPainter extends CustomPainter {
  final double percent;
  final Color fillColor;
  final Color baseColor;

  const _PiePercentPainter({
    required this.percent,
    required this.fillColor,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = math.min(size.width, size.height) / 2;

    final basePaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, basePaint);

    if (percent <= 0) return;

    final sweep = 2 * math.pi * (percent.clamp(0, 100) / 100);
    final arcPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawArc(rect, -math.pi / 2, sweep, true, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _PiePercentPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.baseColor != baseColor;
  }
}
