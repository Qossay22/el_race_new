import 'package:el_race/core/services/notification_storage_service.dart';
import 'package:el_race/data/services/hive_service.dart';
import 'package:el_race/data/services/prayer_notification_service.dart';
import 'package:el_race/ui/presentation/Notification/model/notification_category_listview_model.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationMuteSettingsScreen extends StatefulWidget {
  const NotificationMuteSettingsScreen({super.key});

  @override
  State<NotificationMuteSettingsScreen> createState() =>
      _NotificationMuteSettingsScreenState();
}

class _NotificationMuteSettingsScreenState
    extends State<NotificationMuteSettingsScreen> {
  static const List<String> _alwaysOnCategories = <String>[
    'circular',
    'announcement',
  ];

  static const Map<String, _CategoryUiMeta> _knownCategories = {
    'circular': _CategoryUiMeta(
      title: 'Circulars',
      icon: Icons.campaign_rounded,
      color: Color(0xFF455A64),
    ),
    'announcement': _CategoryUiMeta(
      title: 'Announcements',
      icon: Icons.announcement_rounded,
      color: Color(0xFF6A1B9A),
    ),
    'purchase.order': _CategoryUiMeta(
      title: 'Purchase Orders',
      icon: Icons.shopping_bag_rounded,
      color: Color(0xFF6D4C41),
    ),
    'hr.expense.sheet': _CategoryUiMeta(
      title: 'Expense Sheets',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFFC62828),
    ),
    'account.move': _CategoryUiMeta(
      title: 'Invoices',
      icon: Icons.receipt_long_rounded,
      color: Color(0xFF283593),
    ),
    'employee.requests': _CategoryUiMeta(
      title: 'Employee Requests',
      icon: Icons.badge_rounded,
      color: Color(0xFF00897B),
    ),
    'prayer': _CategoryUiMeta(
      title: 'Prayer Reminders',
      icon: Icons.mosque_rounded,
      color: Color(0xFF00695C),
    ),
    'hr.attendance': _CategoryUiMeta(
      title: 'Attendance',
      icon: Icons.access_time_filled_rounded,
      color: Color(0xFF2E7D32),
    ),
    'cloud.folder': _CategoryUiMeta(
      title: 'Shared Folders',
      icon: Icons.folder_shared_rounded,
      color: Color(0xFF0277BD),
    ),
    'alert': _CategoryUiMeta(
      title: 'Alerts',
      icon: Icons.warning_amber_rounded,
      color: Color(0xFFEF6C00),
    ),
    'weather': _CategoryUiMeta(
      title: 'Weather',
      icon: Icons.cloud_rounded,
      color: Color(0xFF0288D1),
    ),
    'chat_message': _CategoryUiMeta(
      title: 'Chat',
      icon: Icons.chat_bubble_rounded,
      color: Color(0xFF0097A7),
    ),
    'task': _CategoryUiMeta(
      title: 'Tasks',
      icon: Icons.task_alt_rounded,
      color: Color(0xFF5C6BC0),
    ),
    'adhan': _CategoryUiMeta(
      title: 'Adhan Sound',
      icon: Icons.volume_up_rounded,
      color: Color(0xFF2E7D32),
    ),
  };

  /// فئات محلية فقط (لا تأتي من الـ API) - تُضاف تلقائياً إلى قائمة الإعدادات.
  static const List<String> _localOnlyCategories = <String>[
    'chat_message',
    'task',
    'adhan',
  ];

  List<NotificationCategoryModel> _categories =
      const <NotificationCategoryModel>[];
  final Set<String> _savingModels = <String>{};
  bool _isLoading = true;
  bool _isBulkUpdating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  String _humanizeModel(String model) {
    final text = model.trim();
    if (text.isEmpty) return 'Notification';
    final parts = text
        .split(RegExp(r'[._-]'))
        .where((part) => part.trim().isNotEmpty)
        .map((part) => _capitalize(part.trim()))
        .toList(growable: false);

    if (parts.isEmpty) {
      return 'Notification';
    }
    return parts.join(' ');
  }

  NotificationCategoryModel _toCategoryModel(
    String model,
    bool muted, {
    String? apiTitle,
  }) {
    final key = model.trim().toLowerCase();
    final meta = _knownCategories[key];

    // Use API-provided title first, then hardcoded meta, then humanized model
    final title = (apiTitle != null && apiTitle.trim().isNotEmpty)
        ? apiTitle.trim()
        : meta?.title ?? _humanizeModel(key);

    return NotificationCategoryModel(
      model: key,
      title: title,
      icon: meta?.icon ?? Icons.notifications_active_rounded,
      color: meta?.color ?? const Color(0xFF1565C0),
      muted: muted,
    );
  }

  bool _isAlwaysOnCategory(String model) {
    final key = model.trim().toLowerCase();
    return _alwaysOnCategories.contains(key);
  }

  bool _isHiddenNotificationCategory(String model, {String? title}) {
    final normalizedModel =
        model.trim().toLowerCase().replaceAll(RegExp(r'[_\-.]+'), ' ');
    final normalizedTitle =
        (title ?? '').toLowerCase().replaceAll(RegExp(r'[_\-.]+'), ' ');
    final haystack = '$normalizedModel $normalizedTitle';
    return haystack.contains('check out') && haystack.contains('reminder');
  }

  Future<void> _loadSettings({bool forceRefresh = false}) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final settings = await NotificationStorageService.getMuteSettings(
        forceRefresh: forceRefresh,
      );

      final categories =
          await NotificationStorageService.getNotificationCategories(
        forceRefresh: forceRefresh,
      );

      // Build a map of API-provided titles keyed by normalized model
      final apiTitles = <String, String>{};
      final merged = <String, bool>{};
      for (final category in categories) {
        final key = category.model.trim().toLowerCase();
        if (key.isEmpty) continue;
        if (_isHiddenNotificationCategory(key, title: category.title)) {
          continue;
        }
        apiTitles[key] = category.title;
        if (_isAlwaysOnCategory(key)) continue;
        merged[key] = settings[key] ?? false;
      }
      for (final entry in settings.entries) {
        final key = entry.key.trim().toLowerCase();
        if (_isAlwaysOnCategory(key)) continue;
        if (_isHiddenNotificationCategory(key)) continue;
        merged[key] = entry.value;
      }

      // إضافة الفئات المحلية فقط (chat, task, adhan) التي لا تأتي من الـ API
      for (final localKey in _localOnlyCategories) {
        if (!merged.containsKey(localKey)) {
          if (localKey == 'adhan') {
            // مزامنة حالة كتم الأذان من Hive
            final adhanMuted = await HiveService.isPrayerSoundMuted();
            merged[localKey] = adhanMuted;
          } else {
            merged[localKey] = settings[localKey] ?? false;
          }
        }
      }

      final fixedCategoryModels = _alwaysOnCategories
          .map((model) => _toCategoryModel(model, false))
          .toList(growable: false);

      final dynamicCategoryModels = merged.entries
          .map((entry) => _toCategoryModel(
                entry.key,
                entry.value,
                apiTitle: apiTitles[entry.key],
              ))
          .toList(growable: false)
        ..sort((a, b) => a.title.compareTo(b.title));

      final categoryModels = <NotificationCategoryModel>[
        ...fixedCategoryModels,
        ...dynamicCategoryModels,
      ];

      if (!mounted) return;
      setState(() {
        _categories = categoryModels;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  int _mutedCount() {
    return _categories.where((category) => category.muted).length;
  }

  void _setCategoryMuted(String model, bool muted) {
    setState(() {
      _categories = _categories
          .map((category) => category.model == model
              ? category.copyWith(muted: muted)
              : category)
          .toList(growable: false);
    });
  }

  Future<void> _toggleMute(
    NotificationCategoryModel category,
    bool muted,
  ) async {
    if (_isAlwaysOnCategory(category.model)) {
      return;
    }

    final model = category.model;
    final previous = category.muted;
    final isLocalOnly = _localOnlyCategories.contains(model);

    _setCategoryMuted(model, muted);
    setState(() {
      _savingModels.add(model);
    });

    try {
      // الفئات المحلية فقط: تخزين محلي بدون مزامنة API
      if (isLocalOnly) {
        if (model == 'adhan') {
          // مزامنة حالة كتم الأذان مع Hive (المصدر الرسمي لـ PrayerAudioService)
          await HiveService.setPrayerSoundMuted(muted);
          // إلغاء الإشعارات المجدولة إذا تم الكتم
          if (muted) {
            await PrayerNotificationService().cancelAllPendingAdhan();
          }
        }
        // حفظ في SharedPreferences أيضاً للفئات المحلية
        await NotificationStorageService.setLocalMuteSetting(model, muted);
      } else {
        await NotificationStorageService.setMuteSetting(model, muted);
      }
    } catch (e) {
      if (mounted) {
        _setCategoryMuted(model, previous);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update $model: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingModels.remove(model);
        });
      }
    }
  }

  Future<void> _unmuteAll() async {
    final mutedItems = _categories.where((item) => item.muted).toList();
    if (mutedItems.isEmpty) return;

    setState(() {
      _isBulkUpdating = true;
    });

    for (final item in mutedItems) {
      await _toggleMute(item, false);
    }

    if (!mounted) return;
    setState(() {
      _isBulkUpdating = false;
    });
  }

  Widget _buildHeroCard() {
    final mutedCount = _mutedCount();
    final total = _categories.length;
    final statusText = total == 0
        ? 'No notification categories found.'
        : mutedCount == 0
            ? 'All categories are active.'
            : '$mutedCount of $total categories are muted.';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26.r),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0A1F4D),
            Color(0xFF1B3E86),
            Color(0xFF2D67BC),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52.w,
            height: 52.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.18),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notification Preferences',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 28.sp,
                    height: 1.05,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  statusText,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(NotificationCategoryModel category) {
    final isSaving = _savingModels.contains(category.model);
    final isAlwaysOn = _isAlwaysOnCategory(category.model);

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 10.w, 10.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        color: category.muted
            ? category.color.withValues(alpha: 0.08)
            : const Color(0xFFF7F9FC),
        border: Border.all(
          color: category.muted
              ? category.color.withValues(alpha: 0.5)
              : const Color(0xFFE1E7F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: category.color.withValues(alpha: 0.14),
            ),
            child: Icon(category.icon, color: category.color, size: 21.sp),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.title,
                  style: GoogleFonts.poppins(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111D3A),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  category.model,
                  style: GoogleFonts.poppins(
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF5F6F89),
                  ),
                ),
                if (isAlwaysOn)
                  Text(
                    'Always enabled',
                    style: GoogleFonts.poppins(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: category.color,
                    ),
                  ),
              ],
            ),
          ),
          if (isSaving)
            SizedBox(
              width: 18.w,
              height: 18.w,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: category.color,
              ),
            )
          else
            Switch.adaptive(
              value: isAlwaysOn ? true : !category.muted,
              activeColor: const Color(0xFF43A047),
              activeTrackColor: const Color(0xFFA5D6A7),
              inactiveThumbColor: const Color(0xFFE53935),
              inactiveTrackColor: const Color(0xFFEF9A9A),
              onChanged: _isBulkUpdating || isAlwaysOn
                  ? null
                  : (value) => _toggleMute(category, !value),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF3F6FB),
        foregroundColor: appFontColor,
        title: Text(
          'Mute Notifications',
          style: GoogleFonts.poppins(
            color: appFontColor,
            fontSize: 28.sp,
          ),
        ),
        actions: [
          IconButton(
            onPressed:
                _isLoading ? null : () => _loadSettings(forceRefresh: true),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
          if (!_isLoading && _mutedCount() > 0)
            TextButton.icon(
              onPressed: _isBulkUpdating ? null : _unmuteAll,
              icon: const Icon(Icons.volume_up_rounded, size: 16),
              label: Text(
                'Unmute all',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2E6BC3),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadSettings(forceRefresh: true),
              child: ListView(
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                children: [
                  _buildHeroCard(),
                  SizedBox(height: 14.h),
                  if (_error != null)
                    Container(
                      margin: EdgeInsets.only(bottom: 10.h),
                      padding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14.r),
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        _error!,
                        style: GoogleFonts.poppins(
                          color: Colors.red.shade700,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  if (_categories.isEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 26.h),
                      alignment: Alignment.center,
                      child: Text(
                        'No notification categories available.',
                        style: GoogleFonts.poppins(
                          fontSize: 12.sp,
                          color: const Color(0xFF5F6F89),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  else
                    ..._categories.map(_buildCategoryTile),
                ],
              ),
            ),
    );
  }
}

class _CategoryUiMeta {
  final String title;
  final IconData icon;
  final Color color;

  const _CategoryUiMeta({
    required this.title,
    required this.icon,
    required this.color,
  });
}
