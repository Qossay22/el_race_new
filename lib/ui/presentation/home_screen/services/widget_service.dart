import 'dart:convert';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/home_screen/data/widget_model.dart';

class WidgetService {
  static const String _activeWidgetsKey = 'active_widgets';

  static Future<List<WidgetModel>> getActiveWidgets() async {
    final activeWidgetsJson =
        SharedPref().getPreferenceString(_activeWidgetsKey);

    if (activeWidgetsJson.isEmpty) {
      // Initialize with default widgets if none are saved
      await _initializeDefaultWidgets();
      return await getActiveWidgets();
    }

    try {
      final List<dynamic> decoded = jsonDecode(activeWidgetsJson);
      List<WidgetModel> widgets = decoded.map((json) => WidgetModel.fromJson(json)).toList();
      
      // Add time_sheet if not present (migration)
      if (!widgets.any((w) => w.id == 'time_sheet')) {
        final timeSheetWidget = getAvailableWidgets().firstWhere(
          (w) => w.id == 'time_sheet',
        );
        widgets.insert(0, timeSheetWidget.copyWith(isActive: true));
        await saveActiveWidgets(widgets);
      }
      
      return widgets;
    } catch (e) {
      return [];
    }
  }

  static Future<void> _initializeDefaultWidgets() async {
    final defaultWidgets = [
      'time_sheet',
      'petty_cash',
      'lpo',
      'documents',
      // 'my_notes', // Hidden
      'todo_list',
      'projects',
      'my_request',
      'media',
      'my_report',
      'qr_code',
      'attendance',
      'prayer'
    ];

    final allWidgets = getAvailableWidgets();
    final activeWidgets = allWidgets
        .where((widget) => defaultWidgets.contains(widget.id))
        .map((widget) => widget.copyWith(isActive: true))
        .toList();

    await saveActiveWidgets(activeWidgets);
  }

  static Future<void> saveActiveWidgets(List<WidgetModel> widgets) async {
    final widgetsJson = jsonEncode(widgets.map((w) => w.toJson()).toList());
    SharedPref().setPreferencesString(_activeWidgetsKey, widgetsJson);
  }

  static Future<List<WidgetModel>> getAvailableWidgetsWithState() async {
    final activeWidgets = await getActiveWidgets();
    final allWidgets = getAvailableWidgets();

    return allWidgets.map((widget) {
      final isActive = activeWidgets.any((active) => active.id == widget.id);
      return widget.copyWith(isActive: isActive);
    }).toList();
  }

  static Future<void> toggleWidget(String widgetId) async {
    final currentWidgets = await getActiveWidgets();
    final widgetExists = currentWidgets.any((w) => w.id == widgetId);

    if (widgetExists) {
      currentWidgets.removeWhere((w) => w.id == widgetId);
    } else {
      final availableWidget =
          getAvailableWidgets().firstWhere((w) => w.id == widgetId);
      currentWidgets.add(availableWidget.copyWith(isActive: true));
    }

    await saveActiveWidgets(currentWidgets);
  }

  static Future<void> resetToDefaultWidgets() async {
    await _initializeDefaultWidgets();
  }
}
