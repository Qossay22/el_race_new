import 'package:flutter/material.dart';

class NotificationCategoryModel {
  final String model;
  final String title;
  final IconData icon;
  final Color color;
  final bool muted;

  const NotificationCategoryModel({
    required this.model,
    required this.title,
    required this.icon,
    required this.color,
    required this.muted,
  });

  NotificationCategoryModel copyWith({
    String? model,
    String? title,
    IconData? icon,
    Color? color,
    bool? muted,
  }) {
    return NotificationCategoryModel(
      model: model ?? this.model,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      muted: muted ?? this.muted,
    );
  }
}
