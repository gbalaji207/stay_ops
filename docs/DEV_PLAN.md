# DEV_PLAN.md — StayOps

Iterative build plan. Each phase produces a testable APK or verifiable state. Complete and sign off each phase before starting the next.

---

## Phase Overview

| Phase | Focus | Output | Status |
|---|---|---|---|
| 1 | Project setup + Supabase | Schema live, Flutter runs on device | ✅ Done |
| 2 | Auth + Navigation shell | PIN works, bottom nav renders | ✅ Done |
| 3 | Config layer | Rooms/types/sources load from DB | ✅ Done |
| 4 | Booking entry + conflict detection | Can save a booking end-to-end | ✅ Done |
| 5 | Daily view | Room cards + tap-to-edit working | ✅ Done |
| 6 | Monthly view | Heatmap + day detail card working | ✅ Done |
| 7 | Settings | Owner can manage rooms/types/sources | ✅ Done |
| 8 | Home / Dashboard screen | All 6 sections load, card taps open BookingForm | 🔜 Next |
| 9 | Polish + release | Dark mode, edge cases, signed APK | |

---

## Phase 1 — Project Setup & Supabase

### Tasks

**Supabase**
- ✅ Create Supabase project
- ✅ Run table creation SQL: `properties`, `rooms`, `booking_types`, `booking_sources`, `booking_groups`, `booking_days`
- ✅ Create partial unique index on `booking_days (room_id, booking_date) WHERE is_active = true`
- ✅ Disable RLS on all tables
- ✅ Run seed data SQL — property row, 5 rooms, 3 booking types, 5 OTA sources
- ✅ Verify tables and seed data in Supabase Table Editor

**Flutter**
- ✅ `flutter create stay_ops` — clean project
- ✅ Add all dependencies to `pubspec.yaml`
- ✅ Create folder structure (`core/`, `features/`, `shared/`)
- ✅ `core/constants.dart` — `propertyId`, `ownerPin`, `staffPin`
- ✅ `core/supabase_config.dart` — URL + anon key
- ✅ `core/theme/app_theme.dart` — light + dark `ThemeData` with all semantic tokens
- ✅ `main.dart` — `Supabase.initialize()`, `MaterialApp` with `ThemeMode.system`
- ✅ Confirm app launches on device without errors

### Test Checklist
- ✅ App launches and shows blank screen (no crash)
- ✅ Supabase client initialises — verify with a test query in `main.dart` that logs room count to console
- ✅ Remove test query before Phase 2

### Definition of Done
App runs on target Android device. Supabase has seeded data. Theme compiles without errors.

---

## Phase 2 — Auth & Navigation Shell

### Tasks

**Auth**
- ✅ `AuthCubit` + states (`AuthInitial`, `AuthAuthenticated`, `AuthError`)
- ✅ `PINScreen` — logo, 4 dots, numpad grid
- ✅ Auto-submit on 4th digit (no confirm button)
- ✅ Shake animation on wrong PIN
- ✅ Error text below numpad, auto-clear after 2s
- ✅ `AuthCubit` provided at app root

**Navigation**
- ✅ `app.dart` — `go_router` with all routes (`/pin`, `/daily`, `/monthly`, `/entry`, `/settings`, `/settings/rooms`, `/settings/booking-types`, `/settings/booking-sources`)
- ✅ Route guard — unauthenticated → `/pin`; staff → redirect `/settings/*` to `/daily`
- ✅ `HomeShell` — bottom nav with 4 tabs (owner) / 3 tabs (staff)
- ✅ Settings tab fully absent from widget tree for staff role
- ✅ Placeholder screens for Daily, Monthly, Entry, Settings

### Test Checklist
- ✅ Owner PIN → navigates to Daily placeholder, 4-tab nav visible
- ✅ Staff PIN → navigates to Daily placeholder, 3-tab nav visible (no Settings)
- ✅ Wrong PIN → shake + error message → dots reset after 2s
- ✅ Navigating to `/settings` as staff → redirected to `/daily`
- ✅ Back button on Daily does not navigate back to PIN

### Definition of Done
Both PINs work. Role-based nav renders correctly. Route guard blocks staff from settings.

---

## Phase 3 — Config Layer

### Tasks

