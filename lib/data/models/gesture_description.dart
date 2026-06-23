import 'package:flutter/material.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';

class GestureDescription {
  final IconData icon;
  final String title;
  final String step;
  final RxString? statusKey;

  GestureDescription({
    required this.icon,
    required this.title,
    required this.step,
    this.statusKey,
  });
}
