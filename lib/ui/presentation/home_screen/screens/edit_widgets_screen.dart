import 'package:el_race/ui/presentation/home_screen/data/widget_model.dart';
import 'package:el_race/ui/presentation/home_screen/dialogs/add_widget_dialog.dart';
import 'package:el_race/ui/presentation/home_screen/dialogs/save_confirmation_dialog.dart';
import 'package:el_race/ui/presentation/home_screen/screens/home_screen.dart';
import 'package:el_race/ui/presentation/home_screen/screens/main_screens.dart';
import 'package:el_race/ui/presentation/home_screen/services/widget_service.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/card_tile.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/custom_bullet_point.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/tilting_card.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:el_race/utils/Util.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:el_race/utils/orientation_helper.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:el_race/utils/string_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../bloc/home_bloc.dart';

class EditWidgetsScreen extends StatefulWidget {
  const EditWidgetsScreen({super.key});

  @override
  State<EditWidgetsScreen> createState() => _EditWidgetsScreenState();
}

class _EditWidgetsScreenState extends State<EditWidgetsScreen> {
  List<WidgetModel> activeWidgets = [];
  bool isLoading = true;
  bool hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadActiveWidgets();
  }

  Future<void> _loadActiveWidgets() async {
    final widgets = await WidgetService.getActiveWidgets();
    setState(() {
      activeWidgets = widgets;
      isLoading = false;
    });
  }

  void _showAddWidgetDialog() {
    showDialog(
      context: context,
      builder: (context) => AddWidgetDialog(
        onWidgetAdded: () {
          _loadActiveWidgets();
          setState(() {
            hasChanges = true;
          });
        },
      ),
    );
  }

  void _removeWidget(String widgetId, HomeBloc bloc) {
    setState(() {
      bloc.isEdit = true;
      activeWidgets.removeWhere((w) => w.id == widgetId);
      hasChanges = true;
    });
  }

  void _reorderWidgets(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final widget = activeWidgets.removeAt(oldIndex);
      activeWidgets.insert(newIndex, widget);
      hasChanges = true;
    });
  }

  void _showSaveDialog(HomeBloc bloc) {
    showDialog(
      context: context,
      builder: (context) => SaveConfirmationDialog(
        onSave: () => _saveChanges(),
        onCancel: () {
          bloc.isEdit = false;
          Navigator.of(context).pop(); // يغلق الدialog
          Future.microtask(() {
            Navigator.of(context)
                .pop(); // يرجع للشاشة السابقة بأمان بعد إغلاق الدialog
          });
        },
      ),
    );
  }

  Future<void> _saveChanges() async {
    await WidgetService.saveActiveWidgets(activeWidgets);
    setState(() {
      hasChanges = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Widget changes saved successfully'),
        backgroundColor: Color(0xFF4CAF50),
      ),
    );
    Util.pushPageAndRemoveRoutes(const HomeScreen(), context);
  }

  @override
  Widget build(BuildContext context) {
    var bloc = HomeBloc.get(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (bloc.isEdit) {
          _showSaveDialog(bloc);
        } else {
          bloc.isEdit = false;
          if (mounted) {
            Navigator.of(context).pop();
          }
        }

        if (didPop) return;
      },
      child: Scaffold(
        backgroundColor: lightGrey,
        appBar: const HeaderWidget(),
        extendBody: false,
        bottomNavigationBar: const CustomBottomNavBar(
          isMain: false,
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                alignment: Alignment.topCenter,
                children: [
                  Builder(
                    builder: (context) {
                      return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.only(
                            left: SizeConfig().getWidth(16),
                            right: SizeConfig().getWidth(16),
                            top: SizeConfig().getWidth(16),
                            bottom: SizeConfig().getWidth(16) +
                                kBottomNavigationBarHeight +
                                context.systemBottomInset +
                                20,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  BackButton(onPressed: () {
                                    if (bloc.isEdit) {
                                      _showSaveDialog(bloc);
                                    } else {
                                      bloc.isEdit = false;
                                      if (mounted) {
                                        Navigator.of(context).pop();
                                      }
                                    }
                                  }),
                                  Text(
                                    'Edit Widgets',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w400,
                                      color: appFontColor,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _showSaveDialog(bloc),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Image.asset(
                                          'assets/png/save.gif',
                                          width: 45.sp,
                                          height: 45.sp,
                                          fit: BoxFit.cover,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          'Save',
                                          style: GoogleFonts.poppins(
                                            fontSize: 15.sp,
                                            fontWeight: FontWeight.w600,
                                            color: black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: _showAddWidgetDialog,
                                child: Container(
                                  width: double.infinity,
                                  height: SizeConfig().getHeight(175),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    image: const DecorationImage(
                                      image: AssetImage(
                                          'assets/png/add_widgets.png'),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  // child: Center(
                                  //   child: Column(
                                  //     mainAxisAlignment: MainAxisAlignment.center,
                                  //     children: [
                                  //       Container(
                                  //         width: 50,
                                  //         height: 50,
                                  //         decoration: BoxDecoration(
                                  //           color: white.withAlpha((0.9 * 255).toInt()),
                                  //           borderRadius: BorderRadius.circular(25),
                                  //         ),
                                  //         child: Icon(
                                  //           Icons.add,
                                  //           color: const Color(0xFF4CAF50),
                                  //           size: 30.sp,
                                  //         ),
                                  //       ),
                                  //       const SizedBox(height: 8),
                                  //       Text(
                                  //         'Add Widget',
                                  //         style: GoogleFonts.poppins(
                                  //           fontSize: 16.sp,
                                  //           fontWeight: FontWeight.w600,
                                  //           color: white,
                                  //         ),
                                  //       ),
                                  //     ],
                                  //   ),
                                  // ),
                                ),
                              ),
                              if (activeWidgets.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.widgets_outlined,
                                        size: 64.sp,
                                        color: const Color(0xFF858585),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No widgets added yet',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF858585),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Tap the add button above to add your first widget',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14.sp,
                                          color: const Color(0xFF858585),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ReorderableListView.builder(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.only(bottom: 100.w),
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: activeWidgets.length,
                                  onReorder: _reorderWidgets,
                                  itemBuilder: (context, index) {
                                    final widgetItem = activeWidgets[index];
                                    return TiltingCard(
                                      key: ValueKey(index),
                                      child: _buildWidgetCard(widgetItem, bloc),
                                    );
                                  },
                                ),
                            ],
                          ));
                    },
                  ),
                  // const ArraowVisibalityBottomNav(),
                ],
              ),
      ),
    );
  }

  Widget _buildWidgetCard(WidgetModel widget, HomeBloc bloc) {
    return Container(
      key: ValueKey(widget.id),
      margin: const EdgeInsets.only(bottom: 10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildActualWidget(widget),
          Positioned(
            right: -6.w,
            top: -6.w,
            child: GestureDetector(
              onTap: () => _removeWidget(widget.id, bloc),
              child: Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFBA1719),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: black.withAlpha((0.3 * 255).toInt()),
                      spreadRadius: 2,
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.remove,
                  color: white,
                  size: 16.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActualWidget(WidgetModel widget) {
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
          mainIcon: 'assets/png/time_sheet.png',
          cardTitle: translate('home.time_sheet'),
          backgroundImagePath: 'assets/png/gray_card.png',
          topPadding: true,
          topPaddingValue: 40,
          childWidget: Padding(
            padding: EdgeInsets.only(left: 210.w),
            child: Image.asset(
              'assets/png/time_sheet.png',
              width: SizeConfig().getWidth(140),
              height: SizeConfig().getHeight(140),
            ),
          ),
        ),
        Positioned(
          left: 16.w,
          bottom: 16.h,
          child: Image.asset(
            'assets/png/time-sheet-icon.png',
            width: 60.w,
            height: 60.w,
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
        padding: EdgeInsets.only(left: 210.w),
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
                      // bulletColor: Color(0xFF009859),
                      text: 'In progress',
                      textColor: Colors.black,
                      countColor: Colors.white,
                      count: '15',
                      containerColor: Colors.white,
                    ),
                    SizedBox(height: 4),
                    CustomBulletPoint(
                      // bulletColor: Color(0xFFBA1719),
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
                      count: '7',
                      containerColor: Colors.white,
                    ),
                    CustomBulletPoint(
                      //bulletColor: const Color(0xFFBA1719),
                      text: translate('photos'),
                      textColor: Colors.black,
                      countColor: Colors.black,
                      count: '20',
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
}