- ✅ `Room`, `BookingType`, `BookingSource` models (with `fromJson`, extend `Equatable`)
- ✅ `ConfigRepository` — `fetchRooms()`, `fetchBookingTypes()`, `fetchBookingSources()`
  - All queries filter: `is_active=eq.true`, `property_id=eq.<id>`, `order=sort_order.asc`
- ✅ `ConfigCubit` + states (`ConfigLoading`, `ConfigLoaded`, `ConfigError`)
- ✅ `ConfigCubit` provided at app root (above navigator)
- ✅ Post-auth trigger — `BlocListener` on `AuthCubit` calls `ConfigCubit.loadConfig()` on `AuthAuthenticated`
- ✅ `ConfigError` state shows a retry UI (not a blank screen)

### Test Checklist
- ✅ After PIN entry, config loads without error
- ✅ `ConfigLoaded` state contains 5 rooms, 3 booking types, 5 OTA sources
- ✅ Killing network before PIN entry → `ConfigError` state renders retry option
- ✅ Retry succeeds when network restored

### Definition of Done
Config loads for both roles after auth. Cached in `ConfigCubit` for the session.

> **Risk:** If `property_id` in `constants.dart` doesn't match the seeded property UUID, all config queries return empty. Double-check UUID copy-paste.

---

## Phase 4 — Booking Entry & Conflict Detection

### Tasks

**Models**
- ✅ `BookingGroup` model (with `fromJson`, extend `Equatable`)
- ✅ `BookingDay` model
- ✅ `BookingGroupInput` — input DTO for new/edit saves

**Repository**
- ✅ `BookingRepository.checkConflicts(roomId, List<DateTime> nights)` — returns list of conflicting dates
- ✅ `BookingRepository.saveBookingGroup(input)` — INSERT `booking_groups` → get id → INSERT `booking_days` array
- ✅ `BookingRepository.softDeleteConflicts(roomId, dates)` — PATCH `is_active=false`, cascade to parent group if all days inactive

**Cubit**
- ✅ `BookingCubit` + states (`BookingIdle`, `BookingChecking`, `BookingConflict`, `BookingSaving`, `BookingSaved`, `BookingError`)
- ✅ `checkAndSave()` → conflict check → if clear, save; if conflicts, emit `BookingConflict`
- ✅ `confirmOverwrite()` → soft-delete conflicts → save

**UI**
- ✅ `BookingForm` widget — bottom sheet, all fields (see CLAUDE.md)
- ✅ Room dropdown from `ConfigCubit`
- ✅ Booking type chips (single-select) from `ConfigCubit`
- ✅ Booking source dropdown filtered by selected type; hidden if no active sources for type
- ✅ Nights + per-night amount computed display — updates live on date/amount change
- ✅ Save button disabled when `amount == 0` or `check_out <= check_in`
- ✅ Save button label: "Save booking" (new) / "Save changes" (edit)
- ✅ `ConflictDialog` — lists conflicting dates, Cancel + Overwrite buttons
- ✅ `EntryScreen` — opens `BookingForm` as bottom sheet

### Test Checklist
- ✅ Save a single-night booking → verify 1 `booking_groups` row + 1 `booking_days` row in Supabase
- ✅ Save a 3-night booking (₹9,900) → verify 3 `booking_days` rows each with `amount=3300.00`
- ✅ Save a booking where amount doesn't divide evenly (e.g. ₹10,000 / 3) → verify `NUMERIC(10,2)` rounding stored correctly
- ✅ Attempt to save a booking on an already-booked room+date → conflict dialog appears with correct dates listed
- ✅ Cancel conflict dialog → form stays open, no data changed
- ✅ Confirm overwrite → old `booking_days` soft-deleted, new group inserted, form closes
- ✅ Source dropdown hidden when "Offline" or "Direct" type selected (no sources configured)
- ✅ Save button disabled with amount = 0
- ✅ Save button disabled with check-out = check-in

### Definition of Done
New bookings save correctly. Conflict detection works. Overwrite flow soft-deletes correctly.

> **Risk:** The `check_out` exclusive date logic. Night list must be `[check_in, check_in+1, ..., check_out-1]`. Off-by-one here breaks conflict detection and day count display. Unit test this function in isolation.

---

## Phase 5 — Daily View

### Tasks

