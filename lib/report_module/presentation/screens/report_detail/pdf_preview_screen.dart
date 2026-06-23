import 'dart:io';
import 'dart:typed_data';

import 'package:el_race/report_module/core/constants/colors.dart';
import 'package:el_race/report_module/data/repositories/company_repository.dart';
import 'package:el_race/report_module/presentation/widgets/square_button.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;

class PdfDisplayScreen extends StatefulWidget {
  final String link;
  final String? fileName;
  const PdfDisplayScreen({super.key, required this.link, this.fileName});

  @override
  State<PdfDisplayScreen> createState() => _PdfDisplayScreenState();
}

class _PdfDisplayScreenState extends State<PdfDisplayScreen> {
  bool loading = true;
  Uint8List? bytes;
  String? _companyLogo;

  loadFile() async {
    var data = await http.get(Uri.parse(widget.link));
    if (!mounted) return;
    setState(() {
      bytes = data.bodyBytes;
      loading = false;
    });
  }

  _loadCompany() async {
    final company = await CompanyRepository().getCompany();
    if (mounted) setState(() => _companyLogo = company.logo);
  }

  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    if (rootNavigator.canPop()) {
      rootNavigator.pop();
    }
  }

  Future<void> _shareReport() async {
    final rawName = widget.fileName?.trim() ?? '';
    final name = rawName.isNotEmpty ? rawName : widget.link.split('/').last;
    final fileName = name.endsWith('.pdf') ? name : '$name.pdf';
    // Write to temp file so iOS uses the correct filename
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes!);
    final box = context.findRenderObject() as RenderBox?;
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      sharePositionOrigin: box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : const Rect.fromLTWH(0, 0, 100, 100),
    );
  }

  @override
  void initState() {
    loadFile();
    _loadCompany();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomColors.containerColor,
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
            onPressed: _goBack,
          ),
        ),
        title: Image.asset(
          _companyLogo ?? CompanyRepository.company?.logo ?? 'assets/logo/logo.png',
          height: 60,
        ),
        actions: [
          SquareButton(
            icon: Icons.share_outlined,
            color: loading ? CustomColors.black : CustomColors.maroon,
            borderColor: CustomColors.white,
            onPressed: loading
                ? null
                : () => _shareReport(),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: loading
          ? const Center(
              child: Text("Loading Pdf Please Wait..."),
            )
          : Column(
              children: [
                const Divider(
                  height: 1,
                ),
                Expanded(
                  child: SfPdfViewer.memory(
                    bytes!,
                    canShowScrollHead: true,
                    canShowScrollStatus: true,
                    enableDoubleTapZooming: true,
                    enableTextSelection: true,
                    pageSpacing: 4,
                  ),
                ),
              ],
            ),
    );
  }
}
