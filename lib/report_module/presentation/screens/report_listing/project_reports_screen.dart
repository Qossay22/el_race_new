import 'dart:ui';
import 'dart:io';
import 'dart:typed_data';

import 'package:el_race/report_module/core/utils/directory_operation.dart';
import 'package:el_race/report_module/data/models/folder_model.dart';
import 'package:el_race/report_module/data/models/report_model.dart';
import 'package:el_race/report_module/data/models/report_detail_model.dart';
import 'package:el_race/report_module/data/models/report_item_model.dart';
import 'package:el_race/report_module/data/provider/reports_provider.dart';
import 'package:el_race/report_module/data/repositories/company_repository.dart';
import 'package:el_race/report_module/presentation/screens/report_detail/report_detail.dart';
import 'package:el_race/report_module/presentation/screens/add_report_photos/add_report_photos_screen.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:el_race/report_module/presentation/screens/report_detail/image_editing_screen.dart';
import 'package:el_race/report_module/data/services/pdf_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:el_race/report_module/presentation/screens/report_photos/report_photos_screen.dart';
import 'package:el_race/report_module/presentation/dialogs/rename_report_dialog.dart';
import 'package:el_race/report_module/presentation/screens/report_detail/pdf_history_screen.dart';

class ProjectReportsScreen extends StatefulWidget {
  final FolderModel? folder;

  const ProjectReportsScreen({super.key, this.folder});

  @override
  State<ProjectReportsScreen> createState() => _ProjectReportsScreenState();
}

class _ProjectReportsScreenState extends State<ProjectReportsScreen> {
  bool _isLoading = true;
  String _searchQuery = '';
  bool _isCameraButtonExpanded = false;
  List<ReportModel> _reports = [];
  bool _isScrolled = false;
  FolderModel? _folder;

