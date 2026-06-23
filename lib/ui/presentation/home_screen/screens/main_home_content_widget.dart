import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:el_race/core/services/attendance_status_sync_service.dart';
import 'package:el_race/ui/presentation/News%20Banner/news_screen.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/widget_container.dart';
import 'package:el_race/utils/Util.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:el_race/utils/orientation_helper.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../provider/slider_provider.dart';

class MainHomeContentWidget extends StatefulWidget {
  const MainHomeContentWidget({super.key});

  @override
  State<MainHomeContentWidget> createState() => _MainHomeContentWidgetState();
}

class _MainHomeContentWidgetState extends State<MainHomeContentWidget> {
  @override
  void initState() {
    super.initState();
    // Fetch banner announcements on init only
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SliderProvider>().fetchAnnouncementsForBanner();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sliderProvider = Provider.of<SliderProvider>(context);
    final bottomPadding =
        kBottomNavigationBarHeight + context.systemBottomInset + 75.h;

    return RefreshIndicator(
      onRefresh: () async {
        // Clear all cached images
        await DefaultCacheManager().emptyCache();

        // Fetch new data
        await Util.fetchHomeScreenData(context);
        await sliderProvider.refresh();

        // Sync attendance status from server so any external check-in/out
        // is reflected immediately in the timer and swipe button.
        await AttendanceStatusSyncService.refreshFromServer(
          reason: 'pull_to_refresh',
        );
      },
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(
          top: SizeConfig().getHeight(10),
          bottom: bottomPadding,
        ),
        child: Column(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Loading State
                    if (sliderProvider.isLoading)
                      Container(
                        height: 190.h,
                        width: double.infinity,
                        margin: EdgeInsets.symmetric(
                            horizontal: SizeConfig().getWidth(10)),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(23.r),
                            topRight: Radius.circular(23.r),
                            bottomRight: Radius.circular(23.r),
                            bottomLeft: const Radius.circular(0),
                          ),
                          color: lightGrey,
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: buttonDark,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    // Error or Loaded State
                    else
                      CarouselSlider.builder(
                        itemCount: sliderProvider.sliderImages.length,
                        itemBuilder: (BuildContext context, int itemIndex,
                            int pageViewIndex) {
                          final isApiData = sliderProvider.hasApiData;
                          var imageUrl = sliderProvider.sliderImages[itemIndex];
                          final isNetworkImage =
                              imageUrl.startsWith('http') && isApiData;

                          // Add timestamp to URL to break cache
                          if (isNetworkImage) {
                            final separator =
                                imageUrl.contains('?') ? '&' : '?';
                            imageUrl =
                                '$imageUrl${separator}t=${sliderProvider.lastFetchTimestamp}';
                          }

                          return GestureDetector(
                            onTap: () =>
                                Util.pushPage(const NewsScreen(), context),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: SizeConfig().getWidth(10)),
                              child: Container(
                                height: 160.w,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(23.r),
                                    topRight: Radius.circular(23.r),
                                    bottomRight: Radius.circular(23.r),
                                    bottomLeft: const Radius.circular(0),
                                  ),
                                  gradient: LinearGradient(
                                    colors: itemIndex.isEven
                                        ? [
                                            buttonLight,
                                            Colors.white,
                                            buttonDark
                                          ]
                                        : [lightGrey, darkGrey],
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(23.r),
                                    topRight: Radius.circular(23.r),
                                    bottomRight: Radius.circular(23.r),
                                    bottomLeft: const Radius.circular(0),
                                  ),
                                  child: Stack(
                                    children: [
                                      // Background Image
                                      if (isNetworkImage)
                                        CachedNetworkImage(
                                          key: Key(
                                              '${imageUrl}_${sliderProvider.lastFetchTimestamp}'),
                                          imageUrl: imageUrl,
                                          fit: BoxFit.cover,
                                          height: 190.h,
                                          width: double.infinity,
                                          memCacheHeight: null,
                                          memCacheWidth: null,
                                          placeholder: (context, url) =>
                                              Container(
                                            color: lightGrey,
                                            child: const Center(
                                              child: CircularProgressIndicator(
                                                color: buttonDark,
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) =>
                                              Image.asset(
                                            'assets/jpeg/slide_1_c.jpg',
                                            fit: BoxFit.cover,
                                            height: 190.h,
                                            width: double.infinity,
                                          ),
                                        )
                                      else
                                        Image.asset(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          height: 190.h,
                                          width: double.infinity,
                                        ),
                                      // Shadow overlay at bottom of image
                                      Positioned.fill(
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.black.withOpacity(0.0),
                                                Colors.black.withOpacity(0.6),
                                              ],
                                              stops: const [0.0, 0.45, 1.0],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        options: CarouselOptions(
                          height: 190.h,
                          autoPlay: true,
                          aspectRatio: 16 / 9,
                          viewportFraction: 1.0,
                          onPageChanged: (index, reason) {
                            sliderProvider.setCurrentIndex(index);
                          },
                          initialPage: sliderProvider.currentIndex,
                        ),
                      ),

                    // Fixed text bar — stays still, only text changes
                    if (sliderProvider.titles.isNotEmpty)
                      Positioned(
                        bottom: 28.h,
                        left: SizeConfig().getWidth(10),
                        right: SizeConfig().getWidth(10),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xB81B1F26),
                                Color(0xFF717171),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                          padding: EdgeInsets.symmetric(
                              vertical: 8.h, horizontal: 12.w),
                          child: Text(
                            sliderProvider.titles[sliderProvider.currentIndex %
                                sliderProvider.titles.length],
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              shadows: [
                                Shadow(
                                  offset: const Offset(0, 1),
                                  blurRadius: 3,
                                  color: Colors.black.withOpacity(0.3),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),

                    // Dots Indicator
                    Positioned(
                        bottom: 10.h,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                                sliderProvider.titles.length, (index) {
                              final isActive =
                                  sliderProvider.currentIndex == index;
                              return GestureDetector(
                                onTap: () =>
                                    sliderProvider.setCurrentIndex(index),
                                child: Container(
                                  width: 8.w,
                                  height: 8.w,
                                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isActive
                                        ? const Color(0xFF717171)
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: const Color(0xFF717171),
                                      width: 1,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        )),
                  ],
                ),
                //
                // // "See All" Button
                // Padding(
                //   padding: const EdgeInsets.only(top: 12.0, right: 16),
                //   child: Align(
                //     alignment: Alignment.centerRight,
                //     child: GestureDetector(
                //       onTap: () => Util.pushPage(
                //           const ProjectAnnouncementPage(), context),
                //       child: Text(
                //         translate('home.see_all'),
                //         style: GoogleFonts.inter(
                //           fontSize: 16,
                //           color: Colors.grey[700],
                //           fontWeight: FontWeight.w500,
                //         ),
                //       ),
                //     ),
                //   ),
                // ),
              ],
            ),
            SizedBox(height: 25.w),
            const WidgetContainer(),
          ],
        ),
      ),
    );
  }
}
