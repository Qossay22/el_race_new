import 'package:el_race/core/constants/colors.dart';
import 'package:el_race/core/constants/text_styles.dart';
import 'package:el_race/data/models/pdf_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PdfTile extends StatelessWidget {
  final PdfModel pdf;
  final VoidCallback onMoreClicked;
  final VoidCallback onTap;
  const PdfTile(
      {super.key,
      required this.pdf,
      required this.onMoreClicked,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, right: 16, left: 16),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: CustomColors.containerColor),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        width: 33,
                        height: 33,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                            color: CustomColors.white,
                            borderRadius: BorderRadius.circular(8)),
                        child: Center(
                            child: Image.asset(
                          "assets/newapp/text.png",
                          height: 17,
                          width: 17,
                        ))),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  pdf.name,
                                  style: CustomTextStyle.reportHeader.copyWith(
                                      // fontWeight: FontWeight.w500,
                                      color: CustomColors.black),
                                ),
                              ),
                              const SizedBox(
                                width: 20,
                              )
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              DateFormat("dd MMM yyy hh:mm a").format(pdf.date),
                              style: CustomTextStyle.smallGrey.copyWith(
                                  fontWeight: FontWeight.normal,
                                  color: CustomColors.black),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: InkWell(
                    onTap: onMoreClicked, child: const Icon(Icons.more_vert_rounded)))
          ],
        ),
      ),
    );
  }
}
