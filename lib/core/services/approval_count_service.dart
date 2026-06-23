import 'dart:convert';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:http/http.dart' as http;

class ApprovalCountService {
  // Callback to notify when approval count changes
  static void Function()? onCountChanged;

  /// Cached count — set by the Approval screen after loading real data.
  /// -1 means no cache yet (will fetch from API).
  static int _cachedCount = -1;

  /// Called by the Approval screen after it has loaded all items.
  /// Avoids a redundant API call and keeps the badge in sync with what's visible.
  static void updateCachedCount(int count) {
    _cachedCount = count;
    onCountChanged?.call();
  }

  /// Invalidate the cache (call on logout or when the screen is disposed).
  static void invalidateCache() {
    _cachedCount = -1;
  }

  static Future<int> getTotalApprovalCount() async {
    // Return cached value immediately if available
    if (_cachedCount >= 0) {
      return _cachedCount;
    }
    try {
      final token = SharedPref.getLoginData().result?.token;
      if (token == null || token.isEmpty) {
        return 0;
      }

      // Fetch counts from all categories in parallel
      final results = await Future.wait([
        _fetchCategoryCount("hr", token),
        _fetchCategoryCount("rfq", token),
        _fetchCategoryCount("invoice", token),
        _fetchCategoryCount("petty_cash", token),
      ]);

      // Sum all counts
      final totalCount = results.reduce((a, b) => a + b);
      _cachedCount = totalCount;
      // print('📊 Total approval count: $totalCount (HR: ${results[0]}, RFQ: ${results[1]}, Invoice: ${results[2]}, Petty Cash: ${results[3]})');
      return totalCount;
    } catch (e) {
      // print('❌ Error getting approval count: $e');
      return 0;
    }
  }

  static Future<int> _fetchCategoryCount(String category, String token) async {
    try {
      final headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      };

      final url = Uri.parse("https://erp.elrace.com/api/my_approvals_grouped");

      final body = jsonEncode({
        "jsonrpc": "2.0",
        "params": {
          "group_type": category,
        },
      });

      final request = http.Request('GET', url)
        ..headers.addAll(headers)
        ..body = body;

      final response = await request.send().timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final Map<String, dynamic> jsonData = json.decode(responseBody);
        final result = jsonData['result'];

        if (result != null && result['data'] != null) {
          // Map the category to the actual response key
          const Map<String, String> responseKeys = {
            "hr": "human_resources",
            "rfq": "rfq",
            "invoice": "invoices",
            "petty_cash": "petty_cash",
          };

          final actualKey = responseKeys[category] ?? category;
          final data = result['data'][actualKey];

          if (data is List) {
            // print('📊 Category $category: ${data.length} total pending');
            return data.length;
          }
        }
      }
      return 0;
    } catch (e) {
      // print('⚠️ Error fetching $category count: $e');
      return 0;
    }
  }
}
