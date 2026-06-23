import 'package:el_race/report_module/core/constants/colors.dart';
import 'package:el_race/report_module/core/constants/text_styles.dart';
import 'package:el_race/report_module/data/models/report_pdf_model.dart';
import 'package:el_race/report_module/presentation/widgets/custom_textfield.dart';
import 'package:flutter/material.dart';

Future<void> showFileRename(BuildContext context,
    {required ReportPdfModel pdf}) async {
  TextEditingController renameController =
      TextEditingController(text: pdf.fileName);
  await showDialog(
    context: context,
    barrierColor:
        Colors.black.withValues(alpha: 0.5), // Transparent black background
    builder: (context) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15), // Rounded border
        ),
        backgroundColor: CustomColors.white, // White background
        child: Container(
          width: MediaQuery.sizeOf(context).width * 1,
          padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                maxCharacter: 100,
                showLabel: true,
                required: true,
                controller: renameController,
                inputType: TextInputType.phone,
                hintText: "Rename File",
              ),
              const SizedBox(height: 20),
              Row(
                children: [
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
                  const SizedBox(width: 20),
                  Expanded(
                    child: MaterialButton(
                      onPressed: () async {
                        if (renameController.text == "") {
                          return;
                        }
                        //todo rename Api.
                        Navigator.pop(context);
                      },
                      height: 44,
                      color: CustomColors.maroon,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      child: Text(
                        "Save",
                        style: CustomTextStyle.reportTitle.copyWith(
                          color: CustomColors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      );
    },
  );
}
