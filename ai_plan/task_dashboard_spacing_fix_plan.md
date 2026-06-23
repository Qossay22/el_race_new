# Task Dashboard — Spacing / Overflow Fix Plan

**File:** `ai_plan/task_dashboard_spacing_fix_plan.md`
**Date:** 2026-06-22
**Scope:** Layout/spacing fixes only — no feature changes, no data changes, no redesign.

---

## 1. Problem Analysis

### Affected Screen
`lib/ui/presentation/tasks_dashboard/screens/tasks_dashboard_screen.dart`

### Primary Affected Widget
`_TaskCard` (lines 813–1226) — a `StatefulWidget` rendered inside a `ListView` on the Task Dashboard screen.

### Root of Issue
The card uses a single outer `Row` with `crossAxisAlignment: CrossAxisAlignment.end` containing:
- A left `Expanded` column (dynamic height — grows with assignee count)
- A fixed-height vertical divider (`height: 72`)
- A fixed-width right column (`width: 86`)

The left column's height is **unbounded and data-driven** (it grows when there are multiple assignees, long titles, or a department line). The right column and divider are **fixed-size**, so they never match the left column's actual height. This mismatch is the primary source of visual imbalance and clipping.

---

## 2. UI Breakdown

### Card Container
- **File/line:** line 902–916
- **Margin:** `EdgeInsets.symmetric(vertical: 10, horizontal: 16)` — hardcoded, no responsive units
- **Padding:** `EdgeInsets.all(14)` — hardcoded, no responsive units
- **Border radius:** `BorderRadius.circular(22)` — hardcoded

### Stack (card body, line 917)
- Outer `Stack` holds the `Row` layout + `Positioned` starburst badge
- Badge is `top: 6, right: 6` with size 22 — fixed, no responsive units

### Left Column (lines 923–1126)
- **Title (line 929):** `fontSize: 16`, `fontWeight: w800`, right padding `32` (hardcoded to dodge badge), `maxLines: null` — title can be arbitrarily tall
- **Assignee section (line 944):** Uses a `Builder` → `Column` of rows, one per assignee. Each row has `bottom: 6` padding. **No max height or scroll** — grows unboundedly with assignee count.
- **Department text (line 1013):** `maxLines: 1`, `overflow: ellipsis` — correctly constrained
- **List label (line 1047):** `fontSize: 11`, `overflow: visible` — can overflow if list name is long
- **Progress bar section (lines 1059–1124):**
  - Wrapped in `LayoutBuilder`
  - `SizedBox(height: 24)` containing a `Stack` with `Clip.none` — icon at `bottom: 4` can render outside the SizedBox
  - Track: `height: 4` (hardcoded px)
  - Icon: `16×16` (hardcoded px)
  - Time label below bar: `fontSize: 12`, no overflow handling

### Divider (lines 1129–1133)
- `Container(width: 1, height: 72)` — **hardcoded 72px**, does not adapt to content height

### Right Column (lines 1136–1205)
- `SizedBox(width: 86)` — **fixed 86px**, no responsive scaling
- **START DATE / END DATE labels:** `fontSize: 10` (hardcoded)
- **Date values:** `fontSize: 10`, `overflow: visible` — can wrap unexpectedly inside 86px
- **Days countdown (line 1182–1202):**
  - Number: `fontSize: 40`, `fontWeight: w900`, `height: 0.9` — very large text in a 86px column
  - "Days"/"Late" label: `fontSize: 12`, `fontWeight: w700`
  - `Row(crossAxisAlignment: CrossAxisAlignment.center)` with no `Expanded` or overflow guard — can overflow the 86px boundary if digit count is 3+

---

## 3. Root Causes (Detailed)

### RC-1 — Fixed Divider Height Does Not Match Dynamic Left Column
**Line:** 1131
```
Container(width: 1, height: 72, color: const Color(0xFFD9D9D9))
```
The left column height varies by number of assignees, title length, and presence of a department/list label. The divider is always 72px, leaving it visually misaligned (too short when content is tall, proportionally wrong when content is short).

### RC-2 — Fixed Right Column Width on Variable Content
**Line:** 1136–1137
```
SizedBox(width: 86, child: Column(...))
```
The right column contains a `Row` with a 40sp number + label. On tasks with 3-digit day counts ("100 Days"), the `Row` overflows the 86px container. The column width is not responsive to screen DPI or text scale.

### RC-3 — Non-Responsive Font Sizes
Font sizes throughout the card use raw pixel values (`16`, `14`, `12`, `11`, `10`, `40`) instead of `.sp` (flutter_screenutil responsive units). On high-DPI or large-font-scale devices, text renders larger than anticipated, compressing the available space inside fixed-size containers.

