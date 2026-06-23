import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AttendanceReportItem extends StatelessWidget {
  final String title;
  final String value;
  final Color dotColor;
  const AttendanceReportItem({super.key, required this.title, required this.value, required this.dotColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          Text(value,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}