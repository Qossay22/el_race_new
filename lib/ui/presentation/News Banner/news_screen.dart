import 'dart:io';

import 'package:el_race/data/models/announcement_model.dart';
import 'package:el_race/data/services/announcements_api_service.dart';
import 'package:el_race/providers/announcements_provider.dart';
import 'package:el_race/ui/presentation/News%20Banner/news_detail_screen_api.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch news on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnnouncementsProvider>().fetchAnnouncements(
            category: AnnouncementCategory.news,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const HeaderWidget(),
      body: Consumer<AnnouncementsProvider>(
        builder: (context, provider, child) {
          final scrollView = CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              if (Platform.isIOS)
                CupertinoSliverRefreshControl(
                  onRefresh: () => provider.refresh(),
                ),

              // Header section
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/png/news_logo.png',
                          height: 24.h,
                          errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.article,
                              size: 24.h,
                              color: appFontColor),
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          translate('home.news'),
                          style: GoogleFonts.poppins(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w400,
                            color: appFontColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // Content based on state
              if (provider.isLoading)
                _buildLoadingState()
              else if (provider.hasError)
                _buildErrorState(provider)
              else if (provider.isEmpty)
                _buildEmptyState()
              else if (provider.hasData)
                _buildNewsList(provider.announcements),
            ],
          );

          if (Platform.isAndroid) {
            return RefreshIndicator(
              onRefresh: () => provider.refresh(),
              color: appFontColor,
              child: scrollView,
            );
          }

          return scrollView;
        },
      ),
    );
  }

  /// Build loading state
  Widget _buildLoadingState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(appFontColor),
            ),
            SizedBox(height: 16.h),
            Text(
              'Loading news...',
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build error state
  Widget _buildErrorState(AnnouncementsProvider provider) {
    return SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64.w,
                color: Colors.red[400],
              ),
              SizedBox(height: 16.h),
              Text(
                'Error',
                style: GoogleFonts.poppins(
                  fontSize: 24.sp,
                  color: Colors.red[700],
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                provider.errorMessage ?? 'An error occurred',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14.sp,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 24.h),
              ElevatedButton.icon(
                onPressed: () => provider.refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: appFontColor,
                  foregroundColor: Colors.white,
                  padding:
                      EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 64.w,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16.h),
            Text(
              'No News Available',
              style: GoogleFonts.poppins(
                fontSize: 24.sp,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'There are no news items to display at the moment.',
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

  /// Build news list
  Widget _buildNewsList(List<AnnouncementModel> newsList) {
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final newsItem = newsList[index];
            return _buildNewsCard(newsItem,
                isLast: index == newsList.length - 1);
          },
          childCount: newsList.length,
        ),
      ),
    );
  }

  /// Build individual news card
  Widget _buildNewsCard(AnnouncementModel newsItem, {required bool isLast}) {
    final bottomMargin = isLast ? (kBottomNavigationBarHeight + 20.h) : 3.h;

    return Container(
      margin: EdgeInsets.only(bottom: bottomMargin),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NewsDetailScreenAPI(newsItem: newsItem),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(5.w, 15.h, 0, 10.h),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFD6D6D6),
                    Color(0xFFADB2BD),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.25),
                    offset: Offset(0, 4),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.46),
                    offset: Offset(0, 10),
                    blurRadius: 9.6,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  newsItem.name.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.koulen(
                    color: appFontColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 20.sp,
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  _buildNewsImage(newsItem),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.center,
                          colors: [
                            const Color(0xFF000000).withOpacity(0.50),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.6],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: 24.w,
                right: 12.w,
                top: 10.h,
                bottom: 14.h,
              ),
              child: _buildReferenceDescription(newsItem),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsImage(AnnouncementModel newsItem) {
    final imageUrl = newsItem.attachmentUrl;

    if (newsItem.hasAttachment && imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 200.w,
        errorBuilder: (context, error, stackTrace) => Image.asset(
          'assets/jpeg/slide_1_c.jpg',
          fit: BoxFit.cover,
          width: double.infinity,
          height: 200.w,
        ),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: double.infinity,
            height: 200.w,
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      );
    }

    return Image.asset(
      'assets/jpeg/slide_1_c.jpg',
      fit: BoxFit.cover,
      width: double.infinity,
      height: 200.w,
    );
  }

  Widget _buildReferenceDescription(AnnouncementModel newsItem) {
    final description = newsItem.description.trim();
    final preview = description.length > 165
        ? '${description.substring(0, 165).trim()}...'
        : description;

    return RichText(
      text: TextSpan(
        style: GoogleFonts.tajawal(
          fontSize: 14.sp,
          color: Colors.black,
          height: 1.65,
        ),
        children: [
          TextSpan(text: preview),
          TextSpan(
            text: '  See All',
            style: GoogleFonts.tajawal(
              color: const Color(0xFF868686),
              fontWeight: FontWeight.bold,
              fontSize: 16.sp,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        NewsDetailScreenAPI(newsItem: newsItem),
                  ),
                );
              },
          ),
        ],
      ),
    );
  }
}
