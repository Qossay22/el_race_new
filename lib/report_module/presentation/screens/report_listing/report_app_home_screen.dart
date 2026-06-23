import 'dart:ui';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:el_race/report_module/core/utils/flush_bar.dart';
import 'package:el_race/report_module/data/models/folder_model.dart';
import 'package:el_race/report_module/data/provider/reports_provider.dart';
import 'package:el_race/report_module/data/repositories/company_repository.dart';
import 'package:el_race/report_module/presentation/dialogs/add_report.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../widgets/folder_tile.dart';
import '../report_photos/report_photos_screen.dart';

class ReportAppHomeScreen extends StatefulWidget {
  const ReportAppHomeScreen({super.key});

  @override
  State<ReportAppHomeScreen> createState() => _ReportAppHomeScreenState();
}

class _ReportAppHomeScreenState extends State<ReportAppHomeScreen> {
  bool isLoading = true;
  String _searchQuery = '';
  bool _isCreateButtonExpanded = false;
  bool _isCreateButtonBusy = false;
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getData();
    });
  }

  getData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      await CompanyRepository().getCompany();
      final provider = Provider.of<ReportProvider>(context, listen: false);
      await provider.init(base: "https://erp.elrace.com");
      await provider.fetchAllFolders();
    } catch (e) {
      debugPrint('Error loading report folders: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _onCreateReportTap() async {
    if (_isCreateButtonBusy) {
      return;
    }

    if (!_isCreateButtonExpanded) {
      setState(() {
        _isCreateButtonExpanded = true;
      });
      return;
    }

    setState(() {
      _isCreateButtonBusy = true;
    });

    await showAddNewReport(context, type: 2);

    if (mounted) {
      await Provider.of<ReportProvider>(context, listen: false)
          .fetchAllFolders();
      setState(() {
        _isCreateButtonBusy = false;
      });
    }
  }

  Future<void> _openFolderPhotos(FolderModel folder) async {
    if (_isCreateButtonExpanded) {
      setState(() => _isCreateButtonExpanded = false);
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final provider = Provider.of<ReportProvider>(context, listen: false);
      final report = await provider.getOrCreateSingleReportForFolder(folder);

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (report == null) {
        showFlushBar(context,
            message: 'Failed to open report. Please try again');
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReportPhotosScreen(
            report: report,
            folderName: folder.name,
            folderId: folder.id,
            onReportUpdated: () async {
              await getData();
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error opening folder report photos: $e');
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      showFlushBar(context, message: 'Failed to open report. Please try again');
    }
  }

  @override
  Widget build(BuildContext context) {
    ReportProvider reportProviderListener =
        Provider.of<ReportProvider>(context);

    final filteredFolders = reportProviderListener.folders.where((folder) {
      if (_searchQuery.trim().isEmpty) {
        return true;
      }
      final query = _searchQuery.trim().toLowerCase();
      return folder.name.toLowerCase().contains(query) ||
          folder.description.toLowerCase().contains(query);
    }).toList();

    return GestureDetector(
      onTap: () {
        if (_isCreateButtonExpanded) {
          setState(() {
            _isCreateButtonExpanded = false;
          });
        }
      },
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F4F4),
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
                    SliverToBoxAdapter(child: SizedBox(height: 130.h)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(left: 20.w),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Reports',
                                style: GoogleFonts.poppins(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF878B98),
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: _onCreateReportTap,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutCubic,
                                width: _isCreateButtonExpanded ? 145.w : 41.w,
                                height: 35.w,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF27304E),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(20.r),
                                    bottomLeft: Radius.circular(20.r),
                                  ),
                                ),
                                padding: EdgeInsets.symmetric(horizontal: 10.w),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    SvgPicture.asset(
                                      'assets/svg/my-reports-add-icon.svg',
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
                                              _isCreateButtonExpanded ? 1 : 0,
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
                    SliverToBoxAdapter(child: SizedBox(height: 12.h)),
                    if (isLoading)
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => showFolderOrReportLoader(),
                          childCount: 10,
                        ),
                      )
                    else if (filteredFolders.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            'No reports found',
                            style: GoogleFonts.poppins(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF9AA0A6),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final folder = filteredFolders[index];
                            return FolderTile(
                              folder: folder,
                              onTap: () => _openFolderPhotos(folder),
                              onShareTap: () {
                                showFlushBar(
                                  context,
                                  message:
                                      'Share action will be available soon',
                                );
                              },
                              onDragTap: () {
                                showFlushBar(
                                  context,
                                  message:
                                      'Drag action is not available in this view yet',
                                );
                              },
                              onMenuSelected: (value) async {
                                if (value == 'rename') {
                                  if (!context.mounted) return;
                                  showFlushBar(
                                    context,
                                    message:
                                        'Rename function for folder is not available at the moment',
                                  );
                                  return;
                                }

                                if (value == 'delete') {
                                  if (!context.mounted) return;
                                  final confirmed = await showDialog<bool>(
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
                                              color: const Color(0xFF27304E),
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
                                              color: const Color(0xFFE81E25),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmed == true) {
                                    showFlushBar(
                                      context,
                                      message:
                                          'Delete function for folder is not available at the moment.',
                                    );
                                  }
                                }
                              },
                            );
                          },
                          childCount: filteredFolders.length,
                        ),
                      ),
                    SliverToBoxAdapter(child: SizedBox(height: 18.h)),
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
                      padding: EdgeInsets.fromLTRB(0, 12.h, 0, 16.h),
                      decoration: BoxDecoration(
                        color: _isScrolled
                            ? Colors.white.withOpacity(0.55)
                            : Colors.white.withOpacity(0.30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 2,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/png/my-reports-frame.png',
                                width: 22.w,
                                height: 22.w,
                                fit: BoxFit.contain,
                                color: const Color(0xFF151A36),
                                colorBlendMode: BlendMode.srcIn,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                'My Reports',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF151A36),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16.h),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 18.w),
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

Skeletonizer showFolderOrReportLoader() {
  return Skeletonizer(
    enabled: true,
    child: FolderTile(
      folder: FolderModel(
        name: "name",
        createdAt: DateTime.now(),
        companyId: 1,
        reportCount: 0,
        description: '',
        updatedAt: DateTime.now(),
        id: "1",
      ),
      onMenuSelected: (_) {},
    ),
  );
}
