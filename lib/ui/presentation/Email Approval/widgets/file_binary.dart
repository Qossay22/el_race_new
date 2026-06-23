import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class AttachmentPdfViewer extends StatelessWidget {
  final Uint8List pdfBytes;
  final String attchmentName;
  const AttachmentPdfViewer({super.key, required this.pdfBytes,required this.attchmentName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(attchmentName.toString()),
      ),
      body: PDFView(
        pdfData: pdfBytes,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: false,
        pageFling: false,
        onError: (error) {
          debugPrint(error.toString());
        },
        onPageError: (page, error) {
          debugPrint('$page: ${error.toString()}');
        },
      ),
    );
  }
}
