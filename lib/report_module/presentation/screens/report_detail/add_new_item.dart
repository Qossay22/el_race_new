import 'dart:io';

import 'package:el_race/report_module/core/constants/colors.dart';
import 'package:el_race/report_module/core/constants/text_styles.dart';
import 'package:el_race/report_module/data/models/report_detail_model.dart';
import 'package:el_race/report_module/data/models/report_item_model.dart';
import 'package:el_race/report_module/data/provider/reports_provider.dart';
import 'package:el_race/report_module/data/repositories/company_repository.dart';
import 'package:el_race/report_module/presentation/screens/report_detail/camera_screen.dart';
import 'package:el_race/report_module/presentation/screens/report_detail/image_editing_screen.dart';
import 'package:el_race/report_module/presentation/widgets/bottom_appbar.dart';
import 'package:el_race/report_module/presentation/widgets/square_button.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../widgets/custom_textfield.dart';

class AddNewItem extends StatefulWidget {
  final ReportDetailModel report;
  final String folderName;
  final ReportItemModel? item;

  const AddNewItem({
    super.key,
    required this.report,
    this.item,
    required this.folderName,
  });

  @override
  State<AddNewItem> createState() => _AddNewItemState();
}

class _AddNewItemState extends State<AddNewItem> {
  late TextEditingController locationController;
  late TextEditingController descriptionController;
  int currentIndex = -1;
  bool _loading = false;

  bool imageLoading = false;
  @override
  void initState() {
    if (widget.item != null) {
      currentIndex =
          widget.report.reportItems.indexWhere((e) => widget.item!.id == e.id);
    }
    locationController = TextEditingController(text: "");
    descriptionController = TextEditingController(text: "");
    if (widget.item != null) {
      locationController = TextEditingController(text: widget.item!.location);
      descriptionController =
          TextEditingController(text: widget.item!.description);
    }
    super.initState();
  }

