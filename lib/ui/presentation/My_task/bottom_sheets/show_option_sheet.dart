import 'package:el_race/core/constants/colors.dart';
import 'package:el_race/core/constants/text_styles.dart';
import 'package:flutter/material.dart';

Future<int> showEditOptions(BuildContext context,
    {required List<String> options}) async {
  int index = -1;
  await showModalBottomSheet(
    context: context,
    useSafeArea: true,
    backgroundColor: CustomColors.containerColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 80,
              decoration: BoxDecoration(
                  color: CustomColors.blue,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 15),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                  color: CustomColors.white,
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...options.map((e) => Container(
                        height: 40,
                        decoration: options.last == e
                            ? null
                            : BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(
                                        color: CustomColors.blue
                                            .withValues(alpha: .3)))),
                        child: InkWell(
                          onTap: () {
                            index = options.indexOf(e);
                            Navigator.pop(context);
                          },
                          child: Center(
                            child: Text(
                              e,
                              style: CustomTextStyle.reportTitle,
                            ),
                          ),
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(
              height: 12,
            )
          ],
        ),
      );
    },
  );
  return index;
}