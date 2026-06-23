# View Attachment Button — Consistency Fix Plan

**Module:** Notifications → Circulars / Announcements Popup  
**File:** `lib/ui/presentation/Notification/notification_screen.dart`  
**Plan file:** `ai_plan/view_attachment_button_consistency_fix_plan.md`

---

## 1. Root Cause Analysis

Both the Circulars/Announcements popup and the standard Notifications popup live in the same file (`notification_screen.dart`), implemented as two separate private dialog methods:

| Method | Lines | Font | Size | Status |
|---|---|---|---|---|
| `_showCircularAnnouncementDialog()` | 1177–1285 | `BebasNeue` | `24.sp` | **Broken** |
| `_showAnnouncementDialog()` | 1307–1399 | `Inter` | `13.sp w600` | Correct |

`BebasNeue` is a condensed display/headline font with very tall uppercase glyphs. At `24.sp` inside a popup constrained to `75%` of screen height, the button label renders significantly larger than the surrounding content scale, causing:

- Text overflow beyond the button's `AnimatedContainer` bounds
- Button expanding too wide due to an unconstrained `Row` driven by large text
- Visual inconsistency with the Notifications popup which correctly uses a compact body font

---

## 2. UI Hierarchy Breakdown

```
showDialog()
 └── Dialog (borderRadius: 20, bg: white)
      └── Container (maxHeight: 75% screen, padding: 22)
           └── Column (mainAxisSize: min)
                ├── Text — title (Inter 20.sp w700)
                ├── Text — date  (Inter 12.sp w500)
                ├── Flexible → SingleChildScrollView → Text — body
                └── Center
                     └── InkWell (borderRadius: 30)
                          └── AnimatedContainer (padding: h22/v11, radius: 30)
                               └── Row (mainAxisSize: min)   ← overflow origin
                                    ├── Icon (attach_file, size: 16)
                                    ├── SizedBox(width: 6)
                                    └── Text('VIEW ATTACHMENT')  ← 24.sp BebasNeue ← ROOT CAUSE
```

The `Row` has `mainAxisSize: MainAxisSize.min`, so it grows to fit its children. With `24.sp` BebasNeue the row exceeds the available dialog width, pushing the `AnimatedContainer` outside the dialog's padding boundaries.

---

## 3. Files to Inspect

| File | Purpose |
|---|---|
| `lib/ui/presentation/Notification/notification_screen.dart` L1236–1278 | Broken button (Circulars/Announcements popup) |
| `lib/ui/presentation/Notification/notification_screen.dart` L1355–1392 | Reference button (Notifications popup) |
| `lib/ui/presentation/circular_announcement/screens/circular_announcement_screen.dart` | Confirms: no popup here; tapping calls `_openFile()` directly — popup is exclusively in notification_screen |

---

## 4. Strategy: Compare Both Implementations

| Property | Broken (`_showCircularAnnouncementDialog`) | Reference (`_showAnnouncementDialog`) |
|---|---|---|
| Wrapper | `InkWell` + `AnimatedContainer` | `InkWell` + `Container` |
| Font | `GoogleFonts.bebasNeue` | `GoogleFonts.inter` |
| Font size | `24.sp` | `13.sp` |
| Font weight | (BebasNeue has no weight param) | `FontWeight.w600` |
| Letter spacing | `0.5` | `0.5` |
| Icon size | `16` | `18` |
| Icon gap | `SizedBox(6)` | `SizedBox(8)` |
| Container padding | h22 / v11 | h24 / v12 |
| Border radius | `30` | `25` |
| Active color | `Color(0xFF0A1133)` | `Colors.black` |

**The only property causing the defect is the font family + font size.** Everything else is an acceptable minor styling difference between the two popups.

---

## 5. Safe Fix Strategy

**Minimal-diff approach:** Change only the `TextStyle` inside `_showCircularAnnouncementDialog()`. Touch nothing else in the file.

Why this is the safest fix:
- Single property swap in one method
- No new widgets, no structural changes
- `GoogleFonts.inter` is already imported and used in the same file (line ~1381)
- Does not affect any state, navigation, BLoC, provider, or API logic

---

## 6. Fix Options

### Option A — Font/Size Only (Recommended — Minimal)

