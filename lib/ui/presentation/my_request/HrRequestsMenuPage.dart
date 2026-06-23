import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/my_request/RequestEffectiveDate.dart';
import 'package:el_race/ui/presentation/my_request/RequestJobMissionPage.dart';
import 'package:el_race/ui/presentation/my_request/RequestLeavePageNew.dart';
import 'package:el_race/ui/presentation/my_request/RequestPermission.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class HrRequestsMenuPage extends StatelessWidget {
  const HrRequestsMenuPage({super.key});

  Widget _pillButton({
    required BuildContext context,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          margin: EdgeInsets.symmetric(horizontal: 24.w),
          padding: EdgeInsets.symmetric(vertical: 20.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFDDE1E7), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.2,
              color: const Color(0xFF1A1A53),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final login = SharedPref.getLoginData();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const HeaderWidget(),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                SizedBox(height: 5.h),
                Text(
                  'HR REQUESTS',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 2.0,
                    color: appFontColor,
                  ),
                ),
                SizedBox(height: 20.h),
                _pillButton(
                  context: context,
                  label: 'Sick Leave',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RequestLeavePageNew(
                            loginResponseModel: login,
                            leaveType: 'SICK',
                          ),
                        ),
                      );
                  },
                ),
                _pillButton(
                  context: context,
                  label: 'Short Leave',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RequestLeavePageNew(
                            loginResponseModel: login,
                            leaveType: 'SHORT',
                          ),
                        ),
                      );
                  },
                ),
                _pillButton(
                  context: context,
                  label: 'Annual Leave',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RequestLeavePageNew(
                            loginResponseModel: login,
                            leaveType: 'ANNUAL',
                          ),
                        ),
                      );
                  },
                ),
                _pillButton(
                  context: context,
                  label: 'Effective Date',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EffectiveDatePage(
                            loginResponseModel: login,
                          ),
                        ),
                      );
                  },
                ),
                _pillButton(
                  context: context,
                  label: 'Temporary Per',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RequestPermission(
                            loginResponseModel: login,
                          ),
                        ),
                      );
                  },
                ),
                _pillButton(
                  context: context,
                  label: 'Job Mission',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RequestJobMissionPage(
                            loginResponseModel: login,
                          ),
                        ),
                      );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