- ✅ `DailyCubit` + states (`DailyLoading`, `DailyLoaded`, `DailyError`)
- ✅ `DailyCubit.load(date)` — fetches all active `booking_days` for the date, joined with `booking_groups`, `rooms`, `booking_types`, `booking_sources`
- ✅ `DailyCubit.fetchGroupForDay(roomId, date)` — fetches full `booking_group` for edit
- ✅ `DailyScreen` — date navigator, stats bar, scrollable room card list
- ✅ Booked room card — status pill, date range, source tag, per-night amount, payment status
- ✅ Vacant room card — danger-tinted border, "Tap to add booking" hint
- ✅ Booked card tap → fetch group → open `BookingForm` in edit mode (pre-filled)
- ✅ Vacant card tap → open `BookingForm` in new mode (room + date pre-filled)
- ✅ Stats bar: Revenue (sum of `booking_days.amount`), Occupied count, Occupancy %
- ✅ Edit save → `BookingRepository.updateBookingGroup()`:
  - PATCH `booking_groups` metadata
  - Soft-delete removed nights
  - Recalculate and PATCH remaining `booking_days.amount`

### Test Checklist
- ✅ Daily view loads correctly for today
- ✅ All 5 rooms shown — booked rooms show correct source, amount, payment status
- ✅ Vacant room shows "Vacant" pill and hint text
- ✅ Stats bar totals match sum of visible card amounts
- ✅ Tapping a booked card opens edit form pre-filled with correct group data
- ✅ Tapping a vacant card opens new booking form with room + date pre-filled
- ✅ Edit a 3-night booking: change check-out to shorten stay → verify removed night soft-deleted in DB, remaining nights have recalculated amount
- ✅ Edit a booking: change total amount → per-night amount updates correctly
- ✅ Date navigator (‹ ›) loads correct data for adjacent days
- ✅ Amount shown on card = per-night split, not group total (verify with a multi-night booking)

### Definition of Done
Daily view loads, all card states render, edit flow updates DB correctly.

> **Risk:** The edit update sequence (PATCH group → soft-delete removed nights → recalculate remaining amounts) must be atomic enough that a partial failure doesn't leave inconsistent state. Consider wrapping in a try/catch that surfaces a clear error and does not partially commit.

---

## Phase 6 — Monthly View

### Tasks

- ✅ `MonthlyCubit` + states (`MonthlyLoading`, `MonthlyLoaded`, `MonthlyError`)
- ✅ `MonthlyCubit.load(year, month, roomId?)` — fetches all active `booking_days` for the month range
- ✅ Map results to `DayStats` per date: `{ bookedCount, revenue, occupancyPct }`
- ✅ `MonthlyScreen` — month navigator, stats bar, room filter pills, heatmap calendar
- ✅ Heatmap calendar — 7-column grid, correct day-of-week alignment for month start
- ✅ Heatmap cell revenue brackets (all-rooms): 0 / <8k / 8–14k / 14–22k / 22k+
- ✅ Today ring (accent) and selected ring (warning/amber) — visually distinct
- ✅ Revenue label on cell (e.g. "39k") — hidden on level-0 cells
- ✅ Heatmap legend below calendar
- ✅ Room filter pills — "All" + one per active room; filters both heatmap and detail card
- ✅ Day detail card — appears below calendar on date tap; header with date + total; room rows
- ✅ Each room row in detail card: room name, source · type, per-night amount, payment status
- ✅ Room row tap → fetch group → open `BookingForm` in edit mode
- ✅ Tapping a level-0 (empty) date → "No bookings on X" text state in detail area
- ✅ Stats bar: Month Revenue (sum), Avg Occupancy % (mean daily)

### Test Checklist
- ✅ Calendar renders with correct day-of-week alignment for May 2026 (starts on Friday)
- ✅ Heatmap cell colours match revenue brackets
- ✅ Today's date has accent ring; no selected ring until a date is tapped
- ✅ Tapping a date shows correct amber selected ring (today keeps accent ring if today is selected)
- ✅ Day detail card shows correct rooms, amounts, payment status for tapped date
- ✅ Room filter: selecting "Room 101" filters heatmap revenue and detail card rows
- ✅ Room row tap → correct booking group opens in edit form
- ✅ Tapping an empty date shows empty state text
- ✅ Month navigation (‹ ›) loads correct month data
- ✅ Stats bar month revenue matches sum of all booking_days amounts for the month

