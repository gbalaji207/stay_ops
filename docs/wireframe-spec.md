# StayOps — Wireframe & UI Spec

**Product:** StayOps — Hospitality Income Tracker
**Version:** 1.2
**Date:** May 2026
**Scope:** All 6 screens — PIN, Home (Dashboard), Booking Form, Daily, Monthly, Settings

---

## Table of Contents

1. [Design System](#1-design-system)
2. [Screen 1 — PIN Authentication](#2-screen-1--pin-authentication)
3. [Screen 2 — Home / Dashboard](#3-screen-2--home--dashboard)
4. [Screen 3 — Booking Entry / Edit Form](#4-screen-3--booking-entry--edit-form)
5. [Screen 4 — Daily View](#5-screen-4--daily-view)
6. [Screen 5 — Monthly View](#6-screen-5--monthly-view)
7. [Screen 6 — Settings](#7-screen-6--settings)
8. [Navigation & Role Rules](#8-navigation--role-rules)
9. [Open Design Decisions](#9-open-design-decisions)

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
| Correct owner PIN (1234) | `AuthCubit.authenticated(role: owner)` → `ConfigCubit.loadConfig()` → navigate `/home` |
| Correct staff PIN (5678) | `AuthCubit.authenticated(role: staff)` → `ConfigCubit.loadConfig()` → navigate `/home` |
| Wrong PIN | Shake animation on dots · error text appears below numpad · auto-clears after 2s |
| Backspace | Removes last digit, unfills rightmost filled dot |

> Note: default route after login is `/home` (was `/daily` in v1.1). Both roles land on the Home screen.

### Error State
- Error text: 12px, `#E24B4A`, below numpad, height reserved so layout doesn't shift
- Message: "Incorrect PIN. Try again."

### Role hint
- "Owner PIN · Staff PIN" — 11px, `#3C3066`, below error area
- Visible in development; can be removed for production APK

---

## 3. Screen 2 — Home / Dashboard

> **New in v1.2.** Replaces the old Entry tab as the first tab in the bottom nav. The "Entry" tab label and icon are replaced by "Home" with a grid/dashboard icon. New bookings are initiated via a FAB (floating action button) instead.

### Layout
- **Header:** Greeting ("Good morning 👋") + date · Property badge (top-right)
- **Scrollable body:** 6 sections, each with a sticky section header
- **FAB:** Fixed position above bottom nav — opens `BookingForm` in new-booking mode
- **Bottom navigation:** Home · Daily · Monthly · Settings (owner) / Home · Daily · Monthly (staff)

### Header
- Greeting text: 17sp, weight 600, `colorTextPrimary`
  - Time-based: "Good morning" (5am–12pm), "Good afternoon" (12pm–5pm), "Good evening" (5pm–5am)
- Date line: 11sp, `colorTextSecondary` — e.g. "Thursday, 15 May 2026"
- Property badge (top-right): accent-subtle background, property name in `colorAccent`, small building emoji

### Sections

All 6 sections always render. If a section has no data it shows an italic grey empty-state row — never hidden entirely, to avoid layout shift on scroll.

Section headers are **sticky** — they pin to the top of the scroll area as the user scrolls, so section context is never lost.

#### Section 1 — Today's Check-outs
- Header colour: `colorDanger`
- Icon: door-exit arrow
- Count badge: "N rooms" (right-aligned)
- Cards: one `BookingCard` per group where `check_out = today` and `is_active = true`
- Empty state: "No check-outs today"
- **Data query:** `booking_groups WHERE check_out = today AND is_active = true`

#### Section 2 — Today's Check-ins
- Header colour: `colorSuccess`
- Icon: door-enter arrow
- Count badge: "N rooms"
- Cards: one `BookingCard` per group where `check_in = today` and `is_active = true`
- Empty state: "No check-ins today"
- **Data query:** `booking_groups WHERE check_in = today AND is_active = true`

#### Section 3 — Occupancy Today
- No count badge
- **Occupancy strip** (single card): 3 blocks separated by 1px dividers
  - Block 1 — Occupied count (`colorSuccess`, large numeral)
  - Block 2 — Vacant count (`colorDanger`, large numeral)
  - Block 3 — Occupancy % (`colorAccent`, large numeral)
  - Each block has a thin progress bar below the label
- **Data query:** `COUNT booking_days WHERE booking_date = today AND is_active = true`. Vacant = total active rooms − occupied.

#### Section 4 — Upcoming Check-ins
- Count badge: "Next 3 days"
- Grouped by date into `UpcomingCard` components (one card per date)
  - Card day header: "Tomorrow · 16 May" or "17 May" etc. — 10sp, `colorAccent`, uppercase
  - Each row within a card: room name + source (left) · night count + group total amount (right)
- Empty state: "No upcoming check-ins in the next 3 days"
- **Data query:** `booking_groups WHERE check_in IN (today+1, today+2, today+3) AND is_active = true`. Grouped by `check_in`.

#### Section 5 — New Bookings Today
- Count badge: "N added"
- Compact `NewBookingRow` layout (smaller than BookingCard):
  - Accent dot · Room name + "New" badge · date range (left) · group total (right)
- Covers bookings *entered* today for any stay date — not same-day arrivals only
- Empty state: "No new bookings recorded today"
- **Data query:** `booking_groups WHERE DATE(created_at) = today AND is_active = true`

#### Section 6 — Payment Pending
- Header colour: `colorWarning`
- Icon: clock
- Count badge: total pending amount ("₹XX,XXX due") — sum of all pending `total_amount` values
- Cards: one `BookingCard` per group where `payment_received = false AND is_active = true`
- Empty state: "All payments received"
- **Data query:** `booking_groups WHERE payment_received = false AND is_active = true`

### BookingCard (shared component used in sections 1, 2, 6)

```
┌──────────────────────────────────────────┐
│  Room 101                      ₹9,900    │
│  May 13 → 16 · 3 nights  [MakeMyTrip] [Pending] │
└──────────────────────────────────────────┘
```

- Room name: 13sp, weight 600
- Amount: 14sp, weight 600 (group total, not per-night split)
- Date range + night count: 11sp, `colorTextSecondary`
- Source tag: accent-subtle bg
- Payment pill: success/warning tint
- **Tapping any card** → `HomeCubit.fetchGroup(groupId)` → opens `BookingForm` in edit mode pre-filled with full `booking_group`

### FAB
- Fixed position, bottom-right, above bottom nav (bottom: 66px, right: 18px)
- 48×48px, 16px border-radius, `colorAccent` background
- Plus icon (white, 22px stroke)
- Shadow: `0 4px 16px rgba(83,74,183,0.35)` light / `0 4px 20px rgba(83,74,183,0.5)` dark
- **Tapping FAB** → opens `BookingForm` as bottom sheet in new-booking mode (no pre-fills)

### HomeCubit
New cubit required (feature-level scope):

```dart
// States
class HomeLoading extends HomeState {}
class HomeLoaded extends HomeState {
  final List<BookingGroup> checkOuts;
  final List<BookingGroup> checkIns;
  final OccupancySnapshot occupancy;
  final Map<DateTime, List<BookingGroup>> upcoming;  // next 3 days, grouped by date
  final List<BookingGroup> newToday;
  final List<BookingGroup> paymentPending;
}
class HomeError extends HomeState { final String message; }

// Key method
Future<void> load() async {
  emit(HomeLoading());
  // 5 parallel queries via BookingRepository + HomeRepository
  // ...
  emit(HomeLoaded(...));
}
```

### Data Notes
- All 6 queries run in parallel on screen load and on pull-to-refresh
- `created_at` is already on `booking_groups` — no schema change needed
- Amount shown in sections 1, 2, 6 is the **group total** (`booking_groups.total_amount`), not the per-night split. This matches the context (check-in/out and payment are group-level events)
- Upcoming check-ins (section 4) also show group total per upcoming booking

### Role Difference
- Owner: 4-tab bottom nav (Home · Daily · Monthly · Settings)
- Staff: 3-tab bottom nav (Home · Daily · Monthly) — Settings tab absent entirely
- Both roles see all 6 dashboard sections

---

## 4. Screen 3 — Booking Entry / Edit Form

### Trigger Points
The same `BookingForm` widget is reused across all entry points:

| Entry point | Mode | Pre-filled fields |
|---|---|---|
| Home screen FAB | New | None |
| Home — any booking card tap | Edit | All fields from `booking_group` |
| Daily screen — vacant card tap | New | Room, check-in date |
| Daily screen — booked card tap | Edit | All fields from `booking_group` |
| Monthly — day detail row tap | Edit | All fields from `booking_group` |

> Note: the old "Entry tab" direct bottom-nav route is removed in v1.2. The FAB on Home is the primary new-booking entry point.

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
| Notes | Text field | Optional. |

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
- Body: lists each conflicting date + room name as bullets
- Two buttons: "Cancel" (dismiss, stay on form) | "Overwrite" (red, proceeds)
- Overwrite action: soft-deletes conflicting `booking_days` → inserts new group

### Edit Mode: Range Shrink
When check-out is moved earlier:
- Removed nights: `is_active = false` on their `booking_days` rows (amount preserved)
- `booking_groups` updated: new `check_out`, new `total_amount`
- Remaining `booking_days` amounts recalculated with new split

---

## 5. Screen 4 — Daily View

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
- Owner: 4-tab bottom nav (Home · Daily · Monthly · Settings)
- Staff: 3-tab bottom nav (Home · Daily · Monthly) — Settings tab absent entirely

---

## 6. Screen 5 — Monthly View

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

## 7. Screen 6 — Settings

### Access Control
- Settings tab visible **only** for owner role — not greyed out for staff, fully absent from nav
- Route guard: `/settings/*` redirects to `/home` if `role != owner`

### Settings Hub Layout
- **Property card:** Property name + truncated UUID. Read-only display.
- **Configuration section:** 3 rows — Rooms · Booking types · Booking sources. Each shows active count and chevron.
- **Session section:** Sign out row (red icon, chevron).
- **Version footer:** "StayOps v1.2 · May 2026"

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
4. Staff on any screen will see updated dropdowns on next form open

---

## 8. Navigation & Role Rules

### Bottom Nav Tabs

| Tab | Icon | Owner | Staff |
|---|---|---|---|
| Home | grid/dashboard | Visible | Visible |
| Daily | calendar-event | Visible | Visible |
| Monthly | calendar-month | Visible | Visible |
| Settings | settings | Visible | **Hidden** |

> **v1.2 change:** The "Entry" tab (pencil-plus icon) has been replaced by "Home" (grid/dashboard icon). New bookings are created via the FAB on the Home screen rather than via a dedicated bottom-nav tab. This applies to both owner and staff.

### Route Guard Logic
```dart
redirect: (context, state) {
  final auth = authCubit.state;
  if (auth is! AuthAuthenticated) return '/pin';
  if (state.matchedLocation.startsWith('/settings')) {
    if (auth.role != UserRole.owner) return '/home';
  }
  return null;
}
```

### Default Route After Login
Both roles navigate to `/home` (Home / Dashboard screen) after successful PIN entry.

### go_router Route Changes (v1.2)
- `/home` — new HomeScreen (replaces `/entry` as default post-auth destination)
- `/entry` — **removed** (no longer a standalone route; BookingForm is always modal)
- `/daily`, `/monthly`, `/settings/*` — unchanged

---

## 9. Open Design Decisions

| # | Decision | Options | Status |
|---|---|---|---|
| 1 | Heatmap colour scale | Fixed brackets (₹8k/14k/22k) vs. relative percentiles (darkest = highest day of month) | **Open** |
| 2 | Booking source: hide vs. empty state | When selected type has no sources — hide dropdown entirely vs. show disabled "No sources configured" | **Decided: hide entirely** |
| 3 | Conflict dialog room name | Show room name alongside conflicting dates (useful in multi-room context) | **Decided: show room name** |
| 4 | Save button label | "Save booking" / "Save changes" (distinguishes modes) vs. single "Save" | **Decided: distinct labels** |
| 5 | Inline edit vs. edit screen | Settings items expand inline vs. navigate to dedicated edit screen | **Decided: inline for v1** |
| 6 | Heatmap brackets when room filter active | Single-room view has lower revenue — brackets may need adjusting or switch to percentiles | **Open** |
| 7 | Theme | Dynamic (follows OS setting), default fallback = light mode | **Decided: dynamic, light default** |
| 8 | Payment Pending scope | Show ALL pending groups (unbounded) vs. cap to current month or recent N days | **Open** |
| 9 | Home screen refresh | Manual pull-to-refresh only vs. auto-refresh on app foreground | **Open** |
| 10 | Greeting personalisation | Static "Good morning/afternoon/evening" vs. include property name in greeting | **Open** |

---

## Appendix — v1.2 Change Summary

This version adds the Home / Dashboard screen and makes the following changes to existing screens and documentation.

### New
- **Screen 2 — Home / Dashboard** (new screen, replaces Entry tab)
- **HomeCubit** — new feature-level cubit with 5 parallel data queries
- **FAB** — floating action button on Home screen as primary new-booking entry point
- **UpcomingCard** component — date-grouped card for upcoming check-ins section
- **NewBookingRow** component — compact row for new bookings today section

### Changed
- **Bottom nav:** "Entry" tab (pencil-plus) → "Home" tab (grid/dashboard icon) on all screens
- **Default post-auth route:** `/daily` → `/home`
- **Route guard redirect:** Settings guard now redirects to `/home` instead of `/daily`
- **BookingForm trigger points:** FAB on Home added as entry point; Entry tab route removed
- **go_router routes:** `/entry` removed; `/home` added

### Unchanged
- All colour tokens and theme system
- BookingForm fields, validation, and conflict flow
- Daily screen layout and behaviour
- Monthly screen layout and behaviour
- Settings screen layout and behaviour
- All database schema and API contracts
- Role-based access control (staff cannot access Settings)
- PIN authentication screen
