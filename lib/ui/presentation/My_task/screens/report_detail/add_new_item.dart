import 'dart:io';
import 'package:el_race/core/utils/directory_operation.dart';
import 'package:el_race/data/models/report_detail_item.dart';
import 'package:el_race/data/models/report_detail_model.dart';
import 'package:el_race/data/models/report_model.dart';
import 'package:el_race/data/repositories/i_report_repository.dart';
import 'package:el_race/data/repositories/report_repository.dart';
import 'package:el_race/ui/presentation/My_task/screens/report_detail/camera_screen.dart';
import 'package:el_race/ui/presentation/My_task/screens/report_detail/image_editing_screen.dart';
import 'package:el_race/ui/widgets/custom_textfield.dart';
import 'package:flutter/material.dart';

import '../../../../../core/constants/colors.dart';
import '../../../../../core/constants/text_styles.dart';

import '../../../../../data/repositories/company_repository.dart';
import '../../../../widgets/bottom_appbar.dart';
import '../../../../widgets/square_button.dart';


class AddNewItem extends StatefulWidget {
  final ReportDetailModel reportDetailModel;
  final ReportModel report;
  final int index;

  const AddNewItem({
    super.key,
    required this.report,
    required this.reportDetailModel,
    required this.index,
  });

  @override
  State<AddNewItem> createState() => _AddNewItemState();
}

class _AddNewItemState extends State<AddNewItem> {
  late IReportRepository reportRepository;
  String? selectedSection;

  late TextEditingController titleController;
  late TextEditingController descriptionController;

  ReportDetailItem? item;

