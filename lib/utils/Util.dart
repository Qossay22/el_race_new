import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/lpo/screens/lpo_pdf_viewer_screen.dart';
import 'package:el_race/ui/presentation/call_screen/bloc/contact_bloc.dart';
import 'package:el_race/ui/presentation/home_screen/bloc/home_bloc.dart';
import 'package:el_race/ui/presentation/my_request/bloc/requests_bloc.dart';
import 'package:el_race/ui/presentation/my_request/bloc/requests_event.dart';
import 'package:el_race/ui/widgets/custom_toast.dart';
import 'package:el_race/utils/custom_navigate.dart';
import 'package:el_race/utils/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' show BlocProvider;
import 'package:flutter_translate/flutter_translate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:el_race/utils/api_logger.dart';

class Util {
  static fetchHomeScreenData(BuildContext cxt) {
    try {
      // Ensure DI is initialized before accessing blocs
      if (!sl.isRegistered<HomeBloc>()) {
        print('⚠️ HomeBloc not registered, initializing DI...');
        initDI();
      }

      BlocProvider.of<HomeBloc>(cxt, listen: false)
          .add(const FetchLastMonthAttendanceSummary());

      BlocProvider.of<RequestsBloc>(cxt, listen: false)
          .add(const FetchRequestsCount());

      BlocProvider.of<ContactBloc>(cxt, listen: false).add(GetEmployeeLisET());
    } catch (e) {
      print('❌ Error in fetchHomeScreenData: $e');
      // Try to re-initialize DI and retry once
      try {
        initDI();
        BlocProvider.of<HomeBloc>(cxt, listen: false)
            .add(const FetchLastMonthAttendanceSummary());
        BlocProvider.of<RequestsBloc>(cxt, listen: false)
            .add(const FetchRequestsCount());
        BlocProvider.of<ContactBloc>(cxt, listen: false).add(GetEmployeeLisET());
      } catch (retryError) {
        print('❌ Retry also failed: $retryError');
        // Silent fail - the home screen will try to load data itself
      }
    }
  }

  static Future<void> saveAndChangeLocale(
      BuildContext context, String languageCode) async {
    await SharedPref().setAppLanguage(languageCode);
    await changeLocale(context, languageCode);
    // pushPage(const HomeScreen(), context);
  }

  static pushPage(Widget route, BuildContext cxt) {
    return Navigator.push(
      cxt,
      CustomPageRoute(child: route),
    );
  }

  static pushPageAndRemoveRoutes(Widget pushRoute, BuildContext cxt) {
    Navigator.of(cxt).pushAndRemoveUntil(
      CustomPageRoute(child: pushRoute),
      (route) => false,
    );
  }

  static Future<void> openUrl(String url) async {
    print(url);
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }

  static void showComingSoonToast() {
    CustomToast().showToast("Coming Soon 🚧", isCenter: true);
  }

  static String monthName(int month) {
    const monthNames = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "June",
      "July",
      "Aug",
      "Sept",
      "Oct",
      "Nov",
      "Dec"
    ];
    return month >= 1 && month <= 12 ? monthNames[month - 1] : "";
  }

  static void hideKeyBoard(BuildContext context) {
    FocusScope.of(context).requestFocus(FocusNode());
  }

  static void showToast(String body) {
    CustomToast().showToast(body);
  }

  static bool isValidBase64(String str) {
    try {
      if (str.trim().isEmpty || str.length % 4 != 0) return false;
      base64Decode(str);
      return true;
    } catch (_) {
      return false;
    }
  }

  static isValidDateTime(String? value) {
    if (value == null || value.isEmpty) return false;

    try {
      DateTime.parse(value);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Fetches the PDF report URL for a given PO ID and opens it
  /// Returns true if successful, false otherwise
  static Future<bool> openLpoPdfReport(BuildContext context, int poId) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading PDF...'),
          duration: Duration(seconds: 1),
        ),
      );

      final token = SharedPref.getLoginData().result?.token ?? '';
      final url = Uri.parse('https://erp.elrace.com/api/po/report_url');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final body = jsonEncode({
        'jsonrpc': '2.0',
        'params': {
          'po_id': poId,
        },
      });

      // 📤 Log Request
      ApiLogger.logRequest(
        endpoint: url.toString(),
        method: 'POST',
        headers: headers,
        body: body,
      );

      final startTime = DateTime.now();
      final response = await http.post(url, headers: headers, body: body);
      final duration = DateTime.now().difference(startTime);

      if (response.statusCode != 200) {
        ApiLogger.logResponse(
          endpoint: url.toString(),
          statusCode: response.statusCode,
          responseBody: {'error': 'HTTP ${response.statusCode}'},
          duration: duration,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load PDF: HTTP ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }

      final data = jsonDecode(response.body);

      // 📥 Log Response
      ApiLogger.logResponse(
        endpoint: url.toString(),
        statusCode: response.statusCode,
        responseBody: data,
        duration: duration,
      );

      if (data['result']?['status'] == 'success' &&
          data['result']?['report_url'] != null) {
        final pdfUrl = data['result']['report_url'] as String;

        // Open PDF in-app using LpoPdfViewerScreen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LpoPdfViewerScreen(
              pdfUrl: pdfUrl,
              title: 'LPO Report #$poId',
            ),
          ),
        );
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['result']?['error'] ?? 'Failed to retrieve PDF URL',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    } catch (e, stackTrace) {
      ApiLogger.logError(
        endpoint: 'https://erp.elrace.com/api/po/report_url',
        error: e,
        stackTrace: stackTrace,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }
}
