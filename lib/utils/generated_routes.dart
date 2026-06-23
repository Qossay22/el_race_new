import 'package:el_race/ui/presentation/landing_screen/landing_screen.dart';
import 'package:el_race/ui/presentation/signin/bloc/sign_in_bloc.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:el_race/ui/presentation/signin/sign_in_screen.dart';
import 'package:el_race/ui/presentation/splash_screen/splash_screen.dart';
import 'package:el_race/utils/di.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:el_race/ui/presentation/home_screen/screens/home_screen.dart';
import 'package:el_race/ui/presentation/qr_code/qr_code_screen.dart';

import '../ui/presentation/call_screen/bloc/contact_bloc.dart';
import '../ui/presentation/call_screen/call_screen.dart';
// Import additional screens for notification navigation
import '../ui/presentation/my_projects/presentation/screens/my_project.dart';
import '../ui/presentation/PettyCash/PettyCashScreen.dart';
import '../ui/presentation/media/screens/media_list_screen.dart';
import '../ui/presentation/my_notes/screens/my_notes_screen.dart';
import '../ui/presentation/my_request/MyRequestsPage.dart';
import '../ui/presentation/task_sheet/task_sheet_screen.dart';
import '../ui/presentation/Attendace_list/attendance_page.dart';
import '../ui/presentation/News Banner/news_screen.dart';
import '../ui/presentation/tasks_dashboard/screens/task_details.dart';
import '../ui/presentation/Email Approval/delayed/screens/delayed_requests_screen.dart';

class OnGeneratedRoutes {
  Route<dynamic> generatedRoutes(RouteSettings settings) {
    final signInBloc = sl.get<SignInBloc>();
    final contactBloc = sl.get<ContactBloc>();
    switch (settings.name) {
      case '/':
        return CupertinoPageRoute(builder: (_) => const SplashScreen());
      case '/signIN':
        Future.delayed(const Duration(milliseconds: 500), () {
          signInBloc.add(CheckSignedIn());
        });
        return CupertinoPageRoute(builder: (_) => const SignInScreen());
      case '/landing':
        return CupertinoPageRoute(
            builder: (_) => LandingScreen(
                  loginResponseModel: settings.arguments! as LoginResponseModel,
                ));
      case '/home':
        return CupertinoPageRoute(
          builder: (_) => const HomeScreen(), // Pass the argument),
        );
      case '/contact':
        Future.delayed(const Duration(milliseconds: 500), () {
          contactBloc.add(GetEmployeeLisET());
        });
        return CupertinoPageRoute(builder: (_) => const CallScreen());
      case '/qr_code':
        return CupertinoPageRoute(builder: (_) => const QrCodeScreen());

      // Additional routes for notification navigation
      case '/my_projects':
        return CupertinoPageRoute(builder: (_) => const MyProject());
      case '/petty_cash':
        return CupertinoPageRoute(builder: (_) => const PettyCashScreen());
      case '/media':
        return CupertinoPageRoute(builder: (_) => const MediaListScreen());
      case '/my_notes':
        return CupertinoPageRoute(builder: (_) => const MyNotesScreen());
      case '/my_requests':
        return CupertinoPageRoute(builder: (_) => const MyRequestsPage());
      case '/tasks':
        return CupertinoPageRoute(builder: (_) => const TaskSheetPage());
      case '/attendance':
        return CupertinoPageRoute(builder: (_) => const AttendancePage());
      case '/news':
        return CupertinoPageRoute(builder: (_) => const NewsScreen());
      case '/task-details':
        return CupertinoPageRoute(builder: (_) => TaskDetailsScreen());
      case '/delayed_requests':
        return CupertinoPageRoute(builder: (_) => const DelayedRequestsScreen());
    }
    return MaterialPageRoute(
        builder: (_) => Scaffold(
            body:
                Center(child: Text('No route defined for ${settings.name}'))));
  }
}
