import 'package:el_race/core/utils/directory_operation.dart';
import 'package:el_race/data/models/report_model.dart';
import 'package:el_race/data/repositories/i_report_repository.dart';
import 'package:el_race/data/repositories/report_repository.dart';
import 'package:el_race/ui/presentation/My_task/dialogs/add_report.dart';
import 'package:el_race/ui/presentation/My_task/dialogs/rename_report_dialog.dart';
import 'package:el_race/ui/widgets/report_tile.dart';
import 'package:flutter/material.dart';
import '../../../../../core/constants/colors.dart';
import '../../../../../core/constants/text_styles.dart';
import '../../../../../data/repositories/company_repository.dart';
import '../../../../widgets/bottom_appbar.dart';
import '../../../../widgets/square_button.dart';

class FolderReportScreen extends StatefulWidget {
  final ReportModel folder;
  const FolderReportScreen({super.key, required this.folder});

  @override
  State<FolderReportScreen> createState() => _FolderReportScreenState();
}

class _FolderReportScreenState extends State<FolderReportScreen> {
  late IReportRepository reportRepository;
  List<ReportModel> reports = [];

  @override
  void initState() {
    super.initState();
    reportRepository = ReportRepository();
    _loadReports();
  }

  Future<void> _loadReports() async {
    reports = await reportRepository.getAllReportsForFolder(widget.folder.id);
    reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: SquareButton(
              icon: Icons.add,
              color: CustomColors.blue,
              borderColor: CustomColors.white,
              onPressed: () async {
                ReportModel? report = await showAddNewReport(context,
                    type: 1, folderID: widget.folder.id);
                if (report != null) {
                  await reportRepository.addReport(report);
                  reports.insert(0, report);
                }
                setState(() {});
                return;
              },
            ),
          ),
        ],
        bottom: getBottomAppBar(context),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: 20,
            color: CustomColors.blue,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.folder.name,
                  style: CustomTextStyle.reportHeader,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                return ReportTile(
                  report: reports[index],
                  onMenuSelected: (value) async {
                    if (value == 'rename') {
                      if (!context.mounted) return;
                      ReportModel updatedReport = await showRenameDialog(
                          context,
                          report: reports[index]);
                      int reportIndex = reports.indexWhere((r) {
                        return r.id == reports[index].id;
                      });

                      reports[reportIndex] = updatedReport;
                      setState(() {});
                      await reportRepository.updateReport(updatedReport);
                      return;
                    }
                    if (value == 'delete') {
                      if (!context.mounted) return;
                      final shouldDelete = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Report'),
                          content: const Text(
                            'Are you sure you want to delete this report?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (shouldDelete == true) {
                        final reportToDelete = reports[index];
                        await reportRepository.deleteReport(reports[index]);
                        reports.removeWhere((r) {
                          return r.id == reportToDelete.id;
                        });
                        setState(() {});
                        await deleteImageForWholeReport(reportToDelete.id);
                        return;
                      }
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
