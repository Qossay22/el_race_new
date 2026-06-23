import 'dart:io';
import 'dart:typed_data';
import 'package:el_race/data/models/pdf_model.dart';
import 'package:el_race/data/repositories/report_repository.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

deleteImageForWholeReport(String report) async {
  final directory = await getApplicationDocumentsDirectory();
  final targetFolder = '${directory.path}/$report';
  try {
    if (await Directory(targetFolder).exists()) {
      await Directory(targetFolder).delete(recursive: true);
    }
  } catch (e) {
    debugPrint('unable to delete whole report direcotry : $e');
  }
}

deleteImageFromReportSection(String report, String section) async {
  final directory = await getApplicationDocumentsDirectory();
  final targetFolder = '${directory.path}/$report/$section';
  try {
    if (await Directory(targetFolder).exists()) {
      await Directory(targetFolder).delete(recursive: true);
    }
  } catch (e) {
    debugPrint('unable to delete whole report direcotry : $e');
  }
}

Future<void> renameFile(String filePath, String newName) async {
  final file = File(filePath);
  if (await file.exists()) {
    try {
      final newFilePath = p.join(file.parent.path, newName);
      await file.rename(newFilePath);
      debugPrint('File renamed successfully to $newFilePath');
    } catch (e) {
      debugPrint('Error renaming file: $e');
    }
  } else {
    debugPrint('File does not exist at $filePath');
  }
}

Future<Directory> getAppDirectory() async {
  Directory appDocDir = await getApplicationDocumentsDirectory();
  return appDocDir;
}
Future<void> moveFromOneSectionToAnother(
    String reportID, String section, String updatedSection) async {
  final directory = await getApplicationDocumentsDirectory();
  final String oldFolderPath = '${directory.path}/$reportID/$section';
  final String newFolderPath = '${directory.path}/$reportID/$updatedSection';
  final Directory oldFolder = Directory(oldFolderPath);
  if (await oldFolder.exists()) {
    try {
      await oldFolder.rename(newFolderPath);
      debugPrint('Done');
    } catch (e) {
      debugPrint('Error moving folder: $e');
    }
  } else {
    debugPrint('Old folder does not exist: $oldFolderPath');
  }
}

Future<void> deleteFileViaPath(String path) async {
  try {
    if (await File(path).exists()) {
      File(path).delete();
    }
    debugPrint('File at $path is deleted.');
  } catch (e) {
    debugPrint('Error moving folder: $e');
  }
}

//used when we move report item from one section to another
Future<void> copyFileToAnotherSection(
    String reportID, String section, String updatedSection, String path) async {
  if (path == "") return;
  String updatedPath = path.replaceFirst("/$section/", "/$updatedSection/");
  String fileName = updatedPath.split("/").last;
  updatedPath = updatedPath.replaceFirst(fileName, "");
  final Directory targetDir = Directory(updatedPath);
  if (!await targetDir.exists()) {
    await targetDir.create(recursive: true);
  }
  try {
    await File(path).rename(updatedPath + fileName);
    debugPrint('Done');
  } catch (e) {
    debugPrint('Error moving folder: $e');
  }
}

Future<String> saveImageToAppStorage(
    File originalImage, String report, String section) async {
  final Directory directory = await getApplicationDocumentsDirectory();
  String targetDirPath = '${directory.path}/$report/';
  if (section.isNotEmpty) {
    targetDirPath = '${directory.path}/$report/$section/';
  }
  final Directory targetFolder = Directory(targetDirPath);
  if (!await targetFolder.exists()) {
    await targetFolder.create(recursive: true);
  }

  String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
  String newPath = targetFolder.path + fileName;

  try {
    final File newFile = await originalImage.copy(newPath);
    debugPrint("Image saved to app directory: $newPath");
    return newFile.path;
  } catch (e) {
    debugPrint('Unable to save image to app directory: $e');
    return '';
  }
}

Future<String> savePdfToAppStorage(
    Uint8List pdf, String report, String pdfName) async {
  final directory = await getApplicationDocumentsDirectory();
  String newPath = '${directory.path}/$report/pdf/${DateTime.now()}.pdf';

  try {
    final Directory targetDir = Directory(p.dirname(newPath));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final newFile = await File(newPath).writeAsBytes(List<int>.from(pdf));
    await ReportRepository().saveReportPdf(PdfModel(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: "$pdfName.pdf",
        path: newPath,
        date: DateTime.now(),
        reportID: report));
    debugPrint("PDF saved to app directory: ${newFile.path}");
    return newFile.path;
  } catch (e) {
    debugPrint('Unable to save PDF to app directory: $e');
  }
  return '';
}
