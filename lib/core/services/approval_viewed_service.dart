import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Service to track which approval items have been viewed by the user
/// This helps reduce the badge count when items are opened
class ApprovalViewedService {
  static const String _viewedItemsKey = 'viewed_approval_items';

  /// Normalize type names to match the backend format
  static String _normalizeType(String type) {
    final normalized = type.toLowerCase().trim();
    switch (normalized) {
      case 'pettycash':
      case 'petty_cash':
        return 'petty_cash';
      case 'hr':
      case 'human_resources':
        return 'hr';
      case 'rfq':
        return 'rfq';
      case 'invoice':
      case 'invoices':
        return 'invoice';
      default:
        return normalized;
    }
  }

  /// Mark an approval item as viewed
  ///
  /// [type] can be: 'hr', 'rfq', 'invoice', 'petty_cash', 'pettycash', etc
  /// [id] is the unique identifier of the item
  static Future<void> markAsViewed(String type, String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final viewedItems = await getViewedItems();

      // Normalize and create a unique key combining type and id
      final normalizedType = _normalizeType(type);
      final key = '${normalizedType}_$id';

      // print('🔵 markAsViewed called:');
      // print('   - Original type: $type');
      // print('   - Normalized type: $normalizedType');
      // print('   - ID: $id');
      // print('   - Key: $key');
      // print('   - Already viewed: ${viewedItems.contains(key)}');

      if (!viewedItems.contains(key)) {
        viewedItems.add(key);
        await prefs.setString(_viewedItemsKey, json.encode(viewedItems));
        // print('✅ Marked as viewed: $key');
        // print('   - Total viewed items: ${viewedItems.length}');

        // Notify that approval count has changed
        _notifyCountChanged();
      } else {
        // print('⚠️ Already viewed: $key');
      }
    } catch (e) {
      // print('❌ Error marking item as viewed: $e');
    }
  }

  /// Notify listeners that the approval count has changed
  static void _notifyCountChanged() {
    // Import ApprovalCountService dynamically to avoid circular dependency
    try {
      // print('🔔 _notifyCountChanged called');
      // This will trigger the header widget to reload the count
      final callback = _onCountChangedCallback;
      // print('   - Callback exists: ${callback != null}');
      if (callback != null) {
        // print('   - Calling callback...');
        callback();
        // print('   - ✅ Callback executed');
      } else {
        // print('   - ⚠️ No callback registered');
      }
    } catch (e) {
      // print('⚠️ Error notifying count changed: $e');
    }
  }

  /// Callback to notify when an item is marked as viewed
  static void Function()? _onCountChangedCallback;

  /// Set the callback for when count changes
  static void setOnCountChangedCallback(void Function()? callback) {
    _onCountChangedCallback = callback;
  }

  /// Get all viewed item keys
  static Future<List<String>> getViewedItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final viewedString = prefs.getString(_viewedItemsKey);

      if (viewedString != null && viewedString.isNotEmpty) {
        final List<dynamic> decoded = json.decode(viewedString);
        return decoded.cast<String>();
      }
      return [];
    } catch (e) {
      // print('❌ Error getting viewed items: $e');
      return [];
    }
  }

  /// Get viewed items for a specific type
  static Future<List<String>> getViewedItemsForType(String type) async {
    try {
      final allViewed = await getViewedItems();
      return allViewed
          .where((key) => key.startsWith('${type}_'))
          .map((key) => key.replaceFirst('${type}_', ''))
          .toList();
    } catch (e) {
      // print('❌ Error getting viewed items for type: $e');
      return [];
    }
  }

  /// Check if a specific item has been viewed
  static Future<bool> isViewed(String type, String id) async {
    try {
      final viewedItems = await getViewedItems();
      final key = '${type}_$id';
      return viewedItems.contains(key);
    } catch (e) {
      // print('❌ Error checking if item is viewed: $e');
      return false;
    }
  }

  /// Clear all viewed items (useful for logout or data reset)
  static Future<void> clearAllViewed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_viewedItemsKey);
      // print('✅ Cleared all viewed approval items');
    } catch (e) {
      // print('❌ Error clearing viewed items: $e');
    }
  }

  /// Clear viewed items for a specific type
  static Future<void> clearViewedForType(String type) async {
    try {
      final allViewed = await getViewedItems();
      final filtered =
          allViewed.where((key) => !key.startsWith('${type}_')).toList();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_viewedItemsKey, json.encode(filtered));
      // print('✅ Cleared viewed items for type: $type');
    } catch (e) {
      // print('❌ Error clearing viewed items for type: $e');
    }
  }
}
