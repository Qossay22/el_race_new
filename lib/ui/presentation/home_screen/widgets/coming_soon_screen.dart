import 'package:el_race/ui/presentation/home_screen/bloc/home_bloc.dart';
import 'package:el_race/ui/presentation/home_screen/screens/home_screen.dart';
import 'package:el_race/utils/Util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.construction,
                color: const Color(0xFF1A1A53),
                size: 100.sp,
              ),
              SizedBox(height: 30.h),
              Text(
                "Coming Soon",
                style:
                    TextStyle(fontSize: 40.sp, color: const Color(0xFF1A1A53)),
              ),
              SizedBox(height: 15.h),
              Text(
                "We're working hard to bring you this feature. Stay tuned!",
                style:
                    TextStyle(fontSize: 20.sp, color: const Color(0xFF1A1A53)),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40.h),
              TextButton(
                onPressed: () {
                  HomeBloc.get(context).add(const ChangeCurrentIndex(index: 1));
                  Util.pushPageAndRemoveRoutes(const HomeScreen(), context);
                },
                child: Text(
                  "Go To Home >> ",
                  style: TextStyle(
                      fontSize: 20.sp,
                      color: const Color(0xFF1A1A53),
                      decoration: TextDecoration.underline),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
