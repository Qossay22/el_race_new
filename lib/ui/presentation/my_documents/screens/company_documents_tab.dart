import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class CompanyDocumentsTab extends StatefulWidget {
  const CompanyDocumentsTab({
    super.key,
    this.onAddDocument,
    this.onOpenDocument,
  });

  final VoidCallback? onAddDocument;
  final Future<void> Function(Map<String, dynamic> document)? onOpenDocument;

  @override
  State<CompanyDocumentsTab> createState() => _CompanyDocumentsTabState();
}

class _CompanyDocumentsTabState extends State<CompanyDocumentsTab> {
  final PageController _foldersPageController =
      PageController(viewportFraction: 0.82);

  bool _isLoading = false;
  bool _isLoadingFolderContents = false;
  String? _error;

  List<_CompanyFolder> _folders = const [];
  int _currentFolderPage = 0;

  _CompanyFolder? _selectedFolder;
  List<_CompanyAttachment> _selectedFolderAttachments = const [];

  @override
  void initState() {
    super.initState();
    _fetchCompanyFolders();
  }

  @override
  void dispose() {
    _foldersPageController.dispose();
    super.dispose();
  }

  String _normalizeToken(dynamic value) {
    return (value ?? '').toString().trim().toLowerCase();
  }

  Map<String, dynamic> _extractResultEnvelope(dynamic decoded) {
    if (decoded is Map && decoded['result'] is Map) {
      return Map<String, dynamic>.from(decoded['result'] as Map);
    }
    if (decoded is Map && decoded['status'] != null) {
      return Map<String, dynamic>.from(decoded);
    }
    return <String, dynamic>{};
  }

  bool _isSuccessEnvelope(Map<String, dynamic> envelope) {
    final status = _normalizeToken(envelope['status']);
    return status == 'success' || status == 'ok' || status == 'true';
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    return int.tryParse((value ?? '').toString()) ?? fallback;
  }

  Future<dynamic> _sendJsonRpcGet(
    Uri url,
    Map<String, String> headers,
    Map<String, dynamic> params,
  ) async {
    final request = http.Request('GET', url)
      ..headers.addAll(headers)
      ..body = jsonEncode({
        'jsonrpc': '2.0',
        'params': params,
      });

    final streamed = await request.send();
    return http.Response.fromStream(streamed);
  }

