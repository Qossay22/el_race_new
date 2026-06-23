// import 'package:el_race/data/models/prayer_time_listview_model.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:el_race/utils/color_utils.dart';

// class PrayerTimeListView extends StatelessWidget {
//   static final List<PrayerTimeListviewModel> list = [
//     PrayerTimeListviewModel(title: 'Dhuhr', timeLeft: '03:01:02'),
//     PrayerTimeListviewModel(title: 'Aser', timeLeft: '03:01:02'),
//     PrayerTimeListviewModel(title: 'Maghrib', timeLeft: '03:01:02'),
//   ];
//   const PrayerTimeListView({
//     super.key,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       height: 165.w,
//       width: 160.w,
//       child: ListView.separated(
//         itemCount: 3,
//         physics: const NeverScrollableScrollPhysics(),
//         itemBuilder: (context, index) {
//           return PrayerTimeListViewItem(
//             model: list[index],
//             isSelected: index == 0,
//           );
//         },
//         separatorBuilder: (context, index) => SizedBox(
//           height: 10.w,
//         ),
//       ),
//     );
//   }
// }

// class PrayerTimeListViewItem extends StatelessWidget {
//   final PrayerTimeListviewModel model;
//   final bool isSelected;

//   PrayerTimeListViewItem({
//     super.key,
//     required this.model,
//     required this.isSelected,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Opacity(
//       opacity: isSelected ? 1.0 : 0.5, // Reduce opacity for non-selected items
//       child: Container(
//         padding: EdgeInsets.symmetric(horizontal: 6, vertical: 7.w),
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(6),
//           border: Border.all(
//             color: isSelected
//                 ? shadowBlueLight.withValues(alpha: 0.6)
//                 : const Color(0xff151544),
//             width: 1,
//           ),
//         ),
//         child: Row(
//           children: [
//             Text(
//               model.title,
//               style: GoogleFonts.poppins(
//                 fontSize: 9.5,
//                 fontWeight: FontWeight.w400,
//                 color: isSelected ? shadowBlueLight : null,
//               ),
//             ),
//             const Spacer(),
//             Text(
//               'Left: ${model.timeLeft}',
//               style: GoogleFonts.poppins(
//                 fontSize: 9.5,
//                 fontWeight: FontWeight.w400,
//                 color: isSelected ? shadowBlueLight : null,
//               ),
//             ),
//             const Spacer(),
//             ImageIcon(
//               const AssetImage(
//                 'assets/png/alarm.png',
//               ),
//               color: isSelected ? shadowBlueLight : null,
//               size: 15.w,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
