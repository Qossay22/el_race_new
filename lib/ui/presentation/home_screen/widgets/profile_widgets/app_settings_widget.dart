import 'package:el_race/chat/chat.dart';
import 'package:el_race/core/services/notification_api_service.dart';
import 'package:el_race/core/services/notification_storage_service.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/data/services/checkin_reminder_notification_service.dart';
import 'package:el_race/data/services/hive_service.dart';
import 'package:el_race/auth/uaepass_auth_cubit.dart';
import 'package:el_race/ui/presentation/home_screen/bloc/home_bloc.dart';
import 'package:el_race/ui/presentation/home_screen/screens/home_screen.dart';
import 'package:el_race/ui/presentation/signin/sign_in_screen.dart';
import 'package:el_race/ui/presentation/qr_code/qr_scanner_screen.dart';
import 'package:el_race/providers/profile_box_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

class AppSettingsWidget extends StatelessWidget {
  static const bool _showLogoutButton = true;

  final GlobalKey<NavigatorState> navKey;
  final VoidCallback? onMuteControlTap;
  const AppSettingsWidget({
    super.key,
    required this.navKey,
    this.onMuteControlTap,
  });

  String _pickExistingKey(
    Map<String, bool> settings,
    List<String> candidates,
  ) {
    for (final candidate in candidates) {
      final key = candidate.trim().toLowerCase();
      if (settings.containsKey(key)) {
        return key;
      }
    }
    return candidates.first.trim().toLowerCase();
  }

  bool _isHiddenNotificationCategory(String model, {String? title}) {
    final normalizedModel =
        model.trim().toLowerCase().replaceAll(RegExp(r'[_\-.]+'), ' ');
    final normalizedTitle =
        (title ?? '').toLowerCase().replaceAll(RegExp(r'[_\-.]+'), ' ');
    final haystack = '$normalizedModel $normalizedTitle';
    return haystack.contains('check out') && haystack.contains('reminder');
  }