### Definition of Done
Heatmap renders correctly. Day detail card and room filter work. Tap-to-edit flows through to BookingForm.

> **Risk:** Heatmap revenue brackets are fixed (₹8k/14k/22k). These may feel wrong for properties with very different tariff levels. Flag this to the owner during testing — percentile scaling is a future option.

> **Risk:** Calendar day-of-week alignment. The first cell of the grid must be offset by the weekday index of the 1st of the month. Get this wrong and all dates are shifted. Test with multiple months.

---

## Phase 7 — Settings

### Tasks

- ✅ `SettingsCubit` + states (`SettingsLoading`, `SettingsLoaded`, `SettingsError`)
- ✅ `SettingsScreen` — property card, 3 config rows, sign-out row, version footer
- ✅ Sign out → `AuthCubit.logout()` → `AuthInitial` → router redirects to `/pin`
- ✅ `RoomConfigScreen` — list of rooms with inline edit, add new row
- ✅ `BookingTypeConfigScreen` — list of booking types with inline edit, add new row
- ✅ `BookingSourceConfigScreen` — list of sources with type-filter pills, inline edit, add new row
- ✅ Inline edit pattern — row expands in-place: name input + Save / Cancel / Deactivate
- ✅ Save → PATCH Supabase → `SettingsCubit` updates → `ConfigCubit.reload()`
- ✅ Deactivate → `is_active=false` → row dims to 45% opacity (still visible, restorable)
- ✅ Add new → dashed-border input row at bottom → appends at end of sort order
- ✅ Inactive items visible in settings list but absent from `BookingForm` dropdowns (via `ConfigCubit`)

### Test Checklist
- ✅ Settings tab absent from nav when logged in as staff
- ✅ Direct URL `/settings` as staff → redirected to `/daily`
- ✅ Rename a room → name updates in DB → `ConfigCubit.reload()` → new name appears in BookingForm room dropdown
- ✅ Deactivate a room → dims in settings list → absent from BookingForm dropdown → existing bookings for that room unaffected in Daily/Monthly
- ✅ Restore (re-activate) a room → reappears in BookingForm dropdown
- ✅ Add a new OTA source → appears in BookingForm source dropdown when OTA type selected
- ✅ Deactivate an OTA source → disappears from BookingForm dropdown → historical bookings using it still display correctly
- ✅ Sign out → returns to PIN screen → role cleared (verify Settings tab absent after re-login as staff)
- ✅ Booking type filter pills on sources screen filter correctly

### Definition of Done
Owner can manage all config. Changes reflect immediately in BookingForm via ConfigCubit. Staff cannot access settings.

---

## Phase 8 — Home / Dashboard Screen

### Context

Phases 1–7 are complete. This phase adds the Home/Dashboard screen introduced in v1.2 of the wireframe spec. Key structural changes to the existing app:

- The bottom nav "Entry" tab (pencil-plus) is renamed to "Home" (grid/dashboard icon)
- `EntryScreen` is removed — `BookingForm` is now triggered exclusively via a FAB on HomeScreen and card taps from Daily/Monthly (already working)
- Default post-auth route changes from `/daily` → `/home`
- Route guard for `/settings` redirects to `/home` instead of `/daily`

### Navigation changes (before building HomeScreen)
- ✅ `app.dart` — add `/home` route, remove `/entry` route
- ✅ Update `go_router` default redirect: unauthenticated → `/pin`, post-auth → `/home`
- ✅ Update settings route guard: staff redirect → `/home` (was `/daily`)
- ✅ Update `BlocListener` post-auth navigation: `context.go('/home')`
- ✅ `HomeShell` — rename "Entry" tab to "Home", swap icon to grid/dashboard
- ✅ Verify existing Daily/Monthly/Settings tabs still work after nav refactor

### Repository
- ✅ `HomeRepository` — 6 query methods (all on `booking_groups`, filter `property_id` + `is_active`):
  - `fetchCheckOuts(today)` — `check_out = today`
  - `fetchCheckIns(today)` — `check_in = today`
  - `fetchOccupancy(today)` — COUNT `booking_days` where `booking_date = today`; returns `OccupancySnapshot`
  - `fetchUpcoming(today, {days: 3})` — `check_in` between `today+1` and `today+3`; returns `Map<DateTime, List<BookingGroup>>`
  - `fetchNewToday(today)` — `created_at` within IST day boundaries (see risk note below)
  - `fetchPaymentPending()` — `payment_received = false`

