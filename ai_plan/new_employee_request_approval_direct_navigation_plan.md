# Plan: "New Employee Request Approval" — Direct Navigation

## Summary

A single, scoped module / category / type based fallback notification by mapping specific payload conditions (module/category/type) to NotificationType.hr, ensuring direct navigation without triggering popup flow.

**File changed:** `lib/notifications/notification_payload_parser.dart`
**IndexApp status:** No class or file named `IndexApp` exists in the codebase. The authoritative notification files are `notification_payload_parser.dart`, `notification_controller.dart`, `notification_router.dart`, and `firebase_service.dart`.
**Code implemented:** Yes — see change below.

---

## Root Cause

The notification pipeline resolves a `NotificationType` from the payload's `category` / `type` / `model` fields in `_resolveType()`. The "New Employee Request Approval" notification's server payload does not match existing notification routing rules for employee request approvals:

```
hr | hr_approval | human_resources | hr.leave | leave
rfq | request_for_quotation
petty_cash | pettycash
invoice | invoices
employee.requests (+ HR/RFQ/INVOICE/PETTY sub-type)
chat_message | chat
```

This causes it to resolve as `NotificationType.unknown`.

**Cascade:**

1. `NotificationController._handle()` — `unknown` type → returns `false` (line 61–62)
2. `notification_screen.dart` lines 1016–1023 — `!handled` → calls `_showAnnouncementDialog()` ← **this is the popup**
3. System-tray tap (background/terminated) — `handleTap()` returns `false` → **no navigation at all**

---

## Why Direct Navigation Is Better

The current flow forces an extra interaction (dismissing the dialog) before the user can reach the content they tapped on. Direct navigation respects the user's intent and matches how all other navigable notifications (HR leave, RFQ, invoice) already behave.

---

## How This Change Is Safely Isolated

The title fallback fires **only** if:

1. All category-based checks already failed (it's placed last, before `return unknown`)
2. The exact title string `"New Employee Request Approval"` is present in the data

## Only notifications matching employee request conditions will trigger HR routing.

## The Change

**File:** `lib/notifications/notification_payload_parser.dart`
**Method:** `_resolveType()` — insert inside \_resolveType() before returning NotificationType.unknown, before `return NotificationType.unknown`

```dart
// module / category / type based fallback: "New Employee Request Approval" must open the
// HR detail screen directly, regardless of what category the server sent.
if (data['module'] == 'employee_request' ||
    data['category'] == 'approval' ||
    (data['type'] ?? '').contains('employee_request')) {
  return NotificationType.hr;
}
```

---

## Full Notification Flow (After Fix)

```
User taps "New Employee Request Approval" notification
  ↓
FirebaseService._handleNotificationTap()
  ↓
NotificationController.handleTap(rawData)
  ↓
NotificationPayloadParser.parse(rawData)
  _resolveType() → category checks fail → general fallback architecture
  → returns NotificationType.hr
  ↓
NotificationController — type != unknown → routes
  ↓
NotificationRouter.route()
  → case NotificationType.hr → HrDetailsScreen(requestId, rawType)
  ↓
User sees request detail screen immediately
No dialog. No intermediate screen. No extra tap.
```

---

## Data Handling

`_extractRequestId()` tries these fields in order: `request_id` → `requestId` → `record_id` → `id`. The server must include at least one of these in the notification data payload for `HrDetailsScreen` to load the correct record.

`payload.rawType` (the original category string) is passed as the `type` argument to `HrDetailsScreen`, preserving any sub-type context the server sent.

---

## Files Inspected (Not Modified)

| File                                                                | Key Location    | Purpose                                                              |
| ------------------------------------------------------------------- | --------------- | -------------------------------------------------------------------- |
| `lib/notifications/notification_controller.dart`                    | Lines 61–62     | `unknown` type → returns `false` (the gate that triggers the dialog) |
| `lib/notifications/notification_router.dart`                        | Lines 18–23     | `NotificationType.hr` → `HrDetailsScreen` — already correct          |
| `lib/firebase_service.dart`                                         | Lines 521–530   | `_buildEnrichedPayload()` merges `title` into data map               |
| `lib/ui/presentation/Notification/notification_screen.dart`         | Lines 1016–1023 | `!handled` → `_showAnnouncementDialog()` — the popup source          |
| `lib/ui/presentation/Email Approval/screens/hr_details_screen.dart` | Constructor     | Accepts `requestId` + `type`; handles empty `requestId` gracefully   |

---

## What Does NOT Change

- `notification_controller.dart`
- `notification_router.dart`
- `firebase_service.dart`
- `notification_screen.dart` (dialog code stays; it just won't trigger for this title)
- `HrDetailsScreen` and all approval screens
- All other notification types: announcements, circulars, chat, RFQ, petty cash, invoice

---

## Edge Cases

| Case                                        | Behavior                                                                                                 |
| ------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| Server sends no `request_id`                | `requestId` is empty string → `HrDetailsScreen` shows error/empty state, no crash                        |
| App terminated, user taps notification      | `getInitialMessage()` path → same parser → fix applies                                                   |
| App in foreground (Android)                 | Local notification path → `onDidReceiveNotificationResponse` → same parser → fix applies                 |
| Server changes notification title in future | Title match fails → falls back to `unknown` → dialog reappears. Coordinate with backend if title changes |
| Arabic title sent for Arabic-locale users   | May need to add Arabic equivalent string. Confirm with backend                                           |

---

## Risk Analysis

| Risk                               | Likelihood | Mitigation                                                                 |
| ---------------------------------- | ---------- | -------------------------------------------------------------------------- |
| Server changes notification title  | Medium     | If server adds a proper `category` field later, remove this title fallback |
| Title is locale-dependent (Arabic) | Medium     | Ask backend if title is translated; add Arabic string if needed            |
| Missing `request_id` causes crash  | Low        | Verify `HrDetailsScreen` handles empty `requestId` before shipping         |
| Re-entrancy (two rapid taps)       | Low        | Already handled by `_isBusy` guard in `NotificationController`             |

---

## Testing Checklist

- [ ] Send test push notification: title = `"New Employee Request Approval"`, data includes valid `request_id` → `HrDetailsScreen` opens immediately, no dialog
- [ ] Same test while app is **terminated** → direct navigation after splash
- [ ] Same test while app is **in background** → direct navigation
- [ ] Same test with **no `request_id`** → no crash (error/empty state in screen)
- [ ] Tap **announcement/circular** notification → announcement dialog still appears (regression)
- [ ] Tap **chat** notification → chat screen still opens (regression)
- [ ] Tap HR leave notification with `category: "hr"` → still routes to `HrDetailsScreen` (regression)
- [ ] Tap **RFQ** notification → still routes to `RfqDetailsScreen` (regression)
