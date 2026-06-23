# New Employee Request — Navigation Fix Plan (Clean Architecture Revision)

**Module:** Notification Navigation — Approval Request Routing
**Plan file:** `ai_plan/new_employee_request_navigation_plan.md`

---

## Context

"New Employee Request" notifications are stored with `category: 'employee.requests'`. When tapped — either from the in-app Notifications list or from the system notification tray — neither path navigates to the approval detail screens. Instead, both paths produce dead ends.

The previous revision introduced routing logic in two files (`notification_screen.dart` and `firebase_service.dart`) with a stateful router. That design has four compounding problems:

1. **Routing table duplicated** — any change must be made in two files and can diverge silently.
2. **Unsafe field access** — `data['request_id']`, `data['type']`, `data['model']` accessed inline with no type-safe parsing contract.
3. **Stateful router** — `_isNavigating` flag inside `NotificationRouter` violates single-responsibility; a router should be pure.
4. **No single coordinator** — neither the UI layer nor the service layer is the right owner for navigation guard state.

This revision introduces a strict four-layer clean architecture:

```
Notification Tap (any source)
        │
        ▼
NotificationController.handleTap(rawData)   ← SINGLE entry point
        │
        ▼
NotificationPayloadParser.parse(rawData)     ← safe, typed, stateless
        │ returns ParsedNotificationPayload
        ▼
NotificationRouter.route(payload, navigator) ← stateless, pure mapping
        │
        ▼
Target Screen
```

**Intended outcome:** Both tap sources call one method. The UI layer contains zero routing or parsing logic. The router is stateless. The controller is the sole owner of guard/queue state.

---

## Root Cause Analysis

### Path A — Tap from Notification List (`notification_screen.dart`)

```
_buildNotificationItem().onTap  (line 984)
  → _markNotificationAsRead()
  → _showAnnouncementDialog()   ← shows popup only; no navigation
```

### Path B — Tap from System Tray (`firebase_service.dart`)

```
_handleNotificationTap()  (line 499)
  → _isChatNotificationPayload() → _handleChatNotificationTap()  ← existing
  → else → "View-only notification; no navigation."              ← dead end
```

Neither path navigates to `HrDetailsScreen`, `RfqDetailsScreen`, `PettyCashDetailsScreen`, or `InvoiceDetailsScreen`, which already accept `requestId` and `type` as constructor parameters and are ready to use.

---

## Solution Architecture

Two new stateless components plus one stateful controller, all in a new `lib/notifications/` directory. No existing files receive routing or parsing logic.

---

## New Files to Create

### `lib/notifications/notification_payload.dart`

No state. No imports beyond `dart:core`. Contains two declarations only.

**`NotificationType` enum** — exhaustive, compiler-enforced:

| Value | Target |
|---|---|
| `hr` | `HrDetailsScreen` |
| `rfq` | `RfqDetailsScreen` |
| `pettyCash` | `PettyCashDetailsScreen` |
| `invoice` | `InvoiceDetailsScreen` |
| `chat` | Back-delegated to `FirebaseService.delegateChatTap()` |
| `unknown` | Caller shows fallback dialog |

**`ParsedNotificationPayload`** — immutable value object:

| Field | Type | Purpose |
|---|---|---|
| `type` | `NotificationType` | Routing decision |
| `requestId` | `String` | Required by all approval screens; empty string when absent |
| `rawType` | `String` | Original category string, passed as `type:` to screen constructors |
| `raw` | `Map<String, dynamic>` | Full original map, used by `delegateChatTap` |

Helper getters:
- `bool get isNavigable => type != NotificationType.unknown;`
- `bool get isChatType => type == NotificationType.chat;`

---

### `lib/notifications/notification_payload_parser.dart`

Single static method: `parse(Map<String, dynamic> rawData) → ParsedNotificationPayload`

**No state. No side effects. Never throws.**

Field extraction rules:

| Output field | Source fields tried (in order) | Default |
|---|---|---|
| `rawType` | `data['category']`, `data['type']`, `data['model']` | `''` |
| `requestId` | `data['request_id']`, `data['requestId']`, `data['record_id']`, `data['id']` | `''` |

All values go through `.toString().trim()`. Category is additionally lowercased for comparison.

**Type resolution** (private `_resolveType` method):