### Models
- ✅ `OccupancySnapshot` model — `occupied`, `vacant`, `pct` fields

### Cubit
- ✅ `HomeCubit` + states (`HomeLoading`, `HomeLoaded`, `HomeError`)
- ✅ `HomeCubit.load()` — fires all 6 queries in parallel via `Future.wait`
- ✅ `HomeCubit.refresh()` — re-runs `load()`

### UI
- ✅ `HomeScreen` — header (time-based greeting + date + property badge), scrollable sections, FAB
- ✅ **Section 1 — Today's Check-outs**: danger-coloured sticky header + count badge, `BookingCard` list, empty state
- ✅ **Section 2 — Today's Check-ins**: success-coloured sticky header + count badge, `BookingCard` list, empty state
- ✅ **Section 3 — Occupancy Today**: `OccupancyStrip` (occupied / vacant / % with mini progress bars)
- ✅ **Section 4 — Upcoming Check-ins**: `UpcomingCard` per date group (Tomorrow label, then dates), empty state
- ✅ **Section 5 — New Bookings Today**: `NewBookingRow` compact list + count badge, empty state
- ✅ **Section 6 — Payment Pending**: warning-coloured sticky header + total-due amount badge, `BookingCard` list, empty state
- ✅ All section headers sticky (pin to top on scroll)
- ✅ All empty sections show italic grey text — never hidden
- ✅ FAB — fixed bottom-right above nav bar, opens `BookingForm` in new-booking mode (no pre-fills)
- ✅ `BookingCard` tap → fetch full group → open `BookingForm` in edit mode
- ✅ Pull-to-refresh → `HomeCubit.refresh()`

**Widgets to create in `features/home/widgets/`**
- ✅ `booking_card.dart` — room name, group total amount, date range, source tag, payment pill; tappable
- ✅ `occupancy_strip.dart` — 3-block card with dividers and progress bars
- ✅ `upcoming_card.dart` — date header + room rows (room name, source, night count, group total)
- ✅ `new_booking_row.dart` — accent dot + room name + date range + group total; compact

### Test Checklist
- ✅ After PIN entry, lands on Home screen (not Daily)
- ✅ 4-tab nav shows Home · Daily · Monthly · Settings (owner); 3-tab for staff
- ✅ Existing Daily, Monthly, Settings screens still load correctly after nav refactor
- ✅ Check-outs section shows rooms where `check_out = today`
- ✅ Check-ins section shows rooms where `check_in = today`
- ✅ Occupancy strip: occupied count matches booked `booking_days` rows for today; vacant = total rooms − occupied
- ✅ Upcoming section: check-ins for next 3 days grouped by date; "Tomorrow" label on first group
- ✅ New bookings today: only groups created today (IST) appear; a booking created yesterday does not appear
- ✅ Payment pending: all unpaid active groups listed; header shows correct sum of `total_amount`
- ✅ All empty sections show italic grey empty-state text, not blank space
- ✅ Tapping any `BookingCard` opens `BookingForm` pre-filled with correct group data
- ✅ FAB opens `BookingForm` with no pre-fills
- ✅ Save from FAB → pull-to-refresh → new booking appears in correct section(s)
- ✅ Pull-to-refresh re-queries all 6 sections and updates UI
- ✅ Staff login → Home screen loads → no Settings tab; all 6 sections visible

### Definition of Done
Home screen loads with correct data in all 6 sections. FAB and card taps open BookingForm correctly. Nav refactor has no regressions on existing screens. Pull-to-refresh works.

> **Risk:** `created_at` timezone boundary. `created_at` is stored as `TIMESTAMPTZ` (UTC). "Created today" must be filtered using IST day boundaries (UTC+5:30) computed in the app, not raw date comparisons. A booking saved at 11pm IST is 5:30pm UTC — raw UTC date filtering would misclassify it as yesterday.

> **Risk:** `fetchPaymentPending()` returns all-time unpaid groups with no date bound. For a property with accumulated historical unpaid bookings this list could be long. Monitor in testing; a date cap is a future option if needed.

