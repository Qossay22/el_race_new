import 'dart:async';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/my_projects/data/datasources/project_remote_datasource.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_manager_filter_item.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/user_project_model.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/user_projects_response.dart';
import 'package:el_race/ui/presentation/my_projects/data/repositories/project_repository_impl.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_by_filters_usecase.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_by_partner_usecase.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_usecase.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_list_bloc.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/screens/project_list_screen.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final ShaderCallback? shaderCallback;

  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.textAlign,
    this.shaderCallback,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  bool _needsScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfScrollNeeded();
    });
  }

  void _checkIfScrollNeeded() {
    if (!mounted) return;
    if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 0) {
      setState(() {
        _needsScrolling = true;
      });
      _startScrolling();
    }
  }

  void _startScrolling() async {
    if (!mounted || !_needsScrolling) return;

    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    while (mounted && _needsScrolling) {
      // Scroll to end slowly
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(
            milliseconds: (widget.text.length * 120).clamp(4000, 15000)),
        curve: Curves.linear,
      );

      if (!mounted) break;
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) break;

      // Jump back to start instantly (no animation)
      _scrollController.jumpTo(0);

      await Future.delayed(const Duration(milliseconds: 1500));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textWidget = Text(
      widget.text,
      style: widget.style,
      textAlign: widget.textAlign,
    );

    final scrollableText = SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      child: textWidget,
    );

    if (widget.shaderCallback != null) {
      return ShaderMask(
        shaderCallback: widget.shaderCallback!,
        child: scrollableText,
      );
    }

    return scrollableText;
  }
}

class MyProject extends StatefulWidget {
  const MyProject({super.key});

  @override
  State<MyProject> createState() => _MyProjectState();
}

class _MyProjectState extends State<MyProject> {
  bool _isLoading = false;
  String? _error;
  List<UserProjectModel> _projects = [];

  ProjectListBloc _buildProjectsBloc() {
    final repo = ProjectRepositoryImpl(ProjectRemoteDataSource());
    return ProjectListBloc(
      getProjectsUseCase: GetProjectsUseCase(repository: repo),
      getProjectAttachmentsUseCase:
          GetProjectAttachmentsUseCase(repository: repo),
      getProjectsByPartnerUseCase:
          GetProjectsByPartnerUseCase(repository: repo),
      getProjectsByFiltersUseCase:
          GetProjectsByFiltersUseCase(repository: repo),
    );
  }

