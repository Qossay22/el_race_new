import 'dart:io';

import 'package:el_race/report_module/core/constants/colors.dart';
import 'package:el_race/report_module/core/constants/text_styles.dart';
import 'package:el_race/report_module/core/utils/directory_operation.dart';
import 'package:el_race/report_module/data/models/report_item_model.dart';
import 'package:el_race/report_module/data/models/report_model.dart';
import 'package:el_race/report_module/data/provider/reports_provider.dart';
import 'package:el_race/report_module/data/repositories/company_repository.dart';
import 'package:el_race/report_module/data/services/pdf_service.dart';
import 'package:el_race/report_module/presentation/bottom_sheets/create_task_from_report_sheet.dart';
import 'package:el_race/report_module/presentation/bottom_sheets/show_option_sheet.dart';
import 'package:el_race/report_module/presentation/dialogs/add_image_options_dialog.dart';
import 'package:el_race/report_module/presentation/screens/report_detail/add_cover_screen.dart';
import 'package:el_race/report_module/presentation/screens/report_detail/add_new_item.dart';
import 'package:el_race/report_module/presentation/screens/report_detail/camera_screen.dart';
import 'package:el_race/report_module/presentation/screens/report_detail/pdf_history_screen.dart';
import 'package:el_race/report_module/presentation/widgets/bottom_appbar.dart';
import 'package:el_race/report_module/presentation/widgets/linked_tasks_list.dart';
import 'package:el_race/report_module/presentation/widgets/report_item.dart';
import 'package:el_race/report_module/presentation/widgets/square_button.dart';
import 'package:el_race/ui/presentation/tasks/data/task_model.dart';
import 'package:el_race/ui/presentation/tasks/logic/tasks_provider.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../data/models/report_detail_model.dart';
import '../../widgets/cover_page.dart';

