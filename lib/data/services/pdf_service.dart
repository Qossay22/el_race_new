import 'dart:io';

import 'package:el_race/data/models/report_detail_model.dart';
import 'package:el_race/data/models/report_model.dart';
import 'package:el_race/data/repositories/company_repository.dart';
import 'package:el_race/report_module/data/models/company_model.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfService {
  Future<Uint8List> generateReportPdf({
    required ReportModel report,
    required ReportDetailModel reportDetail,
    required String subject,
    required String projectName,
  }) async {
    final pw.Font baseFont = await _loadPdfFont();
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: baseFont,
        bold: baseFont,
        italic: baseFont,
        boldItalic: baseFont,
      ),
    );
    CompanyModel companyData = CompanyRepository.company!;
    final String userName = _getUserName(companyData);

    // Log the resolved user name and sources for troubleshooting.
    final loginName = SharedPref.getLoginDataOrNull()?.result?.data?.name ?? "";
    print(
        'PDF user name resolved: $userName (company: ${companyData.employeeName}, login: $loginName)');

    Uint8List logo = await _loadAssetAsBytes(companyData.logo);
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin:
            const pw.EdgeInsets.only(left: 32, right: 32, bottom: 20, top: 5),
        header: (context) => _buildHeader(context, logo, report, reportDetail,
            projectName, subject, userName),
        footer: (context) => _buildFooter(context, userName),
        build: (context) =>
            _buildBody(context, logo, report, reportDetail, userName),
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(
      context,
      logo,
      ReportModel report,
      ReportDetailModel reportDetail,
      String projectName,
      String subject,
      String userName) {
    CompanyModel companyData = CompanyRepository.company!;
    bool needToShowCover = (context.pageNumber == 1 &&
        reportDetail.coverPage != null &&
        reportDetail.coverPage!.isNotEmpty);
    if (needToShowCover) return pw.SizedBox();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Logo centered at the top.

        pw.Container(
          child: pw.Column(children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Image(pw.MemoryImage(logo), height: 90, width: 170),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      "Report",
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      "No. ${_getReportNumber(report)}",
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                )
              ],
            ),
            pw.SizedBox(height: 2),
            pw.Container(height: 1, color: PdfColors.black),
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black),
              ),
              child: pw.Row(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  if (userName.isNotEmpty)
                    pw.Expanded(
                      child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.start,
                          children: [
                            pw.Text(
                              "Subject:",
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              subject,
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight: pw.FontWeight.normal,
                              ),
                            ),
                          ]),
                    ),
                  pw.Container(width: 1, color: PdfColors.black, height: 44),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.start,
                        children: [
                          pw.Text(
                            "Project",
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            projectName,
                            textAlign: pw.TextAlign.center,
                            style: const pw.TextStyle(
                              fontSize: 13,
                            ),
                          )
                        ]),
                  ),
                  pw.Container(width: 1, color: PdfColors.black, height: 44),
                  pw.Expanded(
                    child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.start,
                        children: [
                          pw.Text(
                            "Date:",
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            " ${DateFormat("dd//MM/yyyy").format(DateTime.now())}",
                            textAlign: pw.TextAlign.center,
                            style: const pw.TextStyle(
                              fontSize: 13,
                            ),
                          )
                        ]),
                  ),
                ],
              ),
            ),
          ]),
        ),

        pw.SizedBox(height: 20),
        if (!needToShowCover) _buildTableHeader()
      ],
    );
  }

  _buildBody(pw.Context context, logo, ReportModel report,
      ReportDetailModel reportDetail, String userName) {
    List<pw.Widget> content = [];
    CompanyModel companyData = CompanyRepository.company!;
    bool needToShowCover =
        (reportDetail.coverPage != null && reportDetail.coverPage!.isNotEmpty);

    if (reportDetail.coverPage != null && reportDetail.coverPage!.isNotEmpty) {
      content.add(pw.SizedBox(
        height: 650,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Image(
                pw.MemoryImage(logo),
                // width: 50,
                height: 150,
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Center(
                  child: pw.Container(
                      // width: 400,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black),
                      ),
                      padding: const pw.EdgeInsets.symmetric(vertical: 5),
                      child: pw.Column(children: [
                        pw.Row(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Expanded(
                              child: pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.start,
                                  children: [
                                    pw.SizedBox(width: 12),
                                    pw.Text(
                                      "Employee Name:",
                                      textAlign: pw.TextAlign.center,
                                      style: pw.TextStyle(
                                        fontSize: 15,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                    pw.Text(
                                      " $userName",
                                      textAlign: pw.TextAlign.center,
                                      style: const pw.TextStyle(
                                        fontSize: 15,
                                      ),
                                    ),
                                  ]),
                            ),
                          ],
                        ),
                        pw.Container(
                            color: PdfColors.black,
                            height: 1,
                            margin: const pw.EdgeInsets.symmetric(vertical: 5)),
                        pw.Row(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Expanded(
                              child: pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.start,
                                  children: [
                                    pw.SizedBox(width: 15),
                                    pw.Text(
                                      "Employee ID:",
                                      textAlign: pw.TextAlign.center,
                                      style: pw.TextStyle(
                                        fontSize: 15,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                    pw.Text(
                                      " ${companyData.employeeID}",
                                      textAlign: pw.TextAlign.center,
                                      style: const pw.TextStyle(
                                        fontSize: 15,
                                      ),
                                    ),
                                  ]),
                            ),
                          ],
                        ),
                        pw.Container(
                            color: PdfColors.black,
                            height: 1,
                            margin: const pw.EdgeInsets.symmetric(vertical: 5)),
                        pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.start,
                            children: [
                              pw.SizedBox(width: 12),
                              pw.Text(
                                "Email:",
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(
                                  fontSize: 15,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                " ${companyData.personEmail}",
                                textAlign: pw.TextAlign.center,
                                style: const pw.TextStyle(
                                  fontSize: 15,
                                ),
                              ),
                            ]),
                        pw.Container(
                            color: PdfColors.black,
                            height: 1,
                            margin: const pw.EdgeInsets.symmetric(vertical: 5)),
                        pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.start,
                            children: [
                              pw.SizedBox(width: 12),
                              pw.Text(
                                "Project:",
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(
                                  fontSize: 15,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                " ${report.name}",
                                textAlign: pw.TextAlign.center,
                                style: const pw.TextStyle(
                                  fontSize: 15,
                                ),
                              )
                            ]),
                        pw.Container(
                            color: PdfColors.black,
                            height: 1,
                            margin: const pw.EdgeInsets.symmetric(vertical: 5)),
                        pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.start,
                            children: [
                              pw.SizedBox(width: 12),
                              pw.Text(
                                "Date:",
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(
                                  fontSize: 15,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                " ${DateFormat("dd//MM/yyyy").format(DateTime.now())}",
                                textAlign: pw.TextAlign.center,
                                style: const pw.TextStyle(
                                  fontSize: 15,
                                ),
                              )
                            ]),
                      ])),
                ),
                pw.SizedBox(height: 20),
                if (!needToShowCover) _buildTableHeader()
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text(reportDetail.coverPage!['title'],
                style:
                    pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text(reportDetail.coverPage!['description'],
                style: const pw.TextStyle(fontSize: 15)),
          ],
        ),
      ));
      // content.add(pw.PageBreak());
    }
    content.add(buildTableBody(reportDetail));
    return content;
  }

  _buildFooter(context, String userName) {
    return pw.Container(
        decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(width: 2))),
        padding: const pw.EdgeInsets.only(top: 10, left: 20, right: 20),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'User: $userName',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 12),
              ),
            ]));
  }

  String _getUserName(CompanyModel companyData) {
    final loginData = SharedPref.getLoginDataOrNull();
    final loginName =
        loginData?.result?.data?.name ?? loginData?.result?.data?.username;

    if (companyData.employeeName.isNotEmpty) return companyData.employeeName;
    if (loginName != null && loginName.isNotEmpty) return loginName;
    return 'Unknown User';
  }

  int _getReportNumber(ReportModel report) {
    final parsedId = int.tryParse(report.id) ?? 0;
    if (parsedId <= 0) return 1001;
    return 1000 + parsedId;
  }

  pw.Widget _buildBulletList(String description) {
    final lines = description
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => line.replaceFirst(RegExp(r'^[•\-*]+\s*'), ''))
        .toList();

    if (lines.isEmpty) {
      return pw.Text(description, style: const pw.TextStyle(fontSize: 13));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('• ', style: const pw.TextStyle(fontSize: 13)),
                pw.Expanded(
                  child:
                      pw.Text(line, style: const pw.TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<pw.Font> _loadPdfFont() async {
    // Use a Unicode-capable font to render names with non-Latin characters.
    final ByteData data =
        await rootBundle.load('assets/fonts/arbicsupport.ttf');
    return pw.Font.ttf(data);
  }

  Future<Uint8List> _loadAssetAsBytes(String assetPath) async {
    final ByteData data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List();
  }

  pw.Widget buildTableBody(ReportDetailModel reportDetail) {
    const double rowHeight = 200;

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey),
      columnWidths: {
        0: const pw.FixedColumnWidth(30),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1),
      },
      children: [
        for (int i = 0; i < reportDetail.items.length; i++)
          pw.TableRow(
            children: [
              pw.Container(
                height: rowHeight,
                alignment: pw.Alignment.center,
                child: pw.Text("${i + 1}"),
              ),
              // Image column - you can replace the placeholder with pw.Image if you have an image widget

              pw.Container(
                height: rowHeight,
                alignment: pw.Alignment.center,
                child: (reportDetail.items[i].type != "text")
                    ? pw.Image(pw.MemoryImage(
                        File(reportDetail.items[i].image!).readAsBytesSync()))
                    : pw.Text(""),
              ),
              pw.Container(
                height: rowHeight,
                alignment: pw.Alignment.center,
                child: pw.Text(reportDetail.items[i].title ?? "",
                    style: const pw.TextStyle(fontSize: 13)),
              ),
              // Content column with created date, title, and description.
              pw.Container(
                height: rowHeight,
                padding: const pw.EdgeInsets.all(6),
                alignment: pw.Alignment.topLeft,
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.start,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (reportDetail.items[i].sectionName != null &&
                        reportDetail.items[i].sectionName != "")
                      pw.Text("${reportDetail.items[i].sectionName}",
                          style: pw.TextStyle(
                              fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    if (reportDetail.items[i].description != null &&
                        reportDetail.items[i].description != "")
                      pw.SizedBox(height: 4),
                    if (reportDetail.items[i].description != null &&
                        reportDetail.items[i].description != "")
                      _buildBulletList(reportDetail.items[i].description!),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  pw.Widget _buildTableHeader() {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey),
      columnWidths: {
        0: const pw.FixedColumnWidth(30),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              alignment: pw.Alignment.center,
              child: pw.Text("#",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              alignment: pw.Alignment.center,
              child: pw.Text("Photo",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              alignment: pw.Alignment.center,
              child: pw.Text("Location",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              alignment: pw.Alignment.center,
              child: pw.Text("Description",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }
}