  Future<void> _openProjectManagerScreen() async {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const _ProjectManagersScreen(),
      ),
    );
  }

  Future<void> _openClientsScreen() async {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const _ClientsScreen(),
      ),
    );
  }

  Future<void> _openCitiesScreen() async {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const _CitiesScreen(),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchUserProjects();
  }

  Future<void> _fetchUserProjects() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final UserProjectsResponse response =
          await ProjectRemoteDataSource().fetchClientsList();

      setState(() {
        _projects = response.projects;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _showFilterPopup() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        Widget filterField(String text, {VoidCallback? onTap}) {
          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10.r),
            child: Container(
              height: 58.h,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: const Color(0xFF8F8F8F),
                  width: 1.3,
                ),
              ),
              child: Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 36.sp / 2,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF7A7A7A),
                ),
              ),
            ),
          );
        }

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 24.h),
          child: Container(
            padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 20.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F1F1),
              borderRadius: BorderRadius.circular(34.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          'assets/newapp/newicon/my_projects_filter_icon.svg',
                          height: 24.sp,
                          width: 24.sp,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          'Filter',
                          style: GoogleFonts.poppins(
                            fontSize: 40.sp / 2,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E2365),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => Navigator.pop(ctx),
                      borderRadius: BorderRadius.circular(20.r),
                      child: Container(
                        width: 30.w,
                        height: 30.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFE53935),
                            width: 1.2,
                          ),
                        ),
                        child: Icon(
                          Icons.close,
                          color: const Color(0xFFE53935),
                          size: 16.sp,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 18.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 22.w),
                  child: Column(
                    children: [
                      filterField(
                        'Project Manager',
                        onTap: () {
                          Navigator.pop(ctx);
                          _openProjectManagerScreen();
                        },
                      ),
                      SizedBox(height: 12.h),
                      filterField(
                        'Clients',
                        onTap: () {
                          Navigator.pop(ctx);
                          _openClientsScreen();
                        },
                      ),
                      SizedBox(height: 12.h),
                      filterField(
                        'City',
                        onTap: () {
                          Navigator.pop(ctx);
                          _openCitiesScreen();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const HeaderWidget(),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 🔹 Projects Title Section (Scrollable)
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 5),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    children: [
                      const Spacer(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            "assets/newapp/my_projects.png",
                            height: 24.w,
                            width: 24.w,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            translate('home.projects'),
                            style: GoogleFonts.koulen(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w500,
                              color: appFontColor,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: _showFilterPopup,
                        borderRadius: BorderRadius.circular(20.r),
                        child: Container(
                          width: 30.w,
                          height: 30.w,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.transparent,
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/newapp/newicon/my_projects_filter_icon.svg',
                              height: 24.sp,
                              width: 24.sp,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),

          // 🔹 Loading or Error or List
          _isLoading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              : _error != null
                  ? SliverFillRemaining(
                      child: Center(
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    )
                  : _projects.isEmpty
                      ? const SliverFillRemaining(
                          child: Center(
                            child: Text('No projects found for this company'),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final project = _projects[index];

                              final id = project.projectId;
                              final name = project.projectName;
                              final totalProjects = project.totalProjects;
                              final totalAmount = project.totalProjectsAmount;
                              final photoUrl = project.photoUrl;

                              return GestureDetector(
                                onTap: () {
                                  debugPrint(
                                    '[MY_PROJECTS][DEFAULT_TAP] partnerId=${project.projectId} '
                                    'agreementId=${project.agreementId} agreementNo=${project.agreementNo}',
                                  );

                                  final bloc = _buildProjectsBloc();

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => BlocProvider.value(
                                        value: bloc,
                                        child: ProjectListScreen(
                                          bloc: bloc,
                                          agreementId: project.agreementId,
                                          partnerId: id,
                                          partnerName: name,
                                          partnerPhoto: photoUrl ?? '',
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                child: buildProjectCard(
                                  id: project.agreementNo ?? '$id',
                                  name: name,
                                  photoUrl: photoUrl ?? '',
                                  projectsCount: totalProjects,
                                  amountAed: totalAmount,
                                  cityId: project.cityId ?? '',
                                ),
                              );
                            },
                            childCount: _projects.length,
                          ),
                        ),
          // Bottom padding
          SliverPadding(padding: EdgeInsets.only(bottom: 100.h)),
        ],
      ),
    );
  }
}

//
// ------------- CARD — EXACT MATCH TO REFERENCE ----------------
//

Widget buildProjectCard({
  required String id,
  required String name,
  required String photoUrl,
  required int projectsCount,
  required double amountAed,
  String location = '',
  String cityId = '',
}) {
  String? normalizedPhotoUrl = photoUrl.trim();
  if (normalizedPhotoUrl.isEmpty) normalizedPhotoUrl = null;
  if (normalizedPhotoUrl != null &&
      normalizedPhotoUrl.contains('erp.elrace.compublic')) {
    normalizedPhotoUrl = normalizedPhotoUrl.replaceAll(
        'erp.elrace.compublic', 'erp.elrace.com/public');
  }

  final formattedAmount = NumberFormat('#,##0.##', 'en').format(amountAed);
  const cardDataGray = Color(0xB8484848);

  return Container(
    margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 7.h),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22.r),
      border: Border.all(color: const Color(0xFF2C2F36), width: 1),
      gradient: const LinearGradient(
        colors: [Color(0xFFD6D6D6), Color(0xFFADB2BD)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.10),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(22.r),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.08,
                child: Image.asset(
                  'assets/newapp/for_attachments.png',
                  width: 150.w,
                  fit: BoxFit.fitHeight,
                  alignment: Alignment.centerRight,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(18.w, 14.h, 18.w, 12.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 18.h,
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: Text(
                          DateFormat('MM/dd/yyyy').format(DateTime.now()),
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                            color: cardDataGray,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  id.isNotEmpty ? id : '-',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 10.h),
                Text(
                  name.trim().isNotEmpty ? name.trim() : '-',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 14.h),
                Row(
                  children: [
                    Expanded(
                      child: RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                          children: [
                            const TextSpan(text: 'Work Order# '),
                            TextSpan(
                              text: '$projectsCount',
                              style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: cardDataGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                            children: [
                              const TextSpan(text: 'Amount# '),
                              TextSpan(
                                text: formattedAmount,
                                style: GoogleFonts.inter(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: cardDataGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on, size: 16.w, color: red),
                    SizedBox(width: 4.w),
                    Flexible(
                      child: Text(
                        cityId.trim().isNotEmpty
                            ? cityId.trim()
                            : location.trim().isNotEmpty
                                ? location.trim()
                                : '-',
                        style: GoogleFonts.inter(
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w700,
                          color: cardDataGray,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PositionedDirectional(
            start: 10.w,
            top: 10.h,
            child: Container(
              width: 34.w,
              height: 34.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: normalizedPhotoUrl != null
                  ? ClipOval(
                      child: Image.network(
                        normalizedPhotoUrl,
                        fit: BoxFit.contain,
                        headers: {
                          'Accept': 'image/*',
                          'Authorization':
                              'Bearer ${SharedPref.getLoginData().result?.token ?? ''}',
                        },
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.business,
                          size: 18.w,
                          color: appFontColor,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.business,
                      size: 18.w,
                      color: appFontColor,
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ProjectManagersScreen extends StatefulWidget {
  const _ProjectManagersScreen();

  @override
  State<_ProjectManagersScreen> createState() => _ProjectManagersScreenState();
}

class _ProjectManagersScreenState extends State<_ProjectManagersScreen> {
  bool _isLoading = true;
  String? _error;
  List<ProjectManagerFilterItem> _managers = const [];

  @override
  void initState() {
    super.initState();
    _loadManagers();
  }

  Future<void> _loadManagers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ProjectRemoteDataSource().fetchProjectManagersList();
      if (!mounted) return;
      setState(() {
        _managers = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _lastUpdateText(String? rawDate) {
    if (rawDate == null || rawDate.trim().isEmpty) {
      return 'Last updates recently';
    }

    final parsed = DateTime.tryParse(rawDate.trim());
    if (parsed == null) return 'Last updates recently';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(parsed.year, parsed.month, parsed.day);
    final diff = today.difference(date).inDays;

    if (diff <= 0) return 'Last updates today';
    if (diff == 1) return 'Last updates yesterday';
    return 'Last updates ${DateFormat('dd/MM/yyyy').format(parsed)}';
  }

  ProjectListBloc _buildProjectsBloc() {
    final repo = ProjectRepositoryImpl(ProjectRemoteDataSource());
    return ProjectListBloc(
      getProjectsUseCase: GetProjectsUseCase(repository: repo),
      getProjectAttachmentsUseCase:
          GetProjectAttachmentsUseCase(repository: repo),
      getProjectsByPartnerUseCase:
          GetProjectsByPartnerUseCase(repository: repo),
      getProjectsByFiltersUseCase:
          GetProjectsByFiltersUseCase(repository: repo),
    );
  }

  void _openManagerProjects(ProjectManagerFilterItem manager) {
    final bloc = _buildProjectsBloc();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: ProjectListScreen(
            bloc: bloc,
            projectManagerId: manager.id,
            partnerName: manager.name,
            partnerPhoto: manager.photoUrl ?? '',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: const HeaderWidget(),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_circle_outlined,
                  color: const Color(0xFF202020),
                  size: 27.sp,
                ),
                SizedBox(width: 6.w),
                Text(
                  'Project Manager',
                  style: GoogleFonts.poppins(
                    fontSize: 36.sp / 2,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF202020),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFBA1719),
                            fontSize: 12.sp,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.only(
                          left: 14.w,
                          right: 14.w,
                          top: 6.h,
                          bottom: 20.h,
                        ),
                        itemCount: _managers.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: const Color(0xFFD5D5D5),
                          thickness: 1,
                          indent: 10.w,
                          endIndent: 10.w,
                        ),
                        itemBuilder: (context, index) {
                          final manager = _managers[index];
                          final avatarUrl = manager.photoUrl;

                          return InkWell(
                            onTap: () => _openManagerProjects(manager),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 4.w,
                                vertical: 10.h,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 27.r,
                                    backgroundColor: Colors.white,
                                    child: CircleAvatar(
                                      radius: 25.r,
                                      backgroundColor: const Color(0xFFE8E8E8),
                                      backgroundImage: avatarUrl != null &&
                                              avatarUrl.isNotEmpty
                                          ? NetworkImage(avatarUrl)
                                          : null,
                                      child: (avatarUrl == null ||
                                              avatarUrl.isEmpty)
                                          ? Text(
                                              manager.name.isEmpty
                                                  ? 'M'
                                                  : manager.name[0]
                                                      .toUpperCase(),
                                              style: GoogleFonts.poppins(
                                                fontSize: 18.sp,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF5C5C5C),
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          manager.name,
                                          maxLines: 5,
                                          style: GoogleFonts.poppins(
                                            fontSize: 21.sp,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF3A3A3A),
                                          ),
                                        ),
                                        SizedBox(height: 2.h),
                                        Text(
                                          _lastUpdateText(manager.lastUpdate),
                                          style: GoogleFonts.poppins(
                                            fontSize: 15.sp,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFFA2A2A2),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 50.w,
                                    height: 54.h,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12.r),
                                      gradient: const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFF3C4C80),
                                          Color(0xFF202F5C),
                                        ],
                                      ),
                                    ),
                                    child: Text(
                                      manager.projectCount.toString(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 20.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _ClientsScreen extends StatefulWidget {
  const _ClientsScreen();

  @override
  State<_ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<_ClientsScreen> {
  bool _isLoading = true;
  String? _error;
  List<ProjectManagerFilterItem> _clients = const [];

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ProjectRemoteDataSource()
          .fetchClientsGroupedList(groupBy: 'client');
      if (!mounted) return;
      setState(() {
        _clients = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _lastUpdateText(String? rawDate) {
    if (rawDate == null || rawDate.trim().isEmpty) {
      return 'Last updates recently';
    }

    final parsed = DateTime.tryParse(rawDate.trim());
    if (parsed == null) return 'Last updates recently';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(parsed.year, parsed.month, parsed.day);
    final diff = today.difference(date).inDays;

    if (diff <= 0) return 'Last updates today';
    if (diff == 1) return 'Last updates yesterday';
    return 'Last updates ${DateFormat('dd/MM/yyyy').format(parsed)}';
  }

  ProjectListBloc _buildProjectsBloc() {
    final repo = ProjectRepositoryImpl(ProjectRemoteDataSource());
    return ProjectListBloc(
      getProjectsUseCase: GetProjectsUseCase(repository: repo),
      getProjectAttachmentsUseCase:
          GetProjectAttachmentsUseCase(repository: repo),
      getProjectsByPartnerUseCase:
          GetProjectsByPartnerUseCase(repository: repo),
      getProjectsByFiltersUseCase:
          GetProjectsByFiltersUseCase(repository: repo),
    );
  }

  void _openClientProjects(ProjectManagerFilterItem client) {
    final bloc = _buildProjectsBloc();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: ProjectListScreen(
            bloc: bloc,
            partnerId: client.id,
            partnerName: client.name,
            partnerPhoto: client.photoUrl ?? '',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: const HeaderWidget(),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.handshake_outlined,
                  color: const Color(0xFF202020),
                  size: 27.sp,
                ),
                SizedBox(width: 6.w),
                Text(
                  'Client',
                  style: GoogleFonts.poppins(
                    fontSize: 36.sp / 2,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF202020),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFBA1719),
                            fontSize: 12.sp,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.only(
                          left: 14.w,
                          right: 14.w,
                          top: 6.h,
                          bottom: 20.h,
                        ),
                        itemCount: _clients.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: const Color(0xFFD5D5D5),
                          thickness: 1,
                          indent: 10.w,
                          endIndent: 10.w,
                        ),
                        itemBuilder: (context, index) {
                          final client = _clients[index];
                          final avatarUrl = client.photoUrl;

                          return InkWell(
                            onTap: () => _openClientProjects(client),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 4.w,
                                vertical: 10.h,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 27.r,
                                    backgroundColor: Colors.white,
                                    child: CircleAvatar(
                                      radius: 25.r,
                                      backgroundColor: const Color(0xFFE8E8E8),
                                      backgroundImage: avatarUrl != null &&
                                              avatarUrl.isNotEmpty
                                          ? NetworkImage(avatarUrl)
                                          : null,
                                      child: (avatarUrl == null ||
                                              avatarUrl.isEmpty)
                                          ? Text(
                                              client.name.isEmpty
                                                  ? 'C'
                                                  : client.name[0]
                                                      .toUpperCase(),
                                              style: GoogleFonts.poppins(
                                                fontSize: 18.sp,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF5C5C5C),
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          client.name,
                                          maxLines: 5,
                                          style: GoogleFonts.poppins(
                                            fontSize: 21.sp,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF3A3A3A),
                                          ),
                                        ),
                                        SizedBox(height: 2.h),
                                        Text(
                                          _lastUpdateText(client.lastUpdate),
                                          style: GoogleFonts.poppins(
                                            fontSize: 15.sp,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFFA2A2A2),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 50.w,
                                    height: 54.h,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12.r),
                                      gradient: const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFF3C4C80),
                                          Color(0xFF202F5C),
                                        ],
                                      ),
                                    ),
                                    child: Text(
                                      client.projectCount.toString(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 20.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _CitiesScreen extends StatefulWidget {
  const _CitiesScreen();

  @override
  State<_CitiesScreen> createState() => _CitiesScreenState();
}

class _CitiesScreenState extends State<_CitiesScreen> {
  bool _isLoading = true;
  String? _error;
  List<ProjectManagerFilterItem> _cities = const [];

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  Future<void> _loadCities() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ProjectRemoteDataSource()
          .fetchClientsGroupedList(groupBy: 'city');
      if (!mounted) return;
      setState(() {
        _cities = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _lastUpdateText(String? rawDate) {
    if (rawDate == null || rawDate.trim().isEmpty) {
      return 'Last updates recently';
    }

    final parsed = DateTime.tryParse(rawDate.trim());
    if (parsed == null) return 'Last updates recently';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(parsed.year, parsed.month, parsed.day);
    final diff = today.difference(date).inDays;

    if (diff <= 0) return 'Last updates today';
    if (diff == 1) return 'Last updates yesterday';
    return 'Last updates ${DateFormat('dd/MM/yyyy').format(parsed)}';
  }

  ProjectListBloc _buildProjectsBloc() {
    final repo = ProjectRepositoryImpl(ProjectRemoteDataSource());
    return ProjectListBloc(
      getProjectsUseCase: GetProjectsUseCase(repository: repo),
      getProjectAttachmentsUseCase:
          GetProjectAttachmentsUseCase(repository: repo),
      getProjectsByPartnerUseCase:
          GetProjectsByPartnerUseCase(repository: repo),
      getProjectsByFiltersUseCase:
          GetProjectsByFiltersUseCase(repository: repo),
    );
  }

  void _openCityProjects(ProjectManagerFilterItem city) {
    final bloc = _buildProjectsBloc();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: ProjectListScreen(
            bloc: bloc,
            cityId: city.id,
            partnerName: city.name,
            partnerPhoto: city.photoUrl ?? '',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: const HeaderWidget(),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: const Color(0xFF202020),
                  size: 27.sp,
                ),
                SizedBox(width: 6.w),
                Text(
                  'City',
                  style: GoogleFonts.poppins(
                    fontSize: 36.sp / 2,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF202020),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFBA1719),
                            fontSize: 12.sp,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.only(
                          left: 14.w,
                          right: 14.w,
                          top: 6.h,
                          bottom: 20.h,
                        ),
                        itemCount: _cities.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: const Color(0xFFD5D5D5),
                          thickness: 1,
                          indent: 10.w,
                          endIndent: 10.w,
                        ),
                        itemBuilder: (context, index) {
                          final city = _cities[index];

                          return InkWell(
                            onTap: () => _openCityProjects(city),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 4.w,
                                vertical: 10.h,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    color: const Color(0xFFD61518),
                                    size: 40.sp,
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          city.name,
                                          maxLines: 5,
                                          style: GoogleFonts.poppins(
                                            fontSize: 21.sp,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF3A3A3A),
                                          ),
                                        ),
                                        SizedBox(height: 2.h),
                                        Text(
                                          _lastUpdateText(city.lastUpdate),
                                          style: GoogleFonts.poppins(
                                            fontSize: 15.sp,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFFA2A2A2),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 50.w,
                                    height: 54.h,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12.r),
                                      gradient: const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFF3C4C80),
                                          Color(0xFF202F5C),
                                        ],
                                      ),
                                    ),
                                    child: Text(
                                      city.projectCount.toString(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 20.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