| Condition | Result |
|---|---|
| Category is `'chat_message'`/`'chat'`, or map has key `'chat_id'`/`'chatId'` | `NotificationType.chat` |
| Category is `'hr'`, `'hr_approval'`, `'human_resources'`, `'hr.leave'`, `'leave'` | `NotificationType.hr` |
| Category is `'rfq'`, `'request_for_quotation'`, `'employee.requests'` with subtype `'RFQ'` | `NotificationType.rfq` |
| Category is `'petty_cash'`, `'pettycash'` | `NotificationType.pettyCash` |
| Category is `'invoice'`, `'invoices'` | `NotificationType.invoice` |
| Anything else | `NotificationType.unknown` |

Adding a new notification type means adding one condition here and one case in the router — nowhere else.

---

### `lib/notifications/notification_router.dart`

Static method: `route(ParsedNotificationPayload payload, NavigatorState navigator) → bool`

**No static state. No flags. No global dependencies. `navKey` is not read here.**

- Returns `true` if a screen was pushed; `false` if type is `chat` or `unknown`.
- Uses a `switch` over `payload.type` — exhaustive, compiler-enforced.
- Each case constructs the target screen and calls a shared `_push(navigator, screen, routeName)` helper.
- `_push` wraps `navigator.push(MaterialPageRoute(...))` in a try/catch; logs and returns `false` on failure without crashing.
- Named route settings (`'/hr_details_from_notification'` etc.) are included for debuggability.

**Only this file imports the four approval screens:**
```
lib/ui/presentation/Email Approval/screens/hr_details_screen.dart
lib/ui/presentation/Email Approval/screens/rfq_details_screen.dart
lib/ui/presentation/Email Approval/screens/pettycash_details_screen.dart
lib/ui/presentation/Email Approval/screens/invoice_details_screen.dart
```

No other file in the system imports these for routing.

---

### `lib/notifications/notification_controller.dart`

**Single entry point. Owns all guard/queue state.**

Static class (mirrors `FirebaseService` and `NotificationStorageService` convention — no GetIt registration needed).

**Private state:**

| Field | Type | Purpose |
|---|---|---|
| `_isBusy` | `bool` | Re-entrancy guard — prevents double-navigation on rapid taps |
| `_pendingRawData` | `Map<String, dynamic>?` | Holds one queued tap that arrived while home was loading or `_isBusy` was true |

**Public API (two methods only):**

- `static bool handleTap(Map<String, dynamic> rawData)` — single entry point for ALL sources
- `static void processPending()` — called by `FirebaseService.processPendingNotificationTap()` when home becomes ready

`handleTap` return contract:
- `true` — tap consumed (navigation performed, or queued for replay when home is ready)
- `false` — tap is view-only (unknown type); caller shows its fallback dialog

**`_handle(rawData)` internal flow:**

```
1. _isBusy == true?
       → _pendingRawData = rawData; return true

2. navKey.currentState == null OR !FirebaseService.isHomeReady?
       → _pendingRawData = rawData; return true (will replay in processPending)

3. payload = NotificationPayloadParser.parse(rawData)

4. payload.isChatType?
       → FirebaseService.delegateChatTap(rawData); return true

5. payload.type == NotificationType.unknown?
       → return false  (caller shows dialog)

6. _isBusy = true
   try:
       navigated = NotificationRouter.route(payload, navKey.currentState!)
       return navigated
   finally:
       _isBusy = false
       if _pendingRawData != null && _pendingRawData != rawData:
           _pendingRawData = null
           processPending()   ← self-drain, same pattern as _handleChatNotificationTap
```

`processPending()` pulls from `_pendingRawData` and calls `_handle()` via `WidgetsBinding.instance.addPostFrameCallback`, matching the exact pattern used by the existing chat pending-replay logic.

**Scenario coverage:**

| Scenario | Behavior |
|---|---|
| Rapid double-tap | Second tap stored in `_pendingRawData`; replayed after first push returns in `finally` |
| Tap from terminated state (home not ready) | Stored in `_pendingRawData`; replayed when `markHomeReady()` triggers `processPendingNotificationTap()` → `processPending()` |
| Inactivity-timeout restart | `markHomeNotReady()` → `_isHomeReady = false`; tap during splash queued; replayed after `markHomeReady()` |

---

## Files to Modify

### 1. `lib/firebase_service.dart`

Four targeted changes. All existing chat logic is untouched.

**Change 1 — Expose `_isHomeReady` as a public getter** (one new line after the existing private field at line 26):

```dart
static bool get isHomeReady => _isHomeReady;
```