### RC-4 — Non-Responsive Padding and Margins
Card padding (`14`), card margin (`10 / 16`), assignee bottom padding (`6`), progress section spacing (`12`, `4`), right column spacers (`6`, `8`) all use `const EdgeInsets` with raw pixel values. They do not scale with screen size, causing cards to look cramped on small screens and wasteful on large screens.

### RC-5 — Title Right Padding Is Hardcoded to Dodge Badge
**Line:** 928
```
Padding(padding: const EdgeInsets.only(right: 32), ...)
```
The title is padded 32px from the right to avoid visually overlapping with the starburst badge (`size: 22`, `top: 6, right: 6`). This is a hardcoded workaround. On devices where the badge renders larger (due to pixel density or scale), the title may still clip into the badge area or the padding may waste too much title width.

### RC-6 — Progress Bar SizedBox with `Clip.none` Can Overflow
**Lines:** 1074–1108
The progress bar lives in a `SizedBox(height: 24)` Stack with `clipBehavior: Clip.none`. The walker icon is positioned at `bottom: 4` (i.e., 4px above the bottom of the SizedBox) with height 16px, placing its top at y=4 from the top of the SizedBox. This is within bounds, but the `Clip.none` means any slight miscalculation allows the icon to paint outside its parent, overlapping the time label below.

### RC-7 — Days Countdown Row Has No Overflow Guard
**Lines:** 1179–1203
```
Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
  Text('${remainingDays.abs()}', style: TextStyle(fontSize: 40, ...)),
  SizedBox(width: 4),
  Text('Days' / 'Late', style: TextStyle(fontSize: 12, ...)),
])
```
No `Expanded`, `Flexible`, or `FittedBox` wraps the number or label. With a 3-digit remaining day count, the total `Row` width will exceed the 86px `SizedBox`, causing a `RenderFlex overflowed` exception.

### RC-8 — `crossAxisAlignment: CrossAxisAlignment.end` on Outer Row Misaligns Sections
**Line:** 920
```
Row(crossAxisAlignment: CrossAxisAlignment.end, children: [...])
```
Aligning to `.end` (bottom) means the right column and divider anchor to the bottom of the tallest child (the left column). When the left column has 1 assignee, the sections look aligned. When there are 3+ assignees, the right section "floats" at the bottom with large empty space above, and the divider appears detached from the top of the card.

### RC-9 — List Name Text Has No Overflow Protection
**Line:** 1047–1054
The list name is rendered with `overflow: TextOverflow.visible` and no `maxLines`. A long list name can push into adjacent elements or spill out of the card bounds.

---

## 4. Fix Strategy (No Code)

### Fix 1 — Make Divider Height Match Content (RC-1)
Replace the hardcoded `height: 72` divider with an `IntrinsicHeight` wrapper around the entire outer `Row`. `IntrinsicHeight` forces all children (left column, divider, right column) to adopt the same height as the tallest child, so the divider always spans the full card content height.

> ⚠️ `IntrinsicHeight` is an O(n²) layout — it is acceptable here because card content is shallow. If performance concerns arise, an `Align` + `FractionallySizedBox` approach can be used instead.

### Fix 2 — Replace Fixed Right Column Width with Flexible (RC-2, RC-7)
Remove the `SizedBox(width: 86)` wrapper. Instead, give the right column a `ConstrainedBox(constraints: BoxConstraints(minWidth: 80, maxWidth: 110))` to allow slight flexibility. Alternatively, convert the outer `Row` proportions so the right column uses a fixed `flex` fraction via `Flexible(flex: 2, ...)` and the left `Expanded` takes `flex: 5`.

Wrap the days countdown `Row` in a `FittedBox(fit: BoxFit.scaleDown)` so the large font number scales down automatically when the column is too narrow to accommodate 3-digit values.

### Fix 3 — Adopt Responsive Units for Font Sizes (RC-3)
Replace all raw font size values in `_TaskCard` with `.sp` units from `flutter_screenutil`:
- Title: `16` → `16.sp`
- Assignee name: `14` → `14.sp`
- Department / time / list label: `11` → `11.sp`, `12` → `12.sp`
- Date labels: `10` → `10.sp`
- Days number: `40` → `40.sp`
- "Days"/"Late" label: `12` → `12.sp`

### Fix 4 — Adopt Responsive Units for Spacing (RC-4)
Replace `const EdgeInsets` instances in `_TaskCard` with responsive equivalents:
- Card `padding: EdgeInsets.all(14)` → `EdgeInsets.all(14.w)`
- Card `margin: EdgeInsets.symmetric(vertical: 10, horizontal: 16)` → `EdgeInsets.symmetric(vertical: 10.h, horizontal: 16.w)`
- Assignee row bottom padding `6` → `6.h`
- Progress section top spacing `12` → `12.h`
- Progress/time gap `4` → `4.h`
- Right column internal spacers `6`, `8` → `6.h`, `8.h`

