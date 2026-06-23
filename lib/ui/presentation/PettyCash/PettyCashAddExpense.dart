import 'dart:async';
import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    String newText = newValue.text.replaceAll(RegExp(r'[^\d.]'), '');

    if (newText.split('.').length > 2) {
      return oldValue;
    }

    final parts = newText.split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : '';

    String formattedInteger = '';
    var count = 0;
    for (var i = integerPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        formattedInteger = ',$formattedInteger';
      }
      formattedInteger = integerPart[i] + formattedInteger;
      count++;
    }

    var formattedText = formattedInteger;
    if (parts.length > 1) {
      formattedText += '.$decimalPart';
    }

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

class PettyCashAddExpense extends StatefulWidget {
  final String fixedExpenseType;

  const PettyCashAddExpense({
    super.key,
    required this.fixedExpenseType,
  });

  @override
  State<PettyCashAddExpense> createState() => _PettyCashAddExpenseState();
}

class _PettyCashAddExpenseState extends State<PettyCashAddExpense> {
  final TextEditingController _projectController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _holderController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  List<Map<String, dynamic>> _projectResults = const [];
  Map<String, dynamic>? _selectedProject;

  bool _isSubmitting = false;
  bool _isProjectLoading = false;
  bool _isExpenseTypeLoading = false;
  Timer? _projectSearchDebounce;

  DateTime _selectedDate = DateTime.now();
  int? _holderId;
  List<_ExpenseTypeOption> _expenseTypeOptions = const [];
  String? _selectedExpenseTypeValue;