  @override
  void dispose() {
    locationController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  int _imageBust = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        surfaceTintColor: Colors.transparent,
        backgroundColor: CustomColors.white,
        centerTitle: true,
        leadingWidth: 70,
        leading: SquareButton(
          icon: Icons.keyboard_backspace,
          color: CustomColors.white,
          borderColor: CustomColors.black,
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Image.asset(
          CompanyRepository.company!.logo,
          height: 60,
        ),
        actions: [
          if (currentIndex != -1 &&
              widget.report.reportItems[currentIndex].type == "image")
            SquareButton(
              icon: Icons.edit,
              color: CustomColors.white,
              borderColor: CustomColors.black,
              onPressed: () async {
                if (widget.report.reportItems[currentIndex].type == "image") {
                  var bytes = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ImageEditingScreen(
                              image: widget
                                  .report.reportItems[currentIndex].image)));
                  if (bytes != null) {
                    imageLoading = true;
                    setState(() {});
                    await File(widget.report.reportItems[currentIndex].image)
                        .writeAsBytes(bytes);
                    await FileImage(
                            File(widget.report.reportItems[currentIndex].image))
                        .evict();
                    _imageBust++;
                    imageLoading = false;
                    setState(() {});
                  }

                  setState(() {});
                }
              },
            ),
          const SizedBox(width: 12)
        ],
        bottom: getBottomAppBar(context,
            report: widget.report, folderName: widget.folderName),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (currentIndex != -1 &&
              widget.report.reportItems[currentIndex].type == "image")
            InkWell(
              onTap: () {},
              child: Stack(
                children: [
                  Skeletonizer(
                    enabled: imageLoading,
                    child: Container(
                      width: double.infinity,
                      height: 216,
                      decoration: BoxDecoration(
                          color: CustomColors.containerColor,
                          borderRadius: BorderRadius.circular(8)),
                      child: Image.file(
                        key: Key(_imageBust.toString()),
                        File(widget.report.reportItems[currentIndex].image),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: SquareButton(
                      icon: Icons.flip_camera_ios,
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

                        await File(
                                widget.report.reportItems[currentIndex].image)
                            .writeAsBytes(
                                await File(result[0].path).readAsBytes());
                        await FileImage(File(
                                widget.report.reportItems[currentIndex].image))
                            .evict();
                        _imageBust++;

                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            ),
          if (currentIndex != -1 &&
              widget.report.reportItems[currentIndex].type == "image")
            const SizedBox(height: 16),
          CustomTextField(
              maxCharacter: 100,
              showLabel: true,
              required: false,
              controller: locationController,
              inputType: TextInputType.text,
              hintText: "Location",
              onChange: (v) async {
                if (currentIndex > -1 &&
                    widget.report.reportItems[currentIndex] != -1) {
                  ReportItemModel updatedItem = widget
                      .report.reportItems[currentIndex]
                      .copyWith(location: v);
                  List<ReportItemModel> itemsUpdated =
                      widget.report.reportItems;
                  itemsUpdated[currentIndex] = updatedItem;
                  await reportProvider.updateReportDetail(
                    widget.report.copyWith(reportItems: itemsUpdated),
                  );

                  if (!context.mounted) return;
                  _loading = false;
                  setState(() {});

                  return;
                }
              }),
          const SizedBox(height: 8),
          CustomTextField(
              maxCharacter: 1000,
              showLabel: true,
              required: false,
              controller: descriptionController,
              inputType: TextInputType.multiline,
              maxLine: 4,
              hintText: "Description",
              onChange: (v) async {
                if (currentIndex > -1 &&
                    widget.report.reportItems[currentIndex] != -1) {
                  ReportItemModel updatedItem = widget
                      .report.reportItems[currentIndex]
                      .copyWith(description: v);
                  List<ReportItemModel> itemsUpdated =
                      widget.report.reportItems;
                  itemsUpdated[currentIndex] = updatedItem;
                  await reportProvider.updateReportDetail(
                    widget.report.copyWith(reportItems: itemsUpdated),
                  );

                  if (!context.mounted) return;
                  _loading = false;
                  setState(() {});
                  return;
                }
              }),
          // const SizedBox(height: 12),
          Center(
            child: Text(
              "item no : ${currentIndex + 1}/${widget.report.reportItems.length}",
              style: CustomTextStyle.reportHeader.copyWith(color: black),
            ),
          ),
          // const SizedBox(height: 12),
          // MaterialButton(
          //   onPressed: () async {
          //     _loading = true;
          //     setState(() {});
          //
          //     if (currentIndex > -1 &&
          //         widget.report.reportItems[currentIndex] != -1) {
          //       ReportItemModel updatedItem =
          //           widget.report.reportItems[currentIndex].copyWith(
          //         location: locationController.text,
          //         description: descriptionController.text,
          //       );
          //       List<ReportItemModel> itemsUpdated = widget.report.reportItems;
          //       itemsUpdated[currentIndex] = updatedItem;
          //       await reportProvider.updateReportDetail(
          //         widget.report.copyWith(reportItems: itemsUpdated),
          //       );
          //
          //       if (!context.mounted) return;
          //       _loading = false;
          //       setState(() {});
          //       Navigator.pop(context, updatedItem);
          //       return;
          //     }
          //
          //     ReportItemModel _newItem = ReportItemModel(
          //         id: DateTime.now().millisecondsSinceEpoch.toString(),
          //         reportId: widget.report.report.id,
          //         type: "text",
          //         image: "",
          //         location: locationController.text,
          //         description: descriptionController.text,
          //         createdAt: DateTime.now(),
          //         updatedAt: DateTime.now());
          //
          //     await reportProvider.updateReportDetail(
          //       widget.report.copyWith(
          //         reportItems: [...widget.report.reportItems, _newItem],
          //       ),
          //     );
          //     if (!context.mounted) return;
          //     _loading = false;
          //     setState(() {});
          //     Navigator.pop(context, _newItem);
          //   },
          //   height: 44,
          //   color: CustomColors.maroon,
          //   shape:
          //       RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          //   child: _loading
          //       ? SizedBox(
          //           height: 30,
          //           width: 30,
          //           child: CircularProgressIndicator(
          //             color: CustomColors.white,
          //           ))
          //       : Text(
          //           "Save",
          //           style: CustomTextStyle.reportTitle.copyWith(
          //             color: CustomColors.white,
          //             fontWeight: FontWeight.w500,
          //           ),
          //         ),
          // ),
          const SizedBox(height: 16),

          // Show navigation buttons only if there are multiple items
          if (widget.report.reportItems.length > 1)
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
                            locationController = TextEditingController(
                                text: widget
                                    .report.reportItems[currentIndex].location);
                            descriptionController = TextEditingController(
                                text: widget.report.reportItems[currentIndex]
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
                    onPressed:
                        (currentIndex + 1) == widget.report.reportItems.length
                            ? null
                            : () async {
                                currentIndex++;
                                locationController = TextEditingController(
                                    text: widget.report
                                        .reportItems[currentIndex].location);
                                descriptionController = TextEditingController(
                                    text: widget.report
                                        .reportItems[currentIndex].description);

                                setState(() {});
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
            )
          else
            // Show Done button if only one item
            MaterialButton(
              onPressed: () {
                Navigator.pop(context);
              },
              height: 44,
              color: Colors.green,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              child: Text(
                "Done",
                style: CustomTextStyle.reportTitle.copyWith(
                  color: CustomColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
