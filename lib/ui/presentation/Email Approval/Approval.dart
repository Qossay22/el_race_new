import 'dart:convert';
import 'dart:ui';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:el_race/ui/presentation/Email%20Approval/delayed/data/delayed_approvals_repository.dart';
import 'package:el_race/ui/presentation/Email%20Approval/delayed/models/delayed_approval_model.dart';
import 'package:el_race/ui/presentation/Email%20Approval/delayed/screens/delayed_requests_screen.dart';
import 'package:el_race/ui/presentation/Email%20Approval/screens/hr_details_screen.dart';
import 'package:el_race/ui/presentation/Email%20Approval/widgets/all_approvals_overview.dart';
import 'package:el_race/ui/presentation/Email%20Approval/widgets/hr_and_pettycash_card.dart';
import 'package:el_race/ui/presentation/Email%20Approval/widgets/invoice_and_rfq_card.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../widgets/header_widget.dart';

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({
    Key? key,
  }) : super(key: key);

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  static const List<_HrRequestTestCase> _hrRequestTestCases = [
    _HrRequestTestCase(id: 35849, title: 'Sick'),
    _HrRequestTestCase(id: 35651, title: 'Short'),
    _HrRequestTestCase(id: 35847, title: 'Job Mission'),
    _HrRequestTestCase(id: 35564, title: 'Temporary Permission'),
    _HrRequestTestCase(id: 35841, title: 'Clearance'),
    _HrRequestTestCase(id: 35837, title: 'Effective Date'),
    _HrRequestTestCase(id: 34068, title: 'Certificate Request'),
    _HrRequestTestCase(id: 32938, title: 'Loan'),
    _HrRequestTestCase(id: 33800, title: 'Salary Increment'),
    _HrRequestTestCase(id: 18915, title: 'Parental'),
    _HrRequestTestCase(id: 31615, title: 'Resign'),
    _HrRequestTestCase(id: 25165, title: 'Termination'),
    _HrRequestTestCase(id: 31875, title: 'Transfer'),
    _HrRequestTestCase(id: 30388, title: 'Passport'),
    _HrRequestTestCase(id: 35803, title: 'Leave Encashment'),
    _HrRequestTestCase(id: 33244, title: 'Car Rent'),
    _HrRequestTestCase(id: 24602, title: 'Maternity'),
    _HrRequestTestCase(id: 35842, title: 'Annual'),
    _HrRequestTestCase(id: 32312, title: 'Promotion'),
  ];

  String selectedCategoryKey = _CategoryKeys.all;
  TextEditingController searchController = TextEditingController();
  final ScrollController _tabScrollController = ScrollController();
  List<dynamic> hrItems = [];
  List<dynamic> rfqItems = [];
  List<dynamic> invoiceItems = [];
  List<dynamic> pettyCashItems = [];
  List<dynamic> allItems = [];
  List<dynamic> approvalItems = [];
  String error = '';

  // Per-category loading/loaded/error state — no full-screen blocking loader
  final Map<String, bool> _categoryLoading = {};
  final Map<String, bool> _categoryLoaded = {};
  Map<String, String> categoryErrors = {};

  // Delayed requests count from API
  int delayedCount = 0;
  DelayedRorResponse? _rorData;
  final DelayedApprovalsRepository _delayedRepo = DelayedApprovalsRepository();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    selectedCategoryKey = categoryKeys.first;
    searchController.addListener(_onSearchChanged);
    // Show the screen immediately — load all categories in background in parallel.
    // Delayed count is also fired in background.
    _loadAllCategoriesInBackground();
    _fetchDelayedCount();
    _fetchRorData();
  }

  @override
  void dispose() {
    searchController.dispose();
    _tabScrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedTab(int index) {
    if (_tabScrollController.hasClients) {
      // Calculate the position based on tab width + padding
      final double tabWidth =
          90 + 9; // 90w for width + 5 right padding + 4 margin
      final double screenWidth = MediaQuery.of(context).size.width;
      final double targetPosition =
          (index * tabWidth) - (screenWidth / 2) + (tabWidth / 2);

      _tabScrollController.animateTo(
        targetPosition.clamp(
            0.0, _tabScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onSearchChanged() {
    setState(() {
      approvalItems = _getFilteredItems();
    });
  }

  List<dynamic> _getFilteredItems() {
    final allFiltered = _getApprovalListForSelectedCategory();
    if (searchController.text.isEmpty) {
      return allFiltered;
    }

    final searchLower = searchController.text.toLowerCase();
    return allFiltered.where((item) {
      final name = item["name"]?.toString().toLowerCase() ?? "";
      final requestNo = item["request_no"]?.toString().toLowerCase() ?? "";
      final reqNo = item["req_no"]?.toString().toLowerCase() ?? "";
      final title = item["title"]?.toString().toLowerCase() ?? "";
      final employeeName =
          item["employee_name"]?.toString().toLowerCase() ?? "";
      final vendor = item["vendor"]?.toString().toLowerCase() ?? "";

      return name.contains(searchLower) ||
          requestNo.contains(searchLower) ||
          reqNo.contains(searchLower) ||
          title.contains(searchLower) ||
          employeeName.contains(searchLower) ||
          vendor.contains(searchLower);
    }).toList();
  }

  String _pickCommentValue(Map<String, dynamic> item) {
    final candidates = <dynamic>[
      item['comment'],
      item['comments'],
      item['note'],
      item['description'],
      item['approval_comment'],
      item['reject_reason'],
      item['rejection_reason'],
      item['manager_comment'],
    ];

    for (final value in candidates) {
      if (value == null || value == false || value == true) continue;
      final text = value.toString().trim();
      if (text.isEmpty) continue;
      final normalized = text.toLowerCase();
      if (normalized == 'null' ||
          normalized == 'false' ||
          normalized == 'true') {
        continue;
      }
      return text;
    }

    return '';
  }

  List<Map<String, dynamic>> _normalizeCategoryItems(
    List<dynamic> rawItems, {
    required String categoryLabel,
  }) {
    return rawItems.whereType<Map>().map((raw) {
      final map = Map<String, dynamic>.from(raw);
      final typeValue = map['type']?.toString().trim();
      map['category'] = categoryLabel;
      map['type'] = (typeValue != null && typeValue.isNotEmpty)
          ? typeValue
          : categoryLabel;

      final existingComment = map['comment'];
      final hasMeaningfulComment = existingComment != null &&
          existingComment != false &&
          existingComment != true &&
          existingComment.toString().trim().isNotEmpty &&
          existingComment.toString().toLowerCase() != 'null' &&
          existingComment.toString().toLowerCase() != 'false' &&
          existingComment.toString().toLowerCase() != 'true';

      if (!hasMeaningfulComment) {
        map['comment'] = _pickCommentValue(map);
      }

      return map;
    }).toList(growable: false);
  }

  Future<List<dynamic>> _fetchCategoryData(String groupType) async {
    final token = SharedPref.getLoginData().result?.token;

    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };

    final url = Uri.parse("https://erp.elrace.com/api/my_approvals_grouped");

    final params = <String, dynamic>{"group_type": groupType};
    if (groupType == 'rfq' || groupType == 'invoice') {
      params['comment'] = '';
    }

    final body = jsonEncode({
      "jsonrpc": "2.0",
      "params": params,
    });

    if (groupType == 'rfq' || groupType == 'invoice') {
      final escapedBody = body.replaceAll("'", r"'\\''");
      debugPrint('🧪 [MyApproval][$groupType] cURL:');
      debugPrint(
        "curl -X GET '$url' -H 'Content-Type: application/json' -H 'Accept: application/json' -H 'Authorization: Bearer $token' --data '$escapedBody'",
      );
    }

    final request = http.Request('GET', url)
      ..headers.addAll(headers)
      ..body = body;

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint('[$groupType] status=${response.statusCode}');

    if (groupType == 'petty_cash' ||
        groupType == 'rfq' ||
        groupType == 'invoice') {
      debugPrint('🧾 [MyApproval][$groupType] Raw response start');
      const chunkSize = 800;
      final raw = response.body;
      for (var i = 0; i < raw.length; i += chunkSize) {
        final end = (i + chunkSize < raw.length) ? i + chunkSize : raw.length;
        debugPrint(raw.substring(i, end));
      }
      debugPrint('🧾 [MyApproval][$groupType] Raw response end');
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      const Map<String, String> responseKeys = {
        "hr": "human_resources",
        "rfq": "rfq",
        "invoice": "invoices",
        "petty_cash": "petty_cash",
      };
      final actualKey = responseKeys[groupType] ?? groupType;
      final items = data['result']['data'][actualKey] ?? [];

      if (groupType == 'petty_cash') {
        debugPrint(
          '🧾 [MyApproval][petty_cash] Parsed items count=${items.length}',
        );
      }

      return items;
    } else {
      throw Exception("Failed to fetch $groupType: ${response.statusCode}");
    }
  }

  /// Loads a single category in the background and updates state when done.
  Future<void> _loadCategory(String categoryKey, {bool force = false}) async {
    if (_categoryLoading[categoryKey] == true) {
      debugPrint(
          '⏳ [ApprovalsScreen] Skip loading $categoryKey (already loading)');
      return;
    }
    if (!force && _categoryLoaded[categoryKey] == true) {
      debugPrint(
          '✅ [ApprovalsScreen] Skip loading $categoryKey (already loaded)');
      return;
    }

    debugPrint(
        '🔄 [ApprovalsScreen] Loading category=$categoryKey force=$force');
    setState(() {
      _categoryLoading[categoryKey] = true;
      if (force) {
        _categoryLoaded[categoryKey] = false;
        categoryErrors.remove(categoryKey);
      }
    });

    try {
      final items = await _fetchCategoryData(categoryKey);
      if (!mounted) return;
      setState(() {
        switch (categoryKey) {
          case 'hr':
            hrItems = _normalizeCategoryItems(items, categoryLabel: 'HR');
          case 'rfq':
            rfqItems = _normalizeCategoryItems(items, categoryLabel: 'RFQ');
          case 'invoice':
            invoiceItems =
                _normalizeCategoryItems(items, categoryLabel: 'INVOICE');
          case 'petty_cash':
            pettyCashItems =
                _normalizeCategoryItems(items, categoryLabel: 'PETTY CASH');
        }
        allItems = [
          ...hrItems,
          ...rfqItems,
          ...invoiceItems,
          ...pettyCashItems
        ];
        approvalItems = _getFilteredItems();
        _categoryLoading[categoryKey] = false;
        _categoryLoaded[categoryKey] = true;
      });
      debugPrint(
        '✅ [ApprovalsScreen] Loaded $categoryKey with ${items.length} items',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        categoryErrors[categoryKey] = e.toString();
        _categoryLoading[categoryKey] = false;
      });
      debugPrint('❌ [ApprovalsScreen] Failed loading $categoryKey: $e');
    }
  }

  /// Fires all 4 categories in parallel without blocking the UI.
  void _loadAllCategoriesInBackground({bool force = false}) {
    debugPrint('🚀 [ApprovalsScreen] Loading all categories (force=$force)');
    _loadCategory('hr', force: force);
    _loadCategory('rfq', force: force);
    _loadCategory('invoice', force: force);
    _loadCategory('petty_cash', force: force);
  }

  List<dynamic> _getApprovalListForSelectedCategory() {
    switch (selectedCategoryKey) {
      case _CategoryKeys.hr:
        return hrItems;
      case _CategoryKeys.rfq:
        return rfqItems;
      case _CategoryKeys.invoice:
        return invoiceItems;
      case _CategoryKeys.pettyCash:
        return pettyCashItems;
      case _CategoryKeys.all:
      default:
        return allItems;
    }
  }

  int _getCategoryCount(String categoryKey) {
    switch (categoryKey) {
      case _CategoryKeys.all:
        return allItems.length;
      case _CategoryKeys.hr:
        return hrItems.length;
      case _CategoryKeys.rfq:
        return rfqItems.length;
      case _CategoryKeys.invoice:
        return invoiceItems.length;
      case _CategoryKeys.pettyCash:
        return pettyCashItems.length;
      default:
        return 0;
    }
  }

  Future<void> _fetchDelayedCount() async {
    try {
      final counters = await _delayedRepo.fetchCounters();
      if (!mounted) return;
      setState(() {
        delayedCount = counters.totalCount;
      });
    } catch (e) {
      debugPrint('Failed to fetch delayed count: $e');
    }
  }

  Future<void> _fetchRorData() async {
    try {
      final ror = await _delayedRepo.fetchRor();
      final hasBreakdownCounts = (ror.hrCount ?? 0) > 0 ||
          (ror.rfqCount ?? 0) > 0 ||
          (ror.pettyCashCount ?? 0) > 0 ||
          (ror.invoiceCount ?? 0) > 0;
      debugPrint(
        '🟣 [ROR SOURCE] API (${hasBreakdownCounts ? 'score+counts' : 'score-only'}) => ror=${ror.rorPercentage}%',
      );
      if (!mounted) return;
      setState(() {
        _rorData = ror;
      });
    } catch (e) {
      debugPrint('Failed to fetch delayed ROR: $e');
      debugPrint(
          '🟡 [ROR SOURCE] Fallback => local tab counts + local formula');
    }
  }

  void _refreshApprovalsAfterAction() {
    debugPrint('🔁 [ApprovalsScreen] Refresh requested after approve/reject');
    _loadAllCategoriesInBackground(force: true);
    _fetchDelayedCount();
    _fetchRorData();
  }

  void _openHrRequestTestCases() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const _HrRequestTestCasesScreen(),
      ),
    );
  }

  String _tabTitleFor(String categoryKey) {
    switch (categoryKey) {
      case _CategoryKeys.all:
        return 'All';
      case _CategoryKeys.hr:
        return 'HR';
      case _CategoryKeys.rfq:
        return 'RFQ';
      case _CategoryKeys.invoice:
        return 'Invoice';
      case _CategoryKeys.pettyCash:
        return 'Petty Cash';
      default:
        return categoryKey;
    }
  }

  String _iconFor(String categoryKey) {
    switch (categoryKey) {
      case _CategoryKeys.all:
        return "assets/svg/all-icon.svg";
      case _CategoryKeys.hr:
        return "assets/svg/hr-icon.svg";
      case _CategoryKeys.rfq:
        return "assets/svg/rfq-icon.svg";
      case _CategoryKeys.invoice:
        return "assets/svg/invoice-icon.svg";
      case _CategoryKeys.pettyCash:
        return "assets/svg/petty-cash-icon.svg";
      default:
        return "assets/icons/default.png";
    }
  }

  Color? _iconTintFor(String categoryKey) {
    if (categoryKey == _CategoryKeys.invoice) {
      return const Color(0xFF16A56B);
    }
    if (categoryKey == _CategoryKeys.pettyCash) {
      return const Color(0xFF32ADE6);
    }
    return null;
  }

  final List<String> categoryKeys = const [
    _CategoryKeys.all,
    _CategoryKeys.hr,
    _CategoryKeys.rfq,
    _CategoryKeys.pettyCash,
    _CategoryKeys.invoice,
  ];
  bool isSearch = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const HeaderWidget(),
      extendBody: true,
      body: Stack(
        children: [
          // Main content - starts from top and scrolls behind tabs
          NotificationListener<ScrollNotification>(
            onNotification: (scrollNotification) {
              if (scrollNotification is ScrollUpdateNotification ||
                  scrollNotification is ScrollEndNotification) {
                final isScrolled = scrollNotification.metrics.pixels > 10;
                if (isScrolled != _isScrolled) {
                  setState(() {
                    _isScrolled = isScrolled;
                  });
                }
              }
              return false;
            },
            child: Column(
              children: [
                body(),
              ],
            ),
          ),
          // iOS-style translucent tabs bar - fixed position, content scrolls behind it
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: _isScrolled ? 5.0 : 0.0,
                  sigmaY: _isScrolled ? 5.0 : 0.0,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _isScrolled
                        ? Colors.white.withOpacity(0.1)
                        : Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: _isScrolled
                            ? Colors.grey.withOpacity(0.3)
                            : Colors.transparent,
                        width: 1.0,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    controller: _tabScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    clipBehavior: Clip.none,
                    child: Row(
                      children: categoryKeys.asMap().entries.map((entry) {
                        int index = entry.key;
                        String categoryKey = entry.value;
                        bool isSelected = selectedCategoryKey == categoryKey;
                        final categoryCount = _getCategoryCount(categoryKey);
                        return Container(
                          margin: const EdgeInsets.only(right: 8.0, left: 2.0),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedCategoryKey = categoryKey;
                                approvalItems = _getFilteredItems();
                                _isScrolled = false;
                              });
                              _scrollToSelectedTab(index);
                              // Trigger category load on tap (no-op if already loading/loaded)
                              if (categoryKey != _CategoryKeys.all) {
                                _loadCategory(_categoryApiKey(categoryKey));
                              }
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted && _isScrolled) {
                                  setState(() {
                                    _isScrolled = false;
                                  });
                                }
                              });
                            },
                            child: _buildGlassTab(
                              icon: _iconFor(categoryKey),
                              iconTint: _iconTintFor(categoryKey),
                              title: _tabTitleFor(categoryKey),
                              isSelected: isSelected,
                              count: 0,
                              showRedDot: categoryCount > 0,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Floating bottom navigation bar
        ],
      ),
    );
  }

  body() {
    // ALL tab: show instantly with live-updating counts as categories load in background
    if (selectedCategoryKey == _CategoryKeys.all) {
      return AllApprovalsOverview(
        invoiceCount: invoiceItems.length,
        pettyCashCount: pettyCashItems.length,
        rfqCount: rfqItems.length,
        hrCount: hrItems.length,
        delayedCount: delayedCount,
        rorInvoiceCount: _rorData?.invoiceCount,
        rorPettyCashCount: _rorData?.pettyCashCount,
        rorRfqCount: _rorData?.rfqCount,
        rorHrCount: _rorData?.hrCount,
        rorPercentage: _rorData?.rorPercentage,
        rorHrRor: _rorData?.hrRor,
        rorRfqRor: _rorData?.rfqRor,
        rorInvoiceRor: _rorData?.invoiceRor,
        rorPettyCashRor: _rorData?.pettyCashRor,
        onHrTestCasesTap: kDebugMode ? _openHrRequestTestCases : null,
        onDelayedTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DelayedRequestsScreen(),
            ),
          );
        },
      );
    }

    // For specific category tabs: show spinner only while that category is loading
    final apiKey = _categoryApiKey(selectedCategoryKey);
    final isLoadingCategory = _categoryLoading[apiKey] == true;
    final hasError = categoryErrors.containsKey(apiKey);

    if (isLoadingCategory) {
      return const Expanded(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (hasError) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 8),
              Text(categoryErrors[apiKey]!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _loadCategory(apiKey),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (selectedCategoryKey == _CategoryKeys.hr ||
        selectedCategoryKey == _CategoryKeys.pettyCash) {
      return HrAndPettycashCard(
        approvalItems: approvalItems,
        onRefresh: _refreshApprovalsAfterAction,
      );
    } else if (selectedCategoryKey == _CategoryKeys.rfq ||
        selectedCategoryKey == _CategoryKeys.invoice) {
      return InvoiceAndRfqCard(
        approvalItems: approvalItems,
        onRefresh: _refreshApprovalsAfterAction,
        categoryType: selectedCategoryKey,
      );
    }

    return const SizedBox.shrink();
  }

  /// Maps a category UI key to the API group_type string.
  String _categoryApiKey(String categoryKey) {
    switch (categoryKey) {
      case _CategoryKeys.hr:
        return 'hr';
      case _CategoryKeys.rfq:
        return 'rfq';
      case _CategoryKeys.invoice:
        return 'invoice';
      case _CategoryKeys.pettyCash:
        return 'petty_cash';
      default:
        return categoryKey;
    }
  }

  Widget _buildGlassTab({
    required String icon,
    Color? iconTint,
    required String title,
    required bool isSelected,
    int count = 0,
    bool showRedDot = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 84.w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF141B3A)
                      : const Color(0xFFB7B7B7),
                  width: isSelected ? 0 : 1.1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF141B3A).withOpacity(0.14),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  color: isSelected ? const Color(0xFF141B3A) : Colors.white,
                ),
                child: Center(
                  child: SvgPicture.asset(
                    icon,
                    height: 42.w,
                    width: 42.w,
                    fit: BoxFit.contain,
                    colorFilter: iconTint != null
                        ? ColorFilter.mode(iconTint, BlendMode.srcIn)
                        : null,
                  ),
                ),
              ),
            ),
            // Badge for count
            if (count > 0)
              Positioned(
                right: -5,
                top: -5,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: red,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    count > 99 ? '99+' : count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (showRedDot)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 6.h),
        SizedBox(
          width: 84.w,
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 10.6.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF161616),
            ),
            maxLines: null,
            overflow: TextOverflow.visible,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _CategoryKeys {
  static const String all = 'all';
  static const String hr = 'hr';
  static const String rfq = 'rfq';
  static const String invoice = 'invoice';
  static const String pettyCash = 'petty_cash';
}