  Future<void> _showTakePicturesDialog() async {
    final TextEditingController reportNameController = TextEditingController();
    final outerContext = context;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: EdgeInsets.symmetric(horizontal: 10.w),
              backgroundColor: Colors.transparent,
              child: Container(
                width: 1.sw,
                padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 16.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(22.r),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(dialogContext),
                        child: Container(
                          width: 30.w,
                          height: 30.w,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE81E25),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close,
                              color: Colors.white, size: 18.w),
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    _DialogTextFieldCard(
                      topLabel: 'Report',
                      title: 'Title',
                      controller: reportNameController,
                      hint: 'Enter report name',
                    ),
                    SizedBox(height: 16.h),
                    SizedBox(
                      width: double.infinity,
                      height: 47.h,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          // Validate report name
                          if (reportNameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(outerContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Please enter report name',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13.sp,
                                    color: Colors.white,
                                  ),
                                ),
                                backgroundColor: const Color(0xFFE81E25),
                                behavior: SnackBarBehavior.floating,
                                margin: EdgeInsets.all(16.w),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                              ),
                            );
                            return;
                          }

                          try {
                            // Close dialog immediately
                            Navigator.pop(dialogContext);
                            if (mounted) {
                              final now = DateTime.now();
                              Navigator.push(
                                outerContext,
                                MaterialPageRoute(
                                  builder: (context) => ReportPhotosScreen(
                                    report: ReportModel(
                                      id: 'draft-${now.millisecondsSinceEpoch}',
                                      name: reportNameController.text.trim(),
                                      companyId: '',
                                      folderId: _folder!.id,
                                      createdAt: now,
                                      updatedAt: now,
                                    ),
                                    folderName: _folder?.name ?? '',
                                    folderId: _folder?.id ?? '',
                                    createReportOnFirstImage: true,
                                    onReportUpdated: () async {
                                      await _loadReports();
                                    },
                                  ),
                                ),
                              );
                            }
                          } catch (_) {
                            if (mounted) {
                              ScaffoldMessenger.of(outerContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to create report. Please try again',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13.sp,
                                      color: Colors.white,
                                    ),
                                  ),
                                  backgroundColor: const Color(0xFFE81E25),
                                  behavior: SnackBarBehavior.floating,
                                  margin: EdgeInsets.all(16.w),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: const Color(0xFF27304E),
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15.r),
                          ),
                        ),
                        icon: SvgPicture.asset(
                          'assets/svg/camera_svgrepo.svg',
                          width: 30.w,
                          height: 30.w,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                        label: Text(
                          'Start',
                          style: GoogleFonts.poppins(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
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

  @override
  void initState() {
    super.initState();
    _folder = widget.folder;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReports());
  }

  Future<void> _loadReports() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<ReportProvider>(context, listen: false);
      // If no folder was passed in, fetch the first available folder
      if (_folder == null) {
        await CompanyRepository().getCompany();
        await provider.init(base: "https://erp.elrace.com");
        await provider.fetchAllFolders();
        if (!mounted) return;
        if (provider.folders.isEmpty) {
          setState(() => _isLoading = false);
          return;
        }
        _folder = provider.folders.first;
      }
      await provider.fetchAllReports(folderID: _folder!.id);
      if (!mounted) return;
      setState(() {
        _reports = provider.reports;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteReport(ReportModel report) async {
    try {
      final provider = Provider.of<ReportProvider>(context, listen: false);
      await provider.deleteReport(reportId: report.id);
      await _loadReports();
    } catch (e) {
      debugPrint('Error deleting report: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredReports = _reports.where((r) {
      if (_searchQuery.isEmpty) return true;
      return r.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return GestureDetector(
      onTap: () {
        if (_isCameraButtonExpanded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted)
              setState(() {
                _isCameraButtonExpanded = false;
              });
          });
        }
      },
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F2F2),
        appBar: const HeaderWidget(),
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (scrollNotification) {
                  if (scrollNotification is ScrollUpdateNotification ||
                      scrollNotification is ScrollEndNotification) {
                    final isScrolled = scrollNotification.metrics.pixels > 10;
                    if (isScrolled != _isScrolled && mounted) {
                      setState(() => _isScrolled = isScrolled);
                    }
                  }
                  return false;
                },
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: SizedBox(height: 146.h)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(left: 22.w, right: 4.w),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Reports',
                                style: GoogleFonts.poppins(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF787B87),
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                if (!_isCameraButtonExpanded) {
                                  // First tap: just expand the button
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    if (mounted)
                                      setState(() {
                                        _isCameraButtonExpanded = true;
                                      });
                                  });
                                } else {
                                  // Second tap (when already expanded): show first dialog
                                  _showTakePicturesDialog();
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutCubic,
                                width: _isCameraButtonExpanded ? 145.w : 41.w,
                                height: 35.w,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF27304E),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(20.r),
                                    bottomLeft: Radius.circular(20.r),
                                  ),
                                ),
                                padding: EdgeInsets.symmetric(horizontal: 13.w),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    SvgPicture.asset(
                                      'assets/svg/report-details-add-icon.svg',
                                      width: 20.w,
                                      height: 20.w,
                                      colorFilter: const ColorFilter.mode(
                                        Colors.white,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                    Expanded(
                                      child: ClipRect(
                                        child: AnimatedAlign(
                                          duration:
                                              const Duration(milliseconds: 260),
                                          curve: Curves.easeOutCubic,
                                          alignment: Alignment.centerLeft,
                                          widthFactor:
                                              _isCameraButtonExpanded ? 1 : 0,
                                          child: Padding(
                                            padding: EdgeInsetsDirectional.only(
                                                start: 4.w),
                                            child: Text(
                                              'New Report',
                                              maxLines: null,
                                              overflow: TextOverflow.clip,
                                              style: GoogleFonts.poppins(
                                                fontSize: 13.sp,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 10.h)),
                    if (_isLoading)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      SliverReorderableList(
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final item = _reports.removeAt(oldIndex);
                            _reports.insert(newIndex, item);
                          });
                        },
                        itemCount: filteredReports.length,
                        itemBuilder: (context, index) {
                          final report = filteredReports[index];
                          return Padding(
                            key: ValueKey(report.id),
                            padding: EdgeInsets.only(left: 12.w, right: 12.w),
                            child: _ProjectReportCard(
                              index: index,
                              report: report,
                              folderName: _folder?.name ?? '',
                              folderId: _folder?.id ?? '',
                              onReportUpdated: () async {
                                await _loadReports();
                              },
                              onDeleteReport: () async {
                                await _deleteReport(report);
                              },
                            ),
                          );
                        },
                      ),
                    SliverToBoxAdapter(child: SizedBox(height: 16.h)),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: _isScrolled ? 15 : 8,
                      sigmaY: _isScrolled ? 15 : 8,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.only(top: 10.h, bottom: 12.h),
                      decoration: BoxDecoration(
                        color: _isScrolled
                            ? Colors.white.withOpacity(0.55)
                            : Colors.white.withOpacity(0.30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          SizedBox(height: 10.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/newapp/report_svgrepo.com.png',
                                width: 24.w,
                                height: 24.w,
                                fit: BoxFit.contain,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                'Reports',
                                style: GoogleFonts.poppins(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF202020),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w),
                            child: Container(
                              height: 52.h,
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F4F4),
                                borderRadius: BorderRadius.circular(28.r),
                                border: Border.all(
                                  color: const Color(0xFFB9BBC3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      onChanged: (value) {
                                        setState(() => _searchQuery = value);
                                      },
                                      style: GoogleFonts.poppins(
                                        fontSize: 16.sp,
                                        color: const Color(0xFF22263A),
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Search',
                                        border: InputBorder.none,
                                        hintStyle: GoogleFonts.poppins(
                                          fontSize: 16.sp,
                                          color: const Color(0xFFA3A6B1),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.search,
                                    size: 22.w,
                                    color: const Color(0xFFA3A6B1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogTextFieldCard extends StatelessWidget {
  final String topLabel;
  final String title;
  final TextEditingController controller;
  final String hint;

  const _DialogTextFieldCard({
    required this.topLabel,
    required this.title,
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFB9BBC3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            topLabel,
            style: GoogleFonts.poppins(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6A6D78),
            ),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF151A36),
            ),
          ),
          SizedBox(height: 8.h),
          Container(
            height: 40.h,
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            decoration: BoxDecoration(
              color: const Color(0xFFEFEFEF),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: const Color(0xFFCFCFCF), width: 1),
            ),
            child: TextField(
              controller: controller,
              style: GoogleFonts.poppins(
                fontSize: 11.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF272A36),
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: GoogleFonts.poppins(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFA2A4AA),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 10.h),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogDropdownCard extends StatefulWidget {
  final String topLabel;
  final String title;
  final String? value;
  final String hint;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DialogDropdownCard({
    required this.topLabel,
    required this.title,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  State<_DialogDropdownCard> createState() => _DialogDropdownCardState();
}

class _DialogDropdownCardState extends State<_DialogDropdownCard> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFB9BBC3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.topLabel,
            style: GoogleFonts.poppins(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6A6D78),
            ),
          ),
          Text(
            widget.title,
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF151A36),
            ),
          ),
          SizedBox(height: 8.h),
          // Trigger row
          GestureDetector(
            onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _isOpen = !_isOpen);
            }),
            child: Container(
              height: 40.h,
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              decoration: BoxDecoration(
                color: const Color(0xFFEFEFEF),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20.r),
                  topRight: Radius.circular(20.r),
                  bottomLeft: _isOpen ? Radius.zero : Radius.circular(20.r),
                  bottomRight: _isOpen ? Radius.zero : Radius.circular(20.r),
                ),
                border: Border.all(color: const Color(0xFFCFCFCF), width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.value != null &&
                              widget.items.contains(widget.value)
                          ? widget.value!
                          : widget.hint,
                      style: GoogleFonts.poppins(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: widget.value != null &&
                                widget.items.contains(widget.value)
                            ? const Color(0xFF272A36)
                            : const Color(0xFFA2A4AA),
                      ),
                      overflow: TextOverflow.visible,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.arrow_drop_down,
                      size: 20.w,
                      color: const Color(0xFF272A36),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Inline expanded list
          if (_isOpen)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEFEFEF),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12.r),
                  bottomRight: Radius.circular(12.r),
                ),
                border: Border(
                  left: BorderSide(color: const Color(0xFFCFCFCF), width: 1),
                  right: BorderSide(color: const Color(0xFFCFCFCF), width: 1),
                  bottom: BorderSide(color: const Color(0xFFCFCFCF), width: 1),
                ),
              ),
              child: Column(
                children: widget.items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isLast = index == widget.items.length - 1;
                  return Column(
                    children: [
                      if (index == 0)
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: const Color(0xFFCFCFCF),
                        ),
                      InkWell(
                        onTap: () {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() => _isOpen = false);
                          });
                          widget.onChanged(item);
                        },
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                              horizontal: 14.w, vertical: 11.h),
                          child: Text(
                            item,
                            style: GoogleFonts.poppins(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF272A36),
                            ),
                          ),
                        ),
                      ),
                      if (!isLast)
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: const Color(0xFFCFCFCF),
                          indent: 14.w,
                          endIndent: 14.w,
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProjectReportCard extends StatefulWidget {
  final int index;
  final ReportModel report;
  final String folderName;
  final String folderId;
  final VoidCallback? onReportUpdated;
  final VoidCallback? onDeleteReport;

  const _ProjectReportCard({
    required this.index,
    required this.report,
    required this.folderName,
    required this.folderId,
    this.onReportUpdated,
    this.onDeleteReport,
  });

  @override
  State<_ProjectReportCard> createState() => _ProjectReportCardState();
}

