import 'package:el_race/ui/presentation/News%20Banner/news_detail_screen.dart';
import 'package:el_race/utils/color_utils.dart'; // Import global colors
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../widgets/header_widget.dart';

import '../home_screen/screens/main_screens.dart';

class ProjectAnnouncementPage extends StatelessWidget {
  final news;
  const ProjectAnnouncementPage({
    super.key,
    required this.news,
  });

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      appBar: HeaderWidget(),
      extendBody: false,
      bottomNavigationBar: CustomBottomNavBar(
        isMain: false,
      ),
    );
  }
}

class NewsPage extends StatelessWidget {
  final List<Map<String, String>> sliderList = const [
    {
      "image": 'assets/jpeg/slide_1_c.jpg',
      "titles": "alain club ",
      "des":
          '''We are pleased to announce the completion of our latest construction project. After months of hard work and dedication, our team has successfully realized this vision by developing a fully integrated sports building for Al Ain Club.
This state-of-the-art facility reflects our commitment to excellence and innovation in construction, blending modern architectural design with functionality to support athletes and the community. Equipped with cutting-edge technology and premium materials, the building includes training areas, administrative offices, locker rooms, and recreational spaces that meet international standards.
The sports building was designed with sustainability in mind, incorporating energy-efficient systems and eco-friendly practices to reduce environmental impact. From the foundation to the finishing touches, every detail was meticulously planned and executed to ensure durability and exceptional quality.
As a company, we take pride in contributing to Al Ain Club’s legacy by providing an environment that fosters talent, encourages teamwork, and inspires greatness. This project not only strengthens our partnership with the sports industry but also demonstrates our ability to deliver large-scale projects that leave a lasting impression.''',
      "des2":
          '''We are pleased to announce the completion of our latest construction project. After months of hard work and dedication, our team has successfully realized this vision by developing a fully integrated sports building for Al Ain Club.''',
    },
    {
      "image": 'assets/jpeg/slide_2_c.jpg',
      "titles": " horse stables project",
      "des":
          '''The company is proud to announce the successful completion of the modern horse stables project located in Falaj Hazza Police Station. This project reflects our unwavering commitment to fine craftsmanship and innovation in equestrian infrastructure.
Designed to provide the utmost comfort and care for the horses, the stables feature advanced ventilation systems, spacious stalls, and state-of-the-art feeding and watering facilities. The layout has been meticulously planned to ensure ease of access for caretakers and to promote the well-being of the horses.
Sustainability and durability were at the forefront of this project. Eco-friendly materials and energy-efficient systems have been incorporated, making the stables not only functional but also environmentally conscious. The design combines traditional aesthetics with modern technology, honoring the heritage of equestrian culture while meeting contemporary standards.
''',
      "des2":
          '''The company is proud to announce the successful completion of the modern horse stables project located in Falaj Hazza Police Station. This project reflects our unwavering commitment to fine craftsmanship and innovation in equestrian infrastructure.''',
    },
    {
      "image": 'assets/jpeg/slide_3_c.jpg',
      "titles": "um kalthom school",
      "des":
          '''Al Race is thrilled to announce the successful completion of Umm Kulthum School, a cutting-edge educational facility designed to empower and inspire the next generation of learners. The school has officially opened its doors to students and staff, symbolizing a major step forward for the community’s educational growth.
This state-of-the-art building combines innovative design with functionality, providing students with an ideal environment for academic and personal development. The facility features modern classrooms, advanced laboratories, spacious recreational areas, and sustainable design elements, ensuring a well-rounded experience for students and staff alike.
We extend our heartfelt gratitude to everyone who contributed to this achievement – our dedicated workforce, supportive partners, and the community whose encouragement has been invaluable. This project is more than just a building; it represents a shared vision for the future, where quality education is accessible in a space that inspires learning and creativity.
''',
      "des2":
          '''Al Race is thrilled to announce the successful completion of Umm Kulthum School, a cutting-edge educational facility designed to empower and inspire the next generation of learners. The school has officially opened its doors to students and staff, symbolizing a major step forward for the community’s educational growth.''',
    },
    {
      "image": 'assets/jpeg/slide_4_c.jpg',
      "titles": "abu dhabi dialysis center",
      "des":
          '''We are proud to announce the successful completion of a state-of-the-art healthcare facility, designed to elevate patient care and meet the growing healthcare needs of our community. This landmark project reflects our commitment to delivering excellence and innovation in the field of healthcare infrastructure.
The facility is equipped with cutting-edge medical technology, modern treatment rooms, and comfortable spaces that prioritize the well-being of patients and healthcare professionals alike. With a focus on accessibility, it ensures that advanced medical services are available to all residents, enhancing the overall quality of care in the region.
This project embodies our dedication to creating spaces that serve as pillars of support for the community, fostering health and wellness for everyone. By combining functionality with innovative design, we aim to set a new standard for healthcare facilities in the area.
We extend our gratitude to our skilled team, trusted partners, and the community for their collaboration and encouragement throughout this journey. Together, we have built more than a facility – we have created a space that will have a lasting, positive impact on people’s lives.
''',
      "des2":
          '''We are proud to announce the successful completion of a state-of-the-art healthcare facility, designed to elevate patient care and meet the growing healthcare needs of our community. This landmark project reflects our commitment to delivering excellence and innovation in the field of healthcare infrastructure.''',
    },
  ];

