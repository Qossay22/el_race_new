import 'package:el_race/report_module/core/constants/colors.dart';
import 'package:el_race/report_module/core/constants/text_styles.dart';
import 'package:flutter/material.dart';

Future<int> showAddImageOptions(BuildContext context) async {
  int index = -1;
  await showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (context) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        backgroundColor: CustomColors.white,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Add Image",
                style: CustomTextStyle.reportTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              MaterialButton(
                onPressed: () {
                  index = 0;
                  Navigator.pop(context);
                },
                height: 44,
                color: CustomColors.blue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                child: Text(
                  "Image From Gallery",
                  style: CustomTextStyle.reportTitle.copyWith(
                    color: CustomColors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              MaterialButton(
                onPressed: () {
                  index = 1;
                  Navigator.pop(context);
                },
                height: 44,
                color: CustomColors.blue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                child: Text(
                  "Image From Camera",
                  style: CustomTextStyle.reportTitle.copyWith(
                    color: CustomColors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              MaterialButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                height: 44,
                color: CustomColors.containerColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                child: Text(
                  "Cancel",
                  style: CustomTextStyle.reportTitle.copyWith(
                    color: CustomColors.maroon,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  return index;
}
