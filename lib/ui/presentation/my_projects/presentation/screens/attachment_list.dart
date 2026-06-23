import 'dart:convert';
import 'dart:io';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_list_bloc.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_list_event.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_list_state.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:slide_to_act/slide_to_act.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/folder_model.dart';
import 'package:el_race/ui/presentation/my_projects/data/datasources/project_remote_datasource.dart';
import 'package:http/http.dart' as http;
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/project_file_opening.dart';

class AttachmentListScreen extends StatefulWidget {
  final ProjectListBloc bloc;
  final int? projectId;
  final String? folderType;

  const AttachmentListScreen({
    super.key,
    required this.bloc,
    this.projectId,
    this.folderType,
  });

  @override
  State<AttachmentListScreen> createState() => _AttachmentListScreenState();
}

class _AttachmentListScreenState extends State<AttachmentListScreen> {
  @override
  void initState() {
    super.initState();
    debugPrint("===============================");
    debugPrint("📋 AttachmentListScreen initState");
    debugPrint("projectId: ${widget.projectId}");
    debugPrint("folderType: ${widget.folderType}");
    debugPrint("===============================");
    // Load attachments if projectId is provided
    if (widget.projectId != null) {
      widget.bloc.add(GetProjectAttachmentsEvent(
        widget.projectId.toString(),
        folderType: widget.folderType,
      ));
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
          // Header Section (Scrollable)
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 10),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/newapp/attachment.png',
                        height: 24.w,
                        width: 24.w,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'ATTACHMENTS',
                        style: GoogleFonts.poppins(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w500,
                          color: appFontColor,
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
          BlocProvider.value(
            value: widget.bloc,
            child: BlocBuilder<ProjectListBloc, ProjectListState>(
              builder: (ctx, state) {
                if (state is ProjectAttachmentsLoading) {
                  return const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  );
                } else if (state is ProjectAttachmentsLoaded) {
                  final list = widget.bloc.projectAttacmentList;
                  if (list.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.attach_file,
                              size: 48.w,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              'No attachments',
                              style: GoogleFonts.poppins(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final attachment = list[index];
                          return Padding(
                            padding: EdgeInsets.only(bottom: 14.h),
                            child: _buildAttachmentRowCard(attachment),
                          );
                        },
                        childCount: list.length,
                      ),
                    ),
                  );
                } else if (state is ProjectAttachmentsError) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Error loading attachments',
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              color: Colors.red,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            state.message,
                            style: GoogleFonts.poppins(
                              fontSize: 12.sp,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  return const SliverFillRemaining(
                    child: Center(child: Text('No data available')),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentRowCard(dynamic attachment) {
    final String name = (attachment.name ?? '').toString();
    final String type = (attachment.type ?? '').toString();
    final String url = (attachment.url ?? '').toString();

    String iconPath = 'assets/png/file-icon.png';
    if (type.contains('spreadsheet') ||
        type.contains('excel') ||
        name.toLowerCase().endsWith('.xlsx') ||
        name.toLowerCase().endsWith('.xls')) {
      iconPath = 'assets/png/excel-icon.png';
    } else if (type.contains('pdf') || name.toLowerCase().endsWith('.pdf')) {
      iconPath = 'assets/png/pdf-icon.png';
    }

    return GestureDetector(
      onTap: () => _downloadFile(url, name),
      child: Container(
        height: 82.h,
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
                            Colors.grey, BlendMode.srcIn),
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
                      child: Center(
                        child: Image.asset(
                          iconPath,
                          width: 150.w,
                          height: 150.w,
                          fit: BoxFit.contain,
                        ),
                      ),
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

  Widget _buildAddNewDocumentCard() {
    return GestureDetector(
      onTap: () => _showAddDocumentDialog(),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(
            color: const Color(0xFFD9D9D9),
            width: 2,
          ),
          color: Colors.white,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/png/add_doc.svg',
              width: 60.w,
              height: 60.w,
            ),
            SizedBox(height: 10.h),
            Text(
              'Add New Document',
              style: GoogleFonts.poppins(
                fontSize: 10.sp,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic,
                letterSpacing: 0.10,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentCard(dynamic attachment) {
    final String name = attachment.name ?? '';
    final String type = attachment.type ?? '';
    final String url = attachment.url ?? '';

    // Determine file icon based on type
    String iconPath = 'assets/png/file-icon.png';
    String fileType = 'FILE';

    if (type.contains('spreadsheet') ||
        type.contains('excel') ||
        name.toLowerCase().endsWith('.xlsx') ||
        name.toLowerCase().endsWith('.xls')) {
      iconPath = 'assets/png/excel-icon.png';
      fileType = 'EXCEL';
    } else if (type.contains('presentation') ||
        type.contains('powerpoint') ||
        name.toLowerCase().endsWith('.pptx') ||
        name.toLowerCase().endsWith('.ppt')) {
      iconPath = 'assets/png/file-icon.png';
      fileType = 'PPT';
    } else if (type.contains('word') ||
        name.toLowerCase().endsWith('.docx') ||
        name.toLowerCase().endsWith('.doc')) {
      iconPath = 'assets/png/file-icon.png';
      fileType = 'DOC';
    } else if (type.contains('pdf') || name.toLowerCase().endsWith('.pdf')) {
      iconPath = 'assets/png/pdf-icon.png';
      fileType = 'PDF';
    }

    return GestureDetector(
      onTap: () => _downloadFile(url, name),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(
            color: const Color(0xFFD9D9D9),
            width: 2,
          ),
          color: Colors.white,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // File Icon
              Image.asset(
                iconPath,
                width: 60.w,
                height: 60.w,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.insert_drive_file,
                  size: 60.w,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 8.h),

              // File Type Label
              Text(
                fileType,
                style: GoogleFonts.poppins(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 4.h),

              // File Name
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                child: Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFFBA1719),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _downloadFile(String url, String fileName) async {
    try {
      await openProjectFileInApp(
        context,
        rawUrl: url,
        fileName: fileName,
      );
    } catch (e) {
      print('Error downloading file: $e');
    }
  }

  void _showAddDocumentDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return _AddDocumentDialog(
          projectId: '', // You need to pass the actual project ID
          onSuccess: () {
            // Refresh attachments list
            Navigator.pop(dialogContext);
          },
        );
      },
    );
  }
}

class _AddDocumentDialog extends StatefulWidget {
  final String projectId;
  final VoidCallback onSuccess;

  const _AddDocumentDialog({
    required this.projectId,
    required this.onSuccess,
  });

  @override
  State<_AddDocumentDialog> createState() => _AddDocumentDialogState();
}

class _AddDocumentDialogState extends State<_AddDocumentDialog>
    with SingleTickerProviderStateMixin {
  final TextEditingController _woNameController = TextEditingController();
  final List<PlatformFile> _selectedFiles = [];
  bool _isUploading = false;
  List<FolderModel> _folders = [];
  FolderModel? _selectedFolder;
  bool _isLoadingFolders = true;
  bool _isPickingFiles = false;
  late AnimationController _arrowAnimationController;
  late Animation<double> _arrowScaleAnimation;

  @override
  void initState() {
    super.initState();
    _loadFolders();

    // Setup animation controller
    _arrowAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _arrowScaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _arrowAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Loop animation
    _arrowAnimationController.repeat(reverse: true);
  }

  Future<void> _loadFolders() async {
    try {
      print('🔄 Starting to load folders...');
      final datasource = ProjectRemoteDataSource();
      final folders = await datasource.fetchProjectFolders();
      print('✅ Folders loaded: ${folders.length} folders');
      for (var folder in folders) {
        print('   - ID: ${folder.id}, Name: ${folder.name}');
      }
      setState(() {
        _folders = folders;
        _isLoadingFolders = false;
        if (_folders.isNotEmpty) {
          _selectedFolder = _folders.first;
          print('✅ Selected default folder: ${_selectedFolder!.name}');
        } else {
          print('⚠️ No folders available');
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingFolders = false;
      });
      print('❌ Error loading folders: $e');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading folders: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _woNameController.dispose();
    _arrowAnimationController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    setState(() {
      _isPickingFiles = true;
    });

    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
          'png',
          'jpg',
          'jpeg'
        ],
      );

      if (result != null) {
        setState(() {
          _selectedFiles.addAll(result.files);
          _isPickingFiles = false;
        });
      } else {
        setState(() {
          _isPickingFiles = false;
        });
      }
    } catch (e) {
      print('Error picking files: $e');
      setState(() {
        _isPickingFiles = false;
      });
    }
  }

  Future<void> _uploadFiles() async {
    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one file')),
      );
      return;
    }

    if (_selectedFolder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a folder')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // Convert files to base64
      List<Map<String, String>> filesData = [];
      for (var file in _selectedFiles) {
        if (file.path != null) {
          final bytes = await File(file.path!).readAsBytes();
          final base64Data = base64Encode(bytes);
          filesData.add({
            'file_name': file.name,
            'file_data': base64Data,
          });
        }
      }

      // Call API to upload files
      final token = SharedPref.getLoginData().result?.token;

      final response = await http.post(
        Uri.parse('https://erp.elrace.com/api/upload_project_attachments'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'params': {
            'project_id':
                widget.projectId.isNotEmpty ? int.parse(widget.projectId) : 0,
            'folder_id': _selectedFolder!.id,
            'files': filesData,
          },
        }),
      );

      print('📤 Upload response: ${response.body}');

      setState(() {
        _isUploading = false;
      });

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        if (decoded['result'] != null &&
            decoded['result']['status'] == 'success') {
          // Success
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ تم رفع ${_selectedFiles.length} ملف بنجاح'),
                backgroundColor: const Color(0xFF009859),
                duration: const Duration(seconds: 3),
              ),
            );
          }
          widget.onSuccess();
        } else {
          // API returned error
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    '❌ فشل الرفع: ${decoded['result']?['message'] ?? 'خطأ غير معروف'}'),
                backgroundColor: const Color(0xFFBA1719),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        // HTTP error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ خطأ في الاتصال: ${response.statusCode}'),
              backgroundColor: const Color(0xFFBA1719),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading files: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(20.r),
        ),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Close button
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 35.w,
                      height: 35.w,
                      decoration: const BoxDecoration(
                        color: Color(0xFFBA1719),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20.w,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // W.O Name field
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'W.O Name',
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD6D6D6), Color(0xFFADB2BD)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30.r),
                      border: Border.all(
                        color: const Color(0xFF000000),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _woNameController,
                      decoration: InputDecoration(
                        hintText: 'Alfouaa Police Station',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          color: Colors.grey[600],
                        ),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 9.h,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // Folder dropdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Folder',
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  _isLoadingFolders
                      ? Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFD6D6D6), Color(0xFFADB2BD)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: const Color(0xFF000000),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(30.r),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 20.w,
                            vertical: 9.h,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 16.w,
                                height: 16.w,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Text(
                                'Loading folders...',
                                style: GoogleFonts.poppins(
                                  fontSize: 14.sp,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFD6D6D6), Color(0xFFADB2BD)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(30.r),
                            border: Border.all(
                              color: const Color(0xFF000000),
                              width: 1,
                            ),
                          ),
                          child: DropdownButtonFormField<FolderModel>(
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 20.w,
                                vertical: 9.h,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                            initialValue: _selectedFolder,
                            hint: Text(
                              'Select folder',
                              style: GoogleFonts.poppins(
                                fontSize: 14.sp,
                                color: Colors.grey,
                              ),
                            ),
                            isExpanded: true,
                            items: _folders.isEmpty
                                ? null
                                : _folders
                                    .map((folder) => DropdownMenuItem(
                                          value: folder,
                                          child: Text(
                                            folder.name,
                                            style: GoogleFonts.poppins(
                                              fontSize: 14.sp,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ))
                                    .toList(),
                            onChanged: _folders.isEmpty
                                ? null
                                : (value) {
                                    print('📌 Folder selected: ${value?.name}');
                                    setState(() {
                                      _selectedFolder = value;
                                    });
                                  },
                          ),
                        ),
                ],
              ),
              SizedBox(height: 20.h),

