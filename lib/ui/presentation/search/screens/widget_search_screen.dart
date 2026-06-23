import 'dart:async';
import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/PettyCash/PettyCashScreen.dart';
import 'package:el_race/ui/presentation/home_screen/screens/main_screens.dart';
import 'package:el_race/ui/presentation/lpo/screens/lpo_screen.dart';
import 'package:el_race/ui/presentation/lpo/widgets/lpo_card_widget.dart';
import 'package:el_race/ui/presentation/my_documents/screens/my_documents_screen.dart';
import 'package:el_race/ui/presentation/my_notes/screens/my_notes_screen.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/screens/my_project.dart';
import 'package:el_race/ui/presentation/my_projects/domain/entities/project_entity.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_card_widget.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_list_bloc.dart';
import 'package:el_race/ui/presentation/my_projects/data/repositories/project_repository_impl.dart';
import 'package:el_race/ui/presentation/my_projects/data/datasources/project_remote_datasource.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_usecase.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_by_partner_usecase.dart';
import 'package:el_race/ui/presentation/todo_list/screens/todo_list_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:el_race/utils/Util.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

/// Enum for search categories
enum SearchCategory {
  pettyCash,
  lpo,
  myDocuments,
  myNotes,
  todoList,
  myProjects,
}

/// Model for search result items
class SearchResultItem {
  final String id;
  final String title;
  final String subtitle;
  final String? amount;
  final String? date;
  final String? status;
  final Map<String, dynamic> rawData;

  SearchResultItem({
    required this.id,
    required this.title,
    required this.subtitle,
    this.amount,
    this.date,
    this.status,
    required this.rawData,
  });
}

class WidgetSearchScreen extends StatefulWidget {
  const WidgetSearchScreen({super.key});

  @override
  State<WidgetSearchScreen> createState() => _WidgetSearchScreenState();
}

class _WidgetSearchScreenState extends State<WidgetSearchScreen> {
  SearchCategory? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isLoading = false;
  String? _error;
  List<SearchResultItem> _searchResults = [];
  bool _hasSearched = false;

  final List<_CategoryOption> _categories = [
    _CategoryOption(
      category: SearchCategory.pettyCash,
      titleKey: 'home.petty_cash',
      icon: Icons.account_balance_wallet_outlined,
      color: appFontColor,
    ),
    _CategoryOption(
      category: SearchCategory.lpo,
      titleKey: 'home.lpo',
      icon: Icons.receipt_long_outlined,
      color: appFontColor,
    ),
    _CategoryOption(
      category: SearchCategory.myDocuments,
      titleKey: 'home.documents',
      icon: Icons.folder_outlined,
      color: appFontColor,
    ),
    _CategoryOption(
      category: SearchCategory.myNotes,
      titleKey: 'home.my_notes',
      icon: Icons.note_alt_outlined,
      color: appFontColor,
    ),
    _CategoryOption(
      category: SearchCategory.todoList,
      titleKey: 'home.todo_list',
      icon: Icons.checklist_outlined,
      color: appFontColor,
    ),
    _CategoryOption(
      category: SearchCategory.myProjects,
      titleKey: 'home.projects',
      icon: Icons.work_outline,
      color: appFontColor,
    ),
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().isNotEmpty && _selectedCategory != null) {
        _performSearch(query.trim());
      } else if (query.trim().isEmpty) {
        setState(() {
          _searchResults = [];
          _hasSearched = false;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    if (_selectedCategory == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _hasSearched = true;
    });

    try {
      final results = await _fetchSearchResults(_selectedCategory!, query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<List<SearchResultItem>> _fetchSearchResults(
      SearchCategory category, String query) async {
    final token = SharedPref.getLoginData().result?.token ?? '';
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    switch (category) {
      case SearchCategory.pettyCash:
        return _searchPettyCash(headers, query);
      case SearchCategory.lpo:
        return _searchLpo(headers, query);
      case SearchCategory.myDocuments:
        return _searchDocuments(headers, query);
      case SearchCategory.myNotes:
        return _searchNotes(headers, query);
      case SearchCategory.todoList:
        return _searchTodoList(headers, query);
      case SearchCategory.myProjects:
        return _searchProjects(headers, query);
    }
  }

  Future<List<SearchResultItem>> _searchPettyCash(
      Map<String, String> headers, String query) async {
    final url = Uri.parse('https://erp.elrace.com/api/get_expenses');
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'params': {'keyword': query},
    });

    final response = await http.post(url, headers: headers, body: body);
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['result'] != null) {
      final List items = data['result']['data'] ?? [];
      return items.map((item) {
        return SearchResultItem(
          id: item['id']?.toString() ?? '',
          title: item['name'] ?? item['expense_type'] ?? 'Expense',
          subtitle: item['description'] ?? '',
          amount: item['amount']?.toString(),
          date: item['date'] ?? item['created_at'],
          status: item['state'] ?? item['status'],
          rawData: item,
        );
      }).toList();
    }
    return [];
  }

  Future<List<SearchResultItem>> _searchLpo(
      Map<String, String> headers, String query) async {
    final url = Uri.parse('https://erp.elrace.com/api/get_lpos');
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'params': {
        'keyword': query,
        'page': 1,
        'limit': 20,
      },
    });

