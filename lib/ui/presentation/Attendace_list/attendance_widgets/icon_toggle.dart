// import 'package:flutter/cupertino.dart';

// class BouncingIconToggle extends StatefulWidget {
//   final IconData icon;
//   final bool isExpanded;
//   final ValueChanged<bool> onToggle;

//   const BouncingIconToggle({
//     Key? key,
//     required this.icon,
//     required this.isExpanded,
//     required this.onToggle,
//   }) : super(key: key);

//   @override
//   State<BouncingIconToggle> createState() => _BouncingIconToggleState();
// }

// class _BouncingIconToggleState extends State<BouncingIconToggle>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   late Animation<double> _offsetAnimation;

//   @override
//   void initState() {
//     super.initState();

//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 300),
//     );

//     _setAnimation();
//   }

//   void _setAnimation() {
//     const double bounceAmount = 10; // how far it bounces
//     final double start = widget.isExpanded ? 0.0 : 0.0;
//     final double peak =
//         widget.isExpanded ? -bounceAmount : bounceAmount; // direction
//     final double end = widget.isExpanded ? bounceAmount : -bounceAmount;

//     _offsetAnimation = TweenSequence([
//       TweenSequenceItem(
//         tween: Tween(begin: start, end: peak)
//             .chain(CurveTween(curve: Curves.easeOut)),
//         weight: 40,
//       ),
//       TweenSequenceItem(
//         tween: Tween(begin: peak, end: end)
//             .chain(CurveTween(curve: Curves.easeInOut)),
//         weight: 60,
//       ),
//     ]).animate(_controller);
//   }

//   void _handleTap() {
//     _setAnimation();
//     _controller.forward(from: 0).whenComplete(() {
//       widget.onToggle(!widget.isExpanded);
//     });
//   }

//   @override
//   void didUpdateWidget(covariant BouncingIconToggle oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     _setAnimation();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: _handleTap,
//       child: AnimatedBuilder(
//         animation: _offsetAnimation,
//         builder: (context, child) {
//           return Transform.translate(
//             offset: Offset(_offsetAnimation.value, 0),
//             child: Icon(widget.icon, size: 28),
//           );
//         },
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }
// }
