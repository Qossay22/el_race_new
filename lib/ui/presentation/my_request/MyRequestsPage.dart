import 'dart:async';
import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/my_request/RequestEffectiveDate.dart';
import 'package:el_race/ui/presentation/my_request/RequestJobMissionPage.dart';
import 'package:el_race/ui/presentation/my_request/RequestLeavePage.dart';
import 'package:el_race/ui/presentation/my_request/RequestPermission.dart';
import 'package:el_race/ui/presentation/my_request/HrRequestsMenuPage.dart';
import 'package:el_race/utils/api_logger.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../widgets/header_widget.dart';

class MyRequestsPage extends StatefulWidget {
  const MyRequestsPage({
    super.key,
  });

  @override
  _MyRequestsPageState createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends State<MyRequestsPage> {
  String selectedRequestType = "Choose your request";
  bool isDropdownOpen = false;
  bool isLoading = true;
  Set<int> expandedItems = {};
  String error = '';
  List<dynamic> requests = [];
  List<dynamic> _allRequests = [];

  final List<String> requestOptions = [
    'Leave',
    'Job Mission',
    'Effective Date',
    'Temporary Permission',
  ];
  TextEditingController searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchRequests();
    searchController.addListener(() {
      final text = searchController.text.trim();
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        if (text.isEmpty) {
          setState(() {
            requests = List<dynamic>.from(_allRequests);
          });
        } else {
          // Prefer server-side search if available
          _fetchRequests(keyword: text);
        }
      });
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchRequests({String keyword = ""}) async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      error = '';
    });

    try {
      final token = SharedPref.getLoginData().result?.token;

      final headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      };

      final body = jsonEncode({
        "jsonrpc": "2.0",
        "params": {"keyword": keyword},
      });

      final url = Uri.parse("https://erp.elrace.com/api/my_requests");

      // 📤 Log Request
      ApiLogger.logRequest(
        endpoint: url.toString(),
        method: 'GET',
        headers: headers,
        body: body,
      );

      final request = http.Request('GET', url)
        ..headers.addAll(headers)
        ..body = body;

      final startTime = DateTime.now();
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final duration = DateTime.now().difference(startTime);

      debugPrint("response: ${response.body}");

      final responseData = jsonDecode(response.body);

      // 📥 Log Response
      ApiLogger.logResponse(
        endpoint: url.toString(),
        statusCode: response.statusCode,
        responseBody: responseData,
        duration: duration,
      );
      if (response.statusCode == 200) {
        final data = responseData;
        final List<dynamic> items = data['result']['data'];

        if (!mounted) return; // ✅ Check again after async call
        setState(() {
          if (keyword.isEmpty) {
            _allRequests = List<dynamic>.from(items);
            requests = List<dynamic>.from(items);
          } else {
            // If backend supports keyword, it already filtered; still guard locally
            requests = items;
          }
          isLoading = false;
        });
      } else {
        throw Exception(
            "Failed to load requests: ${response.statusCode}\n${response.body}");
      }
    } catch (e, stackTrace) {
      // ❌ Log Error
      ApiLogger.logError(
        endpoint: 'https://erp.elrace.com/api/my_requests',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() {
        isLoading = false;
        error = "Something went wrong. Please try again.";
      });
    }
  }

  void _showRequestTypeDialog() {
    String dialogSelectedRequest = selectedRequestType;
    bool isDropdownOpen = true;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 28),
                        GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              isDropdownOpen = !isDropdownOpen;
                            });
                          },
                          child: Container(
                            height: 44.h,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF0F0C29),
                                  Color(0xFF302B63),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(25.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.22),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  selectedRequestType.toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 15.sp,
                                    color: Colors.white,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                SizedBox(width: 6.w),
                                Icon(
                                  isDropdownOpen
                                      ? Icons.arrow_drop_up
                                      : Icons.arrow_drop_down,
                                  color: Colors.white,
                                  size: 20.sp,
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: isDropdownOpen ? 1.0 : 0.0,
                          child: IgnorePointer(
                            ignoring: !isDropdownOpen,
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20.r),
                                border: Border.all(
                                    color: Colors.grey.shade300, width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 5),
                                  )
                                ],
                              ),
                              child: Column(
                                children: List.generate(
                                  requestOptions.length,
                                  (index) => GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () async {
                                      setDialogState(() {
                                        isDropdownOpen = false;
                                        selectedRequestType =
                                            requestOptions[index];
                                      });
                                      Navigator.pop(context);

                                      // Show as dialog instead of navigation
                                      Widget? pageWidget;
                                      if (requestOptions[index] == 'Leave') {
                                        pageWidget = RequestDetailsPage(
                                            loginResponseModel:
                                                SharedPref.getLoginData());
                                      } else if (requestOptions[index] ==
                                          'Temporary Permission') {
                                        pageWidget = RequestPermission(
                                            loginResponseModel:
                                                SharedPref.getLoginData());
                                      } else if (requestOptions[index] ==
                                          'Effective Date') {
                                        pageWidget = EffectiveDatePage(
                                            loginResponseModel:
                                                SharedPref.getLoginData());
                                      } else if (requestOptions[index] ==
                                          'Job Mission') {
                                        pageWidget = RequestJobMissionPage(
                                            loginResponseModel:
                                                SharedPref.getLoginData());
                                      }

                                      if (pageWidget != null) {
                                        showDialog(
                                          context: context,
                                          barrierColor:
                                              Colors.black.withOpacity(0.5),
                                          builder: (context) => Dialog(
                                            backgroundColor: Colors.transparent,
                                            insetPadding: EdgeInsets.zero,
                                            child: pageWidget,
                                          ),
                                        );
                                      }
                                    },
                                    child: Column(
                                      children: [
                                        Container(
                                          width: double.infinity,
                                          padding: EdgeInsets.symmetric(
                                              vertical: 14.h, horizontal: 18.w),
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            requestOptions[index],
                                            style: GoogleFonts.poppins(
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                        if (index != requestOptions.length - 1)
                                          Divider(
                                            height: 1,
                                            thickness: 0.7,
                                            color: Colors.grey.shade300,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16.h),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info,
                                size: 14, color: appFontColor),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                translate('notification.pending_approval'),
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  color: appFontColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.black.withAlpha((0.2 * 255).toInt()),
                              blurRadius: 6,
                              spreadRadius: 1,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child:
                              Icon(Icons.close, size: 18, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatRequestDate(dynamic raw) {
    final input = (raw ?? '').toString().trim();
    if (input.isEmpty) return input;

    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(input));
    } catch (_) {
      // Try common API date formats before falling back to raw value.
      const patterns = <String>[
        'yyyy-MM-dd HH:mm:ss',
        'yyyy-MM-dd HH:mm',
        'yyyy-MM-dd',
        'MM/dd/yyyy',
        'MM/dd/yyyy HH:mm:ss',
        'dd-MM-yyyy',
        'dd-MM-yyyy HH:mm:ss',
      ];

      for (final pattern in patterns) {
        try {
          final parsed = DateFormat(pattern).parseStrict(input);
          return DateFormat('dd/MM/yyyy').format(parsed);
        } catch (_) {}
      }
    }

    return input;
  }

  Widget _buildRequestItem(Map item, int index) {
    final bool isExpanded = expandedItems.contains(index);
    final String status = (item['status'] ?? '').toString().toLowerCase();
    final String statusLabel = status.toUpperCase();

    // 🎨 Status-based styling
    String backgroundImage = 'assets/png/item_bg_green.png'; // Default fallback
    Color textColor = Colors.white;

    switch (status) {
      case 'approve':
      case 'approved':
        backgroundImage = 'assets/png/item_bg_green.png';
        textColor = Colors.green;
        break;
      case 'pending':
        backgroundImage = 'assets/png/item_bg_yellow.png';
        textColor = Colors.amber;
        break;
      case 'cancel':
      case 'cancelled':
      case 'rejected':
      case 'reject':
        backgroundImage = 'assets/png/item_bg_red.png';
        textColor = Colors.red;
        break;
      default:
        backgroundImage = 'assets/png/item_bg_green.png';
        textColor = Colors.white;
    }

    // ألوان التدرّج
    Color bgStart = const Color(0xFF0F0C29);
    Color bgEnd = const Color(0xFF302B63);

    return GestureDetector(
      onTap: () {
        setState(() {
          isExpanded ? expandedItems.remove(index) : expandedItems.add(index);
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
        child: SizedBox(
          height: 60.w,
          child: Stack(
            children: [
              // 🔹 الطبقة الأساسية (Collapsed) - دائماً موجودة
              Container(
                height: 60.w,
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(horizontal: 20.w) +
                    EdgeInsets.only(bottom: 10.w),
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(backgroundImage),
                    fit: BoxFit.cover,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.08 * 255).toInt()),
                      blurRadius: 4,
                      spreadRadius: 2,
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: 80.w,
                      child: Text(
                        _formatRequestDate(item['create_date']),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                          color: appFontColor,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 30,
                      child: VerticalDivider(
                        color: Colors.grey,
                        thickness: 2,
                      ),
                    ),
                    SizedBox(
                      width: 150.w,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'REQ NO',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: appFontColor,
                            ),
                          ),
                          Text(
                            item['name'] ?? '',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                            overflow: TextOverflow.visible,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 30,
                      child: VerticalDivider(
                        color: Colors.grey,
                        thickness: 2,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item['request_type_name']?.trim() ?? '',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: appFontColor,
                        ),
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ],
                ),
              ),

              // 🔥 الطبقة العلوية (Expanded) - تظهر فوق الcollapsed بالضبط
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isExpanded ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !isExpanded,
                  child: Container(
                    height: 55.w,
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [bgStart, bgEnd],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Center(
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 1,
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
    );
  }

  void _showStatusDialog(Map item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildStatusPill(item['status'] ?? 'unknown'),
              const SizedBox(height: 20),
              Text(
                "Date: ${_formatRequestDate(item['create_date'])}",
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Text(
                "Request No: ${item['name']}",
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Text(
                "Type: ${item['request_type_name']}",
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildStatusPill(String status) {
    Color bgColor;
    Color textColor = Colors.white;

    switch (status.toLowerCase()) {
      case 'approve':
        bgColor = Colors.green;
        break;
      case 'draft':
        bgColor = Colors.grey;
        break;
      case 'pending':
        bgColor = Colors.amber;
        break;
      default:
        bgColor = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        gradient:
            LinearGradient(colors: [bgColor.withValues(alpha: 0.8), bgColor]),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: bgColor.withAlpha((0.3 * 255).toInt()),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await _fetchRequests();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: const HeaderWidget(),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    const SizedBox(height: 5),
                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 40),
                        // Centered title
                        Expanded(
                          child: Center(
                            child: Text(
                              translate('home.my_request')
                                  .toString()
                                  .toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 22.sp,
                                fontWeight: FontWeight.w400,
                                color: appFontColor,
                                letterSpacing: 2.0,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        // Plus icon (right)
                        SizedBox(
                          width: 40.w,
                          height: 40.w,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(Icons.add,
                                size: 28.sp, color: appFontColor),
                            onPressed: () async {
                              final result = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const HrRequestsMenuPage(),
                                ),
                              );
                              if (result == true) {
                                await _fetchRequests();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Centered rounded search field
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.66,
                        height: 50.h,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30.r),
                          border: Border.all(
                              color: const Color(0xFFD9D9D9), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.grey.withAlpha((0.06 * 255).toInt()),
                              blurRadius: 6,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: translate('home.Find_your_request'),
                            hintStyle:
                                TextStyle(fontSize: 14.sp, color: appFontColor),
                            prefixIcon: Padding(
                              padding: EdgeInsets.all(12.w),
                              child: Icon(Icons.menu,
                                  size: 20.sp, color: appFontColor),
                            ),
                            suffixIcon: Padding(
                              padding: EdgeInsets.only(right: 12.w),
                              child: Icon(Icons.search,
                                  size: 20.sp, color: appFontColor),
                            ),
                            border: InputBorder.none,
                            contentPadding:
                                EdgeInsets.symmetric(vertical: 14.h),
                          ),
                          onChanged: (query) {},
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            if (isLoading)
              const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()))
            else if (error.isNotEmpty)
              SliverFillRemaining(child: Center(child: Text(error)))
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _buildRequestItem(requests[index], index),
                    childCount: requests.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
