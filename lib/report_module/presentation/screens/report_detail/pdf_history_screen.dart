import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:el_race/report_module/core/constants/colors.dart';
import 'package:el_race/report_module/core/constants/text_styles.dart';
import 'package:el_race/report_module/core/utils/flush_bar.dart';
import 'package:el_race/report_module/data/models/report_detail_model.dart';
import 'package:el_race/report_module/data/models/report_pdf_model.dart';
import 'package:el_race/report_module/data/provider/reports_provider.dart';
import 'package:el_race/report_module/data/repositories/company_repository.dart';
import 'package:el_race/report_module/data/services/pdf_service.dart';
import 'package:el_race/report_module/presentation/bottom_sheets/show_option_sheet.dart';
import 'package:el_race/report_module/presentation/screens/report_detail/pdf_preview_screen.dart';
import 'package:el_race/report_module/presentation/widgets/bottom_appbar.dart';
import 'package:el_race/report_module/presentation/widgets/pdf_tile.dart';
import 'package:el_race/report_module/presentation/widgets/square_button.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../widgets/custom_textfield.dart';

class PdfCreationScreen extends StatefulWidget {
  final ReportDetailModel reportDetailModel;
  final String folderName;
  const PdfCreationScreen(
      {super.key, required this.reportDetailModel, required this.folderName});

  @override
  State<PdfCreationScreen> createState() => _PdfCreationScreenState();
}

class _PdfCreationScreenState extends State<PdfCreationScreen> {
  TextEditingController nameController = TextEditingController();
  // TextEditingController subject = TextEditingController();
  TextEditingController projectName = TextEditingController();
  bool _generating = false;
  double _generationProgress = 0;
  String _generationStatus = '';
  String? _companyLogo;

  List<ReportPdfModel> _pdfs = [];

  @override
  void initState() {
    _loadPdfHistory();
    _loadCompany();
    nameController =
        TextEditingController(text: widget.reportDetailModel.report.name);
    // subject = TextEditingController();
    projectName =
        TextEditingController(text: widget.reportDetailModel.report.name);
    super.initState();
  }

  _loadPdfHistory() async {
    _pdfs = await reportProvider.fetchReports(
        empId: ReportProvider.empID,
        reportId: widget.reportDetailModel.report.id,
        folderId: widget.reportDetailModel.report.folderId);
    if (mounted) setState(() {});
  }

