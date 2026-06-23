import 'package:el_race/report_module/core/constants/colors.dart';
import 'package:el_race/report_module/core/constants/text_styles.dart';
import 'package:el_race/report_module/data/models/folder_model.dart';
import 'package:el_race/report_module/data/provider/reports_provider.dart';
import 'package:el_race/report_module/data/repositories/company_repository.dart';
import 'package:el_race/report_module/presentation/bottom_sheets/show_option_sheet.dart';
import 'package:el_race/report_module/presentation/dialogs/add_report.dart';
import 'package:el_race/report_module/presentation/dialogs/rename_report_dialog.dart';
import 'package:el_race/report_module/presentation/screens/report_detail/report_detail.dart';
import 'package:el_race/report_module/presentation/screens/report_listing/report_app_home_screen.dart';
import 'package:el_race/report_module/presentation/widgets/bottom_appbar.dart';
import 'package:el_race/report_module/presentation/widgets/square_button.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/report_tile.dart';

class FolderReportScreen extends StatefulWidget {
  final FolderModel folder;
  const FolderReportScreen({super.key, required this.folder});

  @override
  State<FolderReportScreen> createState() => _FolderReportScreenState();
}

class _FolderReportScreenState extends State<FolderReportScreen> {
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReports();
    });
  }

  Future<void> _loadReports() async {
    _loading = true;
    setState(() {});
    await reportProvider.fetchAllReports(folderID: widget.folder.id.toString());
    print(widget.folder.id.toString());
    _loading = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    ReportProvider reportProviderListener =
        Provider.of<ReportProvider>(context);
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SquareButton(
              icon: Icons.add,
              color: CustomColors.blue,
              borderColor: CustomColors.white,
              onPressed: () async {
                bool status = await showAddNewReport(context,
                    type: 1, folderID: widget.folder.id.toString());

                if (status) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ReportDetailScreen(
                                report: reportProviderListener.reports.first,
                                folderName: widget.folder.name,
                              )));
                }

                setState(() {});
                return;
              },
            ),
          ),
        ],
        bottom: getBottomAppBar(context, folderName: widget.folder.name),
      ),
      body: Column(
        children: [
          Expanded(
            child: !_loading && reportProviderListener.reports.isEmpty
                ? Center(
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () async {
                        await showAddNewReport(context,
                            type: 1, folderID: widget.folder.id.toString());
                        setState(() {});
                        return;
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "New Report",
                            style:
                                CustomTextStyle.heading.copyWith(color: black),
                          ),
                          Image.asset("assets/png/icons/add_file.png")
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: (_loading ? 10 : 0) +
                        reportProviderListener.reports.length,
                    itemBuilder: (context, index) {
                      if (_loading) {
                        return showFolderOrReportLoader();
                      } else {
                        return ReportTile(
                          folderName: widget.folder.name,
                          report: reportProviderListener.reports[index],
                          onMenuSelected: (value) async {
                            if (value == 'rename') {
                              if (!context.mounted) return;
                              await showRenameReport(context,
                                  report:
                                      reportProviderListener.reports[index]);
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
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
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
                                reportProvider.deleteReport(
                                    reportId: reportProviderListener
                                        .reports[index].id);
                                return;
                              }
                            }
                          },
                        );
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
