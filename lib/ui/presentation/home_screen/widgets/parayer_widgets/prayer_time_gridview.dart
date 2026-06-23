// import 'package:el_race/data/models/prayer_time_listview_model.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:google_fonts/google_fonts.dart';

// class PrayerTimeGridView extends StatelessWidget {
//   static final List<PrayerTimeListviewModel> list = [
//     PrayerTimeListviewModel(title: 'Fajr', timeLeft: '05:05'),
//     PrayerTimeListviewModel(title: 'Shuruk', timeLeft: '06:18'),
//     PrayerTimeListviewModel(title: 'Dhuhr', timeLeft: '12:10'),
//     PrayerTimeListviewModel(title: 'Asr', timeLeft: '15:26'),
//     PrayerTimeListviewModel(title: 'Maghrib', timeLeft: '17:56'),
//     PrayerTimeListviewModel(title: 'Isha', timeLeft: '19:09'),
//   ];
//   const PrayerTimeGridView({
//     super.key,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       height: 168.w,
//       width: 155.w,
//       child: GridView.count(
//         childAspectRatio: 0.9,
//         crossAxisSpacing: 8.w,
//         mainAxisSpacing: 12.w,
//         crossAxisCount: 3,
//         physics: const NeverScrollableScrollPhysics(),
//         children: List.generate(6, (index) {
//           return PrayerTimeGridViewItem(
//             model: list[index],
//           );
//         }),
//       ),
//     );
//   }
// }

// class PrayerTimeGridViewItem extends StatelessWidget {
//   final PrayerTimeListviewModel model;
//   const PrayerTimeGridViewItem({
//     super.key,
//     required this.model,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black..withValues(alpha: 0.2),
//             offset: const Offset(0, 4),
//             blurRadius: 10,
//             spreadRadius: 2,
//           ),
//         ],
//         borderRadius: BorderRadius.circular(7),
//         color: Colors.white,
//       ),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Text(
//             model.title,
//             style: GoogleFonts.poppins(
//               fontSize: 10,
//               fontWeight: FontWeight.w400,
//             ),
//           ),
//           const SizedBox(
//             height: 2,
//           ),
//           Text(
//             model.timeLeft,
//             style: GoogleFonts.poppins(
//               fontSize: 10,
//               fontWeight: FontWeight.w400,
//             ),
//           )
//         ],
//       ),
//     );
//   }
// }
