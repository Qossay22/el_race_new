import 'package:flutter/material.dart';
import 'package:get/get.dart';

class InstructionViewController extends GetxController {
  var data = Get.arguments;

  final Map<String, IconData> instructionIcons = {
    "Make sure your face is clearly visible": Icons.face_retouching_natural,
    "Look straight into the camera": Icons.center_focus_strong_rounded,
    "Ensure proper lighting": Icons.wb_sunny_rounded,
    "Remove any face covering": Icons.no_accounts_rounded,
    "Avoid blurry shots": Icons.blur_off_rounded,
  };

  final List<String> instructions = [
    "Make sure your face is clearly visible",
    "Look straight into the camera",
    "Ensure proper lighting",
    "Remove any face covering",
    "Avoid blurry shots",
  ];


}