              // Attach your file - Row with animated arrow and slide
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 30.w),
                child: Row(
                  children: [
                    // Animated arrow
                    AnimatedBuilder(
                      animation: _arrowScaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _arrowScaleAnimation.value,
                          child: Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.grey,
                            size: 28.w,
                          ),
                        );
                      },
                    ),

                    // Slide action
                    Expanded(
                      child: Container(
                        height: 50.h,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30.r),
                          border: Border.all(
                            color: const Color(0xFF000000),
                            width: 1,
                          ),
                        ),
                        child: SlideAction(
                          onSubmit: _pickFiles,
                          sliderButtonIcon: Icon(
                            Icons.attach_file,
                            color: Colors.white,
                            size: 25.w,
                          ),
                          sliderButtonIconPadding: 10,
                          text: _isPickingFiles
                              ? 'Loading...'
                              : '      Attach your file',
                          textStyle: GoogleFonts.poppins(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF9E9E9E),
                          ),
                          innerColor: const Color(0xFF151544),
                          outerColor: Colors.white,
                          sliderRotate: false,
                          borderRadius: 30.r,
                          elevation: 0,
                          animationDuration: const Duration(milliseconds: 100),
                          reversed: false,
                          submittedIcon: Icon(
                            Icons.attach_file,
                            color: Colors.white,
                            size: 20.w,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),

              // Number of attachments
              if (_selectedFiles.isNotEmpty)
                Text(
                  'No. of attachments ${_selectedFiles.length}',
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    color: Colors.grey,
                  ),
                ),
              SizedBox(height: 24.h),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBA1719),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 9.h),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _uploadFiles,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF009859),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 9.h),
                      ),
                      child: _isUploading
                          ? SizedBox(
                              width: 20.w,
                              height: 20.w,
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Submit',
                              style: GoogleFonts.poppins(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
