import 'dart:math' as math;

import 'package:el_race/report_module/data/models/folder_model.dart';
import 'package:el_race/report_module/data/provider/reports_provider.dart';
import 'package:el_race/report_module/data/repositories/company_repository.dart';
import 'package:el_race/ui/presentation/task_sheet/add_task_sheet.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class UserReportsScreen extends StatefulWidget {
  const UserReportsScreen({super.key});

  static const String routeName = '/user-reports';

  @override
  State<UserReportsScreen> createState() => _UserReportsScreenState();
}

class _UserReportsScreenState extends State<UserReportsScreen> {
  bool _isLoading = true;
  bool _isCreatingProject = false;
  String _searchQuery = '';
  List<FolderModel> _folders = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      await CompanyRepository().getCompany();
      ReportProvider().init(base: 'https://erp.elrace.com');
      await reportProvider.fetchAllFolders();

      if (mounted) {
        setState(() {
          _folders = reportProvider.folders;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showCreateProjectDialog() async {
    final TextEditingController projectNameController = TextEditingController();
    final companyName =
        (CompanyRepository.company?.companyName ?? 'RCC').trim();

    await showDialog<void>(
      context: context,
      barrierDismissible: !_isCreatingProject,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
              backgroundColor: Colors.transparent,
              child: Container(
                padding: EdgeInsets.fromLTRB(18.w, 20.h, 18.w, 18.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(24.r),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DialogInputCard(
                      topLabel: 'Project',
                      title: 'Name',
                      controller: projectNameController,
                      hint: 'Write here',
                    ),
                    SizedBox(height: 14.h),
                    _DialogReadOnlyCard(
                      topLabel: 'Company',
                      title: 'Name',
                      value: companyName.isEmpty ? 'RCC' : companyName,
                    ),
                    SizedBox(height: 20.h),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 42.h,
                            child: ElevatedButton(
                              onPressed: _isCreatingProject
                                  ? null
                                  : () => Navigator.pop(dialogContext),
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: const Color(0xFFC91118),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22.r),
                                ),
                              ),
                              child: Text(
                                'CANCEL',
                                style: GoogleFonts.poppins(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: SizedBox(
                            height: 42.h,
                            child: ElevatedButton(
                              onPressed: _isCreatingProject
                                  ? null
                                  : () async {
                                      final projectName =
                                          projectNameController.text.trim();

                                      if (projectName.isEmpty) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Please enter project name',
                                              style: GoogleFonts.poppins(
                                                fontSize: 13.sp,
                                                color: Colors.white,
                                              ),
                                            ),
                                            backgroundColor:
                                                const Color(0xFFC91118),
                                            behavior:
                                                SnackBarBehavior.floating,
                                            margin: EdgeInsets.all(16.w),
                                          ),
                                        );
                                        return;
                                      }

                                      setState(() => _isCreatingProject = true);
                                      setDialogState(() {});

                                      try {
                                        await reportProvider.createFolder(
                                          title: projectName,
                                          description: companyName,
                                        );
                                        await _loadData();

                                        if (mounted) {
                                          Navigator.pop(dialogContext);
                                        }
                                      } catch (_) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Could not create project',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 13.sp,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              backgroundColor:
                                                  const Color(0xFFC91118),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              margin: EdgeInsets.all(16.w),
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(() =>
                                              _isCreatingProject = false);
                                          setDialogState(() {});
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: const Color(0xFF2A8C3A),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22.r),
                                ),
                              ),
                              child: _isCreatingProject
                                  ? SizedBox(
                                      width: 16.w,
                                      height: 16.w,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'SUBMIT',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
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
  Widget build(BuildContext context) {
    final displayItems = _folders
        .where((folder) {
          if (_searchQuery.trim().isEmpty) return true;
          final query = _searchQuery.trim().toLowerCase();
          return folder.name.toLowerCase().contains(query) ||
              folder.description.toLowerCase().contains(query);
        })
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      appBar: const HeaderWidget(),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(height: 12.h),
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
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF151A36),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 18.w),
              child: SizedBox(
                width: double.infinity,
                height: 46.h,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: const Color(0xFFB9BBC3),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12.r),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AddTaskSheet(),
                              ),
                            );
                          },
                          child: Center(
                            child: Text(
                              'Add a new request',
                              style: GoogleFonts.poppins(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
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
            SizedBox(height: 20.h),
            Padding(
              padding: EdgeInsets.only(left: 20.w),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Projects Reports',
                      style: GoogleFonts.poppins(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF878B98),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _isCreatingProject ? null : _showCreateProjectDialog,
                    child: Container(
                      width: 44.w,
                      height: 44.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFF27304E),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(14.r),
                          bottomLeft: Radius.circular(14.r),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.add,
                        size: 26.w,
                        color: _isCreatingProject
                            ? Colors.white70
                            : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : displayItems.isEmpty
                      ? Center(
                          child: Text(
                            'No reports found',
                            style: GoogleFonts.poppins(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF9AA0A6),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.only(bottom: 18.h),
                          itemCount: displayItems.length,
                          itemBuilder: (context, index) {
                            final folder = displayItems[index];
                            return _ReportCard(
                              title: folder.name.trim().isEmpty
                                  ? 'Project Name'
                                  : folder.name,
                              subtitle: folder.description.trim().isEmpty
                                  ? 'Company Name'
                                  : folder.description,
                              seed: int.tryParse(folder.id) ?? (index + 1),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogInputCard extends StatelessWidget {
  final String topLabel;
  final String title;
  final String hint;
  final TextEditingController controller;

  const _DialogInputCard({
    required this.topLabel,
    required this.title,
    required this.hint,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 14.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFBFC2CC), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            topLabel,
            style: GoogleFonts.poppins(
              fontSize: 11.sp,
              color: const Color(0xFF71748A),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15.sp,
              color: const Color(0xFF22263A),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 12.h),
          Container(
            height: 38.h,
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(19.r),
              border: Border.all(color: const Color(0xFFCDD0D8), width: 1),
            ),
            child: Center(
              child: TextField(
                controller: controller,
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  color: const Color(0xFF22263A),
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 13.sp,
                    color: const Color(0xFFA6A9B3),
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

class _DialogReadOnlyCard extends StatelessWidget {
  final String topLabel;
  final String title;
  final String value;

  const _DialogReadOnlyCard({
    required this.topLabel,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 14.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFBFC2CC), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            topLabel,
            style: GoogleFonts.poppins(
              fontSize: 11.sp,
              color: const Color(0xFF71748A),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15.sp,
              color: const Color(0xFF22263A),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 12.h),
          Container(
            height: 38.h,
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(19.r),
              border: Border.all(color: const Color(0xFFCDD0D8), width: 1),
            ),
            alignment: Alignment.center,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    maxLines: null,
                    overflow: TextOverflow.visible,
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      color: const Color(0xFF6D7180),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  size: 20.w,
                  color: const Color(0xFF2B2E3C),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int seed;

  const _ReportCard({
    required this.title,
    required this.subtitle,
    required this.seed,
  });

  @override
  Widget build(BuildContext context) {
    final points = _sparklinePoints(seed);

    return Container(
      margin: EdgeInsets.fromLTRB(14.w, 0, 14.w, 12.h),
      padding: EdgeInsets.fromLTRB(18.w, 14.h, 12.w, 14.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: const Color(0xFFA7AAB4),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8.h),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF27304E),
                  ),
                  maxLines: null,
                  overflow: TextOverflow.visible,
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF777A86),
                  ),
                  maxLines: null,
                  overflow: TextOverflow.visible,
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          SizedBox(
            width: 132.w,
            height: 94.h,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Image.asset(
                  'assets/png/r1.png',
                  width: 16.w,
                  height: 16.w,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.more_vert,
                    size: 16.w,
                    color: const Color(0xFF27304E),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 130.w,
                  height: 52.h,
                  child: CustomPaint(
                    painter: _ReportChartPainter(points),
                  ),
                ),
                SizedBox(height: 2.h),
                Padding(
                  padding: EdgeInsets.only(right: 2.w),
                  child: Text(
                    '100',
                    style: GoogleFonts.poppins(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF27304E),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Offset> _sparklinePoints(int baseSeed) {
    final random = math.Random(baseSeed.abs() + 21);
    final values = <double>[];

    double current = 0.12 + random.nextDouble() * 0.08;
    for (int i = 0; i < 24; i++) {
      final drift = (random.nextDouble() - 0.3) * 0.18;
      current = (current + drift).clamp(0.08, 0.92);
      if (i > 18) {
        current = (current + 0.05).clamp(0.1, 0.96);
      }
      values.add(current);
    }

    return values
        .asMap()
        .entries
        .map((entry) => Offset(entry.key.toDouble(), entry.value))
        .toList();
  }
}

class _ReportChartPainter extends CustomPainter {
  final List<Offset> points;

  const _ReportChartPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) {
      return;
    }

    final paint = Paint()
      ..color = const Color(0xFF6E758A)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final px = (i / (points.length - 1)) * size.width;
      final py = size.height - (points[i].dy * size.height);
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ReportChartPainter oldDelegate) {
    if (identical(oldDelegate.points, points)) {
      return false;
    }
    if (oldDelegate.points.length != points.length) {
      return true;
    }
    for (int i = 0; i < points.length; i++) {
      if (oldDelegate.points[i] != points[i]) {
        return true;
      }
    }
    return false;
  }
}
