import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:el_race/data/models/global_search_item.dart';
import 'package:el_race/data/models/lpo_search_model.dart';
import 'package:el_race/providers/global_search_provider.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:el_race/utils/global_search_navigation_helper.dart';
import 'package:el_race/utils/Util.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:el_race/ui/presentation/lpo/widgets/lpo_card_widget.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/screens/my_project.dart'
    show buildProjectCard;
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_list_bloc.dart';
import 'package:el_race/ui/presentation/my_projects/data/repositories/project_repository_impl.dart';
import 'package:el_race/ui/presentation/my_projects/data/datasources/project_remote_datasource.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_usecase.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_by_partner_usecase.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_dialog.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/screens/project_list_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Global Search Screen Widget
///
/// Features:
/// - Debounced search (400ms)
/// - Category selection
/// - Loading, empty, and error states
/// - Keyword highlighting
/// - Navigation to detail screens
class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'lpo';

  String? _asNonEmptyString(dynamic value) {
    final s = value?.toString().trim();
    if (s == null || s.isEmpty) return null;
    if (s.toLowerCase() == 'false' || s.toLowerCase() == 'null') return null;
    return s;
  }

  String? _normalizeImageUrl(String? url) {
    if (url == null || url.isEmpty) return null;

    // Some payloads come as "https:/domain..." (missing slash).
    if (url.startsWith('https:/') && !url.startsWith('https://')) {
      return url.replaceFirst('https:/', 'https://');
    }
    if (url.startsWith('http:/') && !url.startsWith('http://')) {
      return url.replaceFirst('http:/', 'http://');
    }

    // Handle scheme-less absolute URL.
    if (url.startsWith('//')) {
      return 'https:$url';
    }

    // Handle relative path from backend.
    if (url.startsWith('/')) {
      return 'https://erp.elrace.com$url';
    }

    return url;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      child: ChangeNotifierProvider(
        create: (_) => GlobalSearchProvider(),
        child: Builder(
          builder: (context) {
            return Scaffold(
              backgroundColor: Colors.white,
              appBar: const HeaderWidget(),
              body: Column(
                children: [
                  _buildSearchBar(),
                  _buildCategorySelector(),
                  Expanded(child: _buildSearchResults()),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Search bar with clear button
  Widget _buildSearchBar() {
    return Consumer<GlobalSearchProvider>(
      builder: (context, provider, _) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              provider.search(
                category: _selectedCategory,
                keyword: value,
                limit: 20,
              );
            },
            decoration: InputDecoration(
              hintText: 'Search...',
              hintStyle: TextStyle(color: Colors.grey[500]),
              prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey[600]),
                      onPressed: () {
                        _searchController.clear();
                        provider.clearResults();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            ),
          ),
        );
      },
    );
  }

  /// Category selector chips
  Widget _buildCategorySelector() {
    final categories = [
      {'value': 'lpo', 'label': 'LPO', 'icon': Icons.description},
      {'value': 'petty_cash', 'label': 'Petty Cash', 'icon': Icons.receipt},
      {'value': 'projects', 'label': 'My Projects', 'icon': Icons.work},
      {'value': 'my_actions', 'label': 'My Actions', 'icon': Icons.assignment},
    ];

    return Container(
      height: 50.h,
      margin: EdgeInsets.only(bottom: 8.h),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedCategory == category['value'];

          return Consumer<GlobalSearchProvider>(
            builder: (context, provider, _) {
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 4.w),
                child: ChoiceChip(
                  label: Text(category['label'] as String),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedCategory = category['value'] as String;
                      });

                      // Re-trigger search if there's text
                      if (_searchController.text.trim().length >= 2) {
                        provider.search(
                          category: _selectedCategory,
                          keyword: _searchController.text,
                          limit: 20,
                        );
                      }
                    }
                  },
                  selectedColor: appFontColor,
                  backgroundColor: Colors.grey[200],
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : appFontColor,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  showCheckmark: false,
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Build search results based on state
  Widget _buildSearchResults() {
    return Consumer<GlobalSearchProvider>(
      builder: (context, provider, _) {
        // Idle state
        if (provider.state == GlobalSearchState.idle) {
          return _buildEmptyState(
            icon: Icons.search,
            title: 'Start Searching',
            message: 'Enter at least 2 characters to search',
          );
        }

        // Loading state - Show skeleton loaders
        if (provider.isLoading) {
          return _buildSkeletonLoader();
        }

        // Error state
        if (provider.hasError) {
          return _buildErrorState(
            message: provider.errorMessage ?? 'An error occurred',
            onRetry: () => provider.retry(),
          );
        }

        // Empty state
        if (provider.isEmpty) {
          return _buildEmptyState(
            icon: Icons.search_off,
            title: 'No Results Found',
            message: 'Try adjusting your search keywords',
          );
        }

        // Results
        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 8.h),
          itemCount: provider.results.length,
          itemBuilder: (context, index) {
            return _buildResultItem(
              context,
              provider.results[index],
              provider.currentKeyword,
            );
          },
        );
      },
    );
  }

  /// Build skeleton loader for petty cash cards
  Widget _buildSkeletonLoader() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      itemCount: 5,
      itemBuilder: (context, index) {
        if (_selectedCategory == 'petty_cash') {
          return _buildPettyCashSkeleton();
        } else if (_selectedCategory == 'lpo') {
          return _buildLpoSkeleton();
        } else if (_selectedCategory == 'my_actions') {
          return _buildGenericSkeleton();
        } else {
          return _buildGenericSkeleton();
        }
      },
    );
  }

  /// Petty Cash skeleton loader
  Widget _buildPettyCashSkeleton() {
    return Container(
        margin: EdgeInsets.symmetric(vertical: 5.h, horizontal: 5.w),
        height: 152.h,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(30.r),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: _buildShimmerBox(width: 73.w, height: 41.h),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: _buildShimmerBox(width: 120.w, height: 14.h)),
                  SizedBox(height: 26.h),
                  _buildShimmerBox(width: 170.w, height: 18.h),
                  const Spacer(),
                  Row(
                    children: [
                      SizedBox(width: 86.w),
                      Expanded(
                        child: Center(
                          child: _buildShimmerBox(width: 90.w, height: 24.h),
                        ),
                      ),
                      SizedBox(
                        width: 92.w,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildShimmerBox(width: 64.w, height: 10.h),
                            SizedBox(height: 4.h),
                            _buildShimmerBox(width: 74.w, height: 10.h),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ));
  }

  /// LPO skeleton loader
  Widget _buildLpoSkeleton() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 5.h, horizontal: 5.w),
      padding: EdgeInsets.all(12.w),
      constraints: BoxConstraints(
        minHeight: 100.h,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildShimmerBox(width: 60.w, height: 20.h),
              const Spacer(),
              _buildShimmerBox(width: 40.w, height: 40.h, isCircle: true),
            ],
          ),
          SizedBox(height: 8.h),
          _buildShimmerBox(width: 150.w, height: 15.h),
          SizedBox(height: 4.h),
          _buildShimmerBox(width: 200.w, height: 15.h),
          SizedBox(height: 8.h),
          Row(
            children: [
              _buildShimmerBox(width: 80.w, height: 15.h),
              const Spacer(),
              _buildShimmerBox(width: 60.w, height: 15.h),
            ],
          ),
        ],
      ),
    );
  }

  /// Generic skeleton loader
  Widget _buildGenericSkeleton() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 5.h, horizontal: 5.w),
      padding: EdgeInsets.all(12.w),
      height: 100.h,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          _buildShimmerBox(width: 48.w, height: 48.h),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildShimmerBox(width: 150.w, height: 15.h),
                SizedBox(height: 8.h),
                _buildShimmerBox(width: 200.w, height: 12.h),
                SizedBox(height: 8.h),
                _buildShimmerBox(width: 80.w, height: 12.h),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Shimmer box widget
  Widget _buildShimmerBox({
    required double width,
    required double height,
    bool isCircle = false,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: isCircle ? null : BorderRadius.circular(4.r),
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
      ),
    );
  }

  /// Build individual search result item
  Widget _buildResultItem(
      BuildContext context, GlobalSearchItem item, String keyword) {
    // Use specific widgets for each category
    if (item.category == 'lpo') {
      return Container(
        width: double.infinity,
        child: _buildLpoCard(item),
      );
    } else if (item.category == 'projects') {
      return _buildProjectCard(item);
    } else if (item.category == 'petty_cash') {
      return _buildPettyCashCard(item);
    } else if (item.category == 'my_actions') {
      return _buildMyActionsCard(item, keyword);
    }

    // Fallback to generic card for other categories
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: InkWell(
        onTap: () => _navigateToDetail(item),
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48.w,
                height: 48.h,
                decoration: BoxDecoration(
                  color: _getCategoryColor(item.category).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  _getCategoryIcon(item.category),
                  color: _getCategoryColor(item.category),
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 12.w),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title with highlighting
                    _buildHighlightedText(
                      item.title,
                      keyword,
                      style: GoogleFonts.poppins(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: appFontColor,
                      ),
                    ),

                    if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Text(
                        item.subtitle!,
                        style: GoogleFonts.poppins(
                          fontSize: 13.sp,
                          color: Colors.grey[600],
                        ),
                        maxLines: null,
                        overflow: TextOverflow.visible,
                      ),
                    ],

                    SizedBox(height: 6.h),

                    // Category badge
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color:
                            _getCategoryColor(item.category).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        item.displayCategory,
                        style: GoogleFonts.poppins(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: _getCategoryColor(item.category),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow icon
              Icon(
                Icons.arrow_forward_ios,
                size: 16.sp,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build highlighted text with keyword emphasis
  Widget _buildHighlightedText(
    String text,
    String keyword, {
    required TextStyle style,
  }) {
    if (keyword.isEmpty) {
      return Text(text, style: style);
    }

    final lowerText = text.toLowerCase();
    final lowerKeyword = keyword.toLowerCase();
    final spans = <TextSpan>[];

    int start = 0;
    int indexOfKeyword;

    while ((indexOfKeyword = lowerText.indexOf(lowerKeyword, start)) != -1) {
      // Add text before keyword
      if (indexOfKeyword > start) {
        spans.add(TextSpan(text: text.substring(start, indexOfKeyword)));
      }

      // Add highlighted keyword
      spans.add(TextSpan(
        text: text.substring(indexOfKeyword, indexOfKeyword + keyword.length),
        style: style.copyWith(
          backgroundColor: Colors.yellow.withOpacity(0.3),
          fontWeight: FontWeight.w700,
        ),
      ));

      start = indexOfKeyword + keyword.length;
    }

    // Add remaining text
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return RichText(
      text: TextSpan(style: style, children: spans),
      maxLines: 2,
      overflow: TextOverflow.visible,
    );
  }

  /// Empty state widget
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80.sp, color: Colors.grey[300]),
            SizedBox(height: 16.h),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Error state widget with retry
  Widget _buildErrorState({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80.sp, color: Colors.grey[400]),
            SizedBox(height: 16.h),
            Text(
              'Oops!',
              style: GoogleFonts.poppins(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                color: Colors.grey[500],
              ),
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: appFontColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get category icon
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'petty_cash':
        return Icons.receipt;
      case 'projects':
        return Icons.work;
      case 'lpo':
        return Icons.description;
      case 'notes':
        return Icons.note;
      case 'documents':
        return Icons.folder;
      case 'tasks':
        return Icons.task;
      case 'my_actions':
        return Icons.assignment;
      default:
        return Icons.search;
    }
  }

  /// Get category color
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'petty_cash':
        return Colors.green;
      case 'projects':
        return Colors.blue;
      case 'lpo':
        return Colors.orange;
      case 'notes':
        return Colors.purple;
      case 'documents':
        return Colors.teal;
      case 'tasks':
        return appFontColor;
      case 'my_actions':
        return const Color(0xFF1A2540);
      default:
        return Colors.grey;
    }
  }

  /// Navigate to detail screen based on category
  void _navigateToDetail(GlobalSearchItem item) {
    GlobalSearchNavigationHelper.navigateToDetail(context, item);
  }

  // Build LPO Card
  Widget _buildLpoCard(GlobalSearchItem item) {
    final data = item.additionalData ?? {};

    // Parse the data into LpoSearchModel
    LpoSearchModel? lpoModel;
    try {
      lpoModel = LpoSearchModel.fromJson(data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error parsing LPO model: $e');
      }
    }

    // Use model data if available, otherwise fallback to manual parsing
    if (lpoModel != null) {
      final modelId = lpoModel.id; // Capture ID in local variable
      return LpoCardWidget(
        poId: modelId,
        name: lpoModel.name,
        vendorName: lpoModel.partnerId,
        projectName: lpoModel.project,
        date: lpoModel.dateOrder,
        amount: lpoModel.amountTotal.toString(),
        attachments: lpoModel.attachments
            .map((a) => {
                  'id': a.id,
                  'name': a.name,
                  'url': a.url,
                })
            .toList(),
        lpoCount: null,
        clientPhoto:
            _normalizeImageUrl(_asNonEmptyString(lpoModel.clientPhoto)),
        requestedByUserPhoto: _normalizeImageUrl(
            _asNonEmptyString(lpoModel.requestedByUserPhoto)),
        requestedBy: lpoModel.requestedBy,
        requesterManager: lpoModel.requesterManager,
        state: lpoModel.state,
        onTap: () => Util.openLpoPdfReport(context, modelId),
      );
    }

    // Fallback to manual parsing
    String? _pickVendor() {
      final partner = data['partner_id'];
      if (partner is List && partner.length > 1) return partner[1]?.toString();
      if (partner != null) return partner.toString();
      return data['vendor_name'] ??
          data['partner_name'] ??
          data['vendor'] ??
          data['supplier'] ??
          data['supplier_name'] ??
          item.subtitle;
    }

    String? _pickProject() {
      final xProject = data['x_project_id'];
      if (xProject is List && xProject.length > 1)
        return xProject[1]?.toString();
      if (xProject != null) return xProject.toString();
      final projectId = data['project_id'];
      if (projectId is List && projectId.length > 1)
        return projectId[1]?.toString();
      if (projectId != null) return projectId.toString();
      return data['project_name'] ??
          data['project'] ??
          data['project_description'] ??
          data['analytic_account_id']?[1] ??
          data['analytic_account_id']?.toString();
    }

    String? _pickAmount() {
      final amountCandidates = [
        data['amount_total'],
        data['total_amount'],
        data['amount_untaxed'],
        data['amount'],
        data['amount_total_signed'],
        data['amount'],
        data['balance_due'],
      ];
      final first = amountCandidates.firstWhere(
        (v) => v != null,
        orElse: () => null,
      );
      return first?.toString();
    }

    String? _pickDate() {
      return data['date_order'] ??
          data['order_date'] ??
          data['commitment_date'] ??
          data['expected_date'] ??
          data['date'] ??
          data['create_date'];
    }

    return LpoCardWidget(
      poId: item.id,
      name: data['name'] ?? item.title,
      vendorName: _pickVendor(),
      projectName: _pickProject(),
      date: _pickDate(),
      amount: _pickAmount(),
      attachments: (data['attachments'] as List?) ?? const [],
      lpoCount: data['lpo_count'],
      clientPhoto: _normalizeImageUrl(
          _asNonEmptyString(data['partner_photo'] ?? data['client_photo'])),
      requestedByUserPhoto: _normalizeImageUrl(
          _asNonEmptyString(data['requested_by_user_photo'])),
      requestedBy: data['requested_by'],
      requesterManager: data['requester_manager'],
      state: data['state'] ?? data['status'],
      onTap: () => Util.openLpoPdfReport(context, item.id),
    );
  }

  // Build Project Card
  Widget _buildProjectCard(GlobalSearchItem item) {
    final data = item.additionalData ?? {};

    debugPrint('🔍 [GlobalSearch] Projects raw data: $data');

    final dynamic countRaw = data['total_projects'] ??
        data['project_count'] ??
        data['difference_days'];
    final int projectsCount = countRaw is num
        ? countRaw.toInt()
        : int.tryParse(countRaw?.toString() ?? '0') ?? 0;

    final dynamic amountRaw = data['total_projects_amount'] ??
        data['wo_amount'] ??
        data['amount'] ??
        data['amount_total'];
    final double amountAed = amountRaw is num
        ? amountRaw.toDouble()
        : double.tryParse(amountRaw?.toString() ?? '0') ?? 0.0;

    final String cardId = (data['agreement_no'] ??
            data['analytic_account_id']?[1] ??
            data['wo_ref_no'] ??
            item.id)
        .toString();

    // Extract real location from response fields
    String location = '';
    final stateId = data['state_id'];
    final countryId = data['country_id'];
    location = (data['location_id'] ??
            data['city'] ??
            data['location'] ??
            data['partner_city'] ??
            (stateId is List && stateId.length > 1 ? stateId[1] : null) ??
            (countryId is List && countryId.length > 1 ? countryId[1] : null) ??
            data['partner_location'] ??
            '')
        .toString();

    final String photoUrl = (data['client_photo'] ??
            data['photo_url'] ??
            data['partner_photo'] ??
            data['project_manager_photo'] ??
            '')
        .toString();

    // Extract project_id: prefer data['project_id'], fallback to item.id
    final int projectId = int.tryParse(
            (data['project_id'] ?? item.id).toString()) ??
        0;

    return GestureDetector(
      onTap: () {
        final repo = ProjectRepositoryImpl(ProjectRemoteDataSource());
        final bloc = ProjectListBloc(
          getProjectsUseCase: GetProjectsUseCase(repository: repo),
          getProjectAttachmentsUseCase:
              GetProjectAttachmentsUseCase(repository: repo),
          getProjectsByPartnerUseCase:
              GetProjectsByPartnerUseCase(repository: repo),
        );
        ProjectDocumentsDialog.show(
          context,
          projectId: projectId,
          bloc: bloc,
        );
      },
      child: buildProjectCard(
        id: cardId,
        name: item.title,
        photoUrl: photoUrl,
        projectsCount: projectsCount,
        amountAed: amountAed,
        location: location,
      ),
    );
  }

  // Build Petty Cash Card
  Widget _buildPettyCashCard(GlobalSearchItem item) {
    final data = item.additionalData ?? {};
    final status = (data['state'] ?? data['status'])?.toString() ?? 'pending';

    final requestNoRaw = _asNonEmptyString(data['reference']) ??
        _asNonEmptyString(data['name']) ??
        _asNonEmptyString(item.title) ??
        item.id.toString();

    final titleRaw = _asNonEmptyString(data['employee_name']) ??
        _asNonEmptyString(data['requested_by']) ??
        _asNonEmptyString(item.subtitle) ??
        _asNonEmptyString(item.title) ??
        'PETTY CASH';

    final rawAmount =
        data['amount_total'] ?? data['total_amount'] ?? data['amount'];
    final amount = _formatPettyCashAmount(rawAmount);

    final dateRaw = _asNonEmptyString(data['date']) ??
        _asNonEmptyString(data['create_date']) ??
        _asNonEmptyString(data['write_date']);
    final lastUpdated = _formatPettyCashDate(dateRaw ?? '');

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 7.h),
      child: GestureDetector(
        onTap: () => _navigateToDetail(item),
        child: Container(
          height: 152.h,
          decoration: BoxDecoration(
            color: const Color(0xFFF9F9F9),
            borderRadius: BorderRadius.circular(30.r),
            border: Border.all(color: const Color(0xFF9F9F9F), width: 1),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.only(topLeft: Radius.circular(30.r)),
                  child: Image.asset(
                    _pettyStatusBadgeAsset(status),
                    width: 73.w,
                    height: 41.h,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        requestNoRaw,
                        maxLines: null,
                        overflow: TextOverflow.visible,
                        style: GoogleFonts.poppins(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0A3887),
                        ),
                      ),
                    ),
                    SizedBox(height: 26.h),
                    Text(
                      titleRaw.toUpperCase(),
                      maxLines: null,
                      overflow: TextOverflow.visible,
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF083A85),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        SizedBox(width: 86.w),
                        Expanded(
                          child: Center(
                            child: Text(
                              amount,
                              style: GoogleFonts.poppins(
                                fontSize: 22.sp,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF073A85),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 92.w,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Last Updated',
                                style: GoogleFonts.poppins(
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFB8B8B8),
                                ),
                              ),
                              Text(
                                lastUpdated,
                                style: GoogleFonts.poppins(
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFB8B8B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPettyCashAmount(dynamic rawAmount) {
    if (rawAmount == null) return '';
    final value = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse(rawAmount.toString()) ?? 0.0;

    final formatter = NumberFormat.decimalPattern();
    if (value == value.roundToDouble()) {
      return formatter.format(value.toInt());
    }
    return formatter.format(value);
  }

  /// Build My Actions search result card
  Widget _buildMyActionsCard(GlobalSearchItem item, String keyword) {
    final data = item.additionalData ?? {};
    final status = (data['status'] ?? '').toString().trim();
    final employeeName = (data['employee_name'] ?? '').toString();
    final requestType = (data['request_type'] ?? '').toString();
    final reference = (data['reference'] ?? '').toString();
    final vendor = (data['vendor'] ?? '').toString();
    final amountTotal = data['amount_total'];
    final date = (data['date'] ?? '').toString();

    String statusBadge;
    Color statusColor;
    switch (status.toLowerCase()) {
      case 'approved':
        statusBadge = 'APPROVED';
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusBadge = 'REJECTED';
        statusColor = Colors.red;
        break;
      case 'pending':
      default:
        statusBadge = status.isNotEmpty ? status.toUpperCase() : 'PENDING';
        statusColor = Colors.orange;
        break;
    }

    String formattedDate = '--';
    if (date.isNotEmpty) {
      try {
        final dt = DateTime.parse(date);
        formattedDate = DateFormat('dd/MM/yy').format(dt);
      } catch (_) {
        formattedDate = date;
      }
    }

    return Card(
        margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            color: Colors.white,
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(children: [
            // Status indicator
            Container(
              width: 4.w,
              height: 60.h,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
            SizedBox(width: 12.w),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title / Name
                  _buildHighlightedText(
                    item.title,
                    keyword,
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0D3E7F),
                    ),
                  ),
                  if (reference.isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    Text(
                      reference,
                      style: GoogleFonts.poppins(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                      maxLines: null,
                      overflow: TextOverflow.visible,
                    ),
                  ],
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      if (employeeName.isNotEmpty) ...[
                        Icon(Icons.person_outline,
                            size: 14.sp, color: Colors.grey[500]),
                        SizedBox(width: 4.w),
                        Flexible(
                          child: Text(
                            employeeName,
                            style: GoogleFonts.poppins(
                              fontSize: 11.sp,
                              color: Colors.grey[600],
                            ),
                            maxLines: null,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ],
                      if (requestType.isNotEmpty) ...[
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 6.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A2540).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            requestType,
                            style: GoogleFonts.poppins(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A2540),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (vendor.isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    Text(
                      vendor,
                      style: GoogleFonts.poppins(
                          fontSize: 11.sp, color: Colors.grey[500]),
                      maxLines: null,
                      overflow: TextOverflow.visible,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 8.w),
            // Right side: amount + date + status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (amountTotal != null && amountTotal != 0)
                  Text(
                    NumberFormat.decimalPattern().format(amountTotal is num
                        ? amountTotal
                        : double.tryParse(amountTotal.toString()) ?? 0),
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0D3E7F),
                    ),
                  ),
                SizedBox(height: 4.h),
                Text(
                  formattedDate,
                  style: GoogleFonts.poppins(
                      fontSize: 11.sp, color: Colors.grey[500]),
                ),
                SizedBox(height: 4.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    statusBadge,
                    style: GoogleFonts.poppins(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ]),
        ));
  }

  String _pettyStatusBadgeAsset(String status) {
    switch (status.trim().toLowerCase()) {
      case 'approved':
        return 'assets/newapp/approvedBadge.png';
      case 'rejected':
      case 'cancelled':
      case 'canceled':
        return 'assets/newapp/rejectBadge.png';
      default:
        return 'assets/newapp/warningBadge.png';
    }
  }

  String _formatPettyCashDate(String date) {
    if (date.isEmpty) return '--/--/----';
    try {
      final normalized = date.contains(' ') && !date.contains('T')
          ? date.replaceFirst(' ', 'T')
          : date;
      final dt = DateTime.parse(normalized);
      return DateFormat('MM/dd/yyyy').format(dt);
    } catch (_) {
      return date;
    }
  }
}