  const NewsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const HeaderWidget(),
      extendBody: false,
      bottomNavigationBar: const CustomBottomNavBar(
        isMain: false,
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/png/news_logo.png',
                        height: 20.h, width: 20.w),
                    const SizedBox(width: 4),
                    Text(
                      translate('home.news'),
                      style: GoogleFonts.poppins(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w400,
                          color: appFontColor),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
              ],
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                var item = sliderList[index];
                // Add extra bottom padding to the last item
                final isLastItem = index == sliderList.length - 1;
                final bottomMargin = isLastItem
                    ? (kBottomNavigationBarHeight +
                        context.systemBottomInset +
                        16)
                    : 3.h;
                return Container(
                  margin: EdgeInsets.only(
                    bottom: bottomMargin,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    // borderRadius: BorderRadius.circular(14),
                    // boxShadow: [
                    //   BoxShadow(
                    //     color: Colors.black.withOpacity(0.1),
                    //     blurRadius: 6,
                    //     offset: const Offset(0, 3),
                    //   )
                    // ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🔹 Title
                      Container(
                        padding: const EdgeInsets.fromLTRB(5, 15, 0, 10),
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
                            // Inner shadow (inset)
                            BoxShadow(
                              color: Color.fromRGBO(0, 0, 0, 0.25),
                              offset: Offset(0, 4),
                              blurRadius: 4,
                              spreadRadius: 0,
                            ),
                            // Outer shadow
                            BoxShadow(
                              color: Color.fromRGBO(0, 0, 0, 0.46),
                              offset: Offset(0, 10),
                              blurRadius: 9.6,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Text(
                                "${item['titles']}".toUpperCase(),
                                style: GoogleFonts.poppins(
                                  color: appFontColor,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 🔹 Image
                      Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4), // شادو خفيف
                              blurRadius: 10,
                              offset: const Offset(0, 4), // لتحت بس
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(0)),
                          child: Stack(
                            children: [
                              Image.asset(
                                "${item['image']}",
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 200.w,
                              ),
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.center,
                                      colors: [
                                        const Color.fromARGB(255, 0, 0, 0)
                                            .withOpacity(0.50),
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
                      ),

                      // 🔹 Description
                      Padding(
                        padding: EdgeInsets.only(
                          left: 40, // ← padding يسار 20
                          right: 12.w,
                          top: 10.h,
                          bottom: 10.h,
                        ),
                        child: _buildExpandableDescription(
                          context: context,
                          fullText: "${item['des2']}",
                          newsItem: item,
                          onSeeAllTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    NewsDetailScreen(newsItem: item),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
              childCount: sliderList.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableDescription({
    required BuildContext context,
    required String fullText,
    required Map newsItem,
    required VoidCallback onSeeAllTap,
  }) {
    // --- إعداد TextPainter لقص النص إلى سطرين ---
    final span = TextSpan(
      text: fullText,
      style: GoogleFonts.poppins(
        fontSize: 14.sp,
        color: Colors.black,
      ),
    );

    final tp = TextPainter(
      text: span,
      maxLines: 2,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: MediaQuery.of(context).size.width - 40);

    // إن كان النص أصلاً أقل من سطرين → أعرضه عادي + زر See All
    final isOverflowing = tp.didExceedMaxLines;

    // النص المقصوص
    String clippedText = fullText;

    if (isOverflowing) {
      // قص النص بناءً على مكان الدخول في السطر الثاني
      int endIndex = tp
          .getPositionForOffset(
            Offset(MediaQuery.of(context).size.width - 40, 40),
          )
          .offset;

      // قص + نقاط
      clippedText = fullText.substring(0, endIndex).trim();
      if (!clippedText.endsWith("...")) {
        clippedText = "$clippedText...";
      }
    }

    // --- واجهة العرض ---
    return RichText(
      text: TextSpan(
        style: GoogleFonts.poppins(
          fontSize: 14.sp,
          color: Colors.black,
        ),
        children: [
          TextSpan(text: clippedText),
          TextSpan(
            text: "  See All",
            style: GoogleFonts.poppins(
              color: const Color(0xFF868686),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            recognizer: TapGestureRecognizer()..onTap = onSeeAllTap,
          ),
        ],
      ),
    );
  }

// class NewsPage2 extends StatelessWidget {
//   const NewsPage2({super.key});

//   @override
//   Widget build(BuildContext context) {
//     ScreenUtil.init(context);

//     final List<Map<String, String>> projects = [
//       {
//         'title': 'ALAIN CLUB',
//         'image': 'assets/images/alain_club.jpg',
//         'desc':
//         'We are pleased to announce the completion of our latest construction project. After months of hard work and dedication, our team has successfully realized this...'
//       },
//       {
//         'title': 'HORSE STABLES PROJECT',
//         'image': 'assets/images/horse_stables.jpg',
//         'desc':
//         'We are pleased to announce the completion of our latest construction project. After months of hard work and dedication, our team has successfully realized this...'
//       },
//       {
//         'title': 'UM KALTHOM SCHOOL',
//         'image': 'assets/images/um_kalthom.jpg',
//         'desc':
//         'Al Race is thrilled to announce the successful completion of Umm Kulthum School, a cutting-edge educational facility designed to empower and inspire...'
//       },
//       {
//         'title': 'ABU DHABI DIALYSIS CENTER',
//         'image': 'assets/images/dialysis_center.jpg',
//         'desc':
//         'We are proud to announce the successful completion of a state-of-the-art healthcare facility, designed to elevate patient care and enhance the healthcare...'
//       },
//     ];

//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: SafeArea(
//         child: Column(
//           children: [
//             // 🔹 Header
//             Container(
//               padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   const Icon(Icons.arrow_back_ios_new, color: Colors.black),
//                   Text(
//                     'NEWS',
//                     style: GoogleFonts.poppins(
//                       fontSize: 20.sp,
//                       fontWeight: FontWeight.bold,
//                       color: const Color(0xFF191F52),
//                     ),
//                   ),
//                   const Icon(Icons.menu, color: Colors.transparent),
//                 ],
//               ),
//             ),

//             // 🔹 News List
//             Expanded(
//               child: ListView.builder(
//                 padding: EdgeInsets.symmetric(horizontal: 10.w),
//                 itemCount: projects.length,
//                 itemBuilder: (context, index) {
//                   final item = projects[index];
//                   return Container(
//                     margin: EdgeInsets.only(bottom: 20.h),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(14),
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.black.withOpacity(0.1),
//                           blurRadius: 6,
//                           offset: const Offset(0, 3),
//                         )
//                       ],
//                     ),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         // 🔹 Title
//                         Container(
//                           width: double.infinity,
//                           padding: EdgeInsets.symmetric(vertical: 8.h),
//                           alignment: Alignment.center,
//                           decoration: const BoxDecoration(
//                             color: Color(0xFFE5E5E5),
//                             borderRadius: BorderRadius.vertical(
//                                 top: Radius.circular(14)),
//                           ),
//                           child: Text(
//                             item['title']!,
//                             style: GoogleFonts.poppins(
//                               fontSize: 16.sp,
//                               fontWeight: FontWeight.bold,
//                               color: const Color(0xFF191F52),
//                             ),
//                           ),
//                         ),

//                         // 🔹 Image
//                         ClipRRect(
//                           borderRadius: const BorderRadius.vertical(
//                               bottom: Radius.circular(0)),
//                           child: Image.asset(
//                             item['image']!,
//                             fit: BoxFit.cover,
//                             width: double.infinity,
//                             height: 180.h,
//                           ),
//                         ),

//                         // 🔹 Description
//                         Padding(
//                           padding: EdgeInsets.symmetric(
//                               horizontal: 12.w, vertical: 10.h),
//                           child: RichText(
//                             text: TextSpan(
//                               style: GoogleFonts.poppins(
//                                 fontSize: 14.sp,
//                                 color: Colors.black,
//                               ),
//                               children: [
//                                 TextSpan(text: item['desc']),
//                                 TextSpan(
//                                   text: '  See All',
//                                   style: GoogleFonts.poppins(
//                                     color: const Color(0xFF191F52),
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   );
//                 },
//               ),
//             ),

//             // 🔹 Bottom Navigation Bar
//             Container(
//               padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 10.h),
//               decoration: const BoxDecoration(
//                 color: Colors.white,
//                 boxShadow: [
//                   BoxShadow(
//                       color: Colors.black12, blurRadius: 5, offset: Offset(0, -2))
//                 ],
//               ),
//               child: const Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Icon(Icons.phone, size: 28, color: Color(0xFF191F52)),
//                   Icon(Icons.home, size: 28, color: Color(0xFF191F52)),
//                   Icon(Icons.newspaper, size: 28, color: Color(0xFF191F52)),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
}