  int currentIndex = 0;
  @override
  void initState() {
    currentIndex = widget.index;
    reportRepository = ReportRepository();
    titleController = TextEditingController(
        text: widget.reportDetailModel.items[currentIndex].title);
    descriptionController = TextEditingController(
        text: widget.reportDetailModel.items[currentIndex].description);

    super.initState();
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        surfaceTintColor: Colors.transparent,
        backgroundColor: CustomColors.white,
        centerTitle: true,
        leadingWidth: 60,
        leading: Align(
          alignment: Alignment.centerRight,
          child: SquareButton(
            icon: Icons.keyboard_backspace,
            color: CustomColors.white,
            borderColor: CustomColors.black,
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        title: Image.asset(
          CompanyRepository.company!.logo,
          height: 60,
        ),
        actions: [
          if (widget.reportDetailModel.items[currentIndex].type == "image")
            SquareButton(
              icon: Icons.edit,
              color: CustomColors.white,
              borderColor: CustomColors.black,
              onPressed: () async {
                if (widget.reportDetailModel.items[currentIndex].type ==
                    "image") {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ImageEditingScreen(
                              image: File(widget.reportDetailModel
                                  .items[currentIndex].image!))));
                  await FileImage(File(
                          widget.reportDetailModel.items[currentIndex].image!))
                      .evict();
                  setState(() {});
                }
              },
            ),
          const SizedBox(width: 12)
        ],
        bottom: getBottomAppBar(context, report: widget.report),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.reportDetailModel.items[currentIndex].type == "image")
            InkWell(
              onTap: () {},
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: 216,
                    decoration: BoxDecoration(
                        color: CustomColors.containerColor,
                        borderRadius: BorderRadius.circular(8)),
                    child: Image.file(
                        key: const Key("image"),
                        File(widget
                            .reportDetailModel.items[currentIndex].image!)),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: SquareButton(
                      icon: Icons.camera_alt_rounded,
                      color: CustomColors.white,
                      borderColor: CustomColors.black,
                      onPressed: () async {
                        setState(() {});
                        var result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const CustomCameraScreen(
                                      onePicture: true,
                                    )));
                        if (result == null ||
                            (result is List && result.isEmpty)) {
                          return;
                        }

                        String fileLocation = await saveImageToAppStorage(
                            File(result[0].path),
                            widget.report.id,
                            selectedSection ?? "unAssigned");
                        await deleteFileViaPath(widget
                            .reportDetailModel.items[currentIndex].image!);
                        ReportDetailItem updatedItem = widget
                            .reportDetailModel.items[currentIndex]
                            .copyWith(
                          image: fileLocation,
                          updatedAt: DateTime.now().toIso8601String(),
                        );
                        widget.reportDetailModel.items[currentIndex] =
                            updatedItem;
                        await reportRepository
                            .updateReportDetail(widget.reportDetailModel);
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            ),
          if (widget.reportDetailModel.items[currentIndex].type == "image")
            const SizedBox(height: 16),
          if (widget.reportDetailModel.items[currentIndex].sectionName !=
                  null &&
              widget.reportDetailModel.items[currentIndex].sectionName !=
                  "unAssigned")
            Wrap(
              children: [
                InkWell(
                  onTap: () {
                    if (selectedSection != "") {
                      selectedSection = "";
                    } else {
                      selectedSection = widget
                          .reportDetailModel.items[currentIndex].sectionName;
                    }

                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: selectedSection == "" && selectedSection == null
                            ? CustomColors.maroon.withValues(alpha: .2)
                            : CustomColors.maroon,
                        borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.reportDetailModel.items[currentIndex]
                              .sectionName!,
                          style: CustomTextStyle.heading,
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.check_circle,
                          color: CustomColors.white,
                        )
                      ],
                    ),
                  ),
                )
              ],
            ),
          const SizedBox(height: 16),
          CustomTextField(
            maxCharacter: 100,
            showLabel: true,
            required: false,
            controller: titleController,
            inputType: TextInputType.text,
            hintText: "Location",
          ),
          const SizedBox(height: 8),
          CustomTextField(
            maxCharacter: 1000,
            showLabel: true,
            required: false,
            controller: descriptionController,
            inputType: TextInputType.multiline,
            maxLine: 4,
            hintText: "Description",
          ),
          const SizedBox(height: 16),
          MaterialButton(
            onPressed: () async {
              ReportDetailItem updatedItem =
                  widget.reportDetailModel.items[currentIndex].copyWith(
                title: titleController.text,
                description: descriptionController.text,
                updatedAt: DateTime.now().toIso8601String(),
              );
              widget.reportDetailModel.items[currentIndex] = updatedItem;
              await reportRepository
                  .updateReportDetail(widget.reportDetailModel);
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            height: 44,
            color: CustomColors.maroon,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Text(
              "Save",
              style: CustomTextStyle.reportTitle.copyWith(
                color: CustomColors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: MaterialButton(
                  disabledColor: CustomColors.maroon.withValues(alpha: .3),
                  onPressed: currentIndex == 0
                      ? null
                      : () async {
                          currentIndex--;
                          setState(() {});
                          titleController = TextEditingController(
                              text: widget
                                  .reportDetailModel.items[currentIndex].title);
                          descriptionController = TextEditingController(
                              text: widget.reportDetailModel.items[currentIndex]
                                  .description);
                        },
                  height: 44,
                  color: CustomColors.maroon,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  child: Text(
                    "Previous",
                    style: CustomTextStyle.reportTitle.copyWith(
                      color: CustomColors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: MaterialButton(
                  disabledColor: CustomColors.blue.withValues(alpha: .3),
                  onPressed: (currentIndex + 1) ==
                          widget.reportDetailModel.items.length
                      ? null
                      : () async {
                          currentIndex++;
                          setState(() {});
                          titleController = TextEditingController(
                              text: widget
                                  .reportDetailModel.items[currentIndex].title);
                          descriptionController = TextEditingController(
                              text: widget.reportDetailModel.items[currentIndex]
                                  .description);
                        },
                  height: 44,
                  color: CustomColors.blue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  child: Text(
                    "Next",
                    style: CustomTextStyle.reportTitle.copyWith(
                      color: CustomColors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
