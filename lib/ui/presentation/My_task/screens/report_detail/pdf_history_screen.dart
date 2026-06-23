import 'dart:typed_data';

import 'package:el_race/core/utils/directory_operation.dart';
import 'package:el_race/core/utils/flush_bar.dart';
import 'package:el_race/data/models/pdf_model.dart';
import 'package:el_race/data/models/report_detail_model.dart';
import 'package:el_race/data/models/report_model.dart';
import 'package:el_race/data/repositories/report_repository.dart';
import 'package:el_race/data/services/pdf_service.dart';
import 'package:el_race/ui/presentation/My_task/bottom_sheets/show_option_sheet.dart';
import 'package:el_race/ui/presentation/My_task/dialogs/file_name.dart';
import 'package:el_race/ui/presentation/My_task/screens/report_detail/pdf_preview_screen.dart';
import 'package:el_race/ui/widgets/custom_textfield.dart';
import 'package:el_race/ui/widgets/pdf_tile.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../../core/constants/colors.dart';
import '../../../../../core/constants/text_styles.dart';

import '../../../../../data/repositories/company_repository.dart';
import '../../../../widgets/bottom_appbar.dart';
import '../../../../widgets/square_button.dart';

class PdfCreationScreen extends StatefulWidget {
  final ReportModel report;
  final ReportDetailModel reportDetailModel;
  const PdfCreationScreen(
      {super.key, required this.report, required this.reportDetailModel});

  @override
  State<PdfCreationScreen> createState() => _PdfCreationScreenState();
}

class _PdfCreationScreenState extends State<PdfCreationScreen> {
  TextEditingController nameController = TextEditingController();
  TextEditingController subject = TextEditingController();
  TextEditingController projectName = TextEditingController();
  bool _generating = false;

  List<PdfModel> _pdfs = [];
  @override
  void initState() {
    _loadPdfHistory();
    nameController = TextEditingController(text: widget.report.name);
    subject = TextEditingController(text: "Weekly");
    projectName = TextEditingController();
    super.initState();
  }

  _loadPdfHistory() async {
    _pdfs = await ReportRepository().getReportPdfs(widget.report);
    _pdfs.sort((a, b) => b.date.compareTo(a.date));
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
        actions: const [],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: CustomTextField(
              maxCharacter: 100,
              showLabel: true,
              required: true,
              controller: subject,
              inputType: TextInputType.text,
              hintText: "Subject",
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CustomTextField(
              maxCharacter: 100,
              showLabel: true,
              required: true,
              controller: nameController,
              inputType: TextInputType.text,
              hintText: "Pdf File name",
            ),
          ),
          Center(
            child: MaterialButton(
              onPressed: () async {
                if (_generating) return;

                // Enforce maximum 3 generated files per report
                if (_pdfs.length >= 3) {
                  showFlushBar(context,
                      message:
                          'Maximum 3 generated reports allowed. Please delete one before generating a new one.');
                  return;
                }

                _generating = true;
                setState(() {});
                if (_pdfs
                    .where((p) => p.name == ("${nameController.text}.pdf"))
                    .isNotEmpty) {
                  _generating = false;
                  setState(() {});
                  showFlushBar(context,
                      message:
                          "A report with the same name already exists. Please change the name and try again.");
                  return;
                }
                Uint8List pdfBytes = await PdfService().generateReportPdf(
                  report: widget.report,
                  reportDetail: widget.reportDetailModel,
                  subject: subject.text,
                  projectName: widget.report.name,
                );
                await savePdfToAppStorage(
                    pdfBytes, widget.report.id, nameController.text);
                await _loadPdfHistory();
                _generating = false;
                if (mounted) setState(() {});
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              color: CustomColors.maroon,
              child: _generating
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: CustomColors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      "Generate Report",
                      style: CustomTextStyle.reportTitle
                          .copyWith(color: CustomColors.white),
                    ),
            ),
          ),
          const Divider(height: 25),
          Expanded(
            child: ListView(
              children: [
                ..._pdfs.map((pdf) => PdfTile(
                      pdf: pdf,
                      onTap: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    PdfDisplayScreen(path: pdf.path)));
                      },
                      onMoreClicked: () async {
                        int status = await showEditOptions(context,
                            options: ['View', "Share", "Rename", "Delete"]);

                        if (status == 0) {
                          if (!context.mounted) return;

                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      PdfDisplayScreen(path: pdf.path)));
                          return;
                        }
                        if (status == 1) {
                          await Share.shareXFiles([XFile(pdf.path)],
                              fileNameOverrides: [pdf.name]);
                          return;
                        }
                        if (status == 2) {
                          await showFileRename(context, pdf: pdf);
                          await _loadPdfHistory();
                          return;
                        }
                        if (status == 3) {
                          if (!context.mounted) return;
                          int status = await showEditOptions(context,
                              options: ['Confirm Delete', "Cancel"]);
                          if (status == 0) {
                            await ReportRepository().deletePdf(pdf);
                            await _loadPdfHistory();
                          }
                          return;
                        }
                      },
                    ))
              ],
            ),
          )
        ],
      ),
    );
  }
}