No change to `_isHomeReady`, `markHomeReady()`, or `markHomeNotReady()`.

**Change 2 — Slim `_handleNotificationTap` (lines 499–515) to three lines:**

```dart
static void _handleNotificationTap(String? payload) {
  final payloadData = _parseNotificationPayload(payload);
  NotificationController.handleTap(payloadData);
}
```

`_parseNotificationPayload` (lines 546–583) is preserved and still called here. No category switching, no routing imports remain in this method.

**Change 3 — Add `delegateChatTap` static method** (adjacent to `_handleChatNotificationTap`):

This is the back-channel `NotificationController` calls when it detects a chat payload, handing decoded data back to the existing chat handler without re-parsing.

```
static void delegateChatTap(Map<String, dynamic> payloadData):
  1. Try jsonEncode(payloadData) → rawPayload; on failure, use payloadData.toString()
  2. Call _handleChatNotificationTap(rawPayload, payloadData)
```

`_handleChatNotificationTap`, `_isChatNotificationPayload`, `_isHandlingChatTap`, `_pendingChatTapPayload`, `_resolveChatType`, `_navigateToChatScreen` — all untouched.

**Change 4 — Update `processPendingNotificationTap`**: add one line at the top:

```dart
NotificationController.processPending();
```

The existing chat-specific replay logic below it is unchanged.

**Import to add:**
```dart
import 'package:el_race/notifications/notification_controller.dart';
```

---

### 2. `lib/ui/presentation/Notification/notification_screen.dart`

One targeted change. **The UI does not import the parser or the router.**

**Change — `_buildNotificationItem().onTap` (lines 984–995):**

```
onTap: () async {
  // 1. Mark as read (unchanged)
  final notificationId = (item['id'] ?? '').toString();
  if (!isRead && notificationId.isNotEmpty) {
    await _markNotificationAsRead(notificationId);
    if (!mounted) return;
  }

  // 2. Extract raw data map — field access only, no parsing logic
  final dynamic nested = item['data'] ?? item['payload'];
  final Map<String, dynamic> rawData = (nested is Map<String, dynamic>)
      ? {
          ...nested,
          if (item.containsKey('category')) 'category': item['category'],
          if (item.containsKey('type') && !nested.containsKey('category'))
            'type': item['type'],
        }
      : Map<String, dynamic>.from(item.map((k, v) => MapEntry(k.toString(), v)));

  // 3. Delegate to controller — returns false only for view-only (unknown) types
  final handled = NotificationController.handleTap(rawData);

  // 4. Fallback: view-only types show the announcement dialog (existing behavior)
  if (!handled && mounted) {
    _showAnnouncementDialog(
      context,
      item['title'] ?? 'Notification',
      item['body'] ?? '',
    );
  }
},
```

The UI calls one method and checks one bool. Zero switch statements, zero screen imports, zero category strings.

**Import to add:**
```dart
import 'package:el_race/notifications/notification_controller.dart';
```

---

## Dependency Graph (no cycles)

```
notification_screen.dart
    └── NotificationController.handleTap()

firebase_service._handleNotificationTap
    └── NotificationController.handleTap()

NotificationController
    ├── FirebaseService.isHomeReady        (read-only getter)
    ├── FirebaseService.delegateChatTap()  (chat back-delegation)
    ├── NotificationPayloadParser.parse()
    ├── NotificationRouter.route()
    └── navKey  (lib/core/app_globals.dart)

NotificationRouter
    ├── HrDetailsScreen
    ├── RfqDetailsScreen
    ├── PettyCashDetailsScreen
    └── InvoiceDetailsScreen

NotificationPayloadParser
    └── ParsedNotificationPayload (pure data)
```

Note on mutual import: `FirebaseService` imports `NotificationController`; `NotificationController` imports `FirebaseService` for two static accessors. Dart handles mutual package imports without issue. To eliminate entirely: introduce a thin `NotificationBridge` class in `lib/notifications/` that exposes `isHomeReady` and `delegateChatTap` — `NotificationController` imports the bridge only, breaking the mutual import.

---

## What Must NOT Change

- `_handleChatNotificationTap`, `_isChatNotificationPayload`, `_isHandlingChatTap`, `_pendingChatTapPayload`, `_resolveChatType`, `_navigateToChatScreen` in `firebase_service.dart`
- `_showAnnouncementDialog` / `_showCircularAnnouncementDialog` in `notification_screen.dart`
- All four approval screens — not imported anywhere except `notification_router.dart`
- `generated_routes.dart`, `app_pages.dart`
- `splash_screen.dart` calls to `FirebaseService.markHomeReady()` / `markHomeNotReady()`
- `lib/utils/di.dart` — no registration needed; all new classes are static
- All BLoC, Provider, Firestore, backend, UI layout, screen designs