class ReportDetailScreen extends StatefulWidget {
  final ReportModel report;
  final String folderName;
  const ReportDetailScreen({
    super.key,
    required this.report,
    required this.folderName,
  });

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  ReportDetailModel? reportDetail;
  int _linkedTasksCount = 0;
  List<TaskModel> _linkedTasks = [];
  final Set<int> _submittingTaskIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadUpdatedRecord();
      await _loadLinkedTasks();
    });
  }

  bool _loading = true;
  String loadingText = "";
  double _loadingProgress = 0;

  Future<void> _loadLinkedTasks() async {
    if (reportDetail == null) return;

    final tasksProvider = Provider.of<TasksProvider>(context, listen: false);

    try {
      if (tasksProvider.status == TasksStatus.initial ||
          tasksProvider.status == TasksStatus.error) {
        await tasksProvider.loadTasks();
      } else if (tasksProvider.status == TasksStatus.empty) {
        await tasksProvider.loadTasks(forceRefresh: true);
      }

      final reportId = reportDetail!.report.id;
      final tasks = tasksProvider.tasks
          .where((task) => task.reportIds.contains(reportId))
          .toList();

      if (mounted) {
        setState(() {
          _linkedTasks = tasks;
          _linkedTasksCount = tasks.length;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _linkedTasks = [];
          _linkedTasksCount = 0;
        });
      }
    }
  }

  Future<void> _loadUpdatedRecord() async {
    loadingText = "";
    _loadingProgress = 0;
    _loading = true;
    setState(() {});
    reportDetail = ReportDetailModel(
      report: widget.report,
      coverPage: null,
      reportItems: [],
    );

    reportDetail = await reportProvider.getReportDetail(widget.report) ??
        ReportDetailModel(
          report: widget.report,
          coverPage: null,
          reportItems: [],
        );
    _loading = false;
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
        leadingWidth: 70,
        leading: SquareButton(
          icon: Icons.keyboard_backspace,
          color: CustomColors.white,
          borderColor: CustomColors.black,
          onPressed: () => Navigator.pop(context),
        ),
        title: CompanyRepository.company?.logo != null
            ? Image.asset(
                CompanyRepository.company!.logo,
                height: 60,
              )
            : const SizedBox.shrink(),
        bottom: getBottomAppBar(context,
            folderName: widget.folderName, report: reportDetail),
        actions: [
          // Tasks Badge Indicator
          if (_linkedTasksCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: CustomColors.maroon.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CustomColors.maroon, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.task_alt,
                        color: CustomColors.maroon,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$_linkedTasksCount',
                        style: TextStyle(
                          color: CustomColors.maroon,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
                            folderName: widget.folderName,
                          )));
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: reportDetail != null
          ? Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.only(bottom: 50),
                  children: [
                    // Linked Tasks Section
                    if (_linkedTasks.isNotEmpty)
                      LinkedTasksList(
                        tasks: _linkedTasks,
                        onSubmit: _onSubmitTask,
                        submittingTaskIds: _submittingTaskIds,
                      ),

                    if (reportDetail!.coverPage != null)
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
                              setState(() {});
                              bool status = await reportProvider
                                  .deleteCoverPage(reportDetail!);
                              if (status) {
                                reportDetail =
                                    reportDetail!.copyWith(coverPage: null);
                              }
                              return;
                            }
                          }
                        },
                      ),
                    ReorderableList(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) => ReportItem(
                            key: Key(reportDetail!.reportItems[index].id),
                            item: reportDetail!.reportItems[index],
                            index: index,
                            onTap: () {
                              _openItemDetail(reportDetail!.reportItems[index]);
                            },
                            onMoreClicked: () async {
                              await _deleteItems(
                                  reportDetail!.reportItems[index]);
                            }),
                        itemCount: reportDetail!.reportItems.length,
                        onReorder: (int oldIndex, int newIndex) async {
                          setState(() {
                            if (newIndex > oldIndex) {
                              newIndex -= 1;
                            }
                            final ReportItemModel movedItem =
                                reportDetail!.reportItems.removeAt(oldIndex);
                            reportDetail!.reportItems
                                .insert(newIndex, movedItem);
                          });
                          await reportProvider
                              .updateReportDetail(reportDetail!);
                          _loadUpdatedRecord();
                        }),
                    if (_loading && loadingText == "") ...[
                      ...List.generate(
                          6,
                          (e) => Skeletonizer(
                                enabled: true,
                                child: ReportItem(
                                  item: ReportItemModel(
                                      id: "0",
                                      reportId: "reportId",
                                      type: "text",
                                      image: "text",
                                      location: "location",
                                      description: "description",
                                      createdAt: DateTime.now(),
                                      updatedAt: DateTime.now()),
                                  onMoreClicked: () {},
                                  onTap: () {},
                                  index: 0,
                                ),
                              ))
                    ]
                  ],
                ),
                if (!_loading &&
                    reportDetail != null &&
                    reportDetail!.coverPage == null &&
                    reportDetail!.reportItems.isEmpty)
                  Center(
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _showAddOptions,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Add item to report",
                            style:
                                CustomTextStyle.heading.copyWith(color: black),
                          ),
                          Image.asset("assets/png/icons/add_image.png")
                        ],
                      ),
                    ),
                  ),
                if (_loading && loadingText != "")
                  Center(
                    child: Container(
                      margin: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                          color: CustomColors.maroon,
                          borderRadius: BorderRadius.circular(8)),
                      height: 80,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          LinearProgressIndicator(
                            value: _loadingProgress > 0
                                ? (_loadingProgress.clamp(0, 100)) / 100
                                : null,
                            color: CustomColors.blue,
                          ),
                          Text(
                            loadingText,
                            style: CustomTextStyle.reportHeader,
                          ),
                          LinearProgressIndicator(
                            value: _loadingProgress > 0
                                ? (_loadingProgress.clamp(0, 100)) / 100
                                : null,
                            color: CustomColors.blue,
                          ),
                        ],
                      ),
                      // width: 600,
                    ),
                  )
              ],
            )
          : const Center(
              child: CircularProgressIndicator(),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddOptions,
        backgroundColor: const Color(0xFF161B54),
        child: const Icon(
          Icons.add_a_photo,
          color: Colors.white,
        ),
      ),
    );
  }

  //adding options for report start
  _showAddOptions([bool insideSection = false]) async {
    int selectedOptionIndex = await showAddImageOptions(context);
    if (selectedOptionIndex == 0) {
      _addGalleryImage();
      return;
    }
    if (selectedOptionIndex == 1) {
      _addCameraImage();
      return;
    }
  }

  Future<void> _addNewCover() async {
    var result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => AddCoverScreen(
                  reportDetail: reportDetail!,
                  folderName: widget.folderName,
                )));
    if (result != null) {
      reportDetail = result;
    }
    setState(() {});
    await _loadUpdatedRecord();
  }

  Future<void> _addCameraImage() async {
    var result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => const CustomCameraScreen(onePicture: false)));
    print(result);

    if (result.isNotEmpty) {
      loadingText = "";

      _loading = true;
      setState(() {});
      for (XFile image in result) {
        loadingText = "images is uploading";
        ReportItemModel newItem = ReportItemModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            reportId: reportDetail!.report.id,
            type: "image",
            image: await saveImageToAppStorage(
                File(image.path),
                reportDetail!.report.folderId.toString() +
                    reportDetail!.report.folderId.toString()),
            location: "",
            description: "",
            createdAt: DateTime.now(),
            updatedAt: DateTime.now());

        await reportProvider.updateReportDetail(
          reportDetail!.copyWith(
            reportItems: [...reportDetail!.reportItems, newItem],
          ),
        );
        reportDetail = reportDetail!.copyWith(
          reportItems: [...reportDetail!.reportItems, newItem],
        );
        setState(() {});
      }
      _loading = false;
      setState(() {});
      await _loadUpdatedRecord();
    }
  }

  Future<void> _addGalleryImage() async {
    ImagePicker imagePicker = ImagePicker();
    List<XFile>? result = await imagePicker.pickMultiImage(imageQuality: 60);
    if (result.isNotEmpty) {
      _loading = true;
      setState(() {});
      for (XFile image in result) {
        loadingText =
            "${result.indexWhere((e) => image == e)} of ${result.length} images is uploading";

        ReportItemModel newItem = ReportItemModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            reportId: reportDetail!.report.id,
            type: "image",
            image: await saveImageToAppStorage(
                File(image.path),
                reportDetail!.report.folderId.toString() +
                    reportDetail!.report.folderId.toString()),
            location: "",
            description: "",
            createdAt: DateTime.now(),
            updatedAt: DateTime.now());

        await reportProvider.updateReportDetail(
          reportDetail!.copyWith(
            reportItems: [...reportDetail!.reportItems, newItem],
          ),
        );

        reportDetail = reportDetail!.copyWith(
          reportItems: [...reportDetail!.reportItems, newItem],
        );
        setState(() {});
      }
      _loading = false;
      loadingText = "";

      setState(() {});
      await _loadUpdatedRecord();
    }
  }

  Future<void> _addNewText() async {
    ReportItemModel? item = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => AddNewItem(
                  report: reportDetail!,
                  folderName: widget.folderName,
                )));
    if (item != null) {
      List<ReportItemModel> items = reportDetail!.reportItems;
      items.add(item);
      reportDetail = reportDetail!.copyWith(reportItems: items);
      setState(() {});
    }
    await _loadUpdatedRecord();
  }

  _openItemDetail(ReportItemModel item) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => AddNewItem(
                  report: reportDetail!,
                  item: item,
                  folderName: widget.folderName,
                )));
    await _loadUpdatedRecord();
  }

  _deleteItems(ReportItemModel item) async {
    int deleteStatus =
        await showEditOptions(context, options: ['Delete', 'Cancel']);
    if (!mounted || deleteStatus == 1 || deleteStatus == -1) return;
    int deleteCodeStatus =
        await showEditOptions(context, options: ['Confirm Delete', 'Cancel']);
    if (deleteCodeStatus == 0) {
      List<ReportItemModel> items = reportDetail!.reportItems;
      items.removeWhere((e) => e.id == item.id);
      reportDetail = reportDetail!.copyWith(reportItems: items);
      await reportProvider.updateReportDetail(reportDetail!);
      setState(() {});

      await _loadUpdatedRecord();
      return;
    }
  }

  Future<void> _onSubmitTask(TaskModel task) async {
    if (task.id == null) return;

    final tasksProvider = Provider.of<TasksProvider>(context, listen: false);

    setState(() {
      _submittingTaskIds.add(task.id!);
    });

    try {
      final message = await tasksProvider.completeTask(task.id!);

      if (mounted) {
        final feedback =
            message ?? tasksProvider.errorMessage ?? 'Unable to submit task';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(feedback)));
      }

      if ((task.projectId ?? '').isNotEmpty) {
        await _regenerateReportForTask(task);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit task: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _submittingTaskIds.remove(task.id!);
        });
      }
      await _loadLinkedTasks();
    }
  }

  Future<void> _regenerateReportForTask(TaskModel task) async {
    if (reportDetail == null) return;

    try {
      await _loadUpdatedRecord();

      setState(() {
        _loading = true;
        _loadingProgress = 20;
        loadingText = 'Preparing updated report... 20%';
      });

      if (mounted) {
        setState(() {
          _loadingProgress = 45;
          loadingText = 'Generating updated report... 45%';
        });
      }

      final pdfBytes = await PdfService().generateReportPdf(
        report: reportDetail!,
        projectName: task.projectId ?? widget.folderName,
      );

      if (mounted) {
        setState(() {
          _loadingProgress = 70;
          loadingText = 'Uploading updated report... 70%';
        });
      }

      final fileName =
          '${reportDetail!.report.name}-${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';

      final success = await reportProvider.uploadReportPdf(
        empId: ReportProvider.empID,
        reportId: reportDetail!.report.id,
        folderId: reportDetail!.report.folderId,
        fileName: fileName,
        pdfBytes: pdfBytes,
        onProgress: (uploadProgress) {
          if (!mounted) return;
          final progress = (70 + (uploadProgress * 30)).clamp(70.0, 100.0);
          setState(() {
            _loadingProgress = progress;
            loadingText =
                'Uploading updated report... ${_loadingProgress.round()}%';
          });
        },
      );

      if (mounted && success != null) {
        setState(() {
          _loadingProgress = 100;
          loadingText = 'Updated report ready 100%';
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success != null
                  ? 'Report regenerated with the latest images'
                  : 'Failed to upload regenerated report',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to regenerate report: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingProgress = 0;
          loadingText = "";
        });
      }
    }
  }

  /// Show Create Task from Report bottom sheet
  Future<void> _showCreateTaskSheet() async {
    if (reportDetail == null) return;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateTaskFromReportSheet(
        reportDetail: reportDetail!,
      ),
    );

    // Refresh tasks count and list if task was created
    if (result == true) {
      await _loadLinkedTasks();
    }
  }
}
