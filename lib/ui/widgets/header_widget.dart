import 'dart:convert';

import 'package:el_race/core/services/approval_count_service.dart';
import 'package:el_race/core/services/approval_viewed_service.dart';
import 'package:el_race/core/services/notification_storage_service.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/providers/profile_box_provider.dart';
import 'package:el_race/ui/presentation/Email Approval/Approval.dart';
import 'package:el_race/ui/presentation/Notification/notification_screen.dart';
import 'package:el_race/ui/presentation/search/screens/widget_search_screen.dart';
import 'package:el_race/ui/presentation/signin/sign_in_screen.dart';
import 'package:el_race/ui/widgets/global_search_screen.dart';
import 'package:el_race/utils/Util.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:el_race/utils/custom_navigate.dart';
import 'package:el_race/utils/orientation_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../presentation/home_screen/bloc/home_bloc.dart';

class HeaderWidget extends StatefulWidget implements PreferredSizeWidget {
  const HeaderWidget({super.key, this.hidden = true});

  final bool hidden;

  @override
  State<HeaderWidget> createState() => _HeaderWidgetState();

  @override
  Size get preferredSize => Size.fromHeight(SizeConfig().getHeight(70));
}

class _HeaderWidgetState extends State<HeaderWidget>
    with WidgetsBindingObserver {
  static String _cachedImageBase64 = '';
  static int _cachedNotificationCount = 0;
  static int _cachedApprovalCount = 0;

  String _imageBase64 = '';
  int _notificationCount = 0;
  int _approvalCount = 0;

  bool _isOpeningApprovals = false;
  bool _isOpeningNotifications = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _imageBase64 = _cachedImageBase64;
    _notificationCount = _cachedNotificationCount;
    _approvalCount = _cachedApprovalCount;

    _loadUserData();
    _loadNotificationCount();
    ApprovalCountService.invalidateCache();
    _loadApprovalCount();

    // Register callback to update approval count when items are viewed
    ApprovalViewedService.setOnCountChangedCallback(() {
      if (mounted) {
        _loadApprovalCount();
      }
    });

    // Register callback for approval count changes (approve/reject actions)
    ApprovalCountService.onCountChanged = () {
      if (mounted) {
        _loadApprovalCount();
      }
    };

    // Register callback for notification count changes
    // Use fast local count (no API call) to avoid race condition
    // where the API hasn't indexed the new notification yet.
    NotificationStorageService.onCountChanged = () {
      if (mounted) {
        _loadNotificationCountLocal();
      }
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Unregister callbacks
    ApprovalViewedService.setOnCountChangedCallback(null);
    ApprovalCountService.onCountChanged = null;
    NotificationStorageService.onCountChanged = null;
    super.dispose();
  }

  Future<void> _refreshCounters() async {
    ApprovalCountService.invalidateCache();
    await Future.wait([
      _loadNotificationCount(),
      _loadApprovalCount(),
    ]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshCounters();
    }
  }

  Future<void> _loadUserData() async {
    if (!SharedPref.isUserAuthenticated()) return;
    final data = SharedPref.getLoginData();
    _imageBase64 = data.result?.data?.image_url ?? '';
    _cachedImageBase64 = _imageBase64;
  }

  Future<void> _loadNotificationCount() async {
    final count = await NotificationStorageService.getTotalCount();
    if (mounted) {
      setState(() {
        _notificationCount = count;
        _cachedNotificationCount = count;
      });
    }
  }

  /// Fast local badge update — reads cached count from SharedPreferences
  /// without making an API call. Used by the [onCountChanged] callback
  /// so the badge updates instantly after a push notification is saved.
  Future<void> _loadNotificationCountLocal() async {
    final count = await NotificationStorageService.getLocalStoredCount();
    if (mounted) {
      setState(() {
        _notificationCount = count;
        _cachedNotificationCount = count;
      });
    }
  }

  Future<void> _loadApprovalCount() async {
    print('🔄 Loading approval count...');
    final count = await ApprovalCountService.getTotalApprovalCount();
    print('   - Count received: $count');
    if (mounted) {
      setState(() {
        _approvalCount = count;
        _cachedApprovalCount = count;
        print('   - ✅ State updated with count: $count');
      });
    } else {
      print('   - ⚠️ Widget not mounted, cannot update state');
    }
  }

  bool _isValidBase64(String str) {
    try {
      if (str.trim().isEmpty || str.length % 4 != 0) return false;
      base64Decode(str);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get profile image - handles both base64 and URL formats
  Widget _getProfileImage(String imageData) {
    if (imageData.isEmpty) {
      return Image.asset(
        'assets/png/profile_1.png',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    // Check if it's a URL (starts with http:// or https://)
    if (imageData.startsWith('http://') || imageData.startsWith('https://')) {
      return Image.network(
        imageData,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/png/profile_1.png',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }

    // Check if it's valid base64
    if (_isValidBase64(imageData)) {
      try {
        return Image.memory(
          base64Decode(imageData),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      } catch (_) {
        // Fall through to default
      }
    }

    // Default fallback
    return Image.asset(
      'assets/png/profile_1.png',
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }

  @override
  Widget build(BuildContext context) {
    var bloc = HomeBloc.get(context);
    return AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: true,
        elevation: 0,
        toolbarHeight: SizeConfig().getHeight(100),
        flexibleSpace: Container(
          padding: EdgeInsets.zero,
          width: ScreenUtil().screenWidth,
          height: SizeConfig().getHeight(115),
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/png/header_bg.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: SizeConfig().getWidth(15), vertical: 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          // Navigate to home screen from anywhere
                          // First pop all pushed routes back to the home screen
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                          // Then reset to the main home tab
                          final bloc = HomeBloc.get(context);
                          bloc.add(ChangeCurrentIndex(index: 1));
                        },
                        child: Image.asset(
                          'assets/gif/el-race-logo.gif',
                          fit: BoxFit.cover,
                          height: SizeConfig().getHeight(55),
                          width: SizeConfig().getWidth(110),
                        ),
                      ),
                      Row(
                        children: [
                          // Global Search Icon (New)
                          GestureDetector(
                            onTap: () {
                              if (SharedPref.isUserAuthenticated()) {
                                // Check current route to prevent stacking search screens
                                final currentRoute = ModalRoute.of(context);
                                final currentRouteName =
                                    currentRoute?.settings.name;

                                // Don't navigate if already on Global Search screen
                                if (currentRouteName == '/global_search') {
                                  return;
                                }

                                Navigator.push(
                                  context,
                                  SlideRightPageRoute(
                                    child: const GlobalSearchScreen(),
                                    settings: const RouteSettings(
                                        name: '/global_search'),
                                  ),
                                );
                              }
                            },
                            child: Icon(
                              Icons.search,
                              size: 28,
                              color: Colors.black.withOpacity(0.7),
                            ),
                          ),

                          SizedBox(width: SizeConfig().getWidth(10)),
                          // Old Search Icon (hidden by flag)
                          widget.hidden
                              ? const SizedBox.shrink()
                              : GestureDetector(
                                  onTap: () {
                                    if (SharedPref.isUserAuthenticated()) {
                                      Navigator.push(
                                        context,
                                        SlideRightPageRoute(
                                          child: const WidgetSearchScreen(),
                                        ),
                                      );
                                    }
                                  },
                                  child: SizedBox(
                                    width: 30,
                                    height: 30,
                                    child: Icon(
                                      Icons.search,
                                      size: 28,
                                      color: Colors.black.withOpacity(0.7),
                                    ),
                                  ),
                                ),
                          widget.hidden
                              ? const SizedBox.shrink()
                              : SizedBox(width: SizeConfig().getWidth(10)),
                          GestureDetector(
                            onTap: () async {
                              if (SharedPref.isUserAuthenticated()) {
                                if (_isOpeningApprovals) return;
                                _isOpeningApprovals = true;

                                try {
                                  // Check current route by name
                                  final currentRoute = ModalRoute.of(context);
                                  final currentRouteName =
                                      currentRoute?.settings.name;

                                  // Don't navigate if already on Approvals page
                                  if (currentRouteName == '/approvals') {
                                    return;
                                  }

                                  // If on Notifications, replace it; otherwise push
                                  if (currentRouteName == '/notifications') {
                                    await Navigator.pushReplacement(
                                      context,
                                      SlideRightPageRoute(
                                        child: const ApprovalsScreen(),
                                        settings: const RouteSettings(
                                            name: '/approvals'),
                                      ),
                                    );
                                  } else {
                                    await Navigator.push(
                                      context,
                                      SlideRightPageRoute(
                                        child: const ApprovalsScreen(),
                                        settings: const RouteSettings(
                                            name: '/approvals'),
                                      ),
                                    );
                                  }

                                  // Keep badge synced with real approvals after returning.
                                  await _loadApprovalCount();
                                } finally {
                                  _isOpeningApprovals = false;
                                }
                              }
                            },
                            child: Stack(
                              alignment: Alignment.topRight,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Image.asset(
                                    'assets/png/approval_icon.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                // Badge for approval count
                                if (_approvalCount > 0)
                                  Positioned(
                                    right: 0,
                                    top: -2,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      constraints: const BoxConstraints(
                                        minWidth: 16,
                                        minHeight: 16,
                                      ),
                                      decoration: const BoxDecoration(
                                        color: red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        _approvalCount > 99
                                            ? '99+'
                                            : _approvalCount.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(width: SizeConfig().getWidth(10)),
                          GestureDetector(
                            onTap: () async {
                              print('🔔 [HEADER] Notification bell tapped');
                              print(
                                  '   - User authenticated: ${SharedPref.isUserAuthenticated()}');

                              if (SharedPref.isUserAuthenticated()) {
                                if (_isOpeningNotifications) return;
                                _isOpeningNotifications = true;

                                try {
                                  // Check current route by name
                                  final currentRoute = ModalRoute.of(context);
                                  final currentRouteName =
                                      currentRoute?.settings.name;

                                  // Don't navigate if already on Notifications page
                                  if (currentRouteName == '/notifications') {
                                    print(
                                        '   - ⚠️ Already on notifications screen, ignoring tap');
                                    return;
                                  }

                                  print(
                                      '   - ✅ Opening notification screen...');

                                  // If on Approvals, replace it; otherwise push
                                  if (currentRouteName == '/approvals') {
                                    await Navigator.pushReplacement(
                                      context,
                                      SlideRightPageRoute(
                                        child: const NotificationScreen(),
                                        settings: const RouteSettings(
                                            name: '/notifications'),
                                      ),
                                    );
                                  } else {
                                    await Navigator.push(
                                      context,
                                      SlideRightPageRoute(
                                        child: const NotificationScreen(),
                                        settings: const RouteSettings(
                                            name: '/notifications'),
                                      ),
                                    );
                                  }

                                  print(
                                      '   - ✅ Returned from notification screen');
                                  // Refresh notification count after returning
                                  _loadNotificationCount();
                                } finally {
                                  _isOpeningNotifications = false;
                                }
                              } else {
                                print('   - ❌ User not authenticated');
                              }
                            },
                            child: Stack(
                              alignment: Alignment.topRight,
                              children: [
                                SizedBox(
                                  width: 30,
                                  height: 30,
                                  child: Image.asset(
                                    'assets/png/bell_image.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  top: -2,
                                  child: _notificationCount > 0
                                      ? Container(
                                          padding: const EdgeInsets.all(3),
                                          constraints: const BoxConstraints(
                                            minWidth: 16,
                                            minHeight: 16,
                                          ),
                                          decoration: const BoxDecoration(
                                            color: red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            _notificationCount > 99
                                                ? '99+'
                                                : _notificationCount.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: SizeConfig().getWidth(15)),
                          GestureDetector(
                            onTap: () {
                              if (!SharedPref.isUserAuthenticated()) {
                                Util.pushPage(const SignInScreen(), context);
                                return;
                              }
                              Provider.of<ProfileBoxProvider>(context,
                                      listen: false)
                                  .toggleProfileBox();
                            },
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: ClipOval(
                                child: _getProfileImage(_imageBase64),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }
}