    final response = await http.post(url, headers: headers, body: body);
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['result'] != null) {
      final List items = data['result']['data'] ?? [];
      return items.map((item) {
        return SearchResultItem(
          id: item['id']?.toString() ?? '',
          title: item['name'] ?? item['lpo_name'] ?? 'LPO',
          subtitle: item['partner_name'] ?? item['vendor'] ?? '',
          amount: item['amount_total']?.toString(),
          date: item['date_order'] ?? item['created_at'],
          status: item['state'] ?? item['status'],
          rawData: item,
        );
      }).toList();
    }
    return [];
  }

  Future<List<SearchResultItem>> _searchDocuments(
      Map<String, String> headers, String query) async {
    final url = Uri.parse('https://erp.elrace.com/api/get_employee_documents');
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'params': {
        'keyword': query,
        'family_only': true,
        'doc_type': 'requested',
      },
    });

    final response = await http.post(url, headers: headers, body: body);
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['result'] != null) {
      final List items = data['result']['data'] ?? [];
      return items.map((item) {
        return SearchResultItem(
          id: item['id']?.toString() ?? '',
          title: item['name'] ?? item['title'] ?? 'Document',
          subtitle: item['document_type'] ?? item['type'] ?? '',
          date: item['expiry_date'] ?? item['created_at'],
          status: item['state'] ?? item['status'],
          rawData: item,
        );
      }).toList();
    }
    return [];
  }

  Future<List<SearchResultItem>> _searchNotes(
      Map<String, String> headers, String query) async {
    final url = Uri.parse('https://erp.elrace.com/api/get_notes');
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'params': {'keyword': query},
    });

    final response = await http.post(url, headers: headers, body: body);
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['result'] != null) {
      final List items = data['result']['data'] ?? [];
      return items.map((item) {
        return SearchResultItem(
          id: item['id']?.toString() ?? '',
          title: item['name'] ?? item['title'] ?? 'Note',
          subtitle: item['description'] ?? item['content'] ?? '',
          date: item['create_date'] ?? item['created_at'],
          status: item['state'] ?? item['status'],
          rawData: item,
        );
      }).toList();
    }
    return [];
  }

  Future<List<SearchResultItem>> _searchTodoList(
      Map<String, String> headers, String query) async {
    final url = Uri.parse('https://erp.elrace.com/api/get_todos');
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'params': {'keyword': query},
    });

    final response = await http.post(url, headers: headers, body: body);
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['result'] != null) {
      final List items = data['result']['data'] ?? [];
      return items.map((item) {
        return SearchResultItem(
          id: item['id']?.toString() ?? '',
          title: item['name'] ?? item['title'] ?? 'Todo',
          subtitle: item['description'] ?? '',
          date: item['due_date'] ?? item['created_at'],
          status:
              item['state'] ?? (item['is_done'] == true ? 'done' : 'pending'),
          rawData: item,
        );
      }).toList();
    }
    return [];
  }

  Future<List<SearchResultItem>> _searchProjects(
      Map<String, String> headers, String query) async {
    final url = Uri.parse('https://erp.elrace.com/api/get_projects');
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'params': {'keyword': query},
    });

    final response = await http.post(url, headers: headers, body: body);
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['result'] != null) {
      final List items = data['result']['data'] ?? [];
      return items.map((item) {
        return SearchResultItem(
          id: item['id']?.toString() ?? '',
          title: item['name'] ?? item['project_name'] ?? 'Project',
          subtitle: item['partner_name'] ?? item['client'] ?? '',
          date: item['date_start'] ?? item['created_at'],
          status: item['stage_id']?[1] ?? item['state'] ?? item['status'],
          rawData: item,
        );
      }).toList();
    }
    return [];
  }

  void _selectCategory(SearchCategory category) {
    setState(() {
      _selectedCategory = category;
      _searchResults = [];
      _hasSearched = false;
      _searchController.clear();
    });
  }

  void _clearCategory() {
    setState(() {
      _selectedCategory = null;
      _searchResults = [];
      _hasSearched = false;
      _searchController.clear();
    });
  }

  void _navigateToWidget() {
    if (_selectedCategory == null) return;

    Widget targetScreen;
    switch (_selectedCategory!) {
      case SearchCategory.pettyCash:
        targetScreen = const PettyCashScreen();
        break;
      case SearchCategory.lpo:
        targetScreen = const LpoListScreen();
        break;
      case SearchCategory.myDocuments:
        targetScreen = const MyDocumentsScreen();
        break;
      case SearchCategory.myNotes:
        targetScreen = const MyNotesScreen();
        break;
      case SearchCategory.todoList:
        targetScreen = const TodoListScreen();
        break;
      case SearchCategory.myProjects:
        targetScreen = const MyProject();
        break;
    }

    Util.pushPage(targetScreen, context);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final remoteDataSource = ProjectRemoteDataSource();
        final repository = ProjectRepositoryImpl(remoteDataSource);
        return ProjectListBloc(
          getProjectsUseCase: GetProjectsUseCase(repository: repository),
          getProjectAttachmentsUseCase:
              GetProjectAttachmentsUseCase(repository: repository),
          getProjectsByPartnerUseCase:
              GetProjectsByPartnerUseCase(repository: repository),
        );
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: const HeaderWidget(),
        extendBody: false,
        bottomNavigationBar: const CustomBottomNavBar(isMain: false),
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                child: Row(
                  children: [
                    BackButton(onPressed: () {
                      if (_selectedCategory != null) {
                        _clearCategory();
                      } else {
                        Navigator.of(context).pop();
                      }
                    }),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        translate('search.title'),
                        style: GoogleFonts.poppins(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w400,
                          color: appFontColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Category Selection or Search
              Expanded(
                child: _selectedCategory == null
                    ? _buildCategorySelection()
                    : _buildSearchInterface(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelection() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            translate('search.select_category'),
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            translate('search.select_category_desc'),
            style: GoogleFonts.poppins(
              fontSize: 13.sp,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 24.h),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16.w,
              mainAxisSpacing: 16.h,
              childAspectRatio: 1.3,
            ),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              return _buildCategoryCard(category);
            },
          ),
          SizedBox(height: 100.h + context.systemBottomInset),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(_CategoryOption option) {
    return GestureDetector(
      onTap: () => _selectCategory(option.category),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              option.color.withOpacity(0.1),
              option.color.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: option.color.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: option.color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: option.color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                option.icon,
                size: 28.sp,
                color: option.color,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              translate(option.titleKey),
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.visible,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchInterface() {
    final selectedOption = _categories.firstWhere(
      (c) => c.category == _selectedCategory,
    );

    return Column(
      children: [
        // Selected category chip
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: selectedOption.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: selectedOption.color.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selectedOption.icon,
                      size: 18.sp,
                      color: selectedOption.color,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      translate(selectedOption.titleKey),
                      style: GoogleFonts.poppins(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: selectedOption.color,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    GestureDetector(
                      onTap: _clearCategory,
                      child: Icon(
                        Icons.close,
                        size: 16.sp,
                        color: selectedOption.color,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _navigateToWidget,
                child: Text(
                  translate('search.view_all'),
                  style: GoogleFonts.poppins(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: blue,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),

        // Search bar
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              autofocus: true,
              decoration: InputDecoration(
                hintText: translate('search.search_placeholder'),
                hintStyle: GoogleFonts.poppins(
                  fontSize: 14.sp,
                  color: Colors.grey[500],
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey[500],
                  size: 22.sp,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _hasSearched = false;
                          });
                        },
                        icon: Icon(
                          Icons.clear,
                          color: Colors.grey[500],
                          size: 20.sp,
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 14.h,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 16.h),

        // Results
        Expanded(
          child: _buildSearchResults(),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48.sp, color: Colors.red[300]),
            SizedBox(height: 16.h),
            Text(
              translate('search.error'),
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8.h),
            TextButton(
              onPressed: () {
                if (_searchController.text.isNotEmpty) {
                  _performSearch(_searchController.text);
                }
              },
              child: Text(translate('search.retry')),
            ),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64.sp,
              color: Colors.grey[300],
            ),
            SizedBox(height: 16.h),
            Text(
              translate('search.start_searching'),
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64.sp,
              color: Colors.grey[300],
            ),
            SizedBox(height: 16.h),
            Text(
              translate('search.no_results'),
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Builder(
      builder: (context) {
        return ListView.separated(
          padding: EdgeInsets.symmetric(horizontal: 16.w) +
              EdgeInsets.only(
                bottom:
                    kBottomNavigationBarHeight + context.systemBottomInset + 16,
              ),
          itemCount: _searchResults.length,
          separatorBuilder: (_, __) => SizedBox(height: 12.h),
          itemBuilder: (context, index) {
            final item = _searchResults[index];
            return _buildResultCard(item);
          },
        );
      },
    );
  }

  Widget _buildResultCard(SearchResultItem item) {
    // Use category-specific widgets
    if (_selectedCategory == SearchCategory.lpo) {
      return _buildLpoCard(item);
    } else if (_selectedCategory == SearchCategory.myProjects) {
      return _buildProjectCard(item);
    } else if (_selectedCategory == SearchCategory.pettyCash) {
      return _buildPettyCashCard(item);
    }

    // Fallback for other categories (documents, notes, todo)
    final selectedOption = _categories.firstWhere(
      (c) => c.category == _selectedCategory,
    );

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: selectedOption.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  selectedOption.icon,
                  size: 20.sp,
                  color: selectedOption.color,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.poppins(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                      maxLines: null,
                      overflow: TextOverflow.visible,
                    ),
                    if (item.subtitle.isNotEmpty)
                      Text(
                        item.subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 12.sp,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.visible,
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (item.amount != null || item.date != null || item.status != null)
            Padding(
              padding: EdgeInsets.only(top: 12.h),
              child: Row(
                children: [
                  if (item.amount != null) ...[
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        '${item.amount} AED',
                        style: GoogleFonts.poppins(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                  ],
                  if (item.date != null) ...[
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14.sp,
                      color: Colors.grey[500],
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      item.date!,
                      style: GoogleFonts.poppins(
                        fontSize: 11.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(width: 8.w),
                  ],
                  if (item.status != null) ...[
                    const Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(item.status!).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        item.status!,
                        style: GoogleFonts.poppins(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          color: _getStatusColor(item.status!),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    final lowercaseStatus = status.toLowerCase();
    if (lowercaseStatus.contains('done') ||
        lowercaseStatus.contains('approved') ||
        lowercaseStatus.contains('complete')) {
      return Colors.green;
    } else if (lowercaseStatus.contains('pending') ||
        lowercaseStatus.contains('waiting') ||
        lowercaseStatus.contains('draft')) {
      return Colors.orange;
    } else if (lowercaseStatus.contains('reject') ||
        lowercaseStatus.contains('cancel')) {
      return Colors.red;
    }
    return Colors.blue;
  }

  // Build LPO Card using the original LpoCardWidget
  Widget _buildLpoCard(SearchResultItem item) {
    final data = item.rawData;
    final poId = data['id'] as int?;
    return LpoCardWidget(
      poId: poId,
      name: data['name'] ?? item.title,
      vendorName: data['vendor_name'] ?? data['partner_name'],
      projectName: data['project_name'] ?? data['x_project_id']?[1],
      date: data['date_order'] ?? data['date'] ?? item.date,
      amount: data['amount_total']?.toString() ?? item.amount,
      attachments: data['attachments'],
      lpoCount: data['lpo_count'],
      clientPhoto: data['partner_photo'],
      requestedByUserPhoto: data['requested_by_user_photo'],
      requestedBy: data['requested_by'],
      requesterManager: data['requester_manager'],
      state: data['state'] ?? item.status,
      onTap: poId != null ? () => Util.openLpoPdfReport(context, poId) : null,
    );
  }

  // Build Project Card using ProjectCardWidget
  Widget _buildProjectCard(SearchResultItem item) {
    final data = item.rawData;

    print('🔍 Building Project Card for: ${item.title}');
    print('📦 Raw data: $data');

    // Create a ProjectEntity from the raw data
    final project = ProjectEntity(
      projectId: int.tryParse(data['id']?.toString() ?? '0') ?? 0,
      partnerId: data['partner_id']?[0]?.toString() ??
          data['partner_id']?.toString() ??
          '',
      name: data['name'] ?? item.title,
      agreementId: data['agreement_id'] ??
          data['analytic_account_id']?[1] ??
          data['analytic_account_id']?.toString() ??
          '',
      woRefNo: data['wo_ref_no'] ?? data['name'] ?? '',
      woAmount: double.tryParse(data['wo_amount']?.toString() ??
              data['amount']?.toString() ??
              '0') ??
          0.0,
      projectStatus: data['project_status'] ?? data['stage_id']?[1] ?? 'Active',
      date: data['date'] ??
          data['date_start'] ??
          item.date ??
          DateTime.now().toString(),
      dateStart: data['date_start'] ??
          data['date'] ??
          item.date ??
          DateTime.now().toString(),
      projectManagerPhoto: data['project_manager_photo'],
      differenceDays:
          int.tryParse(data['difference_days']?.toString() ?? '0') ?? 0,
    );

    print('✅ Project Entity created: ${project.name}');

    // Get or create a ProjectListBloc instance
    final bloc = context.read<ProjectListBloc>();

    return ProjectCardWidget(
      item: project,
      bloc: bloc,
    );
  }

  // Build Petty Cash Card
  Widget _buildPettyCashCard(SearchResultItem item) {
    final data = item.rawData;
    final status = data['state'] ?? data['status'] ?? item.status ?? 'PENDING';
    final date = _formatPettyCashDate(data['date'] ?? item.date ?? '');
    final amount = _formatPettyCashAmount(
        data['amount']?.toString() ?? item.amount ?? '0');

    return Container(
      margin: EdgeInsets.symmetric(vertical: 5.h, horizontal: 5.w),
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/png/item_bg_green.png'),
          fit: BoxFit.cover,
        ),
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha((0.1 * 255).toInt()),
            blurRadius: 4,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 8, 15, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  status.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: appFontColor,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 15),
            const SizedBox(
              height: 30,
              child: VerticalDivider(
                color: Colors.grey,
                thickness: 2,
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Date',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xff151544),
                    ),
                  ),
                  Text(
                    date,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
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
            const SizedBox(width: 5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Amount',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: appFontColor,
                    ),
                  ),
                  Text(
                    amount,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 0),
            const CircleAvatar(
              radius: 10,
              backgroundImage: AssetImage('assets/png/tick-petty.png'),
            ),
            const SizedBox(width: 5),
          ],
        ),
      ),
    );
  }

  String _formatPettyCashDate(String date) {
    if (date.isEmpty) return '--';
    try {
      final dt = DateTime.parse(date);
      return DateFormat('dd/MM/yy').format(dt);
    } catch (_) {
      return date;
    }
  }

  String _formatPettyCashAmount(String amount) {
    if (amount.isEmpty) return '0.00';
    try {
      final value = double.parse(amount);
      return value.toStringAsFixed(2);
    } catch (_) {
      return amount;
    }
  }
}

class _CategoryOption {
  final SearchCategory category;
  final String titleKey;
  final IconData icon;
  final Color color;

  _CategoryOption({
    required this.category,
    required this.titleKey,
    required this.icon,
    required this.color,
  });
}
