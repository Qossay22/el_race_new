import 'package:flutter/services.dart';

/// خدمة لطلب تجاهل تحسينات البطارية لضمان عمل الأذان في الخلفية
class BatteryOptimizationService {
  static const platform = MethodChannel('com.el_race.app/battery_optimization');

  /// التحقق إذا كان التطبيق مستثنى من تحسينات البطارية
  static Future<bool> isBatteryOptimizationIgnored() async {
    try {
      final bool result =
          await platform.invokeMethod('isBatteryOptimizationIgnored');
      return result;
    } catch (e) {
      print('Error checking battery optimization: $e');
      return false;
    }
  }

  /// طلب تجاهل تحسينات البطارية من المستخدم
  static Future<void> requestBatteryOptimizationPermission() async {
    try {
      await platform.invokeMethod('requestBatteryOptimization');
    } catch (e) {
      print('Error requesting battery optimization permission: $e');
    }
  }

  /// طلب الصلاحية إذا لم تكن ممنوحة
  static Future<void> ensureBatteryOptimizationIgnored() async {
    final isIgnored = await isBatteryOptimizationIgnored();
    if (!isIgnored) {
      await requestBatteryOptimizationPermission();
    }
  }
}
