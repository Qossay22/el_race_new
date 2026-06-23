import 'package:flutter/material.dart';

class ConstrainedScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? drawer;
  final Color? color;

  const ConstrainedScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.drawer,
    this.color,
    required Color backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      drawer: drawer,
      backgroundColor: color,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: body,
        ),
      ),
    );
  }
}
