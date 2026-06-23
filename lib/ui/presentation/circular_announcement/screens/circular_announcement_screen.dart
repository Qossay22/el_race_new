import 'package:el_race/ui/presentation/circular_announcement/data/circular_announcement_api_service.dart';
import 'package:el_race/ui/presentation/circular_announcement/data/circular_announcement_model.dart';
import 'package:el_race/ui/presentation/circular_announcement/widgets/circular_announcement_file_viewer.dart';
import 'package:el_race/ui/presentation/home_screen/screens/main_screens.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class CircularAnnouncementScreen extends StatefulWidget {
  /// Optional: initial tab index (0 = circulars, 1 = announcements)
  final int initialTabIndex;

  /// Optional: specific item ID to auto-open
  final int? autoOpenItemId;

  /// Optional: category of the auto-open item ('circular' or 'announcement')
  final String? autoOpenCategory;

  const CircularAnnouncementScreen({
    super.key,
    this.initialTabIndex = 0,
    this.autoOpenItemId,
    this.autoOpenCategory,
  });

  @override
  State<CircularAnnouncementScreen> createState() =>
      _CircularAnnouncementScreenState();
}

class _CircularAnnouncementScreenState extends State<CircularAnnouncementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CircularAnnouncementApiService _apiService =
      CircularAnnouncementApiService();

  bool _isLoading = true;
  String? _error;
  CircularAnnouncementResponse? _data;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.fetchCircularAnnouncements();

      if (mounted) {
        setState(() {
          _data = response;
          _isLoading = false;
        });

        // Auto-open item if specified
        if (widget.autoOpenItemId != null && widget.autoOpenCategory != null) {
          _autoOpenItem();
        }
      }
    } catch (e) {
      print('❌ Error loading circulars/announcements: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _autoOpenItem() {
    if (_data == null || widget.autoOpenItemId == null) return;

    // Switch to correct tab
    if (widget.autoOpenCategory?.toLowerCase() == 'announcement') {
      _tabController.animateTo(1);
      // Find and open the announcement
      final item = _data!.announcements.firstWhere(
        (a) => a.id == widget.autoOpenItemId,
        orElse: () => const CircularAnnouncementItem(
          id: -1,
          title: '',
          description: '',
          category: '',
        ),
      );
      if (item.id != -1 && item.hasFile) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _openFile(item);
        });
      }
    } else {
      _tabController.animateTo(0);
      // Find and open the circular
      final item = _data!.circulars.firstWhere(
        (c) => c.id == widget.autoOpenItemId,
        orElse: () => const CircularAnnouncementItem(
          id: -1,
          title: '',
          description: '',
          category: '',
        ),
      );
      if (item.id != -1 && item.hasFile) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _openFile(item);
        });
      }
    }
  }

  void _openFile(CircularAnnouncementItem item) {
    if (!item.hasFile) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(translate('circular_announcement.no_file_attached')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CircularAnnouncementFileViewer(
          item: item,
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('MMM dd, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const HeaderWidget(),
      bottomNavigationBar: const CustomBottomNavBar(isMain: false),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const SizedBox(height: 10),

          // Tab Bar
          _buildTabBar(),

          const SizedBox(height: 16),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorWidget()
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildListView(_data?.circulars ?? [], 'circular'),
                          _buildListView(
                              _data?.announcements ?? [], 'announcement'),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 55.w,
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              index: 0,
              icon: 'assets/png/urgent_icon.png',
              title: translate('notification_screen.circulars'),
              count: _data?.circularCount ?? 0,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildTabButton(
              index: 1,
              icon: 'assets/png/announcement.png',
              title: translate('news_banner.announcements'),
              count: _data?.announcementCount ?? 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required String icon,
    required String title,
    required int count,
  }) {
    final isSelected = _tabController.index == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _tabController.animateTo(index);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: isSelected
              ? const LinearGradient(
                  colors: [
                    Color.fromARGB(255, 27, 27, 27),
                    appFontColor,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : const LinearGradient(
                  colors: [
                    Color(0xffD6D6D6),
                    Color(0xffADB2BD),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
        ),
        child: Stack(
          children: [
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    icon,
                    height: 25.w,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      title.toUpperCase(),
                      style: GoogleFonts.poppins(
                        color:
                            isSelected ? Colors.white : const Color(0xFF1A237E),
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w400,
                      ),
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ],
              ),
            ),
            // Badge for count
            if (count > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : appFontColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: isSelected ? appFontColor : Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              translate('common.error_occurred'),
              style: GoogleFonts.poppins(
                fontSize: 18.sp,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: Text(translate('common.retry')),
              style: ElevatedButton.styleFrom(
                backgroundColor: appFontColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(List<CircularAnnouncementItem> items, String type) {
    if (items.isEmpty) {
      return _buildEmptyWidget(type);
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: kBottomNavigationBarHeight + context.systemBottomInset + 16,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _buildItemCard(item);
        },
      ),
    );
  }

  Widget _buildEmptyWidget(String type) {
    final isCircular = type == 'circular';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              isCircular
                  ? 'assets/png/urgent_icon.png'
                  : 'assets/png/announcement.png',
              height: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isCircular
                  ? translate('circular_announcement.no_circulars')
                  : translate('circular_announcement.no_announcements'),
              style: GoogleFonts.poppins(
                fontSize: 18.sp,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(CircularAnnouncementItem item) {
    return GestureDetector(
      onTap: () => _openFile(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage('assets/png/bg_petty.png'),
            fit: BoxFit.cover,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.08 * 255).toInt()),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: appFontColor.withAlpha((0.1 * 255).toInt()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                item.isCircular ? Icons.assignment : Icons.campaign,
                color: appFontColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Primary title
                  Text(
                    item.displayTitle,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                  ),

                  if (item.displayBody.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.displayBody,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                    ),
                  ],

                  // Date
                  if (item.date != null)
                    Text(
                      _formatDate(item.date),
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),

            // File indicator
            if (item.hasFile)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: appFontColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.attach_file,
                  color: Colors.white,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
