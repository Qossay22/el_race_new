import 'package:el_race/ui/presentation/my_projects/data/datasources/project_remote_datasource.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_document_item_model.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/project_file_opening.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Screen to display cloud folders and files for a project
class CloudDocumentsScreen extends StatefulWidget {
  final int projectId;
  final String? folderId;
  final String? folderName;
  final String?
      folderType; // "wo" for Work Order, "estimation" for Estimations, null for Cloud

  const CloudDocumentsScreen({
    super.key,
    required this.projectId,
    this.folderId,
    this.folderName,
    this.folderType,
  });

  @override
  State<CloudDocumentsScreen> createState() => _CloudDocumentsScreenState();
}

class _CloudDocumentsScreenState extends State<CloudDocumentsScreen> {
  final ProjectRemoteDataSource _dataSource = ProjectRemoteDataSource();

  bool _isLoading = true;
  String? _error;
  List<ProjectDocumentItem> _items = [];
  List<ProjectDocumentItem> _folders = [];
  List<ProjectDocumentItem> _files = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (widget.folderId != null) {
        // Load folder contents
        final response = await _dataSource.fetchFolderContents(
          widget.projectId,
          widget.folderId!,
        );
        _items = response.items;
      } else {
        // Load project root documents with optional folder_type filter
        final response = await _dataSource.fetchProjectDocuments(
          widget.projectId,
          folderType: widget.folderType,
        );
        _items = response.items;
      }

      // Separate folders and files
      _folders = _items.where((item) => item.isFolder).toList();
      _files = _items.where((item) => item.isFile).toList();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _onFolderTap(ProjectDocumentItem folder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CloudDocumentsScreen(
          projectId: widget.projectId,
          folderId: folder.id,
          folderName: folder.name,
          folderType: widget.folderType, // Pass folderType to sub-folders
        ),
      ),
    );
  }

  Future<void> _onFileTap(ProjectDocumentItem file) async {
    var isLoadingDialogVisible = false;
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      isLoadingDialogVisible = true;

      // Get file details
      final response = await _dataSource.fetchFileDetails(
        widget.projectId,
        file.id,
      );

      // Hide loading
      if (mounted && isLoadingDialogVisible) {
        Navigator.pop(context);
        isLoadingDialogVisible = false;
      }

      final resolvedUrl = response.viewUrl.isNotEmpty
          ? response.viewUrl
          : (response.downloadUrl.isNotEmpty
              ? response.downloadUrl
              : (file.downloadUrl ?? ''));

      if (resolvedUrl.isEmpty) {
        throw Exception('No file URL returned from server');
      }

      if (!mounted) return;

      await openProjectFileInApp(
        context,
        rawUrl: resolvedUrl,
        fileName: file.name.trim().isNotEmpty ? file.name : response.name,
      );
    } catch (e) {
      if (mounted && isLoadingDialogVisible) {
        Navigator.pop(context);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening file: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const HeaderWidget(),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header Section
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 10),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 24.w,
                        color: appFontColor,
                      ),
                      SizedBox(width: 4.w),
                      Flexible(
                        child: Text(
                          widget.folderName ?? 'FOLDERS',
                          style: GoogleFonts.poppins(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w500,
                            color: appFontColor,
                          ),
                          maxLines: null,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),

          // Content
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48.w,
                      color: Colors.red,
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Error loading documents',
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32.w),
                      child: Text(
                        _error!,
                        style: GoogleFonts.poppins(
                          fontSize: 12.sp,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: _loadData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_items.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.folder_off,
                      size: 48.w,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'No documents found',
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Folders Section
            if (_folders.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  child: Text(
                    'FOLDERS',
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF151544),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final folder = _folders[index];
                      return _buildFolderCard(folder);
                    },
                    childCount: _folders.length,
                  ),
                ),
              ),
            ],

            // Files Section (Attachments)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                child: Text(
                  'ATTACHMENTS',
                  style: GoogleFonts.poppins(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF151544),
                  ),
                ),
              ),
            ),
            if (_files.isNotEmpty)
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final file = _files[index];
                      return _buildFileCard(file);
                    },
                    childCount: _files.length,
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Text(
                    'ما في مرفقات',
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),

            // Bottom padding
            SliverToBoxAdapter(
              child: SizedBox(height: 20.h),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFolderCard(ProjectDocumentItem folder) {
    return _buildUnifiedDocumentCard(
      onTap: () => _onFolderTap(folder),
      name: folder.name,
      leading: Image.asset(
        'assets/png/folder.png',
        width: 56.w,
        height: 56.w,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.folder,
            size: 36.w,
            color: const Color(0xFF151544),
          );
        },
      ),
    );
  }

  Widget _buildFileCard(ProjectDocumentItem file) {
    return _buildUnifiedDocumentCard(
      onTap: () => _onFileTap(file),
      name: file.name,
      leading: _buildFileIcon(file),
    );
  }

  Widget _buildUnifiedDocumentCard({
    required String name,
    required Widget leading,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 82.h,
        margin: EdgeInsets.only(bottom: 12.h),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFD6D6D6),
              Color(0xFFD6D6D6),
              Color(0xFFADB2BD),
            ],
            stops: [0.0, 0.4, 1.0],
          ),
          borderRadius: BorderRadius.circular(18.r),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18.r),
          child: Stack(
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.18,
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Colors.grey,
                          BlendMode.srcIn,
                        ),
                        child: SizedBox(
                          width: 150.w,
                          height: double.infinity,
                          child: Image.asset(
                            'assets/newapp/for_attachments.png',
                            fit: BoxFit.contain,
                            alignment: Alignment.centerRight,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                child: Row(
                  children: [
                    SizedBox(
                      width: 62.w,
                      height: 62.w,
                      child: Center(child: leading),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Center(
                        child: Text(
                          name.isEmpty ? 'File Name' : name,
                          maxLines: 2,
                          overflow: TextOverflow.visible,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2E3445),
                          ),
                        ),
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
  }

  Widget _buildFileIcon(ProjectDocumentItem file) {
    if (file.isPdf) {
      return Image.asset(
        'assets/png/pdf-icon.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE53935),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Center(
              child: Text(
                'PDF',
                style: GoogleFonts.poppins(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          );
        },
      );
    } else if (file.isExcel) {
      return Image.asset(
        'assets/png/excel-icon.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Center(
              child: Text(
                'XLS',
                style: GoogleFonts.poppins(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          );
        },
      );
    } else if (file.isWord) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Center(
          child: Text(
            'DOC',
            style: GoogleFonts.poppins(
              fontSize: 10.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    } else if (file.isImage) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF9C27B0),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Icon(
          Icons.image,
          size: 24.w,
          color: Colors.white,
        ),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF607D8B),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Icon(
          Icons.insert_drive_file,
          size: 24.w,
          color: Colors.white,
        ),
      );
    }
  }
}
