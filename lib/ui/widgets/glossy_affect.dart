import 'package:flutter/cupertino.dart';

class CardShinyClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(size.width, 0.0);
    path.lineTo(size.width, size.height / 10);
    path.lineTo(size.width / 10, size.height);
    path.lineTo(0.0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CardShinyClipper oldClipper) => false;
}