---

## Compatibility with Task 1 (Popup Removal)

Task 1 removes `_showAnnouncementDialog()` from `_buildNotificationItem()`. This plan is compatible in either order:

- **Task 1 first**: Unknown types reach the removed call (already absent — no-op). Navigable types return early via controller. Correct.
- **Task 3 (this plan) first**: Navigable types return early via controller before reaching `_showAnnouncementDialog()`. Unknown types still reach it until Task 1 removes it. Correct.
- Implementation order does not matter.

---

## Implementation Order

Steps 1–4 create or minimally touch files with zero risk to the running app. Steps 5–7 are the integration cuts.

| Step | Action | Risk |
|---|---|---|
| 1 | Create `lib/notifications/notification_payload.dart` | None (new file, no callers yet) |
| 2 | Create `lib/notifications/notification_payload_parser.dart` | None |
| 3 | Create `lib/notifications/notification_router.dart` | None |
| 4 | Add `isHomeReady` getter to `firebase_service.dart` (one line) | Minimal |
| 5 | Create `lib/notifications/notification_controller.dart` | None |
| 6 | Modify `firebase_service.dart`: `delegateChatTap`, slim `_handleNotificationTap`, `processPending()` call, import | Low |
| 7 | Modify `notification_screen.dart`: replace onTap body, import | Low |

---

## Testing Checklist

- [ ] `flutter analyze` — zero new warnings
- [ ] Tap `'hr'` / `'employee.requests'` notification in list → `HrDetailsScreen` opens
- [ ] Same with `'rfq'` → `RfqDetailsScreen`
- [ ] Same with `'invoice'` → `InvoiceDetailsScreen`
- [ ] Same with `'petty_cash'` / `'pettycash'` → `PettyCashDetailsScreen`
- [ ] All four types tap from system tray → correct screens via `firebase_service` path
- [ ] Notification with missing `request_id` / `id` → no navigation, no crash
- [ ] Notification with unknown category → controller returns `false`; UI shows announcement dialog
- [ ] Payload where `data` field is null or not a Map → parser returns `unknown`; no crash
- [ ] Rapid double-tap → only one screen pushed (`_isBusy` drops second)
- [ ] Terminated-state launch: tap notification before home ready → queued; replayed after `markHomeReady()`
- [ ] Chat notifications from system tray → still navigate to `ChatScreen` (regression)
- [ ] Chat notifications from in-app list → still delegate via `FirebaseService.delegateChatTap()`
- [ ] Circular / Announcement taps → popup still appears (regression)
- [ ] Back button from approval screen → returns to Notifications list

---

## Risk Analysis

| Risk | Likelihood | Mitigation |
|---|---|---|
| Mutual import between `firebase_service.dart` and `notification_controller.dart` | Certain | Dart handles mutual package imports cleanly; optional `NotificationBridge` eliminates it entirely |
| `item['data']` null or wrong type in notification_screen | Low | Fallback `Map.from(item)` in rawData extraction |
| `request_id` absent from payload | Medium | Parser tries 4 field names; `requestId` defaults to `''`; router returns `false` gracefully |
| Unknown / future category values | Medium | Parser returns `unknown`; controller returns `false`; UI shows dialog |
| `navKey.currentState` null at tap time | Low | Guard step 2 in `_handle()`; tap queued, not dropped |
| Concurrent double-tap | Low | `_isBusy` in `NotificationController` stores and replays second tap |
| Import path for Email Approval screens (spaces in path) | Low | Dart supports spaces; pattern already used elsewhere in this project |

---

## IndexApp Update

| File | Status |
|---|---|
| `lib/notifications/notification_payload.dart` | **New** — add to IndexApp |
| `lib/notifications/notification_payload_parser.dart` | **New** — add to IndexApp |
| `lib/notifications/notification_router.dart` | **New** — add to IndexApp |
| `lib/notifications/notification_controller.dart` | **New** — add to IndexApp |
| `lib/firebase_service.dart` | Modified — already in IndexApp |
| `lib/ui/presentation/Notification/notification_screen.dart` | Modified — already in IndexApp |
