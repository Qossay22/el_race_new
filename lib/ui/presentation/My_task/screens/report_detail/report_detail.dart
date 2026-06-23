import 'dart:io';

import 'package:el_race/core/utils/directory_operation.dart';
import 'package:el_race/data/models/report_detail_item.dart';
import 'package:el_race/data/models/report_detail_model.dart';
import 'package:el_race/data/models/report_model.dart';
import 'package:el_race/data/repositories/i_report_repository.dart';
import 'package:el_race/data/repositories/report_repository.dart';
import 'package:el_race/ui/presentation/My_task/bottom_sheets/show_option_sheet.dart';
import 'package:el_race/ui/presentation/My_task/dialogs/add_section.dart';
import 'package:el_race/ui/presentation/My_task/screens/report_detail/add_cover_screen.dart';
import 'package:el_race/ui/presentation/My_task/screens/report_detail/add_new_item.dart';
import 'package:el_race/ui/presentation/My_task/screens/report_detail/camera_screen.dart';
import 'package:el_race/ui/presentation/My_task/screens/report_detail/pdf_history_screen.dart';
import 'package:el_race/ui/widgets/cover_page.dart';
import 'package:el_race/ui/widgets/report_item.dart';
import 'package:el_race/ui/widgets/section_bar.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../../../core/constants/colors.dart';

import '../../../../../data/repositories/company_repository.dart';
import '../../../../widgets/bottom_appbar.dart';
import '../../../../widgets/square_button.dart';

class ReportDetailScreen extends StatefulWidget {
  final ReportModel report;
  const ReportDetailScreen({super.key, required this.report});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  late IReportRepository reportRepository;
  ReportDetailModel? reportDetail;

  String? selectedSection;

  @override
  void initState() {
    super.initState();
    reportRepository = ReportRepository();
    _loadUpdatedRecord();
  }

