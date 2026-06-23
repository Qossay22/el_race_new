import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../../../utils/urll_utils.dart';

class FamilyInsuranceRequestScreen extends StatefulWidget {
  const FamilyInsuranceRequestScreen({super.key});

  @override
  State<FamilyInsuranceRequestScreen> createState() =>
      _FamilyInsuranceRequestScreenState();
}

class _FamilyInsuranceRequestScreenState
    extends State<FamilyInsuranceRequestScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _eidNumberController = TextEditingController();
  final TextEditingController _eidExpiryController = TextEditingController();
  final TextEditingController _passportNumberController =
      TextEditingController();
  final TextEditingController _passportExpiryController =
      TextEditingController();

  String? _selectedFamilyMember;
  String? _selectedCaseKey;
  int? _selectedNationalityId;

  DateTime? _dob;

  bool _isLoadingInit = false;
  bool _isSubmitting = false;
  String? _initError;

  List<_CaseOption> _caseOptions = const [];
  List<_NationalityOption> _nationalities = const [];
  List<_DocRequirement> _requiredDocs = const [];
  final Map<String, _PickedFile> _pickedFiles = <String, _PickedFile>{};
  final Map<String, DateTime> _docExpiryDates = <String, DateTime>{};
  final Map<String, TextEditingController> _docExpiryControllers =
      <String, TextEditingController>{};

  static const String _initEndpoint = 'family_insurance/init';
  static const String _submitEndpoint = 'family_insurance/submit';

  static const Map<String, List<String>> _fallbackRequiredDocsByCase = {
    'spouse|visa_changed_abu_dhabi': [
      'passport_copy_file',
      'emirates_id_file',
      'resident_cancellation_file',
      'coc_file',
      'photo_file',
      'e_visa_file',
      'changed_status_file',
      'marriage_certificate_file',
    ],
    'spouse|visa_changed_other_region': [
      'passport_copy_file',
      'emirates_id_file',
      'resident_cancellation_file',
      'photo_file',
      'e_visa_file',
      'changed_status_file',
      'marriage_certificate_file',
    ],
    'spouse|resident_visa_outside_uae': [
      'e_visa_file',
      'entry_stamp_file',
      'passport_copy_file',
      'photo_file',
      'marriage_certificate_file',
    ],
    'spouse|visit_to_resident_visa': [
      'e_visa_file',
      'passport_copy_file',
      'photo_file',
      'visit_visa_file',
      'marriage_certificate_file',
    ],
    'child_1|newborn_inside_uae': [
      'photo_file',
      'birth_certificate_file',
    ],
    'child_2|resident_visa_outside_uae': [
      'e_visa_file',
      'entry_stamp_file',
      'passport_copy_file',
      'photo_file',
      'birth_certificate_file',
    ],
    'child_3|visit_to_resident_visa': [
      'e_visa_file',
      'passport_copy_file',
      'photo_file',
      'visit_visa_file',
      'birth_certificate_file',
    ],
  };

  static const Map<String, String> _fallbackDocLabels = {
    'passport_copy_file': 'Passport Copy',
    'emirates_id_file': 'Emirates ID Front & Back',
    'resident_cancellation_file': 'Resident Cancellation',
    'coc_file': 'COC',
    'photo_file': 'Personal Photo',
    'e_visa_file': 'E Visa',
    'changed_status_file': 'Changed Status',
    'marriage_certificate_file': 'Marriage Certificate',
    'entry_stamp_file': 'Entry Stamp',
    'visit_visa_file': 'Visit Visa',
    'birth_certificate_file': 'Birth Certificate',
  };

  static const Color _bg = Color(0xFFF2F2F2);
  static const Color _card = Color(0xFFF8F8F8);
  static const Color _navy = Color(0xFF0C0F3F);
  static const Color _yellow = Color(0xFFF6CC1B);
  static const Color _fieldFill = Color(0xFFE3E4E8);
  static const Color _fieldBorder = Color(0xFFC9CBD2);
  static const Color _uploadFill = Color(0xFFE9EAEE);

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _eidNumberController.dispose();
    _eidExpiryController.dispose();
    _passportNumberController.dispose();
    _passportExpiryController.dispose();
    for (final controller in _docExpiryControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Uri _apiUri(String endpoint) {
    final base = UrlUtil.baseUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base/$endpoint');
  }

  TextEditingController _expiryControllerFor(String field) {
    final existing = _docExpiryControllers[field];
    if (existing != null) {
      final expiry = _docExpiryDates[field];
      existing.text =
          expiry == null ? '' : DateFormat('MM/dd/yyyy').format(expiry);
      return existing;
    }

    final created = TextEditingController(
      text: _docExpiryDates[field] == null
          ? ''
          : DateFormat('MM/dd/yyyy').format(_docExpiryDates[field]!),
    );
    _docExpiryControllers[field] = created;
    return created;
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

  Future<void> _onFamilyMemberChanged(String? member) async {
    if (member == null || member == _selectedFamilyMember) return;

    setState(() {
      _selectedFamilyMember = member;
      _selectedCaseKey = null;
      _selectedNationalityId = null;
      _caseOptions = const [];
      _nationalities = const [];
      _requiredDocs = const [];
      _pickedFiles.clear();
      _docExpiryDates.clear();
      _initError = null;
    });

    await _loadInit(member);
  }

  Future<void> _loadInit(String familyMember) async {
    if (_isLoadingInit) return;

    setState(() {
      _isLoadingInit = true;
      _initError = null;
    });

    try {
      final token = SharedPref.getLoginData().result?.token ?? '';
      if (token.isEmpty) {
        setState(() {
          _initError = 'Session expired. Please login again.';
        });
        return;
      }

      final response = await http.post(
        _apiUri(_initEndpoint),
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
          _initError = 'Failed to load request setup.';
        });
        return;
      }

      final decoded = jsonDecode(response.body);
      final result = _extractResultMap(decoded);
      if (result == null) {
        setState(() {
          _initError = 'Invalid setup response.';
        });
        return;
      }

      final statusToken = _normalizeToken(result['status']);
      if (!(statusToken == 'success' ||
          statusToken == 'ok' ||
          statusToken == 'true')) {
        setState(() {
          _initError =
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

      final caseOptions = <_CaseOption>[];
      for (final item in casesRaw) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final key = (map['case_key'] ?? '').toString().trim();
        final label = (map['case_label'] ?? key).toString().trim();
        if (key.isEmpty) continue;

        final docs = <_DocRequirement>[];
        final docsRaw = (map['required_documents'] is List)
            ? (map['required_documents'] as List)
            : const [];
        for (final d in docsRaw) {
          if (d is! Map) continue;
          final dm = Map<String, dynamic>.from(d);
          final field = (dm['field'] ?? '').toString().trim();
          if (field.isEmpty) continue;
          docs.add(
            _DocRequirement(
              field: field,
              label: (dm['label'] ?? field).toString().trim(),
              type: (dm['type'] ?? '').toString().trim(),
            ),
          );
        }

        caseOptions.add(_CaseOption(key: key, label: label, docs: docs));
      }

      final nationalities = <_NationalityOption>[];
      for (final item in nationalitiesRaw) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final id = int.tryParse((map['id'] ?? '').toString());
        final name = (map['name'] ?? '').toString().trim();
        if (id == null || name.isEmpty) continue;
        nationalities.add(_NationalityOption(id: id, name: name));
      }

      setState(() {
        _caseOptions = caseOptions;
        _nationalities = nationalities;
        _selectedCaseKey =
            caseOptions.isNotEmpty ? caseOptions.first.key : null;
        _selectedNationalityId = nationalities
            .where((n) => n.id == 233)
            .map((n) => n.id)
            .cast<int?>()
            .firstWhere(
              (id) => id != null,
              orElse: () => nationalities.isNotEmpty ? nationalities.first.id : null,
            );
      });

      _syncRequiredDocs();
    } catch (_) {
      setState(() {
        _initError = 'Failed to load request setup.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingInit = false;
        });
      }
    }
  }

  void _syncRequiredDocs() {
    final selectedCase = _caseOptions.where((c) => c.key == _selectedCaseKey);
    final docs = <_DocRequirement>[];
    if (selectedCase.isNotEmpty) {
      docs.addAll(selectedCase.first.docs);
    }

    final member = _selectedFamilyMember ?? '';
    final fallbackKey = '$member|${_selectedCaseKey ?? ''}';
    final fallbackFields = _fallbackRequiredDocsByCase[fallbackKey] ?? const [];
    for (final field in fallbackFields) {
      if (docs.any((d) => d.field == field)) continue;
      final label = _fallbackDocLabels[field] ?? field;
      docs.add(
        _DocRequirement(
          field: field,
          label: label,
          type: field == 'photo_file' ? 'image' : 'pdf',
        ),
      );
    }

    final activeFields = docs.map((d) => d.field).toSet();
    _pickedFiles.removeWhere((key, _) => !activeFields.contains(key));
    _docExpiryDates.removeWhere((key, _) => !activeFields.contains(key));

    setState(() {
      _requiredDocs = docs;
    });
  }

  Future<void> _pickDocFile(String field, {required bool imageOnly}) async {
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
      _pickedFiles[field] = _PickedFile(
        path: picked.path!,
        filename: picked.name,
      );
    });
  }

  bool _validateBeforeSubmit() {
    if ((_selectedFamilyMember ?? '').isEmpty) {
      _showSnack('Please select relationship.');
      return false;
    }
    if ((_selectedCaseKey ?? '').isEmpty) {
      _showSnack('Please select medical request case.');
      return false;
    }
    if (_nameController.text.trim().isEmpty) {
      _showSnack('Please enter full name.');
      return false;
    }
    if (_dob == null) {
      _showSnack('Please select date of birth.');
      return false;
    }
    if (_selectedNationalityId == null) {
      _showSnack('Please select nationality.');
      return false;
    }

    for (final req in _requiredDocs) {
      if (_pickedFiles[req.field] == null) {
        _showSnack('Please upload ${req.label}.');
        return false;
      }
    }

    return true;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_validateBeforeSubmit()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final token = SharedPref.getLoginData().result?.token ?? '';
      if (token.isEmpty) {
        _showSnack('Session expired. Please login again.');
        return;
      }

      final params = <String, dynamic>{
        'family_member': _selectedFamilyMember,
        'medical_request_case': _selectedCaseKey,
        'family_member_name': _nameController.text.trim(),
        'family_member_dob': DateFormat('yyyy-MM-dd').format(_dob!),
        'family_member_nationality_id': _selectedNationalityId,
      };

      final eidNo = _eidNumberController.text.trim();
      if (eidNo.isNotEmpty) {
        params['emirates_id_no'] = eidNo;
      }
      final passportNo = _passportNumberController.text.trim();
      if (passportNo.isNotEmpty) {
        params['passport_no'] = passportNo;
      }

      for (final req in _requiredDocs) {
        final picked = _pickedFiles[req.field];
        if (picked == null) continue;

        final bytes = await File(picked.path).readAsBytes();
        params[req.field] = base64Encode(bytes);

        final filenameKey = req.field.replaceFirst('_file', '_filename');
        params[filenameKey] = picked.filename;

        final expiry = _docExpiryDates[req.field];
        if (expiry != null) {
          final expiryKey = req.field.replaceFirst('_file', '_expiry_date');
          params[expiryKey] = DateFormat('yyyy-MM-dd').format(expiry);
        }
      }

      final response = await http.post(
        _apiUri(_submitEndpoint),
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
        _showSnack(message);
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request submitted successfully.')),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      _showSnack('Failed to submit request.');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _sectionTitle(String text, {bool required = false}) {
    return Row(
      children: [
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        if (required) ...[
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: _yellow,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              'REQUIRED',
              style: GoogleFonts.poppins(
                fontSize: 8.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF403200),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _textField(
    String label,
    TextEditingController controller, {
    String hint = '',
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF2F2F2F),
          ),
        ),
        SizedBox(height: 6.h),
        TextField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
              color: const Color(0xFFB0B0B0),
              fontSize: 11.sp,
            ),
            filled: true,
            fillColor: _fieldFill,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
              borderSide: const BorderSide(color: _fieldBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
              borderSide: const BorderSide(color: _fieldBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
              borderSide:
                  const BorderSide(color: Color(0xFF9FA3AE), width: 1.2),
            ),
          ),
          style: GoogleFonts.poppins(fontSize: 12.sp),
        ),
      ],
    );
  }

  Widget _dropdownField<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String hint = 'Select',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF2F2F2F),
          ),
        ),
        SizedBox(height: 6.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          decoration: BoxDecoration(
            color: _fieldFill,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: _fieldBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              hint: Text(
                hint,
                style: GoogleFonts.poppins(
                  color: const Color(0xFFB0B0B0),
                  fontSize: 11.sp,
                ),
              ),
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                color: const Color(0xFF2F2F2F),
              ),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _uploadBox({
    required String field,
    required String title,
    required bool imageOnly,
  }) {
    final picked = _pickedFiles[field];
    return InkWell(
      onTap: () => _pickDocFile(field, imageOnly: imageOnly),
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: _fieldBorder),
          color: _uploadFill,
        ),
        child: Column(
          children: [
            Icon(Icons.cloud_upload_outlined,
                size: 22.sp, color: const Color(0xFF868686)),
            SizedBox(height: 6.h),
            Text(
              picked == null ? title : picked.filename,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF2F2F2F),
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              imageOnly ? 'JPG/PNG' : 'PDF or JPG (Max 5MB)',
              style: GoogleFonts.poppins(
                fontSize: 10.sp,
                color: const Color(0xFF8D8D8D),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _docCard({
    required String title,
    required String field,
    required bool imageOnly,
    required TextEditingController expiryController,
    required String expiryLabel,
    bool showNumberField = false,
    TextEditingController? numberController,
    String numberLabel = '',
    String numberHint = '',
  }) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(title, required: true),
          SizedBox(height: 10.h),
          if (showNumberField && numberController != null) ...[
            _textField(numberLabel, numberController, hint: numberHint),
            SizedBox(height: 10.h),
          ],
          _textField(
            expiryLabel,
            expiryController,
            hint: 'mm/dd/yyyy',
            readOnly: true,
            onTap: () async {
              await _pickDate(
                initialDate: _docExpiryDates[field],
                onPicked: (d) {
                  setState(() {
                    _docExpiryDates[field] = d;
                    expiryController.text = DateFormat('MM/dd/yyyy').format(d);
                  });
                },
              );
            },
          ),
          SizedBox(height: 10.h),
          _uploadBox(
            field: field,
            title: 'Upload $title',
            imageOnly: imageOnly,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: Colors.black,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'FAMILY DOCUMENT',
          style: GoogleFonts.bebasNeue(
            letterSpacing: 2,
            fontSize: 24.sp,
            color: _navy,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
          children: [
            Center(
              child: GestureDetector(
                onTap: () => _pickDocFile('photo_file', imageOnly: true),
                child: Column(
                  children: [
                    Container(
                      width: 110.w,
                      height: 110.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.transparent,
                        border: Border.all(
                          color: const Color(0xFF9A9A9A),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.add_a_photo_outlined,
                          size: 30.sp,
                          color: const Color(0xFF7D7D7D),
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Upload Profile Picture',
                      style: GoogleFonts.poppins(
                        fontSize: 13.sp,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16.h),
            _sectionTitle('Basic Information'),
            SizedBox(height: 10.h),
            _textField('Full Name', _nameController, hint: 'Enter name'),
            SizedBox(height: 10.h),
            _dropdownField<String>(
              label: 'Relationship',
              value: _selectedFamilyMember,
              hint: 'Select',
              items: const [
                DropdownMenuItem(value: 'spouse', child: Text('Spouse')),
                DropdownMenuItem(value: 'child_1', child: Text('Child 1')),
                DropdownMenuItem(value: 'child_2', child: Text('Child 2')),
                DropdownMenuItem(value: 'child_3', child: Text('Child 3')),
              ],
              onChanged: (v) {
                unawaited(_onFamilyMemberChanged(v));
              },
            ),
            SizedBox(height: 10.h),
            _dropdownField<int>(
              label: 'Nationality',
              value: _selectedNationalityId,
              hint: _isLoadingInit ? 'Loading...' : 'Select nationality',
              items: _nationalities
                  .map(
                    (n) => DropdownMenuItem<int>(
                      value: n.id,
                      child: Text(n.name),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (v) => setState(() => _selectedNationalityId = v),
            ),
            SizedBox(height: 10.h),
            _textField(
              'Date of Birth',
              _dobController,
              hint: 'mm/dd/yyyy',
              readOnly: true,
              onTap: () async {
                await _pickDate(
                  initialDate: _dob,
                  firstDate: DateTime(DateTime.now().year - 100),
                  lastDate: DateTime.now(),
                  onPicked: (d) {
                    setState(() {
                      _dob = d;
                      _dobController.text = DateFormat('MM/dd/yyyy').format(d);
                    });
                  },
                );
              },
            ),
            SizedBox(height: 10.h),
            _dropdownField<String>(
              label: 'Medical Request Case',
              value: _selectedCaseKey,
              hint: _isLoadingInit ? 'Loading...' : 'Select request case',
              items: _caseOptions
                  .map(
                    (c) => DropdownMenuItem<String>(
                      value: c.key,
                      child: Text(c.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (v) {
                setState(() {
                  _selectedCaseKey = v;
                });
                _syncRequiredDocs();
              },
            ),
            if ((_initError ?? '').isNotEmpty) ...[
              SizedBox(height: 8.h),
              Text(
                _initError!,
                style: GoogleFonts.poppins(
                  color: const Color(0xFFBA1719),
                  fontSize: 11.sp,
                ),
              ),
            ],
            SizedBox(height: 16.h),
            if (_requiredDocs.any((d) => d.field == 'emirates_id_file')) ...[
              _docCard(
                title: 'Emirates ID',
                field: 'emirates_id_file',
                imageOnly: false,
                expiryController: _eidExpiryController,
                expiryLabel: 'Expiry Date',
                showNumberField: true,
                numberController: _eidNumberController,
                numberLabel: 'ID Number',
                numberHint: '784-XXXX-XXXXXXX-X',
              ),
              SizedBox(height: 12.h),
            ],
            if (_requiredDocs.any((d) => d.field == 'passport_copy_file')) ...[
              _docCard(
                title: 'Passport Details',
                field: 'passport_copy_file',
                imageOnly: false,
                expiryController: _passportExpiryController,
                expiryLabel: 'Expiry Date',
                showNumberField: true,
                numberController: _passportNumberController,
                numberLabel: 'Passport Number',
                numberHint: 'Enter number',
              ),
            ],
            if (_requiredDocs
                .where((d) =>
                    d.field != 'emirates_id_file' &&
                    d.field != 'passport_copy_file' &&
                    d.field != 'photo_file')
                .isNotEmpty) ...[
              SizedBox(height: 14.h),
              ..._requiredDocs
                  .where((d) =>
                      d.field != 'emirates_id_file' &&
                      d.field != 'passport_copy_file' &&
                      d.field != 'photo_file')
                  .map((d) {
                return Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: _docCard(
                    title: d.label,
                    field: d.field,
                    imageOnly: d.type.toLowerCase() == 'image',
                    expiryController: _expiryControllerFor(d.field),
                    expiryLabel: 'Expiry Date',
                  ),
                );
              }),
            ],
            SizedBox(height: 8.h),
            SizedBox(
              height: 46.h,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _yellow,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: const CircularProgressIndicator(strokeWidth: 2),
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
    );
  }
}

class _CaseOption {
  const _CaseOption({
    required this.key,
    required this.label,
    required this.docs,
  });

  final String key;
  final String label;
  final List<_DocRequirement> docs;
}

class _DocRequirement {
  const _DocRequirement({
    required this.field,
    required this.label,
    required this.type,
  });

  final String field;
  final String label;
  final String type;
}

class _NationalityOption {
  const _NationalityOption({required this.id, required this.name});

  final int id;
  final String name;
}

class _PickedFile {
  const _PickedFile({required this.path, required this.filename});

  final String path;
  final String filename;
}
