import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/report_module/presentation/screens/report_listing/report_app_home_screen.dart';
import 'package:el_race/ui/presentation/Attendace_list/attendance_page.dart';
import 'package:el_race/ui/presentation/PettyCash/PettyCashScreen.dart';
import 'package:el_race/ui/presentation/home_screen/data/widget_model.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/card_tile.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/custom_bullet_point.dart';
import 'package:el_race/ui/presentation/lpo/screens/lpo_screen.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/parayer_widgets/parayer_widget.dart';
import 'package:el_race/ui/presentation/media/screens/media_list_screen.dart';
import 'package:el_race/ui/presentation/my_documents/screens/my_documents_screen.dart';
import 'package:el_race/ui/presentation/my_notes/screens/my_notes_screen.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/screens/my_project.dart';
import 'package:el_race/ui/presentation/my_request/HrRequestsMenuPage.dart';
import 'package:el_race/ui/presentation/my_request/MyRequestsPage.dart';
import 'package:el_race/ui/presentation/task_sheet/task_sheet_screen.dart';
import 'package:el_race/ui/presentation/tasks/logic/tasks_provider.dart';
import 'package:el_race/ui/presentation/tasks_dashboard/screens/tasks_dashboard_screen.dart';
import 'package:el_race/utils/custom_navigate.dart';
import 'package:el_race/utils/Util.dart';
import 'package:el_race/utils/orientation_helper.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../bloc/home_bloc.dart';

class ListViewWidgets extends StatefulWidget {
  const ListViewWidgets({
    super.key,
  });

  @override
  State<ListViewWidgets> createState() => _ListViewWidgetsState();
}

class _ListViewWidgetsState extends State<ListViewWidgets> {
  static const List<String> _figmaOrder = [
    'attendance',
    //'ai_support',
    'media',
    'projects',
    'lpo',
    'external_widget',
    'documents',
    'my_report',
    'time_sheet',
    'my_request',
    'petty_cash',
    'prayer',
  ];

  bool _aiTapped = false;
  int _aiTapVersion = 0;

  List<WidgetModel> activeWidgets = [];
  bool isLoading = true;
  DateTime now = DateTime.now();
  @override
  void initState() {
    super.initState();
    _loadActiveWidgets();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadActiveWidgets();
  }

  Future<void> _loadActiveWidgets() async {
    if (mounted) {
      setState(() {
        activeWidgets = _figmaOrder
            .map((id) => WidgetModel(id: id, title: id))
            .toList(growable: false);
        isLoading = false;
      });
    }
  }