class _HrRequestTestCase {
  final int id;
  final String title;

  const _HrRequestTestCase({required this.id, required this.title});
}

class _HrRequestTestCasesScreen extends StatelessWidget {
  const _HrRequestTestCasesScreen();

  static const List<_HrRequestTestCase> _cases =
      _ApprovalsScreenState._hrRequestTestCases;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBar(
        title: Text(
          'HR Test Cases',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView.separated(
        padding: EdgeInsets.fromLTRB(14.w, 14.w, 14.w, 24.w),
        itemCount: _cases.length,
        separatorBuilder: (_, __) => SizedBox(height: 10.w),
        itemBuilder: (context, index) {
          final testCase = _cases[index];
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            child: InkWell(
              borderRadius: BorderRadius.circular(14.r),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HrDetailsScreen(
                      requestId: testCase.id.toString(),
                      type: 'hr',
                    ),
                  ),
                );
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: const Color(0xFFE2E5EC)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34.w,
                      height: 34.w,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FA),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.poppins(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF20345B),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            testCase.title,
                            style: GoogleFonts.poppins(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF151B2C),
                            ),
                          ),
                          SizedBox(height: 2.w),
                          Text(
                            'request_id: ${testCase.id}',
                            style: GoogleFonts.poppins(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF6A7388),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 22.sp,
                      color: const Color(0xFF7B869F),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
