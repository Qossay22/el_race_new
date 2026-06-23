import 'package:el_race/core/constants/colors.dart';
import 'package:el_race/core/constants/text_styles.dart';
import 'package:flutter/material.dart';

class SectionBar extends StatelessWidget {
  final bool active;
  final String sectionName;
  final String count;
  final VoidCallback onTap;
  final VoidCallback onMoreClick;
  const SectionBar(
      {super.key,
      required this.active,
      required this.sectionName,
      required this.count,
      required this.onTap,
      required this.onMoreClick});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        height: 33,
        decoration: BoxDecoration(
            color: CustomColors.maroon,
            border:
                Border(bottom: BorderSide(color: CustomColors.containerColor))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                RotatedBox(
                  quarterTurns: active ? 1 : 0,
                  child: Icon(
                    Icons.play_arrow,
                    color: CustomColors.white,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  sectionName,
                  style: CustomTextStyle.heading,
                ),
              ],
            ),
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: CustomColors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
                  child: Text(
                    "Items : $count",
                    style: CustomTextStyle.smallWhite,
                  ),
                ),
                InkWell(
                  // padding: EdgeInsets.zero,
                  onTap: onMoreClick,
                  child: Icon(
                    Icons.more_vert_rounded,
                    color: CustomColors.white,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
