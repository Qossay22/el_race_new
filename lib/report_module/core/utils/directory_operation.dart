import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

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

// deleteImageFromReportSection(String report, String section) async {
//   final directory = await getApplicationDocumentsDirectory();
//   final targetFolder = '${directory.path}/$report/$section';
//   try {
//     if (await Directory(targetFolder).exists()) {
//       await Directory(targetFolder).delete(recursive: true);
//     }
//   } catch (e) {
//     debugPrint('unable to delete whole report direcotry : $e');
//   }
// }

// Future<void> renameFile(String filePath, String newName) async {
//   final file = File(filePath);
//   if (await file.exists()) {
//     try {
//       final newFilePath = p.join(file.parent.path, newName);
//       await file.rename(newFilePath);
//       if (kDebugMode) {
//         print('File renamed successfully to $newFilePath');
//       }
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error renaming file: $e');
//       }
//     }
//   } else {
//     if (kDebugMode) {
//       print('File does not exist at $filePath');
//     }
//   }
// }

// Future<void> moveFromOneSectionToAnother(
//     String reportID, String section, String updatedSection) async {
//   final directory = await getApplicationDocumentsDirectory();
//   final String oldFolderPath = '${directory.path}/$reportID/$section';
//   final String newFolderPath = '${directory.path}/$reportID/$updatedSection';
//   final Directory oldFolder = Directory(oldFolderPath);
//   if (await oldFolder.exists()) {
//     try {
//       await oldFolder.rename(newFolderPath);
//       debugPrint('Done');
//     } catch (e) {
//       debugPrint('Error moving folder: $e');
//     }
//   } else {
//     debugPrint('Old folder does not exist: $oldFolderPath');
//   }
// }

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

// //used when we move report item from one section to another
// Future<void> copyFileToAnotherSection(
//     String reportID, String section, String updatedSection, String path) async {
//   if (path == "") return;
//   String updatedPath = path.replaceFirst("/$section/", "/$updatedSection/");
//   String fileName = updatedPath.split("/").last;
//   updatedPath = updatedPath.replaceFirst(fileName, "");
//   final Directory targetDir = Directory(updatedPath);
//   if (!await targetDir.exists()) {
//     await targetDir.create(recursive: true);
//   }
//   try {
//     await File(path).rename(updatedPath + fileName);
//     debugPrint('Done');
//   } catch (e) {
//     debugPrint('Error moving folder: $e');
//   }
// }

Future<String> saveImageToAppStorage(File originalImage, String report) async {
  final Directory directory = await getApplicationDocumentsDirectory();
  String targetDirPath = '${directory.path}/$report/';

  final Directory targetFolder = Directory(targetDirPath);
  if (!await targetFolder.exists()) {
    await targetFolder.create(recursive: true);
  }

  final random = Random();
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  final randomSuffix = random.nextInt(1 << 32).toRadixString(16);
  String fileName = '${timestamp}_$randomSuffix.jpg';
  String newPath = targetFolder.path + fileName;

  while (await File(newPath).exists()) {
    final retrySuffix = random.nextInt(1 << 32).toRadixString(16);
    fileName = '${DateTime.now().microsecondsSinceEpoch}_$retrySuffix.jpg';
    newPath = targetFolder.path + fileName;
  }

  try {
    final File newFile = await originalImage.copy(newPath);
    debugPrint("Image saved to app directory: $newPath");
    return newFile.path;
  } catch (e) {
    debugPrint('Unable to save image to app directory: $e');
    return '';
  }
}
