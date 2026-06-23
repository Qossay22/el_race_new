import 'package:el_race/data/models/announcement_model.dart';
import 'package:el_race/data/models/announcement_details_model.dart';
import 'package:el_race/data/services/announcements_api_service.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';

/// News detail screen that displays full announcement details from API
class NewsDetailScreenAPI extends StatefulWidget {
  final AnnouncementModel newsItem;

  const NewsDetailScreenAPI({
    super.key,
    required this.newsItem,
  });

  @override
  State<NewsDetailScreenAPI> createState() => _NewsDetailScreenAPIState();
}

class _NewsDetailScreenAPIState extends State<NewsDetailScreenAPI> {
  final AnnouncementsApiService _apiService = AnnouncementsApiService();

  AnnouncementDetailsModel? _details;
  bool _isLoadingDetails = false;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _isLoadingDetails = true;
    });

    try {
      final details = await _apiService.fetchAnnouncementDetails(
        announcementId: widget.newsItem.id,
      );

      if (!mounted) return;
      setState(() {
        _details = details;
      });
    } catch (_) {
      // Fallback to list item data if details endpoint fails.
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingDetails = false;
      });
    }
  }

  String get _title {
    final detailsTitle = _details?.title.trim() ?? '';
    if (detailsTitle.isNotEmpty) return detailsTitle;
    return widget.newsItem.name;
  }

  String get _content {
    final detailsText = _details?.announcementText.trim() ?? '';
    if (detailsText.isNotEmpty) return detailsText;
    return widget.newsItem.description;
  }

  String? get _imageUrl {
    final detailsAttachment = _details?.attachmentUrl?.trim() ?? '';
    if (detailsAttachment.isNotEmpty) return detailsAttachment;
    return widget.newsItem.attachmentUrl;
  }

  bool get _hasAttachment {
    if (_details != null) return _details!.hasAttachment;
    return widget.newsItem.hasAttachment;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const HeaderWidget(),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoadingDetails) const LinearProgressIndicator(minHeight: 2),
            SizedBox(height: 8.h),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/png/news_logo.png',
                    height: 20.h,
                    width: 20.w,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.article,
                      size: 20.w,
                      color: appFontColor,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    translate('home.news'),
                    style: GoogleFonts.poppins(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w400,
                      color: appFontColor,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 10.h),
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
                  _title.toUpperCase(),
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
              child: _buildDetailImage(),
            ),
            Container(
              width: double.infinity,
              margin: EdgeInsets.fromLTRB(8.w, 0, 8.w, 16.h),
              padding: EdgeInsets.symmetric(horizontal: 34.w, vertical: 20.h),
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
              child: Text(
                _content,
                textAlign: TextAlign.justify,
                style: GoogleFonts.tajawal(
                  fontSize: 15.sp,
                  color: Colors.black,
                  height: 1.85,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailImage() {
    if (_hasAttachment && _imageUrl != null && _imageUrl!.trim().isNotEmpty) {
      return Image.network(
        _imageUrl!,
        width: double.infinity,
        height: 200.w,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/jpeg/slide_1_c.jpg',
            width: double.infinity,
            height: 200.w,
            fit: BoxFit.cover,
          );
        },
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
      width: double.infinity,
      height: 200.w,
      fit: BoxFit.cover,
    );
  }
}