Change only the `TextStyle` on the broken button's label at line ~1268:

```dart
// BEFORE
style: GoogleFonts.bebasNeue(
  fontSize: 24.sp,
  letterSpacing: 0.5,
  color: Colors.white,
),

// AFTER
style: GoogleFonts.inter(
  fontSize: 13.sp,
  fontWeight: FontWeight.w600,
  color: Colors.white,
  letterSpacing: 0.5,
),
```

### Option B — Full Parity (Option A + minor alignment)

In addition to Option A, align the two secondary differences for exact pixel parity:

```dart
// Icon size: 16 → 18
const Icon(Icons.attach_file, color: Colors.white, size: 18),

// Icon gap: 6 → 8
const SizedBox(width: 8),
```

**Recommendation:** Option B. The two extra value changes are trivial and produce a button that is visually identical to the Notifications reference, reducing future confusion.

### Option C — FittedBox Wrapper (Not Recommended)

Wrap the `Text` in a `FittedBox`. This would visually scale down the oversized BebasNeue text but masks the root cause and adds an unnecessary widget layer. Rejected.

---

## 7. What Must NOT Be Changed

- `showDialog()` call and all its parameters
- `Dialog` widget: `shape`, `backgroundColor`, `barrierColor`, `barrierDismissible`
- `Container` `maxHeight` constraint (`0.75 * screen height`)
- `Column` structure and all sibling children (title, date, body scroll)
- `AnimatedContainer` `duration` and `decoration` (colors, borderRadius)
- `InkWell` `borderRadius` and `onTap` handler
- `_openCircularAnnouncementFile()` method
- Colors: `Color(0xFF0A1133)`, `Color(0xFFB9BFCC)`, `Colors.white`
- `item.hasFile` conditional logic
- Any other method in `notification_screen.dart`
- `circular_announcement_screen.dart` — no changes needed at all

---

## 8. Testing Checklist

- [ ] `flutter analyze` — zero new warnings or errors
- [ ] Hot reload; navigate to Notifications screen
- [ ] Tap a **Circular**-type notification → popup opens → "VIEW ATTACHMENT" button is compact, no overflow
- [ ] Tap an **Announcement**-type notification → same result
- [ ] Visually compare button against generic notification popup (`_showAnnouncementDialog`) → fonts and sizes match
- [ ] Test with `item.hasFile == false` → button renders in gray disabled state, no overflow
- [ ] Test on **small screen** (360dp width) — no overflow
- [ ] Test on **large screen** (412dp width) — button looks balanced
- [ ] Test with **long body content** in popup — scroll works, button stays visible at bottom of dialog

---

## 9. Risk Analysis

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `GoogleFonts.inter` not imported | **None** | — | Already used in `_showAnnouncementDialog()` at line ~1381 in same file |
| Snapshot / golden test failures | **None** | — | No snapshot tests in this project |
| `13.sp` renders too small on some devices | Very low | Cosmetic | Reference button uses same `13.sp` and is already validated in production |
| Icon size 16→18 shifts layout | Very low | Cosmetic | `mainAxisSize: min` adapts; 2px difference is imperceptible |
| Regression in `_showAnnouncementDialog` | **None** | — | Method is not touched |
| Regression in `CircularAnnouncementScreen` | **None** | — | File is not touched |

---

## 10. IndexApp Update Instructions

After this plan file is created, add the following section to `IndexApp` in alphabetical order among the top-level directory sections:

```
### ai_plan

| File | Type | Last Modified | Size |
|---|---:|---:|---:|
| `view_attachment_button_consistency_fix_plan.md` | Markdown | 2026-06-17 | ~5 KB |
```

If an `### ai_plan` section already exists, append the new row to its existing table.

---

## 11. Final Expected Outcome

After applying **Option B**:

- The "VIEW ATTACHMENT" button in the Circulars/Announcements popup is visually identical to the Notifications popup button
- No text overflow, no layout overflow on any screen size
- Button remains pill-shaped: dark navy (`#0A1133`) when `item.hasFile == true`, gray (`#B9BFCC`) when false
- Tap behavior (close dialog → navigate to `CircularAnnouncementFileViewer`) is completely unchanged
- **Two value changes in one method in one file** — zero risk of regression anywhere in the application