class _ProjectReportCardState extends State<_ProjectReportCard> {
  bool _isSharing = false;
  late Future<ReportDetailModel?> _reportDetailFuture;

  @override
  void initState() {
    super.initState();
    _reportDetailFuture = Provider.of<ReportProvider>(context, listen: false)
        .fetchReportDetailFromApi(widget.report.id);
  }

  Future<void> _openPdfScreen() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final provider = Provider.of<ReportProvider>(context, listen: false);
      final reportDetail =
          await provider.fetchReportDetailFromApi(widget.report.id);
      if (reportDetail == null) {
        if (mounted) setState(() => _isSharing = false);
        return;
      }
      if (mounted) {
        setState(() => _isSharing = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfGenerationPage(
              reportId: widget.report.id,
              folderId: widget.folderId,
              folderName: widget.folderName,
              reportItemsCount: reportDetail.reportItems.length,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error opening PDF screen: \$e');
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReportPhotosScreen(
                report: widget.report,
                folderName: widget.folderName,
                folderId: widget.folderId,
                onReportUpdated: widget.onReportUpdated,
              ),
            ),
          );
        });
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: EdgeInsets.only(bottom: 10.h),
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.r),
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(color: const Color(0xFF2C3454), width: 1),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(18.w, 0, 0, 12.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 14.h),
                        Text(
                          widget.report.name.isEmpty
                              ? 'Report Name'
                              : widget.report.name,
                          style: GoogleFonts.poppins(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF27304E),
                          ),
                          maxLines: null,
                          overflow: TextOverflow.visible,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          widget.report.reportType ??
                              DateFormat('dd MMM yyyy')
                                  .format(widget.report.createdAt),
                          style: GoogleFonts.poppins(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF27304E),
                          ),
                          maxLines: null,
                          overflow: TextOverflow.visible,
                        ),
                        SizedBox(height: 14.h),
                        FutureBuilder<ReportDetailModel?>(
                          future: _reportDetailFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return SizedBox(
                                height: 30.w,
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 16.w,
                                      height: 16.w,
                                      child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF9CA3AF)),
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      'Loading...',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              debugPrint(
                                  '❌ Card FutureBuilder error: ${snapshot.error}');
                              return Text(
                                'Error loading',
                                style: GoogleFonts.poppins(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFFE81E25),
                                ),
                              );
                            }

                            if (!snapshot.hasData ||
                                snapshot.data == null ||
                                snapshot.data!.reportItems.isEmpty) {
                              return Text(
                                'No images',
                                style: GoogleFonts.poppins(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF9CA3AF),
                                ),
                              );
                            }

                            final items = snapshot.data!.reportItems
                                .where((item) => item.image.isNotEmpty)
                                .toList();
                            if (items.isEmpty) {
                              return Text(
                                'No images',
                                style: GoogleFonts.poppins(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF9CA3AF),
                                ),
                              );
                            }

                            final displayCount =
                                items.length > 5 ? 5 : items.length;
                            final remaining = items.length - displayCount;

                            return Row(
                              children: [
                                ...List.generate(displayCount, (index) {
                                  final imageUrl = items[index].image;
                                  final isNetworkImage =
                                      imageUrl.startsWith('http');
                                  return Padding(
                                    padding: EdgeInsets.only(right: 4.w),
                                    child: Container(
                                      width: 30.w,
                                      height: 30.w,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: const Color(0xFF2C3454),
                                            width: 1),
                                      ),
                                      child: ClipOval(
                                        child: isNetworkImage
                                            ? Image.network(
                                                imageUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  return Container(
                                                    color:
                                                        const Color(0xFFE5E7EB),
                                                    child: Icon(Icons.image,
                                                        size: 16.w,
                                                        color: const Color(
                                                            0xFF9CA3AF)),
                                                  );
                                                },
                                              )
                                            : Image.file(
                                                File(imageUrl),
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  return Container(
                                                    color:
                                                        const Color(0xFFE5E7EB),
                                                    child: Icon(Icons.image,
                                                        size: 16.w,
                                                        color: const Color(
                                                            0xFF9CA3AF)),
                                                  );
                                                },
                                              ),
                                      ),
                                    ),
                                  );
                                }),
                                if (remaining > 0) ...[
                                  SizedBox(width: 4.w),
                                  Text(
                                    '+$remaining',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF27304E),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 164.w,
                    height: 90.h,
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        // Chart image
                        Positioned(
                          top: 0.h,
                          right: 0,
                          child: SizedBox(
                            width: 164.w,
                            height: 90.h,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8.r),
                              child: Image.asset(
                                'assets/png/r2.png',
                                fit: BoxFit.cover,
                                alignment: Alignment.topRight,
                              ),
                            ),
                          ),
                        ),
                        // Icons without background
                        Positioned(
                            top: 4.h,
                            right: 10.w,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Theme(
                                  data: Theme.of(context).copyWith(
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: const VisualDensity(
                                        horizontal: -4, vertical: -4),
                                  ),
                                  child: PopupMenuButton<String>(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    splashRadius: 16,
                                    icon: Icon(
                                      Icons.more_vert,
                                      size: 22.w,
                                      color: const Color(0xFF27304E),
                                    ),
                                    onSelected: (value) async {
                                      if (value == 'rename') {
                                        await showRenameReport(
                                          context,
                                          report: widget.report,
                                        );
                                        widget.onReportUpdated?.call();
                                      } else if (value == 'delete') {
                                        final confirmed =
                                            await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16.r),
                                            ),
                                            title: Text(
                                              'Delete Report',
                                              style: GoogleFonts.poppins(
                                                fontSize: 18.sp,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF27304E),
                                              ),
                                            ),
                                            content: Text(
                                              'Are you sure you want to delete this report?',
                                              style: GoogleFonts.poppins(
                                                fontSize: 14.sp,
                                                color: const Color(0xFF27304E),
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child: Text(
                                                  'Cancel',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 14.sp,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        const Color(0xFF27304E),
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                child: Text(
                                                  'Delete',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 14.sp,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        const Color(0xFFE81E25),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirmed == true) {
                                          final provider =
                                              Provider.of<ReportProvider>(
                                                  context,
                                                  listen: false);
                                          await provider.deleteReport(
                                              reportId: widget.report.id);
                                          widget.onReportUpdated?.call();
                                        }
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem<String>(
                                        value: 'rename',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit_outlined,
                                                size: 20.w,
                                                color: const Color(0xFF27304E)),
                                            SizedBox(width: 8.w),
                                            Text(
                                              'Rename',
                                              style: GoogleFonts.poppins(
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w500,
                                                color: const Color(0xFF27304E),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline,
                                                size: 20.w,
                                                color: const Color(0xFFE81E25)),
                                            SizedBox(width: 8.w),
                                            Text(
                                              'Delete',
                                              style: GoogleFonts.poppins(
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w500,
                                                color: const Color(0xFFE81E25),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 0.5.w),
                                ReorderableDragStartListener(
                                  index: widget.index,
                                  child: Icon(
                                    Icons.list,
                                    size: 22.w,
                                    color: const Color(0xFF27304E),
                                  ),
                                ),
                              ],
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Share button - bottom right
          Positioned(
            bottom: 18.h,
            right: 14.w,
            child: GestureDetector(
              onTap: _openPdfScreen,
              child: Container(
                width: 24.w,
                height: 24.w,
                decoration: const BoxDecoration(
                  color: Color(0xFF27304E),
                  shape: BoxShape.circle,
                ),
                child: _isSharing
                    ? Padding(
                        padding: EdgeInsets.all(5.w),
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        Icons.share,
                        size: 12.w,
                        color: Colors.white,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportPhotosDialog extends StatefulWidget {
  final String reportName;
  final String reportType;
  final bool isEditing;
  final String? folderId;
  final ReportModel? report;
  final VoidCallback? onReportCreated;

  const _ReportPhotosDialog({
    required this.reportName,
    required this.reportType,
    required this.isEditing,
    this.folderId,
    this.report,
    this.onReportCreated,
  });

  @override
  State<_ReportPhotosDialog> createState() => _ReportPhotosDialogState();
}

class _ReportPhotosDialogState extends State<_ReportPhotosDialog> {
  final List<_PhotoItem> _photoItems = [
    _PhotoItem()
  ]; // Initialize with one item to avoid RangeError
  int _currentIndex = 0;
  final ImagePicker _picker = ImagePicker();
  bool _showValidationError = false;
  bool _isUploading = false;
  bool _isLoadingItems = false;
  String? _uploadErrorMessage;

  @override
  void initState() {
    super.initState();
    _loadExistingItems();
  }

  Future<void> _loadExistingItems() async {
    if (widget.report != null) {
      setState(() => _isLoadingItems = true);
      try {
        final provider = Provider.of<ReportProvider>(context, listen: false);
        debugPrint('🔍 Loading report detail for ID: ${widget.report!.id}');
        final detail =
            await provider.fetchReportDetailFromApi(widget.report!.id);
        debugPrint(
            '🔍 Report detail result: ${detail != null ? 'Found ${detail.reportItems.length} items' : 'null'}');
        if (detail != null && detail.reportItems.isNotEmpty) {
          if (mounted) {
            setState(() {
              _photoItems.clear();
              for (final item in detail.reportItems) {
                debugPrint(
                    '🔍 Item: id=${item.id}, image=${item.image}, location=${item.location}');
                final photoItem = _PhotoItem();
                photoItem.itemId = item.id;
                photoItem.imagePath = item.image.isNotEmpty ? item.image : null;
                photoItem.location =
                    item.location.isNotEmpty ? item.location : null;
                photoItem.locationController.text = item.location;
                photoItem.description = item.description;
                photoItem.descriptionController.text = item.description;
                _photoItems.add(photoItem);
              }
              if (_photoItems.isEmpty) {
                _photoItems.add(_PhotoItem());
              }
              _isLoadingItems = false;
            });
          }
          return;
        }
      } catch (e) {
        debugPrint('❌ Error loading existing items: $e');
      }
      if (mounted) {
        setState(() => _isLoadingItems = false);
      }
    }
  }

  Future<void> _showImageSourceDialog() async {
    await showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: SizedBox(
          width: 200.w,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 16.w),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1B1F26), Color(0xFF1A1A53)],
                stops: [0.72, 1.0],
              ),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.camera);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          'assets/svg/camera_svgrepo.svg',
                          width: 36.sp,
                          height: 36.sp,
                          colorFilter: const ColorFilter.mode(
                              Colors.white, BlendMode.srcIn),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Camera',
                          style: GoogleFonts.poppins(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.gallery);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          'assets/svg/gallery_svgrepo.svg',
                          width: 36.sp,
                          height: 36.sp,
                          colorFilter: const ColorFilter.mode(
                              Colors.white, BlendMode.srcIn),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Gallery',
                          style: GoogleFonts.poppins(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.gallery) {
      // Match old module: gallery pick with quality 60
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 60,
      );
      if (image != null) {
        // Save to app storage like old module
        final folderId = widget.folderId ?? '';
        final savedPath = await saveImageToAppStorage(
          File(image.path),
          folderId + folderId, // Same pattern as old module
        );
        if (savedPath.isNotEmpty) {
          setState(() {
            _photoItems[_currentIndex].imagePath = savedPath;
          });
        }
      }
    } else {
      // Camera capture
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        final folderId = widget.folderId ?? '';
        final savedPath = await saveImageToAppStorage(
          File(image.path),
          folderId + folderId,
        );
        if (savedPath.isNotEmpty) {
          setState(() {
            _photoItems[_currentIndex].imagePath = savedPath;
          });
        }
      }
    }
  }

  void _addNewPhotoItem() {
    final currentItem = _photoItems[_currentIndex];

    // Check if current item has all required data
    if (currentItem.imagePath == null) {
      _showImageSourceDialog();
      return;
    }

    if (currentItem.description.isEmpty || currentItem.location == null) {
      // Show error message inside dialog
      setState(() {
        _showValidationError = true;
      });
      // Hide error after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showValidationError = false;
          });
        }
      });
      return;
    }

    // All data is filled, create new item
    setState(() {
      _showValidationError = false;
      _photoItems.add(_PhotoItem());
      _currentIndex = _photoItems.length - 1;
    });
  }

  void _deleteCurrentImage() {
    setState(() {
      _photoItems[_currentIndex].imagePath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = _photoItems[_currentIndex];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 40.h),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with buttons
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Add Pictures Button
                  ElevatedButton.icon(
                    onPressed: () {
                      _addNewPhotoItem();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF27304E),
                      padding: EdgeInsets.symmetric(
                          horizontal: 16.w, vertical: 10.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    icon:
                        Icon(Icons.camera_alt, size: 18.w, color: Colors.white),
                    label: Text(
                      'Add Pictures',
                      style: GoogleFonts.poppins(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // Close Button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32.w,
                      height: 32.w,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE81E25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, color: Colors.white, size: 18.w),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  children: [
                    // Image Container
                    GestureDetector(
                      onTap: currentItem.imagePath == null
                          ? _showImageSourceDialog
                          : null,
                      child: Container(
                        width: double.infinity,
                        height: 200.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                              color: const Color(0xFFE0E0E0), width: 1),
                        ),
                        child: currentItem.imagePath == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 50.w,
                                    color: const Color(0xFFB0B0B0),
                                  ),
                                  SizedBox(height: 8.h),
                                  Text(
                                    'Tap to add photo',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.sp,
                                      color: const Color(0xFFB0B0B0),
                                    ),
                                  ),
                                ],
                              )
                            : Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16.r),
                                    child: currentItem.imagePath!
                                            .startsWith('http')
                                        ? Image.network(
                                            currentItem.imagePath!,
                                            width: double.infinity,
                                            height: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Center(
                                                child: Icon(Icons.broken_image,
                                                    size: 50.w,
                                                    color: const Color(
                                                        0xFFB0B0B0)),
                                              );
                                            },
                                          )
                                        : Image.file(
                                            File(currentItem.imagePath!),
                                            width: double.infinity,
                                            height: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                  // Icons on top right
                                  Positioned(
                                    top: 8.h,
                                    right: 8.w,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 32.w,
                                          height: 32.w,
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.9),
                                            shape: BoxShape.circle,
                                          ),
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            icon: Icon(
                                              Icons.camera_alt_outlined,
                                              color: const Color(0xFF6A6D78),
                                              size: 16.w,
                                            ),
                                            onPressed: _showImageSourceDialog,
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Container(
                                          width: 32.w,
                                          height: 32.w,
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.9),
                                            borderRadius:
                                                BorderRadius.circular(8.r),
                                          ),
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            icon: Image.asset(
                                              'assets/png/edit.png',
                                              width: 18.w,
                                              height: 18.w,
                                              color: const Color(0xFF6A6D78),
                                            ),
                                            onPressed: () async {
                                              if (currentItem.imagePath == null)
                                                return;
                                              // Only allow drawing on local files
                                              String filePath =
                                                  currentItem.imagePath!;
                                              if (filePath.startsWith('http')) {
                                                // Download to temp file first
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                      content: Text(
                                                          'Please re-take the photo to edit it')),
                                                );
                                                return;
                                              }
                                              final result = await Navigator
                                                  .push<Uint8List>(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      ImageEditingScreen(
                                                          image: filePath),
                                                ),
                                              );
                                              if (result != null && mounted) {
                                                // Save edited image to a new path to avoid cache
                                                final dir =
                                                    File(filePath).parent.path;
                                                final newPath =
                                                    '$dir/edited_${DateTime.now().millisecondsSinceEpoch}.jpg';
                                                await File(newPath)
                                                    .writeAsBytes(result);
                                                // Clear image cache to force reload
                                                imageCache.clear();
                                                imageCache.clearLiveImages();
                                                setState(() {
                                                  currentItem.imagePath =
                                                      newPath;
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Delete button (X) on top left
                                  Positioned(
                                    top: 8.h,
                                    left: 8.w,
                                    child: Container(
                                      width: 32.w,
                                      height: 32.w,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE81E25)
                                            .withOpacity(0.9),
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        icon: Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 16.w,
                                        ),
                                        onPressed: _deleteCurrentImage,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    SizedBox(height: 16.h),

                    // Location Dropdown
                    _buildLocationCard(currentItem),

                    SizedBox(height: 16.h),

                    // Description Field
                    _buildDescriptionCard(currentItem),

                    SizedBox(height: 20.h),

                    // Navigation arrows (if more than 1 item)
                    if (_photoItems.length > 1)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: _currentIndex > 0
                                ? () => WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      if (mounted)
                                        setState(() => _currentIndex--);
                                    })
                                : null,
                            icon: Icon(
                              Icons.arrow_back_ios,
                              size: 20.w,
                              color: _currentIndex > 0
                                  ? const Color(0xFF27304E)
                                  : const Color(0xFFD0D0D0),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            'Items no ${_currentIndex + 1}/${_photoItems.length}',
                            style: GoogleFonts.poppins(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF6A6D78),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          IconButton(
                            onPressed: _currentIndex < _photoItems.length - 1
                                ? () => WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      if (mounted)
                                        setState(() => _currentIndex++);
                                    })
                                : null,
                            icon: Icon(
                              Icons.arrow_forward_ios,
                              size: 20.w,
                              color: _currentIndex < _photoItems.length - 1
                                  ? const Color(0xFF27304E)
                                  : const Color(0xFFD0D0D0),
                            ),
                          ),
                        ],
                      ),

                    SizedBox(height: 20.h),

                    // Validation Error Message
                    if (_showValidationError)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12.w),
                        margin: EdgeInsets.only(bottom: 16.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE81E25),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          widget.isEditing
                              ? 'Failed to create report. Please try again'
                              : 'Please fill all data (Image, Location, Description) before adding new item',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),

                    // Upload Error Message (inline)
                    if (_uploadErrorMessage != null)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12.w),
                        margin: EdgeInsets.only(bottom: 16.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE81E25),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          _uploadErrorMessage!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),

                    // Submit/Edit or Generate Report Button
                    if (!widget.isEditing)
                      SizedBox(
                        width: double.infinity,
                        height: 48.h,
                        child: ElevatedButton(
                          onPressed: _isUploading
                              ? null
                              : () async {
                                  // Save edited photo items via API
                                  if (widget.report != null) {
                                    setState(() => _isUploading = true);
                                    final provider =
                                        Provider.of<ReportProvider>(context,
                                            listen: false);
                                    bool allSuccess = true;

                                    for (int i = 0;
                                        i < _photoItems.length;
                                        i++) {
                                      final photoItem = _photoItems[i];
                                      if (photoItem.imagePath != null &&
                                          photoItem.imagePath!.isNotEmpty) {
                                        final isNetworkUrl = photoItem
                                            .imagePath!
                                            .startsWith('http');
                                        if (photoItem.itemId != null) {
                                          final result =
                                              await provider.updateReportItem(
                                            reportId: widget.report!.id,
                                            itemId: photoItem.itemId!,
                                            location: photoItem.location ?? '',
                                            description: photoItem.description,
                                            imageFile: isNetworkUrl
                                                ? null
                                                : File(photoItem.imagePath!),
                                            index: i,
                                          );
                                          if (result == null)
                                            allSuccess = false;
                                        } else if (!isNetworkUrl) {
                                          final result =
                                              await provider.addReportItem(
                                            reportId: widget.report!.id,
                                            imageFile:
                                                File(photoItem.imagePath!),
                                            location: photoItem.location ?? '',
                                            description: photoItem.description,
                                            index: i,
                                          );
                                          if (result == null)
                                            allSuccess = false;
                                        }
                                      }
                                    }

                                    setState(() => _isUploading = false);

                                    if (allSuccess) {
                                      if (widget.onReportCreated != null) {
                                        widget.onReportCreated!();
                                      }
                                      Navigator.pop(context);
                                    } else {
                                      setState(() {
                                        _uploadErrorMessage =
                                            'Failed to upload some items. Please try again.';
                                      });
                                      Future.delayed(const Duration(seconds: 4),
                                          () {
                                        if (mounted) {
                                          setState(
                                              () => _uploadErrorMessage = null);
                                        }
                                      });
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF27304E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                          ),
                          child: _isUploading
                              ? SizedBox(
                                  width: 24.w,
                                  height: 24.w,
                                  child: const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Submit',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    if (widget.isEditing)
                      SizedBox(
                        width: double.infinity,
                        height: 48.h,
                        child: ElevatedButton(
                          onPressed: _isUploading
                              ? null
                              : () async {
                                  // Create report via API
                                  try {
                                    setState(() => _isUploading = true);
                                    final provider =
                                        Provider.of<ReportProvider>(context,
                                            listen: false);
                                    await provider.createReport(
                                      title: widget.reportName,
                                      folderID: widget.folderId!,
                                    );

                                    // Upload photo items to server via API
                                    final createdReport =
                                        provider.reports.first;
                                    for (int i = 0;
                                        i < _photoItems.length;
                                        i++) {
                                      final photoItem = _photoItems[i];
                                      if (photoItem.imagePath != null &&
                                          photoItem.imagePath!.isNotEmpty) {
                                        await provider.addReportItem(
                                          reportId: createdReport.id,
                                          imageFile: File(photoItem.imagePath!),
                                          location: photoItem.location ?? '',
                                          description: photoItem.description,
                                          index: i,
                                        );
                                      }
                                    }

                                    setState(() => _isUploading = false);

                                    // Call callback to reload reports
                                    if (widget.onReportCreated != null) {
                                      widget.onReportCreated!();
                                    }

                                    Navigator.pop(context);
                                  } catch (e) {
                                    // Show error inside dialog
                                    setState(() {
                                      _isUploading = false;
                                      _uploadErrorMessage =
                                          'Failed to create report. Please try again.';
                                    });
                                    Future.delayed(const Duration(seconds: 4),
                                        () {
                                      if (mounted) {
                                        setState(
                                            () => _uploadErrorMessage = null);
                                      }
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF27304E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                          ),
                          child: _isUploading
                              ? SizedBox(
                                  width: 24.w,
                                  height: 24.w,
                                  child: const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Generate Report',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),

                    SizedBox(height: 16.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(_PhotoItem item) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Location',
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF272A36),
            ),
          ),
          SizedBox(height: 10.h),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
            ),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            child: TextField(
              controller: item.locationController,
              onChanged: (v) => item.location = v,
              style: GoogleFonts.poppins(
                  fontSize: 13.sp, color: const Color(0xFF272A36)),
              decoration: InputDecoration(
                hintText: 'Enter location...',
                hintStyle: GoogleFonts.poppins(
                    fontSize: 13.sp, color: const Color(0xFFB0B0B0)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(_PhotoItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with label and icons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Description',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              Row(
                children: [
                  _buildParagraphIconButton(
                    () => _formatAlignLeft(item),
                    isActive: item.listMode == 'paragraph',
                  ),
                  const SizedBox(width: 8),
                  _buildIconButton(
                    Icons.format_list_bulleted,
                    () => _formatBulletList(item),
                    isActive: item.listMode == 'bullet',
                  ),
                  const SizedBox(width: 8),
                  _buildIconButton(
                    Icons.format_list_numbered,
                    () => _formatNumberedList(item),
                    isActive: item.listMode == 'numbered',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Text field
          TextField(
            controller: item.descriptionController,
            maxLines: 5,
            onChanged: (value) => _handleDescriptionChange(value, item),
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'Enter description...',
              hintStyle: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[400],
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap,
      {bool isActive = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isActive ? Colors.black87 : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isActive ? Colors.white : Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildParagraphIconButton(VoidCallback onTap,
      {bool isActive = false}) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Material(
        color: isActive ? Colors.black87 : Colors.white,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: ColorFiltered(
              colorFilter: isActive
                  ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
                  : const ColorFilter.mode(
                      Colors.transparent, BlendMode.srcOver),
              child: Image.asset('assets/png/paragraphIcon.png',
                  fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  void _formatAlignLeft(_PhotoItem item) {
    item.listMode = 'paragraph';

    final text = item.descriptionController.text;
    if (text.isEmpty) {
      setState(() {});
      return;
    }

    // Remove bullet/number prefixes from ALL lines
    final lines = text.split('\n');
    final cleanedLines = lines.map((line) {
      return line
          .replaceFirst(RegExp(r'^\s*•\s?'), '')
          .replaceFirst(RegExp(r'^\s*\d+\.\s?'), '');
    }).toList();

    final newText = cleanedLines.join('\n');
    if (newText != text) {
      final newCursor = newText.length.clamp(0, newText.length);
      item.descriptionController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursor),
      );
      item.description = newText;
    }

    setState(() {});
  }

  void _handleDescriptionChange(String value, _PhotoItem item) {
    item.description = value;
    if (!value.endsWith('\n')) return;
    if (item.listMode == 'paragraph') return;

    if (item.listMode == 'bullet') {
      final newText = '${value}• ';
      item.descriptionController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.fromPosition(
          TextPosition(offset: newText.length),
        ),
      );
      item.description = newText;
      return;
    }

    if (item.listMode == 'numbered') {
      final nextNumber = _getNextNumber(value);
      final newText = '$value$nextNumber. ';
      item.descriptionController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.fromPosition(
          TextPosition(offset: newText.length),
        ),
      );
      item.description = newText;
    }
  }

  void _formatBulletList(_PhotoItem item) {
    item.listMode = 'bullet';
    _insertPrefixForNewMode(item, prefix: '• ');
    setState(() {});
  }

  void _formatNumberedList(_PhotoItem item) {
    item.listMode = 'numbered';
    final nextNumber = _getNextNumber(item.descriptionController.text);
    _insertPrefixForNewMode(item, prefix: '$nextNumber. ');
    setState(() {});
  }

  int _getNextNumber(String text) {
    final matches = RegExp(r'^(\d+)\.\s', multiLine: true).allMatches(text);
    if (matches.isEmpty) return 1;
    final last = int.tryParse(matches.last.group(1) ?? '0') ?? 0;
    return last + 1;
  }

  void _insertPrefixForNewMode(_PhotoItem item, {required String prefix}) {
    final text = item.descriptionController.text;
    final selection = item.descriptionController.selection;
    final cursor = selection.isValid && selection.baseOffset >= 0
        ? selection.baseOffset
        : text.length;

    final before = text.substring(0, cursor);
    final after = text.substring(cursor);

    final needsNewLine = before.isNotEmpty && !before.endsWith('\n');
    final insertion = needsNewLine ? '\n$prefix' : prefix;
    final newText = '$before$insertion$after';

    item.descriptionController.value = TextEditingValue(
      text: newText,
      selection:
          TextSelection.collapsed(offset: before.length + insertion.length),
    );
    item.description = newText;
  }
}

class _PhotoItem {
  String? itemId; // Server-side ID for existing items
  String? imagePath;
  String? location;
  String description = '';
  String listMode = 'paragraph';
  final TextEditingController locationController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
}
