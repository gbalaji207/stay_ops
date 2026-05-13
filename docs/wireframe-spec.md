# StayOps — Wireframe & UI Spec

**Product:** StayOps — Hospitality Income Tracker
**Version:** 1.1
**Date:** May 2026
**Scope:** All 5 screens — PIN, Booking Form, Daily, Monthly, Settings

---

## Table of Contents

1. [Design System](#1-design-system)
2. [Screen 1 — PIN Authentication](#2-screen-1--pin-authentication)
3. [Screen 2 — Booking Entry / Edit Form](#3-screen-2--booking-entry--edit-form)
4. [Screen 3 — Daily View](#4-screen-3--daily-view)
5. [Screen 4 — Monthly View](#5-screen-4--monthly-view)
6. [Screen 5 — Settings](#6-screen-5--settings)
7. [Navigation & Role Rules](#7-navigation--role-rules)
8. [Open Design Decisions](#8-open-design-decisions)

---

## 1. Design System

### Theme Strategy
- **Mode:** Dynamic — follows system setting (`ThemeMode.system` in Flutter)
- **Default fallback:** Light mode (if system preference unavailable)
- **Implementation:** All widgets use semantic `ThemeData` color tokens — no hardcoded hex values in widget code. Switching theme requires zero widget changes.

```dart
// main.dart
MaterialApp(
  themeMode: ThemeMode.system,   // follows OS setting
  theme: AppTheme.light,         // light fallback / light OS
  darkTheme: AppTheme.dark,      // dark OS
)
```

---

### Color Tokens

All widgets reference these semantic names. Raw hex values are defined once in `app_theme.dart`.

| Token | Role | Light value | Dark value |
|---|---|---|---|
| `colorBackground` | App / screen background | `#F5F5F7` | `#0D0F1A` |
| `colorSurface` | Cards, bottom sheet | `#FFFFFF` | `#1C1F2E` |
| `colorNav` | Bottom nav, overlays | `#FFFFFF` | `#131520` |
| `colorBorder` | Card borders, dividers | `rgba(0,0,0,0.08)` | `rgba(255,255,255,0.06)` |
| `colorTextPrimary` | Headings, values | `#111118` | `#E8E8F0` |
| `colorTextSecondary` | Meta, labels | `#6B6C7E` | `#9395A5` |
| `colorTextHint` | Placeholders, inactive | `#B0B1C0` | `#5A5C70` |
| `colorAccent` | Primary actions, active nav | `#534AB7` | `#7F77DD` |
| `colorAccentSubtle` | Heatmap, source tags, chips | `rgba(83,74,183,0.12)` | `rgba(83,74,183,0.20)` |
| `colorSuccess` | Payment received, active dot | `#1D9E75` | `#1D9E75` |
| `colorSuccessSubtle` | Success badge bg | `rgba(29,158,117,0.12)` | `rgba(29,158,117,0.20)` |
| `colorWarning` | Payment pending, selected ring | `#D4820A` | `#EF9F27` |
| `colorWarningSubtle` | Warning badge bg | `rgba(212,130,10,0.12)` | `rgba(239,159,39,0.15)` |
| `colorDanger` | Vacant, conflict, deactivate | `#C0392B` | `#E24B4A` |
| `colorDangerSubtle` | Danger badge bg | `rgba(192,57,43,0.10)` | `rgba(231,76,60,0.15)` |
| `colorSheetHandle` | Bottom sheet drag handle | `#D1D1DB` | `#2E3045` |

> Note: `colorWarning` uses a darker value in light mode (`#D4820A` instead of `#EF9F27`) to maintain readable contrast on a white surface.

---

### Typography (unchanged across themes)

- **Screen titles:** 16sp, weight 500, `colorTextPrimary`
- **Body / card text:** 13sp, weight 400, `colorTextPrimary`
- **Secondary / meta:** 11sp, `colorTextSecondary`
- **Hints / inactive:** 10sp, `colorTextHint`

---

### Key Components

| Component | Light | Dark |
|---|---|---|
| Room cards | white bg, `rgba(0,0,0,0.08)` border | `#1C1F2E` bg, `rgba(255,255,255,0.06)` border |
| Bottom sheet | white bg, `#D1D1DB` handle | `#1A1D27` bg, `#2E3045` handle |
| Status pills | Semi-transparent tinted bg | Semi-transparent tinted bg |
| Source tags | `rgba(83,74,183,0.10)` bg, `#534AB7` text | `rgba(83,74,183,0.20)` bg, `#AFA9EC` text |
| Bottom nav | white bg, `#534AB7` active | `#131520` bg, `#7F77DD` active |
| Primary button | `#534AB7` bg, white text | `#534AB7` bg, white text |
| Heatmap cells (0) | `#F0F0F5` | `#131520` |
| Heatmap cells (1–4) | `rgba(83,74,183,0.10–0.55)` | `rgba(83,74,183,0.20–0.82)` |

---

## 2. Screen 1 — PIN Authentication

### Layout
- Full-screen dark background (`#0D0F1A`)
- Vertically centered content: logo mark → app name → subtitle → PIN dots → numpad
- No bottom navigation (pre-auth)

### Logo Mark
- 52×52px rounded square (`border-radius: 16px`), `#534AB7` background
- Building/store icon (white, 26px)
- App name: "StayOps" — 20px, weight 500
- Subtitle: "Hospitality income tracker" — 12px, `#5A5C70`

### PIN Dots
- 4 dots, 13×13px each, 14px gap
- Unfilled: `border: 1.5px solid #3C3489`, transparent fill
- Filled: `background: #7F77DD`, `border-color: #7F77DD`
- Dots fill left-to-right as digits are entered

### Numpad
- 3×4 grid, 72×52px keys, 10px gap, 14px border-radius
- Key background: `#1C1F2E`, border: `1px solid rgba(255,255,255,0.07)`
- Key labels: 22px digit + 9px letter cluster below (ABC, DEF, etc.)
- Bottom-left key: empty (no function)
- Bottom-right key: backspace icon

### Behaviour
| Trigger | Action |
|---|---|
| 4 digits entered | Auto-submits immediately — no confirm button |
| Correct owner PIN (1234) | `AuthCubit.authenticated(role: owner)` → `ConfigCubit.loadConfig()` → navigate `/daily` |
| Correct staff PIN (5678) | `AuthCubit.authenticated(role: staff)` → `ConfigCubit.loadConfig()` → navigate `/daily` |
| Wrong PIN | Shake animation on dots · error text appears below numpad · auto-clears after 2s |
| Backspace | Removes last digit, unfills rightmost filled dot |

### Error State
- Error text: 12px, `#E24B4A`, below numpad, height reserved so layout doesn't shift
- Message: "Incorrect PIN. Try again."

### Role hint
- "Owner PIN · Staff PIN" — 11px, `#3C3066`, below error area
- Visible in development; can be removed for production APK

---

## 3. Screen 2 — Booking Entry / Edit Form

### Trigger Points
The same `BookingForm` widget is reused across all three entry points:

| Entry point | Mode | Pre-filled fields |
|---|---|---|
| Entry tab (bottom nav) | New | None |
| Daily screen — vacant card tap | New | Room, check-in date |
| Daily screen — booked card tap | Edit | All fields from `booking_group` |
| Monthly — day detail row tap | Edit | All fields from `booking_group` |

### Presentation
- Rendered as a **bottom sheet** (slides up from bottom)
- Sheet handle: 28px wide, 3px, centered, `#2E3045`
- Backdrop: `rgba(0,0,0,0.6)` — tapping backdrop closes sheet
- Title: "New booking" (new mode) or "Edit booking — Room XXX" (edit mode)

### Form Fields

| Field | Type | Notes |
|---|---|---|
| Room | Dropdown | From `ConfigCubit.rooms` (active only, sorted) |
| Check-in | Date display / picker | Defaults to today |
| Check-out | Date display / picker | Must be > check-in |
| Nights | Computed display | `check_out − check_in`. Read-only. Updates live. |
| Per-night amount | Computed display | `total_amount ÷ nights`. Read-only. Updates live. |
| Total amount (₹) | Number input | Group-level total. Required. |
| Booking type | Chip selector | From `ConfigCubit.bookingTypes`. Single-select. |
| Booking source | Dropdown | From `ConfigCubit.bookingSources` filtered by selected type. Hidden if selected type has no active sources. |
| Payment received | Toggle | Boolean. Group-level (not per-night). |
| Notes | Text input | Optional. |

### Computed Row
- Purple-tinted row (`rgba(83,74,183,0.15)` bg, `#9B93FF` text)
- Left: "X nights" · Right: "₹X,XXX / night"
- Updates live as check-out date or total amount changes

### Validation
- Save button disabled when: amount = 0, or check-out ≤ check-in
- Save button label: "Save booking" (new) / "Save changes" (edit)

### Conflict Detection Flow
```
User taps save
  → BookingCubit.checkAndSave(input)
  → BookingChecking state (loading indicator on button)
  → BookingRepository.checkConflicts(roomId, nightDates)
    ├── No conflicts → proceed to save → BookingSaved → close sheet
    └── Conflicts found → BookingConflict state → show ConflictDialog
```

### Conflict Dialog
- Modal overlay (`rgba(0,0,0,0.75)` backdrop)
- Title: "Booking conflict" with amber warning icon
- Body: lists each conflicting date as a bullet
- Two buttons: "Cancel" (dismiss, stay on form) | "Overwrite" (red, proceeds)
- Overwrite action: soft-deletes conflicting `booking_days` → inserts new group

### Edit Mode: Range Shrink
When check-out is moved earlier:
- Removed nights: `is_active = false` on their `booking_days` rows (amount preserved)
- `booking_groups` updated: new `check_out`, new `total_amount`
- Remaining `booking_days` amounts recalculated with new split

---

## 4. Screen 3 — Daily View

### Layout
- Header: "Daily" title + date navigator (‹ date ›)
- Stats bar: 3 chips — Revenue / Occupied / Occupancy %
- Scrollable room card list (one card per active room, sorted by `sort_order`)
- Bottom navigation

### Stats Bar
- 3 equal chips, `#1C1F2E` bg, 7px border-radius
- Revenue = sum of `booking_days.amount` for all rooms on that date
- Occupied = count of booked rooms
- Occupancy % = occupied ÷ total active rooms × 100

### Room Cards

**Booked card:**
- Status pill: "Booked" — `rgba(29,158,117,0.2)` bg, `#5DCAA5` text
- Meta: date range + night count, source tag (purple tint)
- Amount: per-night split (`booking_days.amount`), NOT the group total
- Payment: "Received" (`#5DCAA5`) or "Pending" (`#EF9F27`)
- Tap: fetches full `booking_group` via `DailyCubit.fetchGroupForDay(roomId, date)` → opens `BookingForm` in edit mode

**Vacant card:**
- Status pill: "Vacant" — `rgba(231,76,60,0.15)` bg, `#F09595` text
- Subtle red border tint: `border-color: rgba(231,76,60,0.2)`
- Body: italic hint "Tap to add booking", amount "—"
- Tap: opens `BookingForm` in new mode, room + date pre-filled

### Amount Display Note
The amount shown on a Daily card is the **per-night split** for that specific date, not the booking group total. The group total is only visible inside the edit form. This avoids confusion on multi-night bookings.

### Role Difference
- Owner: 4-tab bottom nav (Entry · Daily · Monthly · Settings)
- Staff: 3-tab bottom nav (Entry · Daily · Monthly) — Settings tab absent entirely

---

## 5. Screen 4 — Monthly View

### Layout
- Header: "Monthly" title + month navigator (‹ May 2026 ›)
- Stats bar: 2 chips — Month Revenue / Avg Occupancy %
- Room filter pill row (All · Room 101 · Room 102 … )
- Heatmap calendar grid
- Heatmap legend (Low → High)
- Day detail card (appears below calendar when a date is tapped)
- Bottom navigation

### Stats Bar
- Month revenue = sum of all active `booking_days.amount` for the month
- Avg occupancy = mean daily occupancy % across all days in the month

### Room Filter Pills
- Single-select. "All" = no room filter.
- Filters both heatmap revenue values and day detail rows
- Active pill: `#534AB7` bg, `#EEEDFE` text

### Heatmap Calendar

**Grid:** 7 columns (S M T W T F S), rows per week, cells are square aspect-ratio

**Revenue brackets (all-rooms view):**
| Level | Revenue range | Background |
|---|---|---|
| 0 (empty) | ₹0 | `#131520` (darkest, no label) |
| 1 (low) | < ₹8,000 | `rgba(83,74,183,0.20)` |
| 2 | ₹8,000 – ₹14,000 | `rgba(83,74,183,0.38)` |
| 3 | ₹14,000 – ₹22,000 | `rgba(83,74,183,0.60)` |
| 4 (high) | ₹22,000+ | `rgba(83,74,183,0.82)` |

> **Open decision:** Fixed brackets vs. relative percentiles (darkest = highest day of the month). Percentiles adapt better to properties with different tariff levels.

**Cell content:**
- Day number: 9px, weight 500
- Revenue label: 7px below day number (e.g. "₹39k"), hidden on level-0 cells

**Ring states:**
- Today: `1.5px solid #7F77DD` (purple)
- Selected (tapped): `1.5px solid #EF9F27` (amber) — visually distinct from today

### Day Detail Card
- Appears below calendar when any non-empty date is tapped
- Header: date label (left) + total revenue for that date (right, purple)
- One row per booked room:
  - Left: room name + source · type
  - Right: per-night amount + payment status
- Each row is tappable → opens `BookingForm` in edit mode for that room's group
- Tapping an empty (level-0) date shows "No bookings on X May" text state

---

## 6. Screen 5 — Settings

### Access Control
- Settings tab visible **only** for owner role — not greyed out for staff, fully absent from nav
- Route guard: `/settings/*` redirects to `/daily` if `role != owner`

### Settings Hub Layout
- **Property card:** Property name + truncated UUID. Read-only display.
- **Configuration section:** 3 rows — Rooms · Booking types · Booking sources. Each shows active count and chevron.
- **Session section:** Sign out row (red icon, chevron).
- **Version footer:** "StayOps v1.1 · May 2026"

### Sign Out
- Calls `AuthCubit.logout()` → emits `AuthInitial` → router redirects to `/pin`
- In-memory role cleared; no network call needed

### Config Sub-Screens (Rooms / Booking Types / Booking Sources)

**List pattern:**
- Back arrow + "Settings" label at top
- Screen title
- List of items in a grouped card (rounded group, dividers between rows)
- Inline "Add new…" input at bottom of list

**Each list row:**
- Left: item name + subtitle (sort order for rooms, type name for sources)
- Right: active indicator dot (green = active, dim = inactive) + edit icon button

**Active indicator:**
- Green dot (`#1D9E75`) = `is_active = true`
- Dim dot (`#3C3066`) = `is_active = false`
- Inactive rows rendered at 50% opacity — still visible, restorable

**Inline edit state (tap edit icon):**
- Row expands in-place, no separate screen
- Shows: text input (pre-filled with current name), "Save" button, "Cancel" button, "Deactivate" button
- Save: PATCH to Supabase → `SettingsCubit` → `ConfigCubit.reload()`
- Deactivate: sets `is_active = false` → row dims → removed from Entry form dropdowns

**Add new row:**
- Dashed-border input row pinned below the list
- `rgba(83,74,183,0.4)` dashed border, purple "+" icon
- Submitting appends item at end of sort order

### Booking Sources Screen Extra: Type Filter
- Pill row above the list: OTA · Offline · Direct
- Filters visible sources to those linked to the selected type
- Helps manage long source lists

### Post-Save Behaviour
After any write (add, edit, deactivate):
1. `SettingsCubit` PATCHes Supabase
2. Calls `ConfigCubit.reload()`
3. Session cache updated immediately
4. Staff on Entry screen see updated dropdowns on next form open

---

## 7. Navigation & Role Rules

### Bottom Nav Tabs

| Tab | Icon | Owner | Staff |
|---|---|---|---|
| Entry | pencil-plus | Visible | Visible |
| Daily | calendar-event | Visible | Visible |
| Monthly | calendar-month | Visible | Visible |
| Settings | settings | Visible | **Hidden** |

### Route Guard Logic
```dart
redirect: (context, state) {
  final auth = authCubit.state;
  if (auth is! AuthAuthenticated) return '/pin';
  if (state.matchedLocation.startsWith('/settings')) {
    if (auth.role != UserRole.owner) return '/daily';
  }
  return null;
}
```

### Default Route After Login
Both roles navigate to `/daily` after successful PIN entry.

---

## 8. Open Design Decisions

| # | Decision | Options | Status |
|---|---|---|---|
| 1 | Heatmap colour scale | Fixed brackets (₹8k/14k/22k) vs. relative percentiles (darkest = highest day of month) | **Open** |
| 2 | Booking source: hide vs. empty state | When selected type has no sources — hide dropdown entirely vs. show disabled "No sources configured" | **Decided: hide entirely** |
| 3 | Conflict dialog room name | Show room name alongside conflicting dates (useful in multi-room context) | **Decided: show room name** |
| 4 | Save button label | "Save booking" / "Save changes" (distinguishes modes) vs. single "Save" | **Decided: distinct labels** |
| 5 | Inline edit vs. edit screen | Settings items expand inline vs. navigate to dedicated edit screen | **Decided: inline for v1** |
| 6 | Heatmap brackets when room filter active | Single-room view has lower revenue — brackets may need adjusting or switch to percentiles | **Open** |
| 7 | Theme | Dynamic (follows OS setting), default fallback = light mode | **Decided: dynamic, light default** |
