import 'package:el_race/ui/presentation/home_screen/data/widget_model.dart';
import 'package:el_race/ui/presentation/home_screen/services/widget_service.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/card_tile.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/custom_bullet_point.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/tilting_card.dart';
import 'package:el_race/ui/presentation/tasks/tasks_screen.dart';
import 'package:el_race/utils/Util.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:el_race/utils/orientation_helper.dart';
import 'package:el_race/utils/string_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../bloc/home_bloc.dart';

class AddWidgetDialog extends StatefulWidget {
  final Function() onWidgetAdded;

  const AddWidgetDialog({
    super.key,
    required this.onWidgetAdded,
  });

  @override
  State<AddWidgetDialog> createState() => _AddWidgetDialogState();
}

class _AddWidgetDialogState extends State<AddWidgetDialog> {
  List<WidgetModel> availableWidgets = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableWidgets();
  }

  Future<void> _loadAvailableWidgets() async {
    final widgets = await WidgetService.getAvailableWidgetsWithState();
    final inactiveWidgets = widgets.where((w) => !w.isActive).toList();

    setState(() {
      availableWidgets = inactiveWidgets;
      isLoading = false;
    });
  }

  Future<void> _addWidget(String widgetId, HomeBloc bloc) async {
    await WidgetService.toggleWidget(widgetId);
    bloc.isEdit = true;
    widget.onWidgetAdded();
    Navigator.of(context).pop();
  }

  void _openWidget(WidgetModel widgetModel) {
    Navigator.of(context).pop();
    // Navigate to the widget screen based on widget id
    switch (widgetModel.id) {
      case 'todo_list':
        Util.pushPage(const TasksScreen(), context);
        break;
      // Add other cases as needed
      default:
        break;
    }
  }

  Widget _buildWidgetPreview(WidgetModel widget) {
    switch (widget.id) {
      case 'time_sheet':
        return _buildTimeSheetPreview();
      case 'petty_cash':
        return _buildPettyCashPreview();
      case 'lpo':
        return _buildLPOPreview();
      case 'documents':
        return _buildDocumentsPreview();
      case 'my_notes':
        return _buildMyNotesPreview();
      case 'todo_list':
        return _buildTodoListPreview();
      case 'projects':
        return _buildProjectsPreview();
      case 'my_request':
        return _buildMyRequestPreview();
      case 'media':
        return _buildMediaPreview();
      case 'my_report':
        return _buildMyReportPreview();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTimeSheetPreview() {
    return Stack(
      children: [
        GrayCardComponent(
          onClick: null,
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
                  '250',
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontSize: 22.w,
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

  Widget _buildPettyCashPreview() {
    return const GrayCardComponent(
      onClick: null,
      cardTitle: 'Petty Cash',
      backgroundImagePath: 'assets/png/pettycash_new_bg.png',
      childWidget: SizedBox.shrink(),
    );
  }

  Widget _buildLPOPreview() {
    return GrayCardComponent(
      onClick: null,
      mainIcon: 'assets/png/time_sheet.png',
      cardTitle: 'LPO',
      backgroundImagePath: 'assets/png/gray_card.png',
      topPadding: true,
      topPaddingValue: 40,
      childWidget: Padding(
        padding: EdgeInsets.only(left: 170.w),
        child: Image.asset(
          'assets/png/lpo.png',
          width: SizeConfig().getWidth(140),
          height: SizeConfig().getHeight(140),
        ),
      ),
    );
  }

  Widget _buildDocumentsPreview() {
    return Stack(
      children: [
        GrayCardComponent(
          onClick: null,
          cardTitle: translate('home.documents'),
          backgroundImagePath: 'assets/png/gray_card.png',
          childWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              DefaultTextStyle(
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                  color: Color(0xFF1A1A53),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 52),
                  child: SizedBox(
                    width: SizeConfig().getWidth(270),
                    height: SizeConfig().getHeight(50),
                    child: Image.asset('assets/newapp/simple_cards.png'),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 6,
          top: 30,
          child: Image.asset('assets/png/icons/doc_icon.png'),
        ),
      ],
    );
  }

  Widget _buildMyNotesPreview() {
    return Stack(
      children: [
        GrayCardComponent(
          cardTitle: translate('my notes'),
          backgroundImagePath: 'assets/png/blue_card.png',
          onClick: null,
          topPadding: true,
          childWidget: DefaultTextStyle(
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: SizeConfig().getWidth(40),
                  height: SizeConfig().getHeight(150),
                  child: Image.asset(
                    'assets/png/not_icon.png',
                    color: const Color(0xff1A1A53),
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 10),
                const CountWidget(
                  count: '200',
                  countColor: Colors.white,
                  width: 30,
                  containerColor: Color(0xff1A1A53),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 6,
          top: 30,
          child: Opacity(
            opacity: 0.20,
            child: Image.asset('assets/png/notes_icon.png'),
          ),
        ),
      ],
    );
  }

  Widget _buildTodoListPreview() {
    return Stack(
      children: [
        GrayCardComponent(
          cardTitle: translate('home.todo_list'),
          backgroundImagePath: 'assets/png/blue_card.png',
          onClick: null,
          childWidget: const SizedBox.shrink(),
        ),
        Positioned(
          right: 6.w,
          top: 30.h,
          child: Opacity(
            opacity: 0.20,
            child: Image.asset(
              'assets/png/notes_icon.png',
              errorBuilder: (_, __, ___) => Icon(
                Icons.check_box_outlined,
                size: 80.w,
                color: Colors.white.withOpacity(0.2),
              ),
            ),
          ),
        ),
        Positioned(
          right: 10.w,
          top: 10.w,
          child: const CountWidget(
            count: '...',
            countColor: Colors.black,
            containerColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildProjectsPreview() {
    return Stack(
      children: [
        GrayCardComponent(
          cardTitle: translate('home.projects'),
          backgroundImagePath: 'assets/png/gray_card.png',
          onClick: null,
          childWidget: DefaultTextStyle(
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 80),
              child: SizedBox(
                width: SizeConfig().getWidth(190),
                height: SizeConfig().getHeight(80),
                child: const Column(
                  children: [
                    CustomBulletPoint(
                      //bulletColor: Color(0xFF009859),
                      text: 'In progress',
                      textColor: Colors.black,
                      countColor: Colors.black,
                      count: '15',
                      containerColor: Colors.white,
                    ),
                    SizedBox(height: 4),
                    CustomBulletPoint(
                      //bulletColor: Color(0xFFBA1719),
                      text: 'Delay',
                      textColor: Colors.black,
                      countColor: Colors.black,
                      count: '2',
                      containerColor: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 30,
          child: Opacity(
            opacity: .12,
            child: Image.asset('assets/newapp/my_projects.png'),
          ),
        ),
      ],
    );
  }

  Widget _buildMyRequestPreview() {
    return Stack(
      children: [
        GrayCardComponent(
          cardTitle: translate('home.my_request'),
          backgroundImagePath: 'assets/png/gray_card.png',
          onClick: null,
          childWidget: DefaultTextStyle(
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 80),
              child: SizedBox(
                width: SizeConfig().getWidth(190),
                height: SizeConfig().getHeight(80),
                child: Column(
                  children: [
                    CustomBulletPoint(
                      //bulletColor: const Color(0xFF009859),
                      text: translate('Approved'),
                      textColor: Colors.black,
                      countColor: Colors.black,
                      count: '5',
                      containerColor: Colors.white,
                    ),
                    CustomBulletPoint(
                      // bulletColor: const Color(0xFFBA1719),
                      text: translate('home.rejected'),
                      textColor: Colors.black,
                      countColor: Colors.black,
                      count: '5',
                      containerColor: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: -40,
          child: Image.asset('assets/png/my_request.png'),
        ),
      ],
    );
  }

  Widget _buildMediaPreview() {
    return Stack(
      children: [
        GrayCardComponent(
          cardTitle: translate('Media'),
          backgroundImagePath: 'assets/png/gray_card.png',
          onClick: null,
          childWidget: DefaultTextStyle(
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 80),
              child: SizedBox(
                width: SizeConfig().getWidth(190),
                height: SizeConfig().getHeight(80),
                child: Column(
                  children: [
                    CustomBulletPoint(
                      // bulletColor: const Color(0xFF009859),
                      text: translate('videos'),
                      textColor: Colors.black,
                      countColor: Colors.black,
                      containerColor: Colors.white,
                      count: '7',
                    ),
                    CustomBulletPoint(
                      // bulletColor: const Color(0xFFBA1719),
                      text: translate('photos'),
                      textColor: Colors.black,
                      countColor: Colors.black,
                      containerColor: Colors.white,
                      count: '20',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 30,
          child: Opacity(
            opacity: .20,
            child: Image.asset('assets/png/icons/media_icon.png'),
          ),
        ),
      ],
    );
  }

  Widget _buildMyReportPreview() {
    return GrayCardComponent(
      mainIcon: 'assets/png/my_documents.png',
      cardTitle: translate('home.my_report'),
      backgroundImagePath: 'assets/png/notes_new_bg.png',
      onClick: null,
      topPadding: true,
      childWidget: const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    var bloc = HomeBloc.get(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: black.withAlpha((0.1 * 255).toInt()),
                  spreadRadius: 2,
                  blurRadius: 10,
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  if (isLoading)
                    const CircularProgressIndicator()
                  else if (availableWidgets.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'All widgets are already added',
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          color: const Color(0xFF858585),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Column(
                      children: availableWidgets.map((widget) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: TiltingCard(
                            key: ValueKey(widget.id),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                GestureDetector(
                                  onTap: () => _openWidget(widget),
                                  child: _buildWidgetPreview(widget),
                                ),
                                Positioned(
                                  right: -6.w,
                                  top: -6.w,
                                  child: GestureDetector(
                                    onTap: () => _addWidget(widget.id, bloc),
                                    child: Container(
                                      padding: EdgeInsets.all(6.w),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1A1A53),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: black
                                                .withAlpha((0.3 * 255).toInt()),
                                            spreadRadius: 2,
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.add,
                                        color: white,
                                        size: 16.sp,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 5,
            top: 4,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: EdgeInsets.all(3.w),
                decoration: const BoxDecoration(
                  color: red,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 24.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