  _loadCompany() async {
    final company = await CompanyRepository().getCompany();
    if (mounted) setState(() => _companyLogo = company.logo);
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
          _companyLogo ?? CompanyRepository.company?.logo ?? 'assets/logo/logo.png',
          height: 60,
        ),
        bottom: getBottomAppBar(context,
            report: widget.reportDetailModel, folderName: widget.folderName),
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
              controller: projectName,
              inputType: TextInputType.text,
              hintText: "Project Name",
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
              onPressed: _generating ? null : _generateReport,
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
          if (_generating)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: (_generationProgress.clamp(0, 100)) / 100,
                    color: CustomColors.maroon,
                    backgroundColor: Colors.black12,
                    minHeight: 6,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_generationStatus.isEmpty ? 'Processing...' : _generationStatus} ${_generationProgress.round()}%',
                    style: CustomTextStyle.reportTitle,
                  ),
                ],
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
                                builder: (context) => PdfDisplayScreen(
                                    link: pdf.reportLink,
                                    fileName: pdf.fileName)));
                      },
                      onMoreClicked: () async {
                        int status = await showEditOptions(context,
                            options: ['View', "Share", "Delete"]);

                        if (status == 0) {
                          if (!context.mounted) return;

                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => PdfDisplayScreen(
                                      link: pdf.reportLink,
                                      fileName: pdf.fileName)));
                          return;
                        }

                        if (status == 1) {
                          try {
                            final response =
                                await http.get(Uri.parse(pdf.reportLink));
                            if (response.statusCode == 200) {
                              final name = pdf.fileName.isEmpty
                                  ? 'report.pdf'
                                  : pdf.fileName;
                              final fileName = name.endsWith('.pdf') ? name : '$name.pdf';
                              final dir = await getTemporaryDirectory();
                              final file = File('${dir.path}/$fileName');
                              await file.writeAsBytes(response.bodyBytes);
                              final box = context.findRenderObject() as RenderBox?;
                              await Share.shareXFiles(
                                [XFile(file.path, mimeType: 'application/pdf')],
                                sharePositionOrigin: box != null
                                    ? box.localToGlobal(Offset.zero) & box.size
                                    : const Rect.fromLTWH(0, 0, 100, 100),
                              );
                            }
                          } catch (_) {}
                          return;
                        }
                        if (status == 2) {
                          if (!context.mounted) return;
                          final confirm = await showEditOptions(context,
                              options: ['Confirm Delete', "Cancel"]);
                          if (confirm == 0) {
                            final deleted = await reportProvider
                                .deleteReportPdf(fileId: pdf.id);
                            if (deleted) {
                              await _loadPdfHistory();
                            } else {
                              if (context.mounted) {
                                showFlushBar(context,
                                    message: 'Failed to delete file.');
                              }
                            }
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

  _generateReport() async {
    // Hide keyboard if open
    FocusScope.of(context).unfocus();

    if (_generating) return;

    _generating = true;
    _generationProgress = 5;
    _generationStatus = 'Checking report limit...';
    if (mounted) setState(() {});

    try {
      // Re-fetch the latest list so the limit/duplicate checks use fresh data.
      final freshPdfs = await reportProvider.fetchReports(
        empId: ReportProvider.empID,
        reportId: widget.reportDetailModel.report.id,
        folderId: widget.reportDetailModel.report.folderId,
      );
      _pdfs = freshPdfs;
      if (mounted) setState(() {});

      if (freshPdfs.length >= 3) {
        showFlushBar(context,
            message:
                'Maximum 3 generated reports allowed. Please delete one before generating a new one.');
        _generating = false;
        _generationProgress = 0;
        _generationStatus = '';
        if (mounted) setState(() {});
        return;
      }

      if (freshPdfs
          .where((p) =>
              p.fileName == nameController.text ||
              p.fileName == ("${nameController.text}.pdf"))
          .isNotEmpty) {
        showFlushBar(context,
            message:
                "A report with the same name already exists. Please change the name and try again.");
        _generating = false;
        _generationProgress = 0;
        _generationStatus = '';
        if (mounted) setState(() {});
        return;
      }

      _generationProgress = 45;
      _generationStatus = 'Generating PDF...';
      if (mounted) setState(() {});

      Uint8List pdfBytes = await PdfService().generateReportPdf(
        report: widget.reportDetailModel,
        projectName: projectName.text,
      );

      print('file_by: $pdfBytes');

      _generationProgress = 70;
      _generationStatus = 'Uploading PDF...';
      if (mounted) setState(() {});

      final uploadedPdf = await reportProvider.uploadReportPdf(
        empId: ReportProvider.empID,
        reportId: widget.reportDetailModel.report.id,
        folderId: widget.reportDetailModel.report.folderId,
        fileName: nameController.text,
        pdfBytes: pdfBytes,
        onProgress: (uploadProgress) {
          if (!mounted) return;
          setState(() {
            _generationProgress =
                (70 + (uploadProgress * 30)).clamp(70.0, 100.0);
            _generationStatus = 'Uploading PDF...';
          });
        },
      );

      if (uploadedPdf != null) {
        _generationProgress = 100;
        _generationStatus = 'Completed';
        if (mounted) setState(() {});

        // Try to refresh the full list from the server
        final serverPdfs = await reportProvider.fetchReports(
            empId: ReportProvider.empID,
            reportId: widget.reportDetailModel.report.id,
            folderId: widget.reportDetailModel.report.folderId);

        if (serverPdfs.isNotEmpty) {
          _pdfs = serverPdfs;
        } else {
          // Server list API didn't return data yet — use the upload
          // response directly so the user sees it immediately.
          _pdfs = [..._pdfs, uploadedPdf];
        }
      } else {
        showFlushBar(context, message: 'Failed to upload generated report.');
      }
    } catch (e) {
      print('Report generation error: $e');
      if (mounted) {
        showFlushBar(context,
            message: 'Failed to generate report. Please try again.');
      }
    } finally {
      _generating = false;
      _generationProgress = 0;
      _generationStatus = '';
      if (mounted) setState(() {});
    }
  }
}
