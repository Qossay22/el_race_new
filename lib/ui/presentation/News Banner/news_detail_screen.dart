import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';

class NewsDetailScreen extends StatelessWidget {
  final Map<String, dynamic> newsItem;

  const NewsDetailScreen({
    super.key,
    required this.newsItem,
  });

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
            // Back button and NEWS title with icon
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      size: 32,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Row(
                    children: [
                      const SizedBox(width: 30),
                      Image.asset('assets/png/news_logo.png'),
                      const SizedBox(width: 8),
                      Text(
                        translate('home.news'),
                        style: GoogleFonts.poppins(
                            fontSize: 25,
                            fontWeight: FontWeight.w400,
                            color: appFontColor),
                      ),
                    ],
                  ),
                  const SizedBox(width: 100),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // News title banner with background color
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 12.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF9CA3AF).withOpacity(0.8),
                    const Color(0xFFD1D5DB).withOpacity(0.6),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Center(
                child: Text(
                  (newsItem['titles'] ?? '').toString().toUpperCase(),
                  style: GoogleFonts.koulen(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),

            // News image
            Image.asset(
              newsItem['image'] ?? 'assets/jpeg/slide_1_c.jpg',
              width: double.infinity,
              height: 250.h,
              fit: BoxFit.cover,
            ),

            // News full description with padding
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 20.h),
              child: Text(
                newsItem['des'] ?? '',
                style: GoogleFonts.tajawal(
                  fontSize: 15.sp,
                  color: Colors.black,
                  height: 1.8,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.justify,
              ),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }
}