  static const TextStyle _labelStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: Colors.black,
    height: 1.1,
  );

  bool get _isTransportation {
    return widget.fixedExpenseType.toLowerCase().trim() == 'fleet';
  }

  String get _summaryType {
    return _isTransportation ? 'fleet' : 'others';
  }

  String get _effectiveExpenseTypeValue {
    return _selectedExpenseTypeValue ??
        (_isTransportation ? 'fleet' : 'others');
  }

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);
    _holderId = _resolveHolderId();
    _holderController.text = _holderId?.toString() ?? '';
    unawaited(_loadExpenseTypeOptions());
  }

  @override
  void dispose() {
    _projectSearchDebounce?.cancel();
    _projectController.dispose();
    _amountController.dispose();
    _holderController.dispose();
    _dateController.dispose();
    super.dispose();
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

  Future<List<Map<String, dynamic>>> _fetchProjects({
    required String keyword,
  }) async {
    final token = SharedPref.getLoginData().result?.token;
    if (token == null || token.isEmpty) {
      throw Exception('Authentication token is missing');
    }

    final request = http.Request(
      'GET',
      Uri.parse('https://erp.elrace.com/api/petty_cash/projects'),
    )
      ..headers.addAll(<String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      })
      ..body = jsonEncode(<String, dynamic>{
        'jsonrpc': '2.0',
        'params': <String, dynamic>{
          'keyword': keyword,
        },
      });

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch projects: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final result = decoded['result'];
    if (result is! Map<String, dynamic>) {
      return const <Map<String, dynamic>>[];
    }

    final data = result['data'];
    if (data is! List) {
      return const <Map<String, dynamic>>[];
    }

    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  Future<void> _showProjectSearchDialog() async {
    final searchController = TextEditingController();
    var dialogResults = List<Map<String, dynamic>>.from(_projectResults);
    var dialogLoading = false;
    var dialogError = '';

    Future<void> runSearch(StateSetter setDialogState, String keyword) async {
      setDialogState(() {
        dialogLoading = true;
        dialogError = '';
      });

      try {
        final projects = await _fetchProjects(keyword: keyword);
        if (!mounted) return;
        setDialogState(() {
          dialogResults = projects;
          dialogLoading = false;
        });
      } catch (e) {
        setDialogState(() {
          dialogLoading = false;
          dialogError = e.toString();
        });
      }
    }

    if (_projectResults.isEmpty) {
      setState(() => _isProjectLoading = true);
      try {
        final initial = await _fetchProjects(keyword: '');
        if (mounted) {
          setState(() {
            _projectResults = initial;
            _isProjectLoading = false;
          });
          dialogResults = initial;
        }
      } catch (_) {
        if (mounted) {
          setState(() => _isProjectLoading = false);
        }
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Select Project',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: searchController,
                      onChanged: (value) {
                        _projectSearchDebounce?.cancel();
                        _projectSearchDebounce =
                            Timer(const Duration(milliseconds: 350), () {
                          runSearch(setDialogState, value.trim());
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search project/cost center',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (dialogLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: CircularProgressIndicator(),
                      )
                    else if (dialogError.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          dialogError,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    else
                      SizedBox(
                        height: 280,
                        child: ListView.separated(
                          itemCount: dialogResults.length,
                          separatorBuilder: (_, __) =>
                              Divider(color: Colors.grey.shade300, height: 1),
                          itemBuilder: (_, index) {
                            final project = dialogResults[index];
                            final projectName =
                                (project['name'] ?? '').toString().trim();
                            final projectId = int.tryParse(
                                project['project_id']?.toString() ?? '');

                            return ListTile(
                              dense: true,
                              title: Text(
                                projectName.isEmpty
                                    ? 'Unnamed project'
                                    : projectName,
                                maxLines: 2,
                                overflow: TextOverflow.visible,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              subtitle: projectId == null
                                  ? null
                                  : Text('ID: $projectId'),
                              onTap: projectId == null
                                  ? null
                                  : () {
                                      setState(() {
                                        _selectedProject = project;
                                        _projectController.text = projectName;
                                        _projectResults = dialogResults;
                                      });
                                      Navigator.pop(dialogContext);
                                    },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);
      });
    }
  }

  Future<void> _loadExpenseTypeOptions() async {
    if (!mounted) return;

    final token = SharedPref.getLoginData().result?.token;
    if (token == null || token.isEmpty || _holderId == null) {
      setState(() {
        _expenseTypeOptions = const [];
        _selectedExpenseTypeValue = null;
      });
      return;
    }

    setState(() => _isExpenseTypeLoading = true);

    try {
      final requestBody = jsonEncode(<String, dynamic>{
        'jsonrpc': '2.0',
        'params': <String, dynamic>{
          'holder_id': _holderId,
          'type': _summaryType,
        },
      });
      debugPrint('[PettyCash] _loadExpenseTypeOptions → REQUEST');
      debugPrint('[PettyCash]   URL   : https://erp.elrace.com/api/draft_summary');
      debugPrint('[PettyCash]   Body  : $requestBody');

      final response = await http.post(
        Uri.parse('https://erp.elrace.com/api/draft_summary'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: requestBody,
      );

      debugPrint('[PettyCash] _loadExpenseTypeOptions → RESPONSE');
      debugPrint('[PettyCash]   Status: ${response.statusCode}');
      debugPrint('[PettyCash]   Body  : ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Failed to load expense types: ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final result = decoded['result'];
      if (result is! Map<String, dynamic> || result['status'] != 'success') {
        throw Exception('Failed to load expense types');
      }

      final data = result['data'];
      final rawOptions =
          data is Map<String, dynamic> ? data['expense_type_options'] : null;

      debugPrint('[PettyCash]   rawOptions: $rawOptions');

      final parsedOptions = rawOptions is List
          ? rawOptions
              .whereType<Map>()
              .map((item) {
                final map = Map<String, dynamic>.from(item);
                var value = (map['value'] ?? '').toString().trim();
                final label = (map['label'] ?? value).toString().trim();
                if (value.isEmpty) return null;
                // Normalize: API may return 'miscellaneous' but server expects 'others'
                if (value.toLowerCase() == 'miscellaneous') {
                  debugPrint('[PettyCash]   Normalizing "$value" → "others"');
                  value = 'others';
                }
                return _ExpenseTypeOption(value: value, label: label);
              })
              .whereType<_ExpenseTypeOption>()
              .toList(growable: false)
          : const <_ExpenseTypeOption>[];

      debugPrint('[PettyCash]   parsedOptions: ${parsedOptions.map((o) => '{value:${o.value}, label:${o.label}}').toList()}');

      if (!mounted) return;
      setState(() {
        final fallback = _isTransportation
            ? const _ExpenseTypeOption(value: 'fleet', label: 'Transportations')
            : const _ExpenseTypeOption(value: 'others', label: 'Miscellaneous');
        _expenseTypeOptions =
            parsedOptions.isNotEmpty ? parsedOptions : [fallback];
        _selectedExpenseTypeValue = _expenseTypeOptions.first.value;
        debugPrint('[PettyCash]   _selectedExpenseTypeValue set to: $_selectedExpenseTypeValue');
      });
    } catch (e) {
      debugPrint('[PettyCash] _loadExpenseTypeOptions → ERROR: $e');
      if (!mounted) return;
      setState(() {
        final fallback = _isTransportation
            ? const _ExpenseTypeOption(value: 'fleet', label: 'Transportations')
            : const _ExpenseTypeOption(value: 'others', label: 'Miscellaneous');
        _expenseTypeOptions = [fallback];
        _selectedExpenseTypeValue = fallback.value;
        debugPrint('[PettyCash]   fallback used: ${fallback.value}');
      });
    } finally {
      if (mounted) {
        setState(() => _isExpenseTypeLoading = false);
      }
    }
  }

  Future<void> _submitExpense() async {
    if (_holderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Petty cash holder is missing')),
      );
      return;
    }

    if (_selectedProject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a project')),
      );
      return;
    }

    final projectId =
        int.tryParse(_selectedProject?['project_id']?.toString() ?? '');
    if (projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid project selected')),
      );
      return;
    }

    final parsedAmount =
        double.tryParse(_amountController.text.replaceAll(',', '').trim());
    if (parsedAmount == null || parsedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    if (_selectedExpenseTypeValue == null ||
        _selectedExpenseTypeValue!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select expense type')),
      );
      return;
    }

    final token = SharedPref.getLoginData().result?.token;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication token is missing')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final projectName = (_selectedProject?['name'] ?? '').toString().trim();

      final body = <String, dynamic>{
        'jsonrpc': '2.0',
        'params': <String, dynamic>{
          'project_id': projectId,
          'holder_id': _holderId,
          'unit_amount': parsedAmount,
          'name':
              '$projectName - ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
          'type': _effectiveExpenseTypeValue,
          'x_expense_type': _effectiveExpenseTypeValue,
        },
      };

      debugPrint('[PettyCash] _submitExpense → REQUEST');
      debugPrint('[PettyCash]   URL   : https://erp.elrace.com/api/create_hr_expense');
      debugPrint('[PettyCash]   Body  : ${jsonEncode(body)}');

      final response = await http.post(
        Uri.parse('https://erp.elrace.com/api/create_hr_expense'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      debugPrint('[PettyCash] _submitExpense → RESPONSE');
      debugPrint('[PettyCash]   Status: ${response.statusCode}');
      debugPrint('[PettyCash]   Body  : ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Failed to submit expense: ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final result = decoded['result'];
      if (result is! Map<String, dynamic> || result['status'] != 'success') {
        final message = (result is Map<String, dynamic>)
            ? (result['message']?.toString() ?? 'Failed to submit expense')
            : 'Failed to submit expense';
        throw Exception(message);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result['message']?.toString() ?? 'Expense added')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    TextStyle fieldTextStyle(bool isPlaceholder) => TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: isPlaceholder ? Colors.black.withOpacity(0.40) : Colors.black,
        );

    InputDecoration pillDecoration({String? hintText, Widget? suffixIcon}) {
      return InputDecoration(
        hintText: hintText,
        hintStyle: fieldTextStyle(true),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide:
              BorderSide(color: Colors.black.withOpacity(0.25), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide:
              BorderSide(color: Colors.black.withOpacity(0.25), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide:
              BorderSide(color: Colors.black.withOpacity(0.35), width: 1.2),
        ),
      );
    }

    Widget labeledField({required String label, required Widget child}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: _labelStyle,
          ),
          const SizedBox(height: 8),
          child,
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              FocusScope.of(context).unfocus();
              Navigator.pop(context);
            },
            child: const SizedBox.expand(),
          ),
          SafeArea(
            child: Center(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9E9E9),
                        borderRadius: BorderRadius.circular(34),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '+ ADD EXPENSE',
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                              height: 1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 18),
                          labeledField(
                            label: 'Project',
                            child: TextField(
                              controller: _projectController,
                              readOnly: true,
                              textAlign: TextAlign.center,
                              style: fieldTextStyle(
                                  _projectController.text.trim().isEmpty),
                              onTap: _isProjectLoading
                                  ? null
                                  : _showProjectSearchDialog,
                              decoration: pillDecoration(
                                hintText: _isProjectLoading
                                    ? 'Loading...'
                                    : 'Project Name',
                                suffixIcon: const Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 30,
                                  color: Colors.black45,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          labeledField(
                            label: 'Amount',
                            child: TextField(
                              controller: _amountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                ThousandsSeparatorInputFormatter()
                              ],
                              textAlign: TextAlign.center,
                              style: fieldTextStyle(
                                  _amountController.text.trim().isEmpty),
                              decoration: pillDecoration(hintText: '5,000'),
                            ),
                          ),
                          const SizedBox(height: 14),
                          labeledField(
                            label: 'Pettycash holder',
                            child: TextField(
                              controller: _holderController,
                              readOnly: true,
                              textAlign: TextAlign.center,
                              style: fieldTextStyle(
                                  _holderController.text.trim().isEmpty),
                              decoration: pillDecoration(hintText: 'Holder'),
                            ),
                          ),
                          const SizedBox(height: 14),
                          labeledField(
                            label: 'Invoice Date',
                            child: TextField(
                              controller: _dateController,
                              readOnly: true,
                              textAlign: TextAlign.center,
                              style: fieldTextStyle(false),
                              onTap: _pickDate,
                              decoration: pillDecoration(
                                hintText: DateFormat('dd/MM/yyyy')
                                    .format(_selectedDate),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          labeledField(
                            label: 'Expense type',
                            child: _isExpenseTypeLoading
                                ? InputDecorator(
                                    decoration: pillDecoration(),
                                    child: Center(
                                      child: Text(
                                        'Loading...',
                                        style: fieldTextStyle(true),
                                      ),
                                    ),
                                  )
                                : DropdownButtonFormField<String>(
                                    value: _selectedExpenseTypeValue,
                                    isExpanded: true,
                                    decoration: pillDecoration(),
                                    borderRadius: BorderRadius.circular(16),
                                    items: _expenseTypeOptions
                                        .map(
                                          (option) => DropdownMenuItem<String>(
                                            value: option.value,
                                            child: Text(
                                              option.label,
                                              textAlign: TextAlign.center,
                                              style: fieldTextStyle(false),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(growable: false),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() {
                                        _selectedExpenseTypeValue = value;
                                      });
                                    },
                                  ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF676A70),
                                shape: const StadiumBorder(),
                                elevation: 0,
                              ),
                              onPressed: _isSubmitting ? null : _submitExpense,
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      '+ ADD EXPENSE',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseTypeOption {
  final String value;
  final String label;

  const _ExpenseTypeOption({
    required this.value,
    required this.label,
  });
}
