# Contacts Screen — Employee Contact Card UI Overflow Fix Plan

**Screen:** Contacts (Call Screen)
**Component:** `ContactTile` card — `_buildInfoSection()`
**File:** `lib/ui/presentation/call_screen/call_screen.dart`
**Symptom:** `BOTTOM OVERFLOWED BY X PIXELS` on employee contact cards

---

## 1. Root Cause Analysis

Six compounding issues cause the overflow. They are listed from most to least critical.

### Issue A — Fixed container height (line 444)
The outer Container wrapping the entire card is hard-capped at `height: 85.h`. All content
inside must fit within that absolute ceiling. If even one text field wraps to a second line,
the Column inside overflows. No dynamic text card should use a fixed height.

### Issue B — Narrow hardcoded SizedBox widths force unnecessary wrapping (lines 579, 592)
Both the `department` and `job` text widgets are wrapped in `SizedBox(width: 150)` — a raw
pixel value with no responsive scaling. On a typical phone the usable card width for the info
section is ~280px. Constraining text to 150px (54% of available width) forces two-line wrapping
on values that would fit on one line at full width. Each extra wrapped line adds ~11–14px of
vertical height, quickly pushing past the 85.h ceiling.

**Calculation:**
```
Card usable info width:   ~280px
SizedBox constraint:       150px  (only 54% used)
Department "Information Technology & Digital Transformation"
  → 1 line at 280px = ~13px tall
  → 2 lines at 150px = ~26px tall   ← +13px extra per field
```

### Issue C — All text widgets use `TextOverflow.visible` + `maxLines: null` (lines 571, 584, 597, 608)
Every text widget in the info column is configured to grow freely with no line cap and no
clipping. When long values arrive from the server, the Column grows as tall as it needs,
breaking the fixed `85.h` boundary.

### Issue D — Info Column has no height self-constraint (line 566)
The `Column` inside `_buildInfoSection` uses the default `mainAxisSize: MainAxisSize.max`,
which tells Flutter to consume all available vertical space. This amplifies any content excess
and prevents the Column from sizing itself to its children.

### Issue E — Hardcoded padding not scaled (line 565)
The info section uses `EdgeInsets.only(left: 8.0, top: 10, bottom: 10)` in raw pixels. The
20px of vertical padding consumes space from the already-tight 85.h without scaling on larger
or higher-density screens.

### Issue F — Hardcoded font sizes not responsive (lines 574, 586, 599, 610)
Font sizes `14`, `11`, `12`, `12` are raw pixels, not `.sp` units. On devices with system font
scale above 1.0 (accessibility mode), all text renders larger than designed, amplifying the
overflow further.

---

## 2. Layout Breakdown

```
ContactTile
└── Container(height: 85.h)          ← FIXED HEIGHT — root constraint
    └── Padding(horizontal: 15)
        └── Row(crossAxisAlignment: center)
            ├── AnimatedContainer    ← profile image (80.w × 80.w)
            ├── Expanded
            │   └── AnimatedCrossFade
            │       └── _buildInfoSection()
            │           └── Padding(left:8, top:10, bottom:10)  ← hardcoded
            │               └── Column                          ← no mainAxisSize.min
            │                   ├── Text(name)                  ← maxLines: null, visible
            │                   ├── SizedBox(width:150)         ← forces wrapping
            │                   │   └── Text(department)        ← maxLines: null, visible
            │                   ├── SizedBox(width:150)         ← forces wrapping
            │                   │   └── Text(job)              ← maxLines: null, visible
            │                   └── Text(emp)                   ← maxLines: null, visible
            └── SizedBox(width:105.w)
                └── Container(height:32.h)  ← "Contact Me" button (stable, no change)
```

**Why overflow is exactly ~X pixels:**

```
Container total:         85.h  (~88px on a 390pt phone)
Less vertical padding:  -20px  (top 10 + bottom 10)
Available for text:      ~68px

Worst-case content:
  Name (14px × 1.2 LH × 2 lines):        ~34px
  Department (11px × 1.2 LH × 2 lines):  ~26px
  Job (12px × 1.2 LH × 2 lines):         ~29px
  Employee ID (12px × 1.2 LH × 1 line):  ~14px
  Total:                                  ~103px  ← exceeds 68px = OVERFLOW
```

The `SizedBox(width: 150)` is the multiplier — it turns what would be 1-line fields into
2-line fields, adding ~39px of unnecessary height.

---

## 3. Fix Strategy

All six issues are addressed below. No code is included — this is a strategy plan.

### Fix 1 — Replace fixed height with minimum-height constraint
Remove `height: 85.h` from the card Container. Replace it with
`BoxConstraints(minHeight: 85.h)`. The card stays at 85.h for short content (visually
identical) and grows only when content genuinely requires it. This is the Flutter-correct
approach for cards hosting server-provided dynamic text.

### Fix 2 — Remove the hardcoded `SizedBox(width: 150)` wrappers
Remove both `SizedBox(width: 150)` wrappers from `department` and `job` text widgets. These
text widgets already live inside an `Expanded` widget in the Row, which provides full
available horizontal width. Removing the artificial 150px cap allows text to use the full
width, eliminating the forced wrapping that adds the most vertical height.

