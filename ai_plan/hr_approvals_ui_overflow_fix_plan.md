# HR Approvals Card — UI Overflow Fix Plan

**Module:** Approvals > HR Filter Tab
**Component:** HR Request Card (`_buildHrCard`)
**File:** `lib/ui/presentation/Email Approval/widgets/hr_and_pettycash_card.dart`
**Symptom:** `BOTTOM OVERFLOWED BY 5.3 PIXELS`

---

## 1. Root Cause Analysis

### Issue 1 — Rigid fixed height on the card container (line 44)

The Container wrapping the entire HR card declared an absolute height:

```dart
Container(
  height: 150.w,  // ← rigid cap, cannot adapt to content
```

With `vertical: 9.w` padding (18.w total), only `132.w` of vertical space remained for the Column content. That Column contains:

| Widget | Approx height |
|---|---|
| `SizedBox` (avatar + req number Stack) | 34.w |
| `Text` requestType — Poppins 12.4sp w900 (default line-height ~1.4×) | ~17–18px |
| `SizedBox(height: 6.w)` | ~6px |
| `Text` employeeName — Poppins 12sp w700 | ~16px |
| `SizedBox(height: 1.8.w)` | ~2px |
| `Text` empCode — Poppins 12sp w700 | ~16px |
| `SizedBox(height: 10.h)` **(unit bug)** | ~10–11px |
| `Text` date — Poppins 10sp w600 | ~14px |

Summed: **~115–117px ≈ 132.w on many devices** — already at the limit before any font-scale variation.

### Issue 2 — Unit inconsistency: `.h` instead of `.w` (line 157)

```dart
SizedBox(height: 10.h),  // ← .h = height-scaled, .w = width-scaled
```

`flutter_screenutil` resolves `.h` against the device's logical height and `.w` against its logical width. On phones where height > width (typical portrait phones), `10.h` can render slightly taller than `10.w`, adding the extra pixels that tip the layout over the 5.3px edge.

---

## 2. Changes Applied

### Change 1 — Replace `height` with `constraints` (line 44)

```dart
// BEFORE
Container(
  height: 150.w,

// AFTER
Container(
  constraints: BoxConstraints(minHeight: 150.w),
```

Using `minHeight` instead of `height` keeps the card at exactly `150.w` when content fits (visually identical), and allows it to grow by a few pixels only when content genuinely needs more room. This is the Flutter-idiomatic way to make a card adapt to dynamic text.

### Change 2 — Fix `Expanded` + unbounded Column (lines 62, 116–171)

Switching from `height` to `constraints` means the parent Column now receives an unbounded height from the ListView. An `Expanded` widget inside an unbounded Column throws:
`RenderFlex children have non-zero flex but incoming height constraints are unbounded.`

Fix: add `mainAxisSize: MainAxisSize.min` to both Columns and remove the `Expanded` wrapper around the inner Column.

```dart
// BEFORE
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    SizedBox(height: 34.w, ...),
    Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        ...
      ),
    ),
  ],
)

// AFTER
Column(
  mainAxisSize: MainAxisSize.min,          // ← added
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    SizedBox(height: 34.w, ...),
    Column(                                // ← Expanded removed
      mainAxisSize: MainAxisSize.min,      // ← added
      mainAxisAlignment: MainAxisAlignment.start,
      ...
    ),
  ],
)
```

### Change 3 — Fix unit inconsistency (line 158)

```dart
// BEFORE
SizedBox(height: 10.h),

// AFTER
SizedBox(height: 10.w),
```

All other spacing in this method uses `.w`. Using `.w` here ensures consistent, predictable spacing across all screen sizes.

---

## 3. Scope

| Area | Changed? |
|---|---|
| `_buildHrCard` method | ✅ Three changes |
| `_buildPettyCashCard` method | ❌ Unchanged — already uses `Spacer()` |
| Any other widget/screen | ❌ Unchanged |
| Colors, gradients, borders | ❌ Unchanged |
| Tab structure / filter logic | ❌ Unchanged |
| BLoC / repository / data layer | ❌ Unchanged |

---

## 4. Verification Steps

1. `flutter analyze` — confirm zero new errors or warnings.
2. Hot-reload on Android and iOS device/emulator.
3. Open **Approvals → HR tab**.
4. Confirm no yellow overflow stripe on any HR card.
5. Test edge cases:
   - Long `requestType` string (e.g. "Annual Leave Request - Extended")
   - Long employee name with 3 names (handled by `_limitToFirstThreeNames`)
   - Empty `empCode` field
6. Confirm **Petty Cash tab** cards render correctly (no regression).
7. Confirm **All, RFQ, Invoice tabs** are unaffected.
