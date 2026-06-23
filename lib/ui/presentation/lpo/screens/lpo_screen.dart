import 'dart:async';
import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/home_screen/screens/main_screens.dart';
import 'package:el_race/ui/presentation/lpo/widgets/lpo_card_widget.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:el_race/utils/api_logger.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:el_race/utils/Util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class LpoListScreen extends StatefulWidget {
  const LpoListScreen({super.key});

  @override
  State<LpoListScreen> createState() => _LpoListScreenState();
}

class _LpoListScreenState extends State<LpoListScreen> {
  final _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  String _keyword = '';

  // Pagination
  int _currentPage = 1;
  final int _limit = 10;
  bool _hasMore = false;

  // Search UI (match MediaListScreen)
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  final bool _showSearch = false;

  String? _asNonEmptyString(dynamic value) {
    final s = value?.toString().trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  String? _normalizeImageUrl(String? url) {
    if (url == null) return null;
    // Some payloads come as "https:/domain..." (missing slash). Normalize to "https://".
    if (url.startsWith('https:/') && !url.startsWith('https://')) {
      return url.replaceFirst('https:/', 'https://');
    }
    if (url.startsWith('http:/') && !url.startsWith('http://')) {
      return url.replaceFirst('http:/', 'http://');
    }
    return url;
  }

  void _debugPrintLpoImageFields(List list, {String tag = 'LPO'}) {
    if (!kDebugMode) return;

    final total = list.length;
    final take = total < 10 ? total : 10;
    debugPrint('[$tag] Items: $total | showing first $take image fields');

    for (var i = 0; i < take; i++) {
      final item = list[i];
      if (item is! Map) {
        debugPrint('[$tag][$i] unexpected item type: ${item.runtimeType}');
        continue;
      }

      final id = item['id'];
      final name = _asNonEmptyString(item['name']);
      final clientPhoto =
          _normalizeImageUrl(_asNonEmptyString(item['client_photo']));
      final requesterPhoto = _normalizeImageUrl(
          _asNonEmptyString(item['requested_by_user_photo']));

      debugPrint(
        '[$tag][$i] id=$id name=${name ?? '-'} '
        '| client_photo=${clientPhoto ?? '<empty>'} '
        '| requested_by_user_photo=${requesterPhoto ?? '<empty>'}',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchLpos();

    _searchController.addListener(() {
      final text = _searchController.text.trim();
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        setState(() {
          _keyword = text;
        });
        _fetchLpos(keyword: text);
      });
    });
  }

  // @override
  // void didChangeDependencies() {
  //   super.didChangeDependencies();

  // }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      print(
          '📜 Scroll: Reached bottom - hasMore: $_hasMore, isLoadingMore: $_isLoadingMore, isLoading: $_isLoading');
      if (_hasMore && !_isLoadingMore && !_isLoading) {
        print('📜 Scroll: Calling _loadMoreLpos()');
        _loadMoreLpos();
      }
    }
  }

  Future<void> _fetchLpos({String? keyword}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = SharedPref.getLoginData().result?.token ?? '';
      final url = Uri.parse('https://erp.elrace.com/api/get_lpos');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final effectiveKeyword = (keyword ?? _keyword).trim();
      final Map<String, dynamic> params = {
        'page': 1,
        'limit': _limit,
      };
      if (effectiveKeyword.isNotEmpty) {
        params['keyword'] = effectiveKeyword;
      }

      final body = jsonEncode({
        'jsonrpc': '2.0',
        'params': params,
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

      // Check status code first before parsing JSON
      if (response.statusCode != 200) {
        ApiLogger.logResponse(
          endpoint: url.toString(),
          statusCode: response.statusCode,
          responseBody: {
            'error': 'HTTP ${response.statusCode}',
            'body': response.body.substring(
                0, response.body.length > 200 ? 200 : response.body.length)
          },
          duration: duration,
        );

        setState(() {
          _error =
              'Failed to load LPOs: HTTP ${response.statusCode}\n${response.statusCode == 401 ? 'Authentication failed. Please login again.' : response.statusCode == 403 ? 'Access denied.' : 'Server error.'}';
          _isLoading = false;
        });
        return;
      }

      final data = jsonDecode(response.body);

      // 📥 Log Response
      ApiLogger.logResponse(
        endpoint: url.toString(),
        statusCode: response.statusCode,
        responseBody: data,
        duration: duration,
      );

      print('========== LPO API RESPONSE ==========');
      print(jsonEncode(data));
      print('======================================');

      if (data['result'] != null) {
        final List list = (data['result']['data'] ?? []) as List;
        final bool hasMore = data['result']['has_more'] ?? false;

        _debugPrintLpoImageFields(list, tag: 'LPO_FETCH');

        setState(() {
          _items = list.cast<Map<String, dynamic>>();
          _currentPage = 1;
          _hasMore = hasMore;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['error']?.toString() ?? 'Failed to load LPOs';
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      // ❌ Log Error
      ApiLogger.logError(
        endpoint: 'https://erp.elrace.com/api/get_lpos',
        error: e,
        stackTrace: stackTrace,
      );
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreLpos() async {
    if (_isLoadingMore || !_hasMore) return;

    print(
        '🔄 Load More: Current page: $_currentPage, Next page: ${_currentPage + 1}');

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final token = SharedPref.getLoginData().result?.token ?? '';
      final url = Uri.parse('https://erp.elrace.com/api/get_lpos');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final effectiveKeyword = _keyword.trim();
      final Map<String, dynamic> params = {
        'page': _currentPage + 1,
        'limit': _limit,
      };
      if (effectiveKeyword.isNotEmpty) {
        params['keyword'] = effectiveKeyword;
      }

      final body = jsonEncode({
        'jsonrpc': '2.0',
        'params': params,
      });

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
        setState(() {
          _isLoadingMore = false;
        });
        return;
      }

      final data = jsonDecode(response.body);

      ApiLogger.logResponse(
        endpoint: url.toString(),
        statusCode: response.statusCode,
        responseBody: data,
        duration: duration,
      );

      if (data['result'] != null) {
        final List list = (data['result']['data'] ?? []) as List;
        final bool hasMore = data['result']['has_more'] ?? false;
        print('✅ Load More: Got ${list.length} items, has_more: $hasMore');

        _debugPrintLpoImageFields(list, tag: 'LPO_LOAD_MORE');

        setState(() {
          _items.addAll(list.cast<Map<String, dynamic>>());
          _currentPage += 1;
          _hasMore = hasMore;
          _isLoadingMore = false;
        });
        print(
            '✅ Load More: Updated to page $_currentPage, total items: ${_items.length}');
      } else {
        setState(() {
          _isLoadingMore = false;
        });
      }
    } catch (e, stackTrace) {
      ApiLogger.logError(
        endpoint: 'https://erp.elrace.com/api/get_lpos',
        error: e,
        stackTrace: stackTrace,
      );
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Widget _buildInlineSearchField() {
    return Container(
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/png/bg_atten.png'),
          fit: BoxFit.none,
        ),
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(29.w),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha((0.2 * 255).toInt()),
            blurRadius: 4,
            spreadRadius: 2,
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Find LPO',
          prefixIcon: Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.search, size: 18, color: appFontColor),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('${SharedPref.getLoginData().result?.token}');
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const HeaderWidget(),
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 🔹 LPO Title Section (Scrollable)
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 10),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        "assets/png/lpo_blue.svg",
                        height: 24.w,
                        width: 24.w,
                      ),
                      SizedBox(width: 4.w),
                      if (!_showSearch)
                        Text(
                          translate('home.lpo'),
                          style: GoogleFonts.poppins(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w500,
                            color: appFontColor,
                          ),
                          overflow: TextOverflow.visible,
                        )
                      else
                        Expanded(child: _buildInlineSearchField()),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),

          // 🔹 Loading or Error or List
          _isLoading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              : _error != null
                  ? SliverFillRemaining(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                    )
                  : _items.isEmpty
                      ? SliverFillRemaining(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                translate('no_data_available'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  color: appFontColor,
                                ),
                              ),
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: EdgeInsets.only(
                            bottom: kBottomNavigationBarHeight +
                                context.systemBottomInset +
                                16,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final item = _items[index];
                                final poId = item['id'] as int?;
                                final name = (item['name'] ?? '').toString();
                                final vendor =
                                    (item['partner_id'] ?? '').toString();
                                final project =
                                    (item['project'] ?? '').toString();
                                final dateStr =
                                    (item['date_order'] ?? '').toString();
                                final amount =
                                    (item['amount_total'] ?? '').toString();
                                final clientPhoto = item['client_photo'];
                                final requestedByPhoto =
                                    item['requested_by_user_photo'];
                                final requestedBy =
                                    (item['requested_by'] ?? '').toString();
                                final requesterManager =
                                    (item['requester_manager'] ?? '')
                                        .toString();
                                final state = (item['state'] ?? '').toString();
                                final attachments =
                                    (item['attachments'] ?? []) as List;

                                return LpoCardWidget(
                                  poId: poId,
                                  name: name,
                                  vendorName: vendor,
                                  projectName: project,
                                  date: dateStr,
                                  amount: amount,
                                  clientPhoto: clientPhoto,
                                  requestedByUserPhoto: requestedByPhoto,
                                  requestedBy: requestedBy,
                                  requesterManager: requesterManager,
                                  state: state,
                                  attachments: attachments,
                                  onTap: poId != null
                                      ? () =>
                                          Util.openLpoPdfReport(context, poId)
                                      : null,
                                );
                              },
                              childCount: _items.length,
                            ),
                          ),
                        ),

          // 🔹 Loading More Indicator
          if (_isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