> **Risk:** Nav refactor regression. Changing the default route and removing `/entry` touches `go_router` config that all existing screens depend on. Run the full existing-screen smoke test before building any new HomeScreen UI.

---

## Phase 9 — Polish & Release

### Tasks

**Dark mode**
- [ ] Verify all screens in dark mode — no hardcoded colours leaking through
- [ ] Test system theme switch (OS setting change) reflects without restart
- [ ] Heatmap cells, status pills, source tags all render correctly in dark mode
- [ ] Home screen section header colours (danger, success, warning) correct in dark mode
- [ ] FAB shadow renders correctly in dark mode

**Edge cases**
- [ ] First day of month — calendar alignment correct
- [ ] Last day of month — no overflow into next month
- [ ] All rooms vacant on a date — Daily stats bar shows ₹0, 0/5, 0%; Home occupancy strip shows 0/5/0%
- [ ] Home screen all sections empty (quiet day) — every section shows italic grey empty state, no layout shift
- [ ] Booking with ₹0 amount — save button disabled (cannot save)
- [ ] Very long room name or source name — card layout doesn't break on Home, Daily, or Monthly
- [ ] No booking sources configured for a type — source dropdown hidden in BookingForm
- [ ] Config load fails (network error) — retry UI shown, app doesn't crash
- [ ] Home screen load fails (network error) — error state shown, pull-to-refresh available

**Release build**
- [ ] Set final `ownerPin` and `staffPin` in `constants.dart`
- [ ] Confirm `propertyId` is correct UUID
- [ ] Remove any debug logging / test queries
- [ ] Remove "Owner PIN · Staff PIN" hint from PIN screen (or confirm intentional)
- [ ] `flutter build apk --release`
- [ ] Install and full regression test on target Android device
- [ ] Distribute APK

### Final Regression Test (full flow)
- [ ] Fresh install — PIN screen appears
- [ ] Owner login → config loads → **Home screen**
- [ ] Home screen shows correct check-outs, check-ins, occupancy for today
- [ ] Tap FAB → BookingForm opens with no pre-fills → save a single-night booking
- [ ] Tap FAB → save a 3-night booking, verify per-night split
- [ ] Pull-to-refresh on Home → new bookings appear in "New Bookings Today" and correct sections
- [ ] Tap a card in Payment Pending → edit form opens pre-filled → toggle payment received → save → card disappears from section
- [ ] Navigate to Daily view — bookings show correctly
- [ ] Navigate to Monthly view — heatmap shows correct revenue cells
- [ ] Tap a date in Monthly — day detail card shows correct rooms
- [ ] Tap a room row in detail card — edit form opens pre-filled
- [ ] Edit the booking: change check-out date — verify DB updated correctly
- [ ] Attempt a conflicting booking — conflict dialog appears, overwrite works
- [ ] Settings: rename a room, verify change in BookingForm dropdown
- [ ] Settings: deactivate a source, verify absent from BookingForm dropdown
- [ ] Sign out → PIN screen
- [ ] Staff login → 3-tab nav (Home · Daily · Monthly), no Settings tab
- [ ] Staff can add bookings via FAB and edit via card taps on all screens

### Definition of Done
Full regression passes on physical device. Signed APK distributed to owner.

---

## Risk Register

| Risk | Phase | Mitigation |
|---|---|---|
| Off-by-one in night list (`check_out` exclusive) | 4 ✅ | Unit test night list generation before any DB work |
| Partial edit update leaving inconsistent DB state | 5 ✅ | Wrap edit sequence in try/catch; surface clear error |
| Heatmap day-of-week misalignment | 6 ✅ | Test against known months (May 2026 starts Friday) |
| Fixed revenue brackets feeling wrong for property | 6 ✅ | Note as known limitation; percentile mode is a future option |
| Property UUID mismatch (constants vs DB) | 3 ✅ | Verify with a logged query immediately after config load |
| Nav refactor regression (removing `/entry`, changing default route) | 8 | Smoke-test all existing screens before building HomeScreen UI |
| `created_at` timezone boundary for "new today" query | 8 | Compute IST day boundaries (UTC+5:30) in app; never use raw date comparison on TIMESTAMPTZ |
| Payment pending section unbounded growth | 8 | Document as known; add date cap in a future release if needed |
| PIN hardcoded in constants shipped to wrong person | 9 | Change PINs immediately before release build |