### Fix 3 — Cap text lines and use ellipsis for secondary fields
Set `maxLines: 1` and `overflow: TextOverflow.ellipsis` on `department`, `job`, and
`employee ID` fields. These are supplementary data points — a truncated label is far better
UX than a broken card layout. Allow the `name` field a maximum of 2 lines to handle
genuinely long names gracefully, still with `overflow: ellipsis`.

### Fix 4 — Add `mainAxisSize: MainAxisSize.min` to the info Column
The Column in `_buildInfoSection` must be given `mainAxisSize: MainAxisSize.min` so it wraps
its children rather than expanding to fill available space. This is the correct companion to
switching from a fixed `height` to a `minHeight` constraint.

### Fix 5 — Replace hardcoded padding with responsive units
Convert `EdgeInsets.only(left: 8.0, top: 10, bottom: 10)` to `.w`/`.h` scaled units so
padding is proportional across all screen sizes and does not consume a fixed slice of the card
regardless of device.

### Fix 6 — Replace hardcoded font sizes with `.sp` units
Convert font sizes `14`, `11`, `12`, `12` to `.sp` equivalents. This respects the app's
ScreenUtil design baseline and system font-scale settings, preventing accessibility modes
from inflating text beyond the card's intended proportions.

---

## 4. Text Overflow Handling Strategy

| Field | Max lines | Overflow mode | Rationale |
|---|---|---|---|
| Employee name | 2 | ellipsis | Primary identifier — allow one wrap |
| Department | 1 | ellipsis | Secondary info — single line sufficient |
| Job title | 1 | ellipsis | Secondary info — single line sufficient |
| Employee ID | 1 | ellipsis | Always short — one line is always enough |

---

## 5. Responsive Design Strategy

- Use `BoxConstraints(minHeight:)` on any card that displays server-provided text.
- Never place `SizedBox(width: N)` around text that already lives inside an `Expanded` parent.
  The `Expanded` already bounds the available width — further constraining it only causes
  wrapping.
- Replace all raw pixel values (`8.0`, `10`, `150`, `14`, `11`, `12`) with `.w`, `.h`,
  `.sp` equivalents from `flutter_screenutil`.
- Apply `mainAxisSize: MainAxisSize.min` to every Column inside a card that hosts dynamic
  content.

---

## 6. Contact Button Stability

The "Contact Me" button (`SizedBox(width: 105.w)` → `Container(height: 32.h)`) is already
fully responsive and sits at the Row level, entirely outside the info Column. It is not
affected by any of the above changes and requires no modification. It will remain visually
and functionally stable after the fix.

---

## 7. Consistency Across Cards

The inconsistent appearance across different employee cards is a direct consequence of Issue B.
Cards with short department/job names happen to fit within the 150px SizedBox on one line and
appear correct. Cards with longer values wrap to two lines and overflow. After removing the
SizedBox constraints and adding `maxLines: 1` with ellipsis, every card will render identically
regardless of data length.

---

## 8. Prevention Strategy for Future Components

| Rule | Rationale |
|---|---|
| Never use `height:` on a card that displays server text | Use `minHeight` — fixed height breaks on long content |
| Never use `SizedBox(width: N)` inside `Expanded` | `Expanded` already bounds the width — double-constraining causes wrapping |
| Always pair `maxLines: null` with a bounded parent or explicit `maxLines` | Unbounded text in a fixed container always overflows eventually |
| All padding, font sizes, and widths must use `.w`, `.h`, `.sp` | Raw pixels break on non-baseline screen sizes and accessibility font scales |
| Add `mainAxisSize: MainAxisSize.min` to Columns inside cards | Prevents Column from competing for space it doesn't need |

---

## 9. Scope Summary

| Area | Change required | Location |
|---|---|---|
| Card Container height | Yes — replace `height` with `constraints` | Line 444 |
| Info Column `mainAxisSize` | Yes — add `MainAxisSize.min` | Line 566 |
| Info section padding units | Yes — replace raw pixels with `.w`/`.h` | Line 565 |
| `SizedBox(width: 150)` on department | Yes — remove | Line 579 |
| `SizedBox(width: 150)` on job | Yes — remove | Line 592 |
| Text `maxLines` + `overflow` on all 4 fields | Yes — set caps and ellipsis | Lines 571, 583, 596, 607 |
| Font sizes → `.sp` | Yes — convert all 4 values | Lines 574, 586, 599, 610 |
| "Contact Me" button | No change | — |
| Expanded icons section | No change | — |
| BLoC / data / repository | No change | — |
| Any other screen | No change | — |

**Single file to modify:** `lib/ui/presentation/call_screen/call_screen.dart`

---

## 10. Verification Checklist

After applying the fix:

- `dart analyze` on the file returns zero errors
- Contacts screen scrolls without any yellow overflow stripe
- Cards with short names/departments look identical to the original design
- Cards with long department names (e.g. "Information Technology & Digital Transformation")
  show a single truncated line with ellipsis — no overflow
- Cards with long job titles show a single truncated line — no overflow
- Device font scale at 1.3× (accessibility) — no overflow on any card
- Small device (360×640) — all cards render cleanly
- Tap to expand card — icon section renders correctly, layout is stable
- Live search filtering — no card breaks or reflows abnormally during search
- Petty Cash, HR Approvals, and all other screens are unaffected