  Future<void> _showMuteControlPopup(BuildContext context) async {
    final results = await Future.wait([
      NotificationStorageService.getMuteSettings(),
      NotificationStorageService.getNotificationCategories(),
    ]);
    final dialogHostContext =
        navKey.currentState?.overlay?.context ?? navKey.currentContext;
    if (dialogHostContext == null) return;

    final settings = results[0] as Map<String, bool>;
    final apiCategories = results[1] as List<NotificationCategoryApiModel>;

    final channels = apiCategories
        .where((c) =>
            c.model.trim().isNotEmpty &&
            !_isHiddenNotificationCategory(c.model, title: c.title))
        .map(
          (c) => _MuteChannelItem(
            label: c.title.trim().isNotEmpty ? c.title : c.model,
            key: c.model.trim().toLowerCase(),
          ),
        )
        .toList(growable: false);

    final valueByKey = <String, bool>{
      for (final channel in channels)
        channel.key: settings[channel.key] == true,
    };

    await showDialog<void>(
      context: dialogHostContext,
      useRootNavigator: true,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        var isSaving = false;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> updateChannel(
                _MuteChannelItem item, bool value) async {
              final previous = valueByKey[item.key] ?? false;

              setDialogState(() {
                valueByKey[item.key] = value;
                isSaving = true;
              });

              try {
                await NotificationStorageService.setMuteSetting(
                    item.key, value);
              } catch (_) {
                setDialogState(() {
                  valueByKey[item.key] = previous;
                });

                final messenger = ScaffoldMessenger.maybeOf(dialogHostContext);
                messenger?.showSnackBar(
                  const SnackBar(
                    content: Text('Failed to update mute setting'),
                    backgroundColor: Color(0xffBA1719),
                  ),
                );
              } finally {
                setDialogState(() {
                  isSaving = false;
                });
              }
            }

            return Dialog(
              elevation: 0,
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 34),
              child: Container(
                padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 14.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F8),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final item in channels)
                      Padding(
                        padding: EdgeInsets.only(bottom: 10.h),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.label,
                                style: const TextStyle(
                                  color: Color(0xFF1D1F5A),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Transform.scale(
                              scale: 0.9,
                              child: Directionality(
                                textDirection: TextDirection.ltr,
                                child: Switch(
                                  value: !(valueByKey[item.key] ?? false),
                                  onChanged: isSaving
                                      ? null
                                      : (value) => updateChannel(item, !value),
                                  activeThumbColor: const Color(0xFF43A047),
                                  activeTrackColor: const Color(0xFFA5D6A7),
                                  inactiveThumbColor: const Color(0xFFE53935),
                                  inactiveTrackColor: const Color(0xFFEF9A9A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: 2.h),
                    SizedBox(
                      height: 32.h,
                      child: ElevatedButton.icon(
                        onPressed: isSaving
                            ? null
                            : () =>
                                Navigator.of(dialogContext, rootNavigator: true)
                                    .pop(),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: const Color(0xFF0FA25E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text(
                          'DONE',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        /*
        Container(
          margin: const EdgeInsets.only(top: 0),
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          color: Colors.grey.shade100,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.15 * 255).toInt()),
                      offset: const Offset(0, 1.68),
                      // blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Container(
                        width: 100.w,
                        height: 34.w,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: !SharedPref().isArabic()
                                ? [
                                    const Color(0xFF151544),
                                    const Color(0xFF3535AA)
                                  ] // لو مش عربي
                                : [Colors.white, Colors.grey[300]!], // لو عربي
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(20.3),
                        ),
                        child: ElevatedButton(
                          onPressed: () async {
                            final provider = Provider.of<ProfileBoxProvider>(
                                context,
                                listen: false);
                            if (provider.isProfileVisible) {
                              provider.hideProfileBox();
                            }
                            await Util.saveAndChangeLocale(context, 'en');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            //  backgroundColor: !SharedPref().isArabic()
                            //       ? appFontColor
                            //       : Colors.white,
                            minimumSize: const Size(100, 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20.3)),
                          ),
                          child: Text(translate('profile.english'),
                              style: TextStyle(
                                  color: !SharedPref().isArabic()
                                      ? Colors.white
                                      : Colors.black,
                                  fontSize: 10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 100.w,
                      height: 34.w,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20.3),
                      ),
                      child: ElevatedButton(
                        onPressed: () async {
                          final provider = Provider.of<ProfileBoxProvider>(
                              context,
                              listen: false);
                          if (provider.isProfileVisible) {
                            provider.hideProfileBox();
                          }
                          await Util.saveAndChangeLocale(context, 'ar');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SharedPref().isArabic()
                              ? appFontColor
                              : Colors.grey.shade200,
                          minimumSize: const Size(100, 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.3)),
                        ),
                        child: Text(translate('profile.arabic'),
                            style: TextStyle(
                                color: SharedPref().isArabic()
                                    ? Colors.white
                                    : Colors.black,
                                fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 2.w),
              // Container(
              //   height: 2,
              //   width: double.infinity,
              //   decoration: BoxDecoration(
              //     color: Colors.grey.shade300,
              //     // boxShadow: [
              //     //   BoxShadow(
              //     //     color: Colors.black.withAlpha(
              //     //         (0.15 * 255).toInt()),
              //     //     offset: const Offset(0, 2),
              //     //     blurRadius: 4,
              //     //   ),
              //     // ],
              //   ),
              // ),

              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.w),
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.15 * 255).toInt()),
                      offset: const Offset(0, 1.68),
                      //blurRadius: 4,
                    )
                  ],
                  color: Colors.white,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Image.asset('assets/png/notification_filled_icon.png'),
                    const SizedBox(width: 12),
                    Text(translate('profile.mute_notifications'),
                        style: GoogleFonts.poppins(fontSize: 11)),
                    const Spacer(),
                    Consumer<ProfileBoxProvider>(
                      builder: (context, provider, child) {
                        return SizedBox(
                          height: 10.57,
                          child: Transform.scale(
                            scale: 0.7, // تصغير الحجم
                            child: Switch(
                              value: provider.muteNotifications,
                              onChanged: (v) {
                                provider.setMuteNotifications(v);
                              },
                              activeColor: appFontColor,
                              activeTrackColor: const Color(
                                  0xffD9D9D9), // لون الخلفية لما يكون ON
                              inactiveThumbColor: const Color(
                                  0xff3E3C3C), // لون الزر لما يكون OFF
                              inactiveTrackColor: const Color(
                                  0xffD9D9D9), // لون الخلفية لما يكون OFF
                            ),
                          ),
                        );
                      },
                    )
                    // Switch.adaptive(
                    //   value: isMuted,
                    //   onChanged: (val) => _updateMuteStatus(val),
                    //   activeColor: const Color(0xFF1A1A53),
                    //   activeTrackColor: Colors.grey.shade400,
                    // ),
                  ],
                ),
              ),
              //🔹 Divider with shadow
              SizedBox(height: 2.w),

              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.w),
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.15 * 255).toInt()),
                      offset: const Offset(0, 1.68),
                      //blurRadius: 4,
                    )
                  ],
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      child: Image.asset('assets/png/dark_mode_icon.png'),
                    ),
                    const SizedBox(width: 22),
                    Text(translate('profile.dark_mode'),
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        */
        SizedBox(height: 40.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.08 * 255).toInt()),
                offset: const Offset(0, -2),
                blurRadius: 3,
              ),
              BoxShadow(
                color: Colors.black.withAlpha((0.12 * 255).toInt()),
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
          child: InkWell(
            onTap: onMuteControlTap ?? () => _showMuteControlPopup(context),
            child: Row(
              children: [
                Image.asset(
                  'assets/newapp/newicon/mute_notification.png',
                  width: 20,
                  height: 20,
                ),
                SizedBox(width: 10.w),
                Text(
                  'Mute Notifications',
                  style: TextStyle(
                    color: const Color(0xffBA1719),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showLogoutButton) ...[
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 12.w,
            ),
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.15 * 255).toInt()),
                  offset: const Offset(0, 1.68),
                  //blurRadius: 4,
                )
              ],
              borderRadius: const BorderRadius.only(
                bottomRight: Radius.circular(20),
              ),
              gradient: const LinearGradient(
                colors: [Color(0xFF999999), Color(0xFFFFFFFF)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Image.asset('assets/png/log_out_icon.png'),
                SizedBox(
                  width: 25.w,
                ),
                TextButton(
                  onPressed: () async {
                    // print('🚪 Logout button pressed');

                    // Hide profile box first (before showing dialog)
                    final provider =
                        Provider.of<ProfileBoxProvider>(context, listen: false);
                    if (provider.isProfileVisible) {
                      provider.hideProfileBox();
                    }

                    // Wait a bit for the animation to complete
                    await Future.delayed(const Duration(milliseconds: 300));

                    // Use navKey.currentContext if available, otherwise fallback to context
                    final dialogContext = navKey.currentContext ?? context;

                    // Show confirmation dialog
                    final shouldLogout = await showDialog<bool>(
                      context: dialogContext,
                      barrierDismissible: false,
                      builder: (ctx) => AlertDialog(
                        title: Text(
                          translate('profile.logout_confirmation_title'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        content: Text(
                            translate('profile.logout_confirmation_message')),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: Text(
                              translate('common.cancel'),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xffBA1719),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              translate('profile.logout'),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    );

                    // If user confirmed, proceed with logout
                    if (shouldLogout == true) {
                      // Show loading dialog
                      final loadingContext = navKey.currentContext ?? context;
                      showDialog(
                        context: loadingContext,
                        barrierDismissible: false,
                        builder: (ctx) => const PopScope(
                          canPop: false,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xffBA1719),
                            ),
                          ),
                        ),
                      );

                      try {
                        // Cleanup chat module (Firebase signout, FCM unsubscribe, etc.)
                        // print('🧹 Cleaning up chat module...');
                        try {
                          await ChatModuleHelper.instance.cleanup().timeout(
                                const Duration(seconds: 5),
                              );
                          // print('✅ Chat module cleaned up');
                        } catch (e) {
                          // print('⚠️ Chat cleanup failed (continuing): $e');
                        }

                        // Clear UAE PASS session
                        try {
                          await context
                              .read<UaepassAuthCubit>()
                              .logout()
                              .timeout(
                                const Duration(seconds: 5),
                              );
                        } catch (e) {
                          // print('⚠️ UAE Pass logout failed (continuing): $e');
                        }

                        // إلغاء إشعارات التذكير بـ check in/out عند تسجيل الخروج
                        try {
                          await CheckInReminderNotificationService()
                              .cancelAllReminders();
                          // print('✅ Check-in/out reminders cancelled');
                        } catch (e) {
                          // print('⚠️ Failed to cancel reminders (continuing): $e');
                        }

                        // Clear user preferences
                        // print('🧹 Clearing preferences...');
                        await SharedPref().clearPreferences();
                        // Update login state in Hive for background service
                        await HiveService.setUserLoggedIn(false);
                        // print('✅ Preferences cleared');
                      } catch (e) {
                        // print('❌ Logout error: $e');
                      } finally {
                        // Reset bottom navigation to Home for the next session.
                        try {
                          context
                              .read<HomeBloc>()
                              .add(const ChangeCurrentIndex(index: 1));
                        } catch (e) {
                          // print('⚠️ Failed to reset HomeBloc index on logout: $e');
                        }

                        // Reset biometric session flag so next login prompts again
                        HomeScreenPage.resetAuthSession();

                        // Always navigate to sign in, even if some cleanup failed
                        // print('🧭 Navigating to sign in...');
                        final navContext = navKey.currentContext ?? context;
                        Navigator.pushAndRemoveUntil(
                          navContext,
                          MaterialPageRoute(
                              builder: (context) => const SignInScreen()),
                          (route) => false,
                        );
                        // print('✅ Navigation completed');
                      }
                    }
                  },
                  child: Text(translate('profile.logout'),
                      style: const TextStyle(
                          color: Color(0xffBA1719),
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MuteChannelItem {
  final String label;
  final String key;

  const _MuteChannelItem({
    required this.label,
    required this.key,
  });
}
