# Remove "Attendance Synced" Notification — Plan

**Module:** Notifications Screen — Local Notification Filtering  
**File:** `lib/ui/presentation/Notification/notification_screen.dart`  
**Plan file:** `ai_plan/remove_attendance_synced_notification_plan.md`

---

## 1. Root Cause Analysis

"Attendance Synced" is a **local notification** stored in SharedPreferences via `NotificationStorageService`. It is generated when an attendance sync push is received from Firebase (category: `hr.attendance`). The notification title is the literal string `"Attendance Synced"` (or similar variants).

The notification appears in the UI because `_getFilteredNotifications()` returns all stored notifications matching the current tab's category — it has no title-level exclusion filter. To suppress only this specific notification from the list, a title-based exclusion must be added to the filter method.

The fix must NOT remove the backend sync behavior (`AttendanceStatusSyncService.refreshFromServer()`) — only the list display entry for this particular title.

---

## 2. UI Hierarchy Breakdown

```
NotificationScreen
 └── _buildLocalNotificationsList()  (line 810)
      └── _getFilteredNotifications()  (line 565)  ← FILTER POINT
           ├── Tab index == 0 → exclude 'circular' and 'announcement' categories
           └── Other tabs → exact category match
           ↓
           Returns: List<Map<String, dynamic>>
           ↓
      └── ListView.builder
           └── Dismissible → _buildNotificationItem()
```

The `_getFilteredNotifications()` method at line 565 is the single chokepoint through which all local notifications pass before being displayed. Adding the title exclusion here ensures it applies to ALL tabs — whether the user is on the "Notifications" tab (index 0) or an "Attendance" sub-tab.

---

## 3. Files to Inspect

| File | Lines | Purpose |
|---|---|---|
| `lib/ui/presentation/Notification/notification_screen.dart` | 565–598 | `_getFilteredNotifications()` — the filter method to modify |
| `lib/core/services/notification_storage_service.dart` | 515–557 | `_normalizeApiNotification()` — where notification title is stored (read-only reference) |
| `lib/firebase_service.dart` | 456–497 | `_isAttendancePush()` — attendance detection logic (must NOT be changed) |

---

## 4. Strategy: Identify "Attendance Synced" Notifications

**How the notification is identified:**

| Field | Value |
|---|---|
| `item['title']` | `"Attendance Synced"` (exact, or close variants) |
| `item['category']` | `"hr.attendance"` (normalized lowercase) |

**Filter approach options:**

| Option | Condition | Risk |
|---|---|---|
| **A — Title match (Recommended)** | `item['title']?.toLowerCase() == 'attendance synced'` | Removes only the specific title — other attendance notifications (e.g., "Check-In Recorded") are unaffected |
| B — Category match | `item['category'] == 'hr.attendance'` | Removes ALL attendance notifications — too broad, breaks sync feedback |

**Recommendation: Option A (title match).** This is the most surgical filter: it removes only the "Attendance Synced" entry while leaving all other attendance-related notifications intact.

---

## 5. Safe Fix Strategy

Add a single additional `.where()` condition inside `_getFilteredNotifications()`. The condition runs after all existing filters and excludes any notification whose title (case-insensitive, trimmed) equals `'attendance synced'`.

No new methods, no new imports, no structural changes.

---

## 6. The Fix

**File:** `lib/ui/presentation/Notification/notification_screen.dart`  
**Method:** `_getFilteredNotifications()`, lines 565–598

The fix adds one helper and one filter condition. The cleanest insertion point is at the very top of the method, so it applies universally regardless of tab index:

```dart
// BEFORE (line 565)
List<Map<String, dynamic>> _getFilteredNotifications() {
  if (notifications.isEmpty) return [];
  if (_notificationTabs.isEmpty || currentIndex >= _notificationTabs.length) {
    return notifications;
  }
  ...
}

// AFTER
List<Map<String, dynamic>> _getFilteredNotifications() {
  if (notifications.isEmpty) return [];
  if (_notificationTabs.isEmpty || currentIndex >= _notificationTabs.length) {
    return notifications;
  }

  final selectedCategory = _notificationTabs[currentIndex].category;

  // Tab 0: show all except circular/announcement
  if (currentIndex == 0) {
    return notifications.where((notification) {
      final id = (notification['id'] ?? '').toString();
      if (_dismissedNotificationIds.contains(id)) return false;
      final cat = (notification['category'] ?? '').toString().toLowerCase().trim();
      if (cat == 'circular' || cat == 'announcement') return false;
      final title = (notification['title'] ?? '').toString().toLowerCase().trim();
      return title != 'attendance synced';           // ← ADD THIS LINE
    }).toList();
  }

  // Remaining tabs: filter by exact category
  return notifications.where((notification) {
    final id = (notification['id'] ?? '').toString();
    if (_dismissedNotificationIds.contains(id)) return false;
    final notificationCategory =
        (notification['category'] ?? 'notification').toString().toLowerCase();
    if (notificationCategory != selectedCategory.toLowerCase()) return false;
    final title = (notification['title'] ?? '').toString().toLowerCase().trim();
    return title != 'attendance synced';             // ← ADD THIS LINE
  }).toList();
}
```

**Diff size:** Add 2 lines (one per `where` block). Change 0 existing lines.

---

## 7. What Must NOT Be Changed

- `_isAttendancePush()` in `firebase_service.dart` — attendance detection untouched
- `AttendanceStatusSyncService.refreshFromServer()` — sync still triggers on push
- Notification storage (`NotificationStorageService.saveNotification()`) — still saves the push
- All other notification titles — only `'attendance synced'` is excluded from display
- Dismiss (swipe-to-read) behavior — untouched
- `_buildNotificationItem()` — untouched
- Circular/Announcement paths — untouched
- The mute settings for `hr.attendance` — untouched

---

## 8. Testing Checklist

- [ ] `flutter analyze` — zero new warnings
- [ ] Open Notifications screen; confirm "Attendance Synced" notification does NOT appear in any tab
- [ ] Confirm other attendance notifications (e.g., "Check-In Recorded", "Attendance Updated") still appear in the Attendance tab if present
- [ ] Trigger an attendance sync → backend sync still happens (no regression in `AttendanceStatusSyncService`)
- [ ] Switch to all other notification tabs → no unintended items hidden
- [ ] Pull-to-refresh → filter still applies after reload
- [ ] Swipe-to-dismiss on another notification → still works

---

## 9. Risk Analysis

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Title text differs from `"Attendance Synced"` (different casing, trailing space) | Very low | Item not hidden | Filter uses `.toLowerCase().trim()` — handles case and whitespace |
| Title varies (e.g., "Attendance synced ✓") | Low | Item not hidden | If confirmed, expand condition to `title.contains('attendance synced')` |
| Other notifications with same title accidentally hidden | None | — | "Attendance Synced" is a unique system-generated title |
| Sync logic broken | None | — | Filter is display-only; storage and sync are unaffected |
| Filter breaks pagination | None | — | Filter runs on in-memory list; pagination logic is separate |

---

## 10. IndexApp Update

`notification_screen.dart` is already registered in IndexApp. No new files created — no IndexApp update needed for this specific fix.

---

## 11. Final Expected Outcome

- "Attendance Synced" notification is invisible in all tabs of the Notifications screen
- All other notification types display normally
- Attendance sync logic (push receipt → `refreshFromServer()`) continues to work
- Two lines added to one method — zero regressions