  Future<void> _loadUpdatedRecord() async {
    reportDetail = await reportRepository.getReportDetail(widget.report.id);
    reportDetail!.items
        .where((i) =>
            i.sectionName == "unAssigned" ||
            i.sectionName == "" ||
            i.sectionName == null)
        .toList();
    setState(() {});
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
        bottom: getBottomAppBar(context, report: widget.report),
        actions: [
          SquareButton(
            icon: Icons.share_outlined,
            color: CustomColors.maroon,
            borderColor: CustomColors.white,
            onPressed: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => PdfCreationScreen(
                            reportDetailModel: reportDetail!,
                            report: widget.report,
                          )));
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      floatingActionButton: SquareButton(
        icon: Icons.add,
        color: CustomColors.maroon,
        borderColor: CustomColors.white,
        onPressed: _showAddOptions,
      ),
      body: reportDetail != null
          ? ListView(
              padding: const EdgeInsets.only(bottom: 50),
              children: [
                if (reportDetail!.coverPage != null &&
                    reportDetail!.coverPage!.isNotEmpty)
                  CoverPageTile(
                    data: reportDetail!.coverPage!,
                    onMoreClicked: () async {
                      int status = await showEditOptions(context,
                          options: ["Edit", "Delete"]);
                      if (status == 0) {
                        _addNewCover();
                        return;
                      }
                      if (status == 1) {
                        if (!context.mounted) return;
                        int status = await showEditOptions(context,
                            options: ["Confirm Delete", "Cancel"]);
                        if (status == 0) {
                          ReportDetailModel updatedReported =
                              reportDetail!.copyWith(coverPage: null);
                          await reportRepository
                              .updateReportDetail(updatedReported);
                          await _loadUpdatedRecord();
                          return;
                        }
                      }
                    },
                  ),
                if (reportDetail!.items.isNotEmpty &&
                    reportDetail!.sections.isNotEmpty)
                  SectionBar(
                      active: selectedSection == "unAssigned",
                      sectionName: "Un Assigned",
                      count: reportDetail!.items.length.toString(),
                      onTap: () {
                        if ("unAssigned" == selectedSection) {
                          selectedSection = null;
                        } else {
                          selectedSection = "unAssigned";
                        }
                        setState(() {});
                      },
                      onMoreClick: () async {
                        _sectionMoreClick("unAssigned", true);
                      }),
                if (selectedSection == "unAssigned" ||
                    reportDetail!.sections.isEmpty)
                  ReorderableList(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemBuilder: (context, index) => ReportItem(
                          key: Key(reportDetail!.items[index].id),
                          item: reportDetail!.items[index],
                          index: index,
                          onTap: () {
                            _editExistingItem(reportDetail!.items[index]);
                          },
                          onMoreClicked: () async {
                            await _itemEditOptions(reportDetail!.items[index]);
                          }),
                      itemCount: reportDetail!.items.length,
                      onReorder: (int oldIndex, int newIndex) async {
                        setState(() {
                          if (newIndex > oldIndex) {
                            newIndex -= 1;
                          }
                          final ReportDetailItem movedItem =
                              reportDetail!.items.removeAt(oldIndex);
                          reportDetail!.items.insert(newIndex, movedItem);
                        });
                        await reportRepository
                            .updateReportDetail(reportDetail!);
                        _loadUpdatedRecord();
                      })
              ],
            )
          : const Center(
              child: CircularProgressIndicator(),
            ),
    );
  }

  //adding options for report start
  _showAddOptions([bool insideSection = false]) async {
    List<String> options = [
      "Image From Gallery",
      "Image From Camera",
      // "Add New Section",
      "Add Text Block",
      "Add Cover Page",
    ];
    if (insideSection) {
      options = [
        "Image From Gallery",
        "Image From Camera",
        "Add Text Block",
      ];
    }

    int selectedOptionIndex = await showEditOptions(context, options: options);
    if (selectedOptionIndex == 0) {
      _addGalleryImage();
      return;
    }
    if (selectedOptionIndex == 1) {
      _addCameraImage();
      return;
    }
    if (selectedOptionIndex == 2) {
      _addNewText();
      return;
    }
    if (selectedOptionIndex == 3) {
      _addNewCover();
      return;
    }
  }

  Future<void> _addCameraImage() async {
    var result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => const CustomCameraScreen(
                  onePicture: false,
                )));
    if (result != null && result is List && result.isNotEmpty) {
      List<ReportDetailItem> items = [...reportDetail!.items];

      for (int i = 0; i < result.length; i++) {
        String fileLocation = await saveImageToAppStorage(File(result[i].path),
            widget.report.id, selectedSection ?? "unAssigned");
        ReportDetailItem item = ReportDetailItem(
          sectionName: selectedSection,
          title: "",
          description: "",
          image: fileLocation,
          id: const Uuid().v4(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now().toIso8601String(),
          type: "image",
        );
        items.add(item);
        ReportDetailModel updatedReported =
            reportDetail!.copyWith(items: items);
        await reportRepository.updateReportDetail(updatedReported);
        if (result.length == 1) {
          await _loadUpdatedRecord();
          if (!mounted) return;

          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => AddNewItem(
                        index: reportDetail!.items
                            .indexWhere((i) => i.id == item.id),
                        report: widget.report,
                        reportDetailModel: reportDetail!,
                      )));
        }
      }

      await _loadUpdatedRecord();
    }
  }

  Future<void> _addGalleryImage() async {
    ImagePicker imagePicker = ImagePicker();
    List<XFile>? result = await imagePicker.pickMultiImage(imageQuality: 60);
    if (result.isNotEmpty) {
      List<ReportDetailItem> items = [...reportDetail!.items];
      for (int i = 0; i < result.length; i++) {
        String fileLocation = await saveImageToAppStorage(File(result[i].path),
            widget.report.id, selectedSection ?? "unAssigned");
        ReportDetailItem item = ReportDetailItem(
          sectionName: selectedSection,
          title: "",
          description: "",
          image: fileLocation,
          id: const Uuid().v4(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now().toIso8601String(),
          type: "image",
        );
        items.add(item);
        ReportDetailModel updatedReported =
            reportDetail!.copyWith(items: items);
        await reportRepository.updateReportDetail(updatedReported);

        if (result.length == 1) {
          await _loadUpdatedRecord();
          if (!mounted) return;
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => AddNewItem(
                        index: reportDetail!.items
                            .indexWhere((i) => i.id == item.id),
                        report: widget.report,
                        reportDetailModel: reportDetail!,
                      )));
        }
      }

      await _loadUpdatedRecord();
    }
  }

  Future<void> _addNewText() async {
    List<ReportDetailItem> items = [...reportDetail!.items];

    ReportDetailItem item = ReportDetailItem(
      sectionName: selectedSection,
      title: "",
      description: "",
      image: "",
      id: const Uuid().v4(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now().toIso8601String(),
      type: "text",
    );
    items.add(item);
    await reportRepository
        .updateReportDetail(reportDetail!.copyWith(items: items));
    await _loadUpdatedRecord();
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => AddNewItem(
                  index: reportDetail!.items.indexWhere((i) => i.id == item.id),
                  report: widget.report,
                  reportDetailModel: reportDetail!,
                )));
    await _loadUpdatedRecord();
    // check the text item is still empty may be delete but not needed for now
  }

  Future<void> _addNewSection() async {
    ReportDetailModel? updatedReportedModel =
        await addNewSection(context, report: reportDetail!);
    if (updatedReportedModel != null) {
      reportRepository.updateReportDetail(updatedReportedModel);
      await _loadUpdatedRecord();
    }
  }

  Future<void> _addNewCover() async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => AddCoverScreen(
                reportDetail: reportDetail!, report: widget.report)));

    await _loadUpdatedRecord();
  }

  _editExistingItem(ReportDetailItem i) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => AddNewItem(
                  index:
                      reportDetail!.items.indexWhere((item) => i.id == item.id),
                  report: widget.report,
                  reportDetailModel: reportDetail!,
                )));

    await _loadUpdatedRecord();
  }

  _itemEditOptions(ReportDetailItem item) async {
    int selectedOptionStatus = -1;
    if (selectedSection == "unAssigned" && reportDetail!.sections.isNotEmpty) {
      selectedOptionStatus = await showEditOptions(context,
          options: ['delete', 'Assign to section']);
    } else {
      if (reportDetail!.sections.isEmpty ||
          reportDetail!.sections.length == 1) {
        selectedOptionStatus =
            await showEditOptions(context, options: ['delete']);
      } else {
        selectedOptionStatus = await showEditOptions(context,
            options: ['delete', 'Move to other section']);
      }
    }

    if (selectedOptionStatus == 0) {
      if (!mounted) return;
      int deleteCodeStatus =
          await showEditOptions(context, options: ['Confirm Delete', 'Cancel']);
      if (deleteCodeStatus == 0) {
        if (item.type != "text") {
          await deleteFileViaPath(item.image!);
        }
        ReportDetailModel updatedReportModel = reportDetail!.copyWith(
            items: reportDetail!.items.where((i) => i.id != item.id).toList());
        await reportRepository.updateReportDetail(updatedReportModel);
        await _loadUpdatedRecord();
        // setState(() {});
        return;
      }
    }
    if (selectedOptionStatus == 1) {
      List<String> sections =
          reportDetail!.sections.where((s) => s != selectedSection).toList();
      if (!mounted) return;
      int selectedOptionStatus =
          await showEditOptions(context, options: sections);
      if (selectedOptionStatus == -1) return;
      String newSection = sections[selectedOptionStatus];

      String oldSection = selectedSection!;
      copyFileToAnotherSection(
          reportDetail!.id, oldSection, newSection, item.image!);
      List<ReportDetailItem> updatedItems = reportDetail!.items.map((i) {
        if (item.id == i.id) {
          return item.copyWith(
              sectionName: newSection,
              image: i.image!.replaceFirst("/$oldSection/", "/$newSection/"));
        }
        return i;
      }).toList();

      reportDetail = reportDetail!.copyWith(items: updatedItems);
      reportRepository.updateReportDetail(reportDetail!);
      _loadUpdatedRecord();

      return;
    }
  }

  _sectionMoreClick(String section, [bool unAssigned = false]) async {
    List<String> options = ['Edit', 'delete', "Move up", "Move Down"];
    if (reportDetail!.sections.length == 1 || unAssigned) {
      options.remove("Move up");
      options.remove("Move Down");
      if (unAssigned) options.remove("Edit");
    }
    int selectedOptionStatus = await showEditOptions(context, options: options);
    if (selectedOptionStatus == 0 && !unAssigned) {
      if (!mounted) return;
      ReportDetailModel? updatedReportedModel = await addNewSection(context,
          report: reportDetail!, sectionName: section);
      if (updatedReportedModel != null) {
        reportRepository.updateReportDetail(updatedReportedModel);
        await _loadUpdatedRecord();
      }
      return;
    }
    if (selectedOptionStatus == 1 ||
        (unAssigned && selectedOptionStatus == 0)) {
      if (!mounted) return;
      int deleteCodeStatus =
          await showEditOptions(context, options: ['Confirm Delete', 'Cancel']);
      if (deleteCodeStatus == 0) {
        ReportDetailModel updatedReportModel = reportDetail!.copyWith(
            items: reportDetail!.items.where((i) {
          return unAssigned
              ? (i.sectionName != "unAssigned" &&
                  i.sectionName != "" &&
                  i.sectionName != null)
              : i.sectionName != section;
        }).toList());
        if (!unAssigned) updatedReportModel.sections.remove(section);
        await reportRepository.updateReportDetail(updatedReportModel);
        await _loadUpdatedRecord();
        await deleteImageFromReportSection(reportDetail!.id, section);
        return;
      }
    }
    if (selectedOptionStatus == 2) {
      List<String> updateSectionOrder = [...reportDetail!.sections];
      int firstIndex = updateSectionOrder.indexOf(section);
      if (firstIndex > 0) {
        String temp = updateSectionOrder[firstIndex - 1];
        updateSectionOrder[firstIndex - 1] = updateSectionOrder[firstIndex];
        updateSectionOrder[firstIndex] = temp;
        ReportDetailModel updatedReportModel =
            reportDetail!.copyWith(sections: updateSectionOrder);
        await reportRepository.updateReportDetail(updatedReportModel);
        await _loadUpdatedRecord();
      }

      return;
    }
    if (selectedOptionStatus == 3) {
      List<String> updateSectionOrder = [...reportDetail!.sections];
      int firstIndex = updateSectionOrder.indexOf(section);
      if (firstIndex != (reportDetail!.sections.length - 1)) {
        String temp = updateSectionOrder[firstIndex + 1];
        updateSectionOrder[firstIndex + 1] = updateSectionOrder[firstIndex];
        updateSectionOrder[firstIndex] = temp;
        ReportDetailModel updatedReportModel =
            reportDetail!.copyWith(sections: updateSectionOrder);
        await reportRepository.updateReportDetail(updatedReportModel);
        await _loadUpdatedRecord();
      }

      return;
    }
  }

  //adding options for report end
}