### Fix 5 — Fix Title Badge Clearance with Computed Padding (RC-5)
Replace the hardcoded `right: 32` title padding with a value derived from the badge size plus its right margin:
`badge_size (22) + badge_right_offset (6) + inner_gap (4)` = 32 is already approximately correct but should be expressed as a constant or responsive value (`22.r + 6.w + 4.w`) to remain stable across screen sizes.

### Fix 6 — Guard Progress Bar Icon from Overflowing (RC-6)
Change `clipBehavior: Clip.none` to `clipBehavior: Clip.hardEdge` on the progress `Stack`, OR increase the `SizedBox` height from `24` to `28.h` to give the icon sufficient vertical room. Confirm the icon bottom-alignment formula still positions the icon correctly above the track after any height change.

### Fix 7 — Guard Days Row Against 3-Digit Overflow (RC-7)
Wrap the days number `Text` in a `Flexible(fit: FlexFit.loose)` or wrap the entire countdown `Row` in `FittedBox(fit: BoxFit.scaleDown, child: Row(...))` so the layout compresses gracefully rather than overflowing.

### Fix 8 — Change Outer Row Alignment to `CrossAxisAlignment.start` (RC-8)
Change the outer `Row` from `crossAxisAlignment: CrossAxisAlignment.end` to `CrossAxisAlignment.start` so the right column and divider anchor to the top of the card content, matching the natural reading direction. Combined with Fix 1 (`IntrinsicHeight`), all sections will be both top-aligned and equal height.

### Fix 9 — Add Overflow Protection to List Name (RC-9)
Change the list name `Text` `overflow` from `TextOverflow.visible` to `TextOverflow.ellipsis` and set `maxLines: 1`.

---

## 5. UI Safety Rules

- No visual redesign — colors, shapes, icons, badge remain unchanged
- No new UI components introduced
- No data model changes (`TodoModel`, `TodoFirebaseProvider`)
- No feature logic changes (toggle complete, navigation, filtering)
- Only layout constraints, spacing values, and text overflow properties are modified
- All changes confined to `_TaskCard` and its inner widgets in `tasks_dashboard_screen.dart`

---

## 6. File to Modify

| File | Widget | Changes |
|------|---------|---------|
| `lib/ui/presentation/tasks_dashboard/screens/tasks_dashboard_screen.dart` | `_TaskCard` / `_TaskCardState.build()` | All 9 fixes above |

No other files require modification.

---

## 7. Testing Checklist

### Overflow Verification
- [ ] Task card with 1 assignee: no overflow, divider matches content height
- [ ] Task card with 3+ assignees: left column expands, divider and right column stretch to match
- [ ] Task with 3-digit remaining days (e.g., 100+): days row does not overflow the right column
- [ ] Task with no due date: `--` placeholder renders without overflow
- [ ] Task with very long title (40+ chars): title wraps cleanly, badge not overlapped
- [ ] Task with long list name: ellipsis truncates correctly at 1 line

### Layout Consistency
- [ ] All cards in the list show consistent left-edge alignment for titles
- [ ] All cards show consistent right column width
- [ ] Divider is always the same height as the card body content on each card
- [ ] Progress bar icon does not clip outside its SizedBox

### Screen Size Validation
- [ ] Small phone (360×640): no clipping, readable text, no overflow
- [ ] Standard phone (390×844): baseline — must look identical to current design intent
- [ ] Large phone / tablet (412×915+): spacing scales proportionally, not overextended

### Scroll Performance
- [ ] ListView scrolls smoothly with 20+ task cards
- [ ] No jank caused by `IntrinsicHeight` (measure with Flutter DevTools if uncertain)

### Edge Cases
- [ ] Task marked completed: line-through title still wraps correctly
- [ ] Task overdue: red "Late" label fits within right column
- [ ] Task with no assignees: "Unassigned" row displays correctly
- [ ] Task with no department: department line absent, no extra gap left

---

## 8. Implementation Order (Recommended Sequence)

1. **Fix 8** — Change `crossAxisAlignment` to `.start` (lowest risk, immediate alignment improvement)
2. **Fix 1** — Wrap outer Row with `IntrinsicHeight` (makes divider match content)
3. **Fix 9** — List name overflow → ellipsis (1-line change, zero risk)
4. **Fix 6** — Progress bar clip guard (1-line change)
5. **Fix 7** — Days row `FittedBox` (prevents crash on 3-digit values)
6. **Fix 2** — Right column width → flexible (requires testing both narrow and wide devices)
7. **Fix 5** — Title badge clearance → responsive constant
8. **Fix 3** — Font sizes → `.sp` units (touch all Text widgets in _TaskCard)
9. **Fix 4** — Padding/margins → responsive units (touch all EdgeInsets in _TaskCard)

Fixes 1–7 address correctness (overflow/crash). Fixes 8–9 address responsiveness (scale). Implement and test in this order to isolate regressions.