  Future<void> _fetchCompanyFolders() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _selectedFolder = null;
      _selectedFolderAttachments = const [];
    });

    try {
      final token = SharedPref.getLoginData().result?.token ?? '';
      if (token.isEmpty) {
        throw Exception('Session expired. Please login again.');
      }

      final url = Uri.parse('https://erp.elrace.com/api/company/folders');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      var response = await _sendJsonRpcGet(url, headers, <String, dynamic>{});

      // Some environments reject GET with body; fallback to plain GET.
      if (response.statusCode == 400 ||
          response.statusCode == 404 ||
          response.statusCode == 405) {
        response = await http.get(
          url,
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to load company folders (HTTP ${response.statusCode})');
      }

      final decoded = jsonDecode(response.body);
      final envelope = _extractResultEnvelope(decoded);
      if (!_isSuccessEnvelope(envelope)) {
        throw Exception(
          envelope['message']?.toString() ??
              (decoded is Map ? decoded['error']?.toString() : null) ??
              'Failed to load company folders',
        );
      }

      final rawData = envelope['data'] ??
          (decoded is Map && decoded['data'] is List ? decoded['data'] : null);
      if (rawData is! List) {
        throw Exception('Invalid folders response format');
      }

      final mapped = rawData
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .map(
            (m) => _CompanyFolder(
              id: _toInt(m['id']),
              name: (m['name'] ?? 'Folder').toString(),
              totalFiles: _toInt(m['total_files']),
            ),
          )
          .where((f) => f.id > 0)
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _folders = mapped;
        if (_currentFolderPage >= _folders.length) {
          _currentFolderPage = _folders.isEmpty ? 0 : _folders.length - 1;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openFolder(_CompanyFolder folder) async {
    if (!mounted) return;
    setState(() {
      _isLoadingFolderContents = true;
      _error = null;
    });

    try {
      final token = SharedPref.getLoginData().result?.token ?? '';
      if (token.isEmpty) {
        throw Exception('Session expired. Please login again.');
      }

      final url =
          Uri.parse('https://erp.elrace.com/api/company/folder/contents');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response =
          await _sendJsonRpcGet(url, headers, {'unit_id': folder.id});

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to load folder contents (HTTP ${response.statusCode})');
      }

      final decoded = jsonDecode(response.body);
      final envelope = _extractResultEnvelope(decoded);
      if (!_isSuccessEnvelope(envelope)) {
        throw Exception(
          envelope['message']?.toString() ??
              (decoded is Map ? decoded['error']?.toString() : null) ??
              'Failed to load folder contents',
        );
      }

      final data = envelope['data'];
      if (data is! Map) {
        throw Exception('Invalid folder contents response format');
      }

      final rawAttachments = data['attachments'];
      final attachments = (rawAttachments is List)
          ? rawAttachments
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .map(
                (m) => _CompanyAttachment(
                  id: _toInt(m['id']),
                  name: (m['name'] ?? 'File').toString(),
                  mimetype: (m['mimetype'] ?? '').toString(),
                  createdAt: (m['create_date'] ?? '').toString(),
                  fileUrl: (m['file_url'] ?? '').toString(),
                  raw: m,
                ),
              )
              .where((a) => a.id > 0)
              .toList(growable: false)
          : const <_CompanyAttachment>[];

      if (!mounted) return;
      setState(() {
        _selectedFolder = folder;
        _selectedFolderAttachments = attachments;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFolderContents = false;
        });
      }
    }
  }

  int get _totalFilesAcrossFolders {
    var total = 0;
    for (final folder in _folders) {
      total += folder.totalFiles;
    }
    return total;
  }

  void _goBackToFolders() {
    if (!mounted) return;
    setState(() {
      _selectedFolder = null;
      _selectedFolderAttachments = const [];
      _error = null;
    });
  }

  Future<void> _openAttachment(_CompanyAttachment attachment) async {
    final callback = widget.onOpenDocument;
    if (callback == null) return;

    final map = Map<String, dynamic>.from(attachment.raw)
      ..['name'] = attachment.name
      ..['title'] = attachment.name
      ..['attachment_ids'] = [
        {
          'attachment_id': attachment.id,
        }
      ];

    await callback(map);
  }

  Widget _buildTopFoldersHeader() {
    return Padding(
      padding: EdgeInsets.only(left: 22.w, right: 22.w, top: 8.h, bottom: 6.h),
      child: Row(
        children: [
          Text(
            'Folders no ${_folders.length}',
            style: GoogleFonts.poppins(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF7A7A7A),
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildFoldersPager() {
    if (_folders.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 26.h),
        child: Column(
          children: [
            Icon(
              Icons.folder_off_rounded,
              size: 46.sp,
              color: const Color(0xFF98A0AE),
            ),
            SizedBox(height: 10.h),
            Text(
              'No company folders',
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF3B4352),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Folders will appear here once available.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF7B8290),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 250.h,
      child: PageView.builder(
        controller: _foldersPageController,
        itemCount: _folders.length,
        onPageChanged: (index) {
          if (!mounted) return;
          setState(() {
            _currentFolderPage = index;
          });
        },
        itemBuilder: (context, index) {
          final folder = _folders[index];
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: GestureDetector(
              onTap:
                  _isLoadingFolderContents ? null : () => _openFolder(folder),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: SvgPicture.asset(
                      'assets/newapp/company_document_tab_folder.svg',
                      fit: BoxFit.contain,
                    ),
                  ),
                  Positioned(
                    top: 20.h,
                    right: 34.w,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 140.w),
                      child: Text(
                        folder.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFoldersDots() {
    if (_folders.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: 2.h, bottom: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List<Widget>.generate(_folders.length, (index) {
          final isActive = index == _currentFolderPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: EdgeInsets.symmetric(horizontal: 5.w),
            width: 12.w,
            height: 12.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? const Color(0xFF7A7A7A) : Colors.white,
              border: Border.all(
                color: const Color(0xFF9E9E9E),
                width: 1,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNoOfFilesCard() {
    final totalFiles = _folders.isEmpty ? 0 : _totalFilesAcrossFolders;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 0.w, vertical: 4.h),
      child: SizedBox(
        height: 360.h,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bubbleLeft = constraints.maxWidth * 0.60;
            final bubbleTop = constraints.maxHeight * 0.72;
            final bubbleSize = constraints.maxWidth * 0.15;

            return Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/newapp/company_documents_no_of_file.png',
                    fit: BoxFit.contain,
                  ),
                ),
                Positioned(
                  left: bubbleLeft,
                  top: bubbleTop,
                  width: bubbleSize,
                  height: bubbleSize,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        totalFiles.toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 30.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
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

  Widget _buildFolderContents() {
    final folder = _selectedFolder;
    if (folder == null) return const SizedBox.shrink();

    return Column(
      children: [
        Padding(
          padding:
              EdgeInsets.only(left: 10.w, right: 12.w, top: 6.h, bottom: 6.h),
          child: Row(
            children: [
              IconButton(
                onPressed: _goBackToFolders,
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: const Color(0xFF27304E),
              ),
              Expanded(
                child: Text(
                  folder.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1D2445),
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              SizedBox(width: 40.w),
            ],
          ),
        ),
        if (_isLoadingFolderContents)
          const Expanded(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_selectedFolderAttachments.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                'No files in this folder',
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF7A7A7A),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding:
                      EdgeInsets.only(left: 28.w, right: 18.w, bottom: 8.h),
                  child: Row(
                    children: [
                      Text(
                        'No of files ${_selectedFolderAttachments.length}',
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF808080),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding:
                        EdgeInsets.symmetric(horizontal: 22.w, vertical: 4.h),
                    itemCount: _selectedFolderAttachments.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 20.w,
                      mainAxisSpacing: 18.h,
                      mainAxisExtent: 178.h,
                    ),
                    itemBuilder: (context, index) {
                      final item = _selectedFolderAttachments[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(12.r),
                        onTap: () => _openAttachment(item),
                        child: Column(
                          children: [
                            SizedBox(
                              width: 92.w,
                              height: 92.w,
                              child: Image.asset(
                                'assets/newapp/pdf.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              item.name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF111111),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_selectedFolder != null) {
          _goBackToFolders();
          return false;
        }
        return true;
      },
      child: Builder(
        builder: (context) {
          if (_isLoading && _folders.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_error != null && _folders.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFBA1719),
                        fontSize: 12.sp,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    OutlinedButton(
                      onPressed: _fetchCompanyFolders,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (_selectedFolder != null) {
            return _buildFolderContents();
          }

          return Stack(
            children: [
              ListView(
                padding: EdgeInsets.only(top: 6.h, bottom: 8.h),
                children: [
                  _buildTopFoldersHeader(),
                  _buildFoldersPager(),
                  _buildFoldersDots(),
                  _buildNoOfFilesCard(),
                ],
              ),
              if (_isLoadingFolderContents)
                Positioned.fill(
                  child: AbsorbPointer(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.12),
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16.w, vertical: 12.h),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2.6),
                              ),
                              SizedBox(width: 10.w),
                              Text(
                                'Loading folder files...',
                                style: GoogleFonts.poppins(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF27304E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CompanyFolder {
  const _CompanyFolder({
    required this.id,
    required this.name,
    required this.totalFiles,
  });

  final int id;
  final String name;
  final int totalFiles;
}

class _CompanyAttachment {
  const _CompanyAttachment({
    required this.id,
    required this.name,
    required this.mimetype,
    required this.createdAt,
    required this.fileUrl,
    required this.raw,
  });

  final int id;
  final String name;
  final String mimetype;
  final String createdAt;
  final String fileUrl;
  final Map<String, dynamic> raw;
}