  Widget _buildCustomWidget(WidgetModel widget) {
    const isReorderMode = false;

    switch (widget.id) {
      case 'time_sheet':
        return _buildTimeSheetWidget(isReorderMode: isReorderMode);
      case 'petty_cash':
        return _buildPettyCashWidget(isReorderMode: isReorderMode);
      case 'lpo':
        return _buildLPOWidget(isReorderMode: isReorderMode);
      case 'external_widget':
        return _buildExternalWidgetRow();
      case 'documents':
        return _buildDocumentsWidget(isReorderMode: isReorderMode);
      case 'my_notes':
        return _buildMyNotesWidget(isReorderMode: isReorderMode);
      case 'todo_list':
        return _buildTodoListWidget(isReorderMode: isReorderMode);
      case 'projects':
        return _buildProjectsWidget(isReorderMode: isReorderMode);
      case 'my_request':
        return _buildMyRequestWidget(isReorderMode: isReorderMode);
      case 'media':
        return _buildMediaWidget(isReorderMode: isReorderMode);
      case 'my_report':
        return _buildMyReportWidget(isReorderMode: isReorderMode);
      case 'attendance':
        return _buildAttendanceWidget(isReorderMode: isReorderMode);
      case 'ai_support':
        return _buildAiSupportWidget();
      case 'prayer':
        return const ParayerWidget();
      // QR widget removed from home screen - only available in sidebar
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTimeSheetWidget({bool isReorderMode = false}) {
    final loginData = SharedPref.getLoginData();
    final widgetData = loginData.result?.data?.defaultWidgets?.data;
    final timesheetCount =
        widgetData?.timesheetWidget?.recordCount?.toString() ?? '0';
    final isDisabled = widgetData?.timesheetWidget?.isDisabled == true;

    return Stack(
      children: [
        GrayCardComponent(
          onClick: (isReorderMode || isDisabled)
              ? null
              : () => Util.pushPage(const TaskSheetPage(), context),
          cardTitle: 'Timesheet',
          upperCaseTitle: false,
          backgroundImagePath: 'assets/png/t-sheet.png',
          childWidget: const SizedBox.shrink(),
        ),
        Positioned(
          left: 16.w,
          bottom: 12.h,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Image.asset(
                'assets/png/time-sheet-icon.png',
                width: 44.w,
                height: 44.w,
              ),
              SizedBox(width: 6.w),
              Padding(
                padding: EdgeInsets.only(bottom: 6.h),
                child: Text(
                  timesheetCount,
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontSize: 19.w,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPettyCashWidget({bool isReorderMode = false}) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23.r),
        child: Stack(
          children: [
            GrayCardComponent(
              onClick: isReorderMode
                  ? null
                  : () => Util.pushPage(const PettyCashScreen(), context),
              cardTitle: translate('home.petty_cash'),
              titleColor: Colors.white,
              backgroundImagePath:
                  'assets/newapp/petty_cach_widget_background.png',
              childWidget: const SizedBox.shrink(),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Transform.translate(
                    offset: Offset(-12.w, 30.h),
                    child: Opacity(
                      opacity: 0.28,
                      child: Image.asset(
                        'assets/newapp/d_for_petty_Cach.png',
                        height: 30.h,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLPOWidget({bool isReorderMode = false}) {
    final loginData = SharedPref.getLoginData();
    final widgetData = loginData.result?.data?.defaultWidgets?.data;
    final lpoTotal =
        widgetData?.lpoWidget?.recordMap?['total']?.toString() ?? '0';
    final isDisabled = widgetData?.lpoWidget?.isDisabled == true;

    return GrayCardComponent(
      onClick: (isReorderMode || isDisabled)
          ? null
          : () => Util.pushPage(const LpoListScreen(), context),
      cardTitle: translate('home.lpo'),
      titleColor: Colors.white,
      backgroundImagePath: 'assets/newapp/Lpo_background_widget.png',
      topPadding: true,
      childWidget: SizedBox(),

      // childWidget: Padding(
      //   padding: EdgeInsets.only(
      //     left: 210.w,
      //   ),
      //   child: Image.asset(
      //     'assets/png/lpo.png',
      //     width: SizeConfig().getWidth(140),
      //     height: SizeConfig().getHeight(140),
      //   ),
      // ),
    );
  }

  Widget _buildExternalWidgetRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 8.w;
        final tileSize = (constraints.maxWidth - (spacing * 2)) / 3;

        return SizedBox(
          height: tileSize,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                SizedBox(
                  width: tileSize,
                  height: tileSize,
                  child: _buildExternalWidgetTile(
                    assetPath: 'assets/newapp/tasks managment.svg',
                    onTap: () =>
                        Util.pushPage(const TasksDashboardScreen(), context),
                  ),
                ),
                SizedBox(width: spacing),
                SizedBox(
                  width: tileSize,
                  height: tileSize,
                  child: _buildExternalWidgetTile(
                    assetPath: 'assets/newapp/Notes widget.png',
                    onTap: null,
                  ),
                ),
                SizedBox(width: spacing),
                SizedBox(
                  width: tileSize,
                  height: tileSize,
                  child: _buildExternalWidgetTile(
                    assetPath: 'assets/newapp/tickets widget.svg',
                    onTap: null,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExternalWidgetTile({
    required String assetPath,
    VoidCallback? onTap,
  }) {
    final isPngAsset = assetPath.toLowerCase().endsWith('.png');

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18.r),
        child: isPngAsset
            ? Image.asset(
                assetPath,
                fit: BoxFit.contain,
              )
            : SvgPicture.asset(
                assetPath,
                fit: BoxFit.contain,
              ),
      ),
    );
  }

  Widget _buildDocumentsWidget({bool isReorderMode = false}) {
    final loginData = SharedPref.getLoginData();
    final widgetData = loginData.result?.data?.defaultWidgets?.data;
    final docsCount =
        widgetData?.myDocumentsWidget?.recordCount?.toString() ?? '0';
    final isDisabled = widgetData?.myDocumentsWidget?.isDisabled == true;

    return Stack(
      children: [
        GrayCardComponent(
          onClick: (isReorderMode || isDisabled)
              ? null
              : () => Util.pushPage(const MyDocumentsScreen(), context),
          cardTitle: translate(''),
          titleColor: Colors.white,
          backgroundImagePath: 'assets/newapp/newicon/my Document (1).png',
          backgroundFit: BoxFit.fill,
          childWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 40.h),
                child: const SizedBox(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMyNotesWidget({bool isReorderMode = false}) {
    final loginData = SharedPref.getLoginData();
    final widgetData = loginData.result?.data?.defaultWidgets?.data;
    final notesData = widgetData?.myNotesWidget?.recordMap;
    final totalNotes =
        ((notesData?['saved_count'] ?? 0) + (notesData?['draft_count'] ?? 0))
            .toString();
    final isDisabled = widgetData?.myNotesWidget?.isDisabled == true;

    return Stack(
      children: [
        GrayCardComponent(
          cardTitle: translate('home.my_notes'),
          backgroundImagePath: 'assets/png/blue_card.png',
          onClick: (isReorderMode || isDisabled)
              ? null
              : () => Navigator.push(
                    context,
                    SlideRightPageRoute(child: const MyNotesScreen()),
                  ),
          childWidget: const SizedBox.shrink(),
        ),
        Positioned(
          right: 6.w,
          top: 30.h,
          child: Opacity(
            opacity: 0.20,
            child: Image.asset('assets/png/notes_icon.png'),
          ),
        ),
        Positioned(
          right: 10.w,
          top: 10.w,
          child: CountWidget(
            count: totalNotes,
            countColor: Colors.black,
            containerColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildTodoListWidget({bool isReorderMode = false}) {
    return Consumer<TasksProvider>(
      builder: (context, tasksProvider, child) {
        if (tasksProvider.status == TasksStatus.initial) {
          Future.microtask(() => tasksProvider.loadTasks());
        }

        final isLoading = tasksProvider.status == TasksStatus.loading ||
            tasksProvider.status == TasksStatus.initial;
        final hasError = tasksProvider.status == TasksStatus.error;
        final todoCount = hasError
            ? '!'
            : isLoading
                ? '...'
                : tasksProvider.tasks.length.toString();

        return Stack(
          children: [
            GrayCardComponent(
              cardTitle: "Task Managment",
              titleColor: Colors.white,
              backgroundImagePath:
                  'assets/newapp/task_managment_widget_backdround.png',
              onClick: isReorderMode
                  ? null
                  : () {
                      if (hasError) {
                        // Show error message in a snackbar when tapped
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(tasksProvider.errorMessage ??
                                'Failed to load tasks'),
                            action: SnackBarAction(
                              label: 'Retry',
                              onPressed: () => tasksProvider.loadTasks(),
                            ),
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      } else {
                        // Navigate to new Tasks Dashboard
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const TasksDashboardScreen(),
                          ),
                        );
                      }
                    },
              childWidget: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : hasError
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.white.withOpacity(0.5),
                                size: 40,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to retry',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
            ),
            /*
            Positioned(
              right: 10.w,
              top: 10.w,
              child: CountWidget(
                count: todoCount,
                countColor: Colors.black,
                containerColor: hasError ? Colors.red.shade100 : Colors.white,
              ),
            ),
            */
          ],
        );
      },
    );
  }

  Widget _buildProjectsWidget({bool isReorderMode = false}) {
    final loginData = SharedPref.getLoginData();
    final widgetData = loginData.result?.data?.defaultWidgets?.data;
    final projectsData = widgetData?.myProjectsWidget?.recordMap;
    final totalProjects = projectsData?['total_projects']?.toString() ?? '0';
    final delayedProjects =
        projectsData?['delayed_projects']?.toString() ?? '0';
    final isDisabled = widgetData?.myProjectsWidget?.isDisabled == true;

    return ClipRRect(
      borderRadius: BorderRadius.circular(23.r),
      child: Stack(
        children: [
          GrayCardComponent(
            cardTitle: translate('home.projects'),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFD6D6D6),
                Color(0xFFADB2BD),
              ],
            ),
            onClick: (isReorderMode || isDisabled)
                ? null
                : () => Util.pushPage(const MyProject(), context),
            childWidget: Directionality(
              textDirection: TextDirection.ltr,
              child: DefaultTextStyle(
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
                child: const SizedBox.shrink(),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.centerRight,
                child: Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    Transform.translate(
                      offset: Offset(50.w, 40.h),
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xB81B1F26), // #1B1F26 with 0.72 opacity
                            Color(0xFF717171),
                          ],
                        ).createShader(bounds),
                        child: Opacity(
                          opacity: 0.16,
                          child: Image.asset(
                            'assets/newapp/Ellipse 106.png',
                            height: 260.h,
                            fit: BoxFit.contain,
                            color: Colors.white,
                            colorBlendMode: BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(10.w, 5.h),
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xB81B1F26), // #1B1F26 with 0.72 opacity
                            Color(0xFF717171),
                          ],
                        ).createShader(bounds),
                        child: Opacity(
                          opacity: 0.16,
                          child: Image.asset(
                            'assets/newapp/Ellipse 105.png',
                            height: 230.h,
                            fit: BoxFit.contain,
                            color: Colors.white,
                            colorBlendMode: BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyRequestWidget({bool isReorderMode = false}) {
    final loginData = SharedPref.getLoginData();
    final widgetData = loginData.result?.data?.defaultWidgets?.data;
    final requestData = widgetData?.myRequestWidget?.recordMap;
    final totalRequests =
        requestData?['total_requests_count']?.toString() ?? '0';
    final waitingApproval =
        requestData?['waiting_for_approval_count']?.toString() ?? '0';
    final isDisabled = widgetData?.myRequestWidget?.isDisabled == true;

    return ClipRRect(
      borderRadius: BorderRadius.circular(23.r),
      child: Stack(
        children: [
          GrayCardComponent(
            cardTitle: 'HR Requests',
            backgroundImagePath: 'assets/newapp/blue_widget_background.png',
            backgroundFit: BoxFit.fill,
            onClick: (isReorderMode || isDisabled)
                ? null
                : () => Util.pushPage(const HrRequestsMenuPage(), context),
            childWidget: const SizedBox.shrink(),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.centerRight,
                child: Opacity(
                  opacity: 0.35,
                  child: Image.asset(
                    'assets/newapp/R.png',
                    height: 220.h,
                    fit: BoxFit.contain,
                    color: const Color.fromARGB(255, 138, 188, 226),
                    colorBlendMode: BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaWidget({bool isReorderMode = false}) {
    final loginData = SharedPref.getLoginData();
    final widgetData = loginData.result?.data?.defaultWidgets?.data;
    final mediaData = widgetData?.mediaWidget?.recordMap;
    final mediaCount = mediaData?['media_count']?.toString() ?? '0';
    // final filesCount = mediaData?['files']?.toString() ?? '0';
    final isDisabled = widgetData?.mediaWidget?.isDisabled == true;

    return Stack(
      children: [
        GrayCardComponent(
          // Keep base component untouched; hide its title for this card only.
          cardTitle: '',
          backgroundImagePath: 'assets/newapp/media_widget_background.png',
          onClick: (isReorderMode || isDisabled)
              ? null
              : () => Util.pushPage(const MediaListScreen(), context),
          childWidget: Directionality(
            textDirection: TextDirection.ltr,
            child: DefaultTextStyle(
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
              child: Padding(
                padding: EdgeInsets.only(top: 80.h),
                child: SizedBox(
                  width: SizeConfig().getWidth(190),
                  height: SizeConfig().getHeight(80),
                  child: const Column(
                    children: [
                      /*
                      CustomBulletPoint(
                        text: translate('home.videos'),
                        textColor: Colors.black,
                        countColor: Colors.black,
                        count: mediaCount,
                        containerColor: Colors.white,
                      ),
                      */
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 36.w,
          top: 16,
          child: Text(
            translate('home.media').toUpperCase(),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.9,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMyReportWidget({bool isReorderMode = false}) {
    final loginData = SharedPref.getLoginData();
    final widgetData = loginData.result?.data?.defaultWidgets?.data;
    final reportsCount =
        widgetData?.myReportsWidget?.recordCount?.toString() ?? '0';
    final isDisabled = widgetData?.myReportsWidget?.isDisabled == true;

    return GrayCardComponent(
      mainIcon: 'assets/png/my_documents.png',
      cardTitle: translate('home.my_report'),
      titleColor: Colors.white,
      backgroundImagePath: 'assets/newapp/my_report_widget_background.png',
      onClick: (isReorderMode || isDisabled)
          ? null
          : () => Util.pushPage(const ReportAppHomeScreen(), context),
      topPadding: true,
      childWidget: const SizedBox.shrink(),
      // childWidget: Container(
      //   width: SizeConfig().getWidth(200),
      //   height: SizeConfig().getHeight(67),
      //   child: Row(
      //     mainAxisAlignment: MainAxisAlignment.center,
      //     crossAxisAlignment: CrossAxisAlignment.center,
      //     children: [
      //       SizedBox(
      //         width: SizeConfig().getWidth(55),
      //         height: SizeConfig().getHeight(42.11),
      //         child: Image.asset('$imagePrefixIcons/id_card.png'),
      //       ),
      //       SizedBox(width: SizeConfig().getWidth(20)),
      //       SizedBox(
      //         width: SizeConfig().getWidth(55),
      //         height: SizeConfig().getHeight(44.40),
      //         child: Image.asset('$imagePrefixIcons/licnc.png'),
      //       ),
      //       SizedBox(width: SizeConfig().getWidth(20)),
      //     ],
      //   ),
      // ),
    );
  }

  Widget _buildAttendanceWidget({bool isReorderMode = false}) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (cxt, state) {
        var bloc = HomeBloc.get(cxt);
        final monthAbbrev = bloc.monthName.length >= 3
            ? bloc.monthName.substring(0, 3).toUpperCase()
            : bloc.monthName.toUpperCase();
        final widgetData =
            SharedPref.getLoginData().result?.data?.defaultWidgets?.data;
        final isDisabled = widgetData?.attendanceWidget?.isDisabled == true;

        return ClipRRect(
          borderRadius: BorderRadius.circular(23.r),
          child: Stack(
            alignment: Alignment.centerRight,
            children: [
              GrayCardComponent(
                cardTitle: translate('home.attendance'),
                backgroundImagePath: 'assets/newapp/blue_widget_background.png',
                onClick: (isReorderMode || isDisabled)
                    ? null
                    : () => Util.pushPage(const AttendancePage(), context),
                childWidget: const SizedBox.shrink(),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(23.r),
                      border: Border.all(
                        color: const Color(0xFFCAD2E5).withOpacity(0.9),
                        width: 1.15,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: SvgPicture.asset(
                    'assets/svg/attendance-effect.svg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Opacity(
                      opacity: 1,
                      child: SvgPicture.asset(
                        'assets/newapp/fingerprint.svg',
                        fit: BoxFit.contain,
                        colorFilter: ColorFilter.mode(
                          Colors.white.withOpacity(0.8),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 8.w,
                top: 6.h,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18.r),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      width: 96.w,
                      height: 32.h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18.r),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.72),
                          width: 0.95,
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.68),
                            const Color(0xFFE4ECF9).withOpacity(0.36),
                            const Color(0xFFD4DFEE).withOpacity(0.20),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.42),
                            blurRadius: 6,
                            offset: const Offset(0, -1),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: 7.w,
                            right: 7.w,
                            top: 2.h,
                            child: Container(
                              height: 7.h,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12.r),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withOpacity(0.52),
                                    const Color(0xFFe1edf5).withOpacity(0.1),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 11.w),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.calendar_month_outlined,
                                    size: 20.sp,
                                    color: const Color(0xFF2B2F6B),
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    monthAbbrev,
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFF2B2F6B),
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.15,
                                      height: 1,
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
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showComingSoonForFiveSeconds() async {
    final currentTap = ++_aiTapVersion;
    if (mounted) {
      setState(() => _aiTapped = true);
    }

    await Future.delayed(const Duration(seconds: 5));

    if (!mounted || currentTap != _aiTapVersion) return;
    setState(() => _aiTapped = false);
  }

  Widget _buildAiSupportWidget() {
    return GestureDetector(
      onTap: _showComingSoonForFiveSeconds,
      child: Container(
        width: double.infinity,
        height: 170.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: const [
            BoxShadow(
              color: Color(0x596B3FA0),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18.r),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/gif/ai.gif',
                  fit: BoxFit.cover,
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        const Color(0xFF1A1040).withOpacity(0.72),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 14.h,
                left: 22.w,
                right: 22.w,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) {
                    final slide = Tween<Offset>(
                      begin: const Offset(1.0, 0.0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOut,
                    ));
                    return SlideTransition(
                      position: slide,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: _aiTapped
                      ? Align(
                          key: const ValueKey('coming'),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Coming` Soon',
                            textAlign: TextAlign.left,
                            style: GoogleFonts.poppins(
                              fontSize: 26.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        )
                      : Align(
                          key: const ValueKey('ai'),
                          alignment: Alignment.centerLeft,
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Ai ',
                                  style: GoogleFonts.poppins(
                                    fontSize: 32.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                TextSpan(
                                  text: 'support',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w400,
                                    color: const Color(0xD9FFFFFF),
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

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: !SharedPref.isUserAuthenticated() ? .5 : 1,
      child: IgnorePointer(
        ignoring: !SharedPref.isUserAuthenticated(),
        child: Column(
          children: [
            const SizedBox(height: 10),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else
              ...activeWidgets.map((widget) {
                return Column(
                  children: [
                    _buildCustomWidget(widget),
                    const SizedBox(height: 10),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }
}
