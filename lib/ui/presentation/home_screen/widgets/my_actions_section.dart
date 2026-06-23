import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:el_race/ui/presentation/my_actions/screens/hr_screen.dart';
import 'package:el_race/ui/presentation/my_actions/screens/my_requests_screen.dart';
import 'package:el_race/ui/presentation/my_actions/screens/rfq_screen.dart';
import 'package:el_race/ui/presentation/my_actions/screens/petty_cash_my_action_screen.dart';
import 'package:el_race/ui/presentation/my_actions/screens/invoice_my_actions_screen.dart';
import 'package:el_race/ui/presentation/my_actions/screens/signatures_screen.dart';
import 'package:el_race/ui/presentation/my_actions/screens/reports_screen.dart';
import 'package:el_race/ui/presentation/my_actions/screens/timesheet_screen.dart';
import 'package:el_race/utils/custom_navigate.dart';

class MyActionsSection extends StatelessWidget {
  const MyActionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 26.w),
          child: Text(
            'ACTIONS',
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF484848),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        SizedBox(
          height: 100.h,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            children: [
              SizedBox(width: 20.w),
              _MyActionTile(
                iconAsset: 'assets/newapp/newicon/hr.png',
                label: 'HR',
                onTap: () {
                  Navigator.push(
                    context,
                    SlideRightPageRoute(
                      child: const HrScreen(),
                      settings: const RouteSettings(name: '/hr'),
                    ),
                  );
                },
              ),
              SizedBox(width: 12.w),
              _MyActionTile(
                iconAsset: 'assets/newapp/newicon/rfq.png',
                label: 'RFQ',
                onTap: () {
                  Navigator.push(
                    context,
                    SlideRightPageRoute(
                      child: const RfqScreen(),
                      settings: const RouteSettings(name: '/rfq'),
                    ),
                  );
                },
              ),
              SizedBox(width: 12.w),
              _MyActionTile(
                iconAsset: 'assets/newapp/newicon/Cash.png',
                label: 'Petty Cash',
                onTap: () {
                  Navigator.push(
                    context,
                    SlideRightPageRoute(
                      child: const PettyCashMyActionScreen(),
                      settings:
                          const RouteSettings(name: '/petty_cash_my_actions'),
                    ),
                  );
                },
              ),
              SizedBox(width: 12.w),
              _MyActionTile(
                iconAsset: 'assets/newapp/newicon/Invoice.png',
                label: 'invoice',
                onTap: () {
                  Navigator.push(
                    context,
                    SlideRightPageRoute(
                      child: const InvoiceMyActionsScreen(),
                      settings:
                          const RouteSettings(name: '/invoice_my_actions'),
                    ),
                  );
                },
              ),
              SizedBox(width: 12.w),
              _MyActionTile(
                iconAsset: 'assets/png/signarute-frame.png',
                label: 'Signature',
                onTap: () {
                  Navigator.push(
                    context,
                    SlideRightPageRoute(
                      child: const SignaturesScreen(),
                      settings: const RouteSettings(name: '/signatures'),
                    ),
                  );
                },
              ),
              SizedBox(width: 12.w),
              _MyActionTile(
                iconAsset: 'assets/png/my-reports-frame.png',
                label: 'My Reports',
                onTap: () {
                  Navigator.push(
                    context,
                    SlideRightPageRoute(
                      child: const ReportsScreen(),
                      settings: const RouteSettings(name: '/reports'),
                    ),
                  );
                },
              ),
              SizedBox(width: 12.w),
              _MyActionTile(
                iconAsset: 'assets/png/time-sheet-frame.png',
                label: 'Timesheets',
                onTap: () {
                  Navigator.push(
                    context,
                    SlideRightPageRoute(
                      child: const TimesheetScreen(),
                      settings: const RouteSettings(name: '/timesheet'),
                    ),
                  );
                },
              ),
              SizedBox(width: 12.w),
              _MyActionTile(
                iconAsset: 'assets/newapp/newicon/my_action_my_request.png',
                label: 'My Requests',
                onTap: () {
                  Navigator.push(
                    context,
                    SlideRightPageRoute(
                      child: const MyRequestsScreen(),
                      settings: const RouteSettings(name: '/my_requests'),
                    ),
                  );
                },
              ),
              SizedBox(width: 20.w),
            ],
          ),
        ),
      ],
    );
  }
}

class _MyActionTile extends StatelessWidget {
  final String iconAsset;
  final String label;
  final VoidCallback? onTap;

  const _MyActionTile({
    required this.iconAsset,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(18.r);

    return InkWell(
      borderRadius: borderRadius,
      onTap: onTap,
      child: SizedBox(
        width: 78.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62.w,
              height: 62.w,
              decoration: BoxDecoration(
                color: const Color(0xFFD9D9D9),
                borderRadius: borderRadius,
                border: Border.all(
                  color: const Color(0xFF8E9099),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Image.asset(
                iconAsset,
                width: 32.w,
                height: 32.w,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: const Color(0xFF9AA0A6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
