import 'package:flutter/material.dart';

class TitleBarWithIconAndBackWidget extends StatelessWidget {
  const TitleBarWithIconAndBackWidget({super.key, this.title});

  final String? title;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 369,
          height: 40,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(
                width: 20,
              ),
              SizedBox(
                width: 20,
                height: 20,
                child: Image.asset('assets/png/back_icon.png'),
              ),
              const Spacer(),
              Text(
                title ?? "",
                style: const TextStyle(
                  color: Color(0xFF002E6B),
                  fontSize: 16,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              // Container(
              //   padding: const EdgeInsets.all(12),
              //   clipBehavior: Clip.antiAlias,
              //   decoration: ShapeDecoration(
              //     color: const Color(0xFF1A1A53),
              //     shape: RoundedRectangleBorder(
              //       side:
              //           const BorderSide(width: 0.73, color: Color(0xFF1A1A53)),
              //       borderRadius: BorderRadius.circular(23.81),
              //     ),
              //     shadows: const [
              //       BoxShadow(
              //         color: Color(0x3F000000),
              //         blurRadius: 5.50,
              //         offset: Offset(0, 5.50),
              //         spreadRadius: 0,
              //       )
              //     ],
              //   ),
              //   child: Row(
              //     mainAxisSize: MainAxisSize.min,
              //     mainAxisAlignment: MainAxisAlignment.center,
              //     crossAxisAlignment: CrossAxisAlignment.center,
              //     children: [
              //       Container(
              //         width: 14.55,
              //         height: 14.55,
              //         clipBehavior: Clip.antiAlias,
              //         decoration: const BoxDecoration(),
              //         child: Image.asset('assets/png/back_icon.png'),
              //       ),
              //     ],
              //   ),
              // ),
              const SizedBox(
                width: 20,
              )
            ],
          ),
        ),
      ],
    );
  }
}
