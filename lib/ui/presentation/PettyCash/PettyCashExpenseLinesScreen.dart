import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:el_race/ui/widgets/header_widget.dart';

/// Screen to display expense lines for a specific expense sheet
class PettyCashExpenseLinesScreen extends StatefulWidget {
  final int sheetId;
  final String sheetName;
  final String? sheetState;
  final double? totalAmount;

  const PettyCashExpenseLinesScreen({
    super.key,
    required this.sheetId,
    required this.sheetName,
    this.sheetState,
    this.totalAmount,
  });

  @override
  State<PettyCashExpenseLinesScreen> createState() =>
      _PettyCashExpenseLinesScreenState();
}

class _PettyCashExpenseLinesScreenState
    extends State<PettyCashExpenseLinesScreen> {
  bool isLoading = true;
  String error = '';
  List<Map<String, dynamic>> expenseLines = [];

  final NumberFormat _amountFormat = NumberFormat('#,##0');

  @override
  void initState() {
    super.initState();
    _fetchExpenseLines();
  }

  String _formatAmount(dynamic value) {
    final numVal = (value is num)
        ? value
        : num.tryParse(value?.toString().replaceAll(',', '') ?? '') ?? 0;
    return _amountFormat.format(numVal.round());
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr == 'false') {
      return '';
    }
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null) return dateStr;
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  Color _statusColor(String? state) {
    final s = (state ?? '').toString().toLowerCase();
    if (s.contains('paid') || s.contains('approve') || s.contains('done')) {
      return const Color(0xFF18A558);
    }
    if (s.contains('submit') || s.contains('pending') || s.contains('draft')) {
      return const Color(0xFFF0B400);
    }
    if (s.contains('reject') || s.contains('cancel') || s.contains('refuse')) {
      return const Color(0xFFD1002C);
    }
    return const Color(0xFF18A558);
  }

  Future<void> _fetchExpenseLines() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      error = '';
    });

    try {
      final loginData = SharedPref.getLoginData();
      final token = loginData.result?.token;

      final headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      };

      final url = Uri.parse("https://erp.elrace.com/api/expense/lines");

      final bodyData = {
        "jsonrpc": "2.0",
        "params": {
          "sheet_id": widget.sheetId,
        },
      };
      final body = jsonEncode(bodyData);

      print(
          '\n╔═══════════════════════════════════════════════════════════════');
      print('║ 📡 PETTY CASH API: EXPENSE LINES');
      print('╠═══════════════════════════════════════════════════════════════');
      print('║ 🌐 URL: $url');
      print('║ 📤 METHOD: POST');
      print('║ 📋 HEADERS:');
      headers.forEach((key, value) {
        if (key == 'Authorization') {
          print('║    $key: Bearer ${value.toString().substring(7, 27)}...');
        } else {
          print('║    $key: $value');
        }
      });
      print('║ 📦 BODY:');
      print('║    sheet_id: ${widget.sheetId}');
      print('║    Full: $body');
      print(
          '╚═══════════════════════════════════════════════════════════════\n');

      final response = await http.post(
        url,
        headers: headers,
        body: body,
      );

      print(
          '\n╔═══════════════════════════════════════════════════════════════');
      print('║ 📥 PETTY CASH API RESPONSE: EXPENSE LINES');
      print('╠═══════════════════════════════════════════════════════════════');
      print('║ ✅ STATUS CODE: ${response.statusCode}');
      print('║ 📄 RESPONSE BODY (RAW):');
      print('║ ${response.body}');
      print('║');
      print('║ 📄 RESPONSE BODY (FORMATTED):');
      try {
        final jsonData = jsonDecode(response.body);
        final prettyJson = const JsonEncoder.withIndent('  ').convert(jsonData);
        prettyJson.split('\n').forEach((line) => print('║ $line'));
      } catch (e) {
        print('║ Failed to format JSON: $e');
      }
      print(
          '╚═══════════════════════════════════════════════════════════════\n');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['result'];

        if (result != null && result['data'] != null) {
          final lines = result['data'];
          if (lines is List) {
            setState(() {
              expenseLines = List<Map<String, dynamic>>.from(lines);
              isLoading = false;
            });
            print('✅ Expense lines loaded: ${expenseLines.length} items');
          } else {
            setState(() {
              expenseLines = [];
              isLoading = false;
            });
          }
        } else {
          throw Exception("Invalid response format");
        }
      } else {
        throw Exception(
            "Failed to load expense lines: ${response.statusCode}");
      }
    } catch (e, stackTrace) {
      print(
          '\n╔═══════════════════════════════════════════════════════════════');
      print('║ ⚠️ EXPENSE LINES API ERROR');
      print('╠═══════════════════════════════════════════════════════════════');
      print('║ Error: $e');
      print(
          '║ Stack Trace: ${stackTrace.toString().split('\n').take(3).join('\n║ ')}');
      print(
          '╚═══════════════════════════════════════════════════════════════\n');
      if (!mounted) return;
      setState(() {
        isLoading = false;
        error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: const HeaderWidget(),
      body: Column(
        children: [
          // Header with sheet info
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F0FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/png/Bill.png',
                          width: 24,
                          height: 24,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.sheetName,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                          if (widget.sheetState != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _statusColor(widget.sheetState),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.sheetState!.toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _statusColor(widget.sheetState),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.totalAmount != null)
                      Text(
                        '${_formatAmount(widget.totalAmount)} AED',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFD1002C),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Expense Lines Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Image.asset(
                  'assets/png/draft2.png',
                  width: 20,
                  height: 20,
                  color: Colors.black87,
                ),
                const SizedBox(width: 8),
                Text(
                  'EXPENSE LINES',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                if (!isLoading)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6E6E6E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${expenseLines.length}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Expense Lines List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : error.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading expense lines',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _fetchExpenseLines,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : expenseLines.isEmpty
                        ? Center(
                            child: Text(
                              'No expense lines found.',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchExpenseLines,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              itemCount: expenseLines.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final line = expenseLines[index];
                                return _buildExpenseLineItem(line);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseLineItem(Map<String, dynamic> line) {
    final name = (line['name'] ?? line['description'] ?? 'Expense').toString();
    final amount = line['unit_amount'] ?? line['amount'] ?? 0;
    final date = _formatDate(line['date']?.toString());
    final expenseType =
        (line['x_expense_type'] ?? line['expense_type'] ?? '').toString();
    final state = (line['state'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Expense Type Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getExpenseTypeColor(expenseType).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(
                _getExpenseTypeIcon(expenseType),
                size: 20,
                color: _getExpenseTypeColor(expenseType),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (expenseType.isNotEmpty) ...[
                      Text(
                        expenseType.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _getExpenseTypeColor(expenseType),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (date.isNotEmpty)
                      Text(
                        date,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.black45,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Amount & Status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '-${_formatAmount(amount)}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFD1002C),
                ),
              ),
              const SizedBox(height: 4),
              if (state.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor(state).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    state.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: _statusColor(state),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getExpenseTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'fuel':
      case 'petrol':
        return const Color(0xFFE67E22);
      case 'hospitality':
        return const Color(0xFF9B59B6);
      case 'site':
      case 'site material':
        return const Color(0xFF3498DB);
      default:
        return const Color(0xFF7F8C8D);
    }
  }

  IconData _getExpenseTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'fuel':
      case 'petrol':
        return Icons.local_gas_station;
      case 'hospitality':
        return Icons.restaurant;
      case 'site':
      case 'site material':
        return Icons.construction;
      default:
        return Icons.receipt_long;
    }
  }
}
