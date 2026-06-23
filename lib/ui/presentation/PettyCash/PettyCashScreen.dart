import 'dart:convert';
import 'dart:math' as math;

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/PettyCash/PettyCashDraftScreen.dart';
import 'package:el_race/ui/presentation/PettyCash/PettyCashList.dart';
import 'package:el_race/ui/presentation/PettyCash/PettyCashSubmittedScreen.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class PettyCashScreen extends StatefulWidget {
  const PettyCashScreen({super.key});

  @override
  State<PettyCashScreen> createState() => _PettyCashScreenState();
}

class _PettyCashScreenState extends State<PettyCashScreen> {
  bool _isLoading = true;
  String _error = '';
  bool _isNotHolder = false;
  _PettyCashHomeData _home = const _PettyCashHomeData.empty();

  final NumberFormat _wholeAmountFormat = NumberFormat('#,##0.##');
  final NumberFormat _integerAmountFormat = NumberFormat('#,##0');

  @override
  void initState() {
    super.initState();
    _fetchPettyCashHome();
  }

  void _logLongMessage(String label, String message) {
    const chunkSize = 800;
    if (message.isEmpty) {
      debugPrint('$label: <empty>');
      return;
    }

    for (var index = 0; index < message.length; index += chunkSize) {
      final end = math.min(index + chunkSize, message.length);
      debugPrint(
          '$label ${index ~/ chunkSize + 1}: ${message.substring(index, end)}');
    }
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
      if (result is! Map<String, dynamic>) return null;

      final data = result['data'];
      if (data is! Map<String, dynamic>) return null;

      final rawHolderId = data['holder_id'];
      if (rawHolderId is int) return rawHolderId;
      if (rawHolderId is List &&
          rawHolderId.isNotEmpty &&
          rawHolderId.first is int) {
        return rawHolderId.first as int;
      }
      return int.tryParse(rawHolderId?.toString() ?? '');
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchPettyCashHome() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = '';
      _isNotHolder = false;
    });

    try {
      final token = SharedPref.getLoginData().result?.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token is missing');
      }

      final holderId = _resolveHolderId();
      if (holderId == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isNotHolder = true;
          });
        }
        return;
      }

      final url = Uri.parse('https://erp.elrace.com/api/petty_cash_home');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final request = http.Request('GET', url)
        ..headers.addAll(headers)
        ..body = jsonEncode({
          'jsonrpc': '2.0',
          'params': <String, dynamic>{
            'holder_id': holderId,
          },
        });

      _logLongMessage(
        'PettyCashHome request body',
        jsonEncode({
          'jsonrpc': '2.0',
          'params': <String, dynamic>{
            'holder_id': holderId,
          },
        }),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('PettyCashHome statusCode: ${response.statusCode}');
      _logLongMessage('PettyCashHome raw response', response.body);

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to load petty cash home: ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      _logLongMessage('PettyCashHome decoded', jsonEncode(decoded));

      final result = decoded['result'];
      if (result is! Map<String, dynamic>) {
        debugPrint(
            'PettyCashHome unexpected result type: ${result.runtimeType}');
        throw Exception('Invalid petty cash response');
      }

      final data = (result['data'] is Map<String, dynamic>)
          ? result['data'] as Map<String, dynamic>
          : result;

      _logLongMessage('PettyCashHome result map', jsonEncode(result));
      _logLongMessage('PettyCashHome selected data', jsonEncode(data));

      final parsedHome = _PettyCashHomeData.fromJson(data);
      debugPrint(
        'PettyCashHome parsed values: '
        'batchId=${parsedHome.batchId}, '
        'totalLimit=${parsedHome.totalLimit}, '
        'draftAmount=${parsedHome.draftAmount}, '
        'submittedAmount=${parsedHome.submittedAmount}, '
        'paidAmount=${parsedHome.paidAmount}, '
        'balanceAmount=${parsedHome.balanceAmount}, '
        'recentSheets=${parsedHome.recentSheets.length}',
      );

      if (!mounted) return;
      setState(() {
        _home = parsedHome;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('PettyCashHome fetch error: $e');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatTopAmount(num value) {
    if (value % 1 == 0) {
      return _integerAmountFormat.format(value);
    }
    return _wholeAmountFormat.format(value);
  }

  String _formatSheetAmount(num value) {
    final absValue = value.abs();
    if (absValue % 1 == 0) {
      return _integerAmountFormat.format(absValue);
    }
    return _wholeAmountFormat.format(absValue);
  }

  String _formatSheetDate(String rawDate) {
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

  Color _statusDotColor(String state) {
    final normalized = state.trim().toLowerCase();
    if (normalized.contains('done') ||
        normalized.contains('paid') ||
        normalized.contains('approved')) {
      return const Color(0xFF0AA15F);
    }
    if (normalized.contains('submit') ||
        normalized.contains('pending') ||
        normalized.contains('progress')) {
      return const Color(0xFFFF9300);
    }
    if (normalized.contains('draft') ||
        normalized.contains('reject') ||
        normalized.contains('cancel') ||
        normalized.contains('refuse')) {
      return const Color(0xFFC81F25);
    }
    return const Color(0xFF0AA15F);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: const HeaderWidget(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isNotHolder
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Not a Petty Cash Holder',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your account is not assigned as a petty cash holder. Please contact your administrator.',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Colors.black54,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : _error.isNotEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Failed to load petty cash home',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _error,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.black54,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 18),
                            ElevatedButton(
                              onPressed: _fetchPettyCashHome,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchPettyCashHome,
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.zero,
                        children: [
                          _buildHeroSection(context),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Recent ${math.min(_home.recentSheets.length, 10)}/10',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black.withOpacity(0.28),
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const PettyCashSubmittedScreen(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'View More',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black.withOpacity(0.28),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_home.recentSheets.isEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(22, 24, 22, 40),
                              child: Center(
                                child: Text(
                                  'No recent expense sheets',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            )
                          else
                            ..._home.recentSheets
                                .take(10)
                                .map(_buildRecentSheetRow),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return SizedBox(
      height: 360,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 235,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0B0C19), Color(0xFF353536)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: -8,
                  left: -14,
                  child: Opacity(
                    opacity: 0.68,
                    child: Image.asset(
                      'assets/png/lines.png',
                      width: 170,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 14, 28, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/png/ppcash.png',
                            width: 28,
                            height: 28,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'PETTYCASH',
                            style: GoogleFonts.poppins(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 1.1,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your Balance',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.95),
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatTopAmount(_home.balanceAmount),
                        style: GoogleFonts.poppins(
                          fontSize: 56,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 0.95,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSummaryMetric('Amount', _home.totalLimit),
                          _buildSummaryMetric('Draft', _home.draftAmount),
                          _buildSummaryMetric(
                              'Not Paid', _home.submittedAmount),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            top: 239.h,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildDashboardAction(
                      icon: Icons.local_gas_station_outlined,
                      label: 'Transportation',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PettyCashDraftScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: _buildDashboardAction(
                      icon: Icons.format_list_bulleted_rounded,
                      label: 'Miscellaneous',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PettyCashList(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric(String label, num value) {
    return SizedBox(
      width: 92,
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.92),
              height: 1,
            ),
            textAlign: TextAlign.center,
            maxLines: null,
            overflow: TextOverflow.visible,
          ),
          const SizedBox(height: 6),
          Text(
            _formatTopAmount(value),
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1,
            ),
            textAlign: TextAlign.center,
            maxLines: null,
            overflow: TextOverflow.visible,
            softWrap: false,
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardAction({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      enableFeedback: onTap != null,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38, color: const Color(0xFF161616)),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF191919),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSheetRow(_PettyCashSheet sheet) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: null,
        enableFeedback: false,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 22),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.black.withOpacity(0.18),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFF5EEFA),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Image.asset(
                    'assets/png/Bill.png',
                    width: 24,
                    height: 24,
                    color: const Color(0xFF0E0E0E),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sheet.name,
                      maxLines: null,
                      overflow: TextOverflow.visible,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0A0A0A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatSheetDate(sheet.lastUpdate),
                      maxLines: null,
                      overflow: TextOverflow.visible,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black.withOpacity(0.34),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '-${_formatSheetAmount(sheet.amount)}',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFFF1421),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: _statusDotColor(sheet.state),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PettyCashHomeData {
  final int? batchId;
  final double totalLimit;
  final double draftAmount;
  final double submittedAmount;
  final double paidAmount;
  final double balanceAmount;
  final List<_PettyCashSheet> recentSheets;

  const _PettyCashHomeData({
    required this.batchId,
    required this.totalLimit,
    required this.draftAmount,
    required this.submittedAmount,
    required this.paidAmount,
    required this.balanceAmount,
    required this.recentSheets,
  });

  const _PettyCashHomeData.empty()
      : batchId = null,
        totalLimit = 0,
        draftAmount = 0,
        submittedAmount = 0,
        paidAmount = 0,
        balanceAmount = 0,
        recentSheets = const [];

  factory _PettyCashHomeData.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    return _PettyCashHomeData(
      batchId: json['batch_id'] as int?,
      totalLimit: toDouble(json['total_limit'] ?? json['incoming']),
      draftAmount: toDouble(json['draft_amount'] ?? json['draft']),
      submittedAmount:
          toDouble(json['submitted_amount'] ?? json['not_paid_amount']),
      paidAmount: toDouble(json['paid_amount'] ?? json['paid']),
      balanceAmount: toDouble(json['balance_amount'] ?? json['balance']),
      recentSheets: (json['recent_sheets'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => _PettyCashSheet.fromJson(
              Map<String, dynamic>.from(item as Map<dynamic, dynamic>)))
          .toList(growable: false),
    );
  }
}

class _PettyCashSheet {
  final String name;
  final String lastUpdate;
  final double amount;
  final String state;

  const _PettyCashSheet({
    required this.name,
    required this.lastUpdate,
    required this.amount,
    required this.state,
  });

  factory _PettyCashSheet.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    return _PettyCashSheet(
      name: (json['name'] ?? 'RCC PC 1').toString(),
      lastUpdate: (json['last_update'] ?? json['date'] ?? '').toString(),
      amount: toDouble(json['amount'] ?? json['total_amount']),
      state: (json['state'] ?? '').toString(),
    );
  }
}
