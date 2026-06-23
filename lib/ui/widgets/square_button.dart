import 'package:flutter/cupertino.dart';

class SquareButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color borderColor;
  final VoidCallback onPressed;
  const SquareButton(
      {super.key,
      required this.icon,
      required this.color,
      required this.borderColor,
      required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        height: 42,
        width: 42,
        decoration: BoxDecoration(
            color: color,
            border: Border.all(color: borderColor.withValues(alpha: .3)),
            borderRadius: BorderRadius.circular(12)),
        child: Center(
          child: Icon(
            icon,
            // "assets/pngs/$icon.png",
            size: 24,
            color: borderColor,
            // width: 24,
          ),
        ),
      ),
    );
  }
}
