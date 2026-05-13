# DEV_PLAN.md — StayOps

Iterative build plan. Each phase produces a testable APK or verifiable state. Complete and sign off each phase before starting the next.

---

## Phase Overview

| Phase | Focus | Output |
|---|---|---|
| 1 | Project setup + Supabase | Schema live, Flutter runs on device |
| 2 | Auth + Navigation shell | PIN works, bottom nav renders |
| 3 | Config layer | Rooms/types/sources load from DB |
| 4 | Booking entry + conflict detection | Can save a booking end-to-end |
| 5 | Daily view | Room cards + tap-to-edit working |
| 6 | Monthly view | Heatmap + day detail card working |
| 7 | Settings | Owner can manage rooms/types/sources |
| 8 | Polish + release | Dark mode, edge cases, signed APK |

---

## Phase 1 — Project Setup & Supabase

### Tasks

**Supabase**
- [x] Create Supabase project
- [x] Run table creation SQL: `properties`, `rooms`, `booking_types`, `booking_sources`, `booking_groups`, `booking_days`
- [x] Create partial unique index on `booking_days (room_id, booking_date) WHERE is_active = true`
- [x] Disable RLS on all tables
- [x] Run seed data SQL — property row, 5 rooms, 3 booking types, 5 OTA sources
- [x] Verify tables and seed data in Supabase Table Editor

**Flutter**
- [x] `flutter create stay_ops` — clean project
- [x] Add all dependencies to `pubspec.yaml`
- [x] Create folder structure (`core/`, `features/`, `shared/`)
- [x] `core/constants.dart` — `propertyId`, `ownerPin`, `staffPin`
- [x] `core/supabase_config.dart` — URL + anon key
- [x] `core/theme/app_theme.dart` — light + dark `ThemeData` with all semantic tokens
- [x] `main.dart` — `Supabase.initialize()`, `MaterialApp` with `ThemeMode.system`
- [x] Confirm app launches on device without errors

### Test Checklist
- [x] App launches and shows blank screen (no crash)
- [x] Supabase client initialises — verify with a test query in `main.dart` that logs room count to console
- [x] Remove test query before Phase 2

### Definition of Done
App runs on target Android device. Supabase has seeded data. Theme compiles without errors.

---

## Phase 2 — Auth & Navigation Shell

### Tasks

**Auth**
- [ ] `AuthCubit` + states (`AuthInitial`, `AuthAuthenticated`, `AuthError`)
- [ ] `PINScreen` — logo, 4 dots, numpad grid
- [ ] Auto-submit on 4th digit (no confirm button)
- [ ] Shake animation on wrong PIN
- [ ] Error text below numpad, auto-clear after 2s
- [ ] `AuthCubit` provided at app root

**Navigation**
- [ ] `app.dart` — `go_router` with all routes (`/pin`, `/daily`, `/monthly`, `/entry`, `/settings`, `/settings/rooms`, `/settings/booking-types`, `/settings/booking-sources`)
- [ ] Route guard — unauthenticated → `/pin`; staff → redirect `/settings/*` to `/daily`
- [ ] `HomeShell` — bottom nav with 4 tabs (owner) / 3 tabs (staff)
- [ ] Settings tab fully absent from widget tree for staff role
- [ ] Placeholder screens for Daily, Monthly, Entry, Settings

### Test Checklist
- [ ] Owner PIN → navigates to Daily placeholder, 4-tab nav visible
- [ ] Staff PIN → navigates to Daily placeholder, 3-tab nav visible (no Settings)
- [ ] Wrong PIN → shake + error message → dots reset after 2s
- [ ] Navigating to `/settings` as staff → redirected to `/daily`
- [ ] Back button on Daily does not navigate back to PIN

### Definition of Done
Both PINs work. Role-based nav renders correctly. Route guard blocks staff from settings.

---

## Phase 3 — Config Layer

### Tasks

- [ ] `Room`, `BookingType`, `BookingSource` models (with `fromJson`, extend `Equatable`)
- [ ] `ConfigRepository` — `fetchRooms()`, `fetchBookingTypes()`, `fetchBookingSources()`
  - All queries filter: `is_active=eq.true`, `property_id=eq.<id>`, `order=sort_order.asc`
- [ ] `ConfigCubit` + states (`ConfigLoading`, `ConfigLoaded`, `ConfigError`)
- [ ] `ConfigCubit` provided at app root (above navigator)
- [ ] Post-auth trigger — `BlocListener` on `AuthCubit` calls `ConfigCubit.loadConfig()` on `AuthAuthenticated`
- [ ] `ConfigError` state shows a retry UI (not a blank screen)

### Test Checklist
- [ ] After PIN entry, config loads without error
- [ ] `ConfigLoaded` state contains 5 rooms, 3 booking types, 5 OTA sources
- [ ] Killing network before PIN entry → `ConfigError` state renders retry option
- [ ] Retry succeeds when network restored

### Definition of Done
Config loads for both roles after auth. Cached in `ConfigCubit` for the session.

> **Risk:** If `property_id` in `constants.dart` doesn't match the seeded property UUID, all config queries return empty. Double-check UUID copy-paste.

---

## Phase 4 — Booking Entry & Conflict Detection

### Tasks

**Models**
- [ ] `BookingGroup` model (with `fromJson`, extend `Equatable`)
- [ ] `BookingDay` model
- [ ] `BookingGroupInput` — input DTO for new/edit saves

**Repository**
- [ ] `BookingRepository.checkConflicts(roomId, List<DateTime> nights)` — returns list of conflicting dates
- [ ] `BookingRepository.saveBookingGroup(input)` — INSERT `booking_groups` → get id → INSERT `booking_days` array
- [ ] `BookingRepository.softDeleteConflicts(roomId, dates)` — PATCH `is_active=false`, cascade to parent group if all days inactive

**Cubit**
- [ ] `BookingCubit` + states (`BookingIdle`, `BookingChecking`, `BookingConflict`, `BookingSaving`, `BookingSaved`, `BookingError`)
- [ ] `checkAndSave()` → conflict check → if clear, save; if conflicts, emit `BookingConflict`
- [ ] `confirmOverwrite()` → soft-delete conflicts → save

**UI**
- [ ] `BookingForm` widget — bottom sheet, all fields (see CLAUDE.md)
- [ ] Room dropdown from `ConfigCubit`
- [ ] Booking type chips (single-select) from `ConfigCubit`
- [ ] Booking source dropdown filtered by selected type; hidden if no active sources for type
- [ ] Nights + per-night amount computed display — updates live on date/amount change
- [ ] Save button disabled when `amount == 0` or `check_out <= check_in`
- [ ] Save button label: "Save booking" (new) / "Save changes" (edit)
- [ ] `ConflictDialog` — lists conflicting dates, Cancel + Overwrite buttons
- [ ] `EntryScreen` — opens `BookingForm` as bottom sheet

### Test Checklist
- [ ] Save a single-night booking → verify 1 `booking_groups` row + 1 `booking_days` row in Supabase
- [ ] Save a 3-night booking (₹9,900) → verify 3 `booking_days` rows each with `amount=3300.00`
- [ ] Save a booking where amount doesn't divide evenly (e.g. ₹10,000 / 3) → verify `NUMERIC(10,2)` rounding stored correctly
- [ ] Attempt to save a booking on an already-booked room+date → conflict dialog appears with correct dates listed
- [ ] Cancel conflict dialog → form stays open, no data changed
- [ ] Confirm overwrite → old `booking_days` soft-deleted, new group inserted, form closes
- [ ] Source dropdown hidden when "Offline" or "Direct" type selected (no sources configured)
- [ ] Save button disabled with amount = 0
- [ ] Save button disabled with check-out = check-in

### Definition of Done
New bookings save correctly. Conflict detection works. Overwrite flow soft-deletes correctly.

> **Risk:** The `check_out` exclusive date logic. Night list must be `[check_in, check_in+1, ..., check_out-1]`. Off-by-one here breaks conflict detection and day count display. Unit test this function in isolation.

---

## Phase 5 — Daily View

### Tasks

- [ ] `DailyCubit` + states (`DailyLoading`, `DailyLoaded`, `DailyError`)
- [ ] `DailyCubit.load(date)` — fetches all active `booking_days` for the date, joined with `booking_groups`, `rooms`, `booking_types`, `booking_sources`
- [ ] `DailyCubit.fetchGroupForDay(roomId, date)` — fetches full `booking_group` for edit
- [ ] `DailyScreen` — date navigator, stats bar, scrollable room card list
- [ ] Booked room card — status pill, date range, source tag, per-night amount, payment status
- [ ] Vacant room card — danger-tinted border, "Tap to add booking" hint
- [ ] Booked card tap → fetch group → open `BookingForm` in edit mode (pre-filled)
- [ ] Vacant card tap → open `BookingForm` in new mode (room + date pre-filled)
- [ ] Stats bar: Revenue (sum of `booking_days.amount`), Occupied count, Occupancy %
- [ ] Edit save → `BookingRepository.updateBookingGroup()`:
  - PATCH `booking_groups` metadata
  - Soft-delete removed nights
  - Recalculate and PATCH remaining `booking_days.amount`

### Test Checklist
- [ ] Daily view loads correctly for today
- [ ] All 5 rooms shown — booked rooms show correct source, amount, payment status
- [ ] Vacant room shows "Vacant" pill and hint text
- [ ] Stats bar totals match sum of visible card amounts
- [ ] Tapping a booked card opens edit form pre-filled with correct group data
- [ ] Tapping a vacant card opens new booking form with room + date pre-filled
- [ ] Edit a 3-night booking: change check-out to shorten stay → verify removed night soft-deleted in DB, remaining nights have recalculated amount
- [ ] Edit a booking: change total amount → per-night amount updates correctly
- [ ] Date navigator (‹ ›) loads correct data for adjacent days
- [ ] Amount shown on card = per-night split, not group total (verify with a multi-night booking)

### Definition of Done
Daily view loads, all card states render, edit flow updates DB correctly.

> **Risk:** The edit update sequence (PATCH group → soft-delete removed nights → recalculate remaining amounts) must be atomic enough that a partial failure doesn't leave inconsistent state. Consider wrapping in a try/catch that surfaces a clear error and does not partially commit.

---

## Phase 6 — Monthly View

### Tasks

- [ ] `MonthlyCubit` + states (`MonthlyLoading`, `MonthlyLoaded`, `MonthlyError`)
- [ ] `MonthlyCubit.load(year, month, roomId?)` — fetches all active `booking_days` for the month range
- [ ] Map results to `DayStats` per date: `{ bookedCount, revenue, occupancyPct }`
- [ ] `MonthlyScreen` — month navigator, stats bar, room filter pills, heatmap calendar
- [ ] Heatmap calendar — 7-column grid, correct day-of-week alignment for month start
- [ ] Heatmap cell revenue brackets (all-rooms): 0 / <8k / 8–14k / 14–22k / 22k+
- [ ] Today ring (accent) and selected ring (warning/amber) — visually distinct
- [ ] Revenue label on cell (e.g. "39k") — hidden on level-0 cells
- [ ] Heatmap legend below calendar
- [ ] Room filter pills — "All" + one per active room; filters both heatmap and detail card
- [ ] Day detail card — appears below calendar on date tap; header with date + total; room rows
- [ ] Each room row in detail card: room name, source · type, per-night amount, payment status
- [ ] Room row tap → fetch group → open `BookingForm` in edit mode
- [ ] Tapping a level-0 (empty) date → "No bookings on X" text state in detail area
- [ ] Stats bar: Month Revenue (sum), Avg Occupancy % (mean daily)

### Test Checklist
- [ ] Calendar renders with correct day-of-week alignment for May 2026 (starts on Friday)
- [ ] Heatmap cell colours match revenue brackets
- [ ] Today's date has accent ring; no selected ring until a date is tapped
- [ ] Tapping a date shows correct amber selected ring (today keeps accent ring if today is selected)
- [ ] Day detail card shows correct rooms, amounts, payment status for tapped date
- [ ] Room filter: selecting "Room 101" filters heatmap revenue and detail card rows
- [ ] Room row tap → correct booking group opens in edit form
- [ ] Tapping an empty date shows empty state text
- [ ] Month navigation (‹ ›) loads correct month data
- [ ] Stats bar month revenue matches sum of all booking_days amounts for the month

### Definition of Done
Heatmap renders correctly. Day detail card and room filter work. Tap-to-edit flows through to BookingForm.

> **Risk:** Heatmap revenue brackets are fixed (₹8k/14k/22k). These may feel wrong for properties with very different tariff levels. Flag this to the owner during testing — percentile scaling is a future option.

> **Risk:** Calendar day-of-week alignment. The first cell of the grid must be offset by the weekday index of the 1st of the month. Get this wrong and all dates are shifted. Test with multiple months.

---

## Phase 7 — Settings

### Tasks

- [ ] `SettingsCubit` + states (`SettingsLoading`, `SettingsLoaded`, `SettingsError`)
- [ ] `SettingsScreen` — property card, 3 config rows, sign-out row, version footer
- [ ] Sign out → `AuthCubit.logout()` → `AuthInitial` → router redirects to `/pin`
- [ ] `RoomConfigScreen` — list of rooms with inline edit, add new row
- [ ] `BookingTypeConfigScreen` — list of booking types with inline edit, add new row
- [ ] `BookingSourceConfigScreen` — list of sources with type-filter pills, inline edit, add new row
- [ ] Inline edit pattern — row expands in-place: name input + Save / Cancel / Deactivate
- [ ] Save → PATCH Supabase → `SettingsCubit` updates → `ConfigCubit.reload()`
- [ ] Deactivate → `is_active=false` → row dims to 45% opacity (still visible, restorable)
- [ ] Add new → dashed-border input row at bottom → appends at end of sort order
- [ ] Inactive items visible in settings list but absent from `BookingForm` dropdowns (via `ConfigCubit`)

### Test Checklist
- [ ] Settings tab absent from nav when logged in as staff
- [ ] Direct URL `/settings` as staff → redirected to `/daily`
- [ ] Rename a room → name updates in DB → `ConfigCubit.reload()` → new name appears in BookingForm room dropdown
- [ ] Deactivate a room → dims in settings list → absent from BookingForm dropdown → existing bookings for that room unaffected in Daily/Monthly
- [ ] Restore (re-activate) a room → reappears in BookingForm dropdown
- [ ] Add a new OTA source → appears in BookingForm source dropdown when OTA type selected
- [ ] Deactivate an OTA source → disappears from BookingForm dropdown → historical bookings using it still display correctly
- [ ] Sign out → returns to PIN screen → role cleared (verify Settings tab absent after re-login as staff)
- [ ] Booking type filter pills on sources screen filter correctly

### Definition of Done
Owner can manage all config. Changes reflect immediately in BookingForm via ConfigCubit. Staff cannot access settings.

---

## Phase 8 — Polish & Release

### Tasks

**Dark mode**
- [ ] Verify all screens in dark mode — no hardcoded colours leaking through
- [ ] Test system theme switch (OS setting change) reflects without restart
- [ ] Heatmap cells, status pills, source tags all render correctly in dark mode

**Edge cases**
- [ ] First day of month — calendar alignment correct
- [ ] Last day of month — no overflow into next month
- [ ] All rooms vacant on a date — stats bar shows ₹0, 0/5, 0%
- [ ] Booking with ₹0 amount — save button disabled (cannot save)
- [ ] Very long room name or source name — card layout doesn't break
- [ ] No booking sources configured for a type — source dropdown hidden in BookingForm
- [ ] Config load fails (network error) — retry UI shown, app doesn't crash

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
- [ ] Owner login → config loads → Daily view
- [ ] Add a single-night booking via Entry tab
- [ ] Add a 3-night booking via Entry tab, verify per-night split
- [ ] View both bookings in Daily view
- [ ] View month in Monthly view — heatmap shows correct revenue cells
- [ ] Tap a date in Monthly — day detail card shows correct rooms
- [ ] Tap a room row in detail card — edit form opens pre-filled
- [ ] Edit the booking: change check-out date — verify DB updated correctly
- [ ] Attempt a conflicting booking — conflict dialog appears, overwrite works
- [ ] Settings: rename a room, verify change in BookingForm
- [ ] Settings: deactivate a source, verify absent from BookingForm
- [ ] Sign out → PIN screen
- [ ] Staff login → 3-tab nav, no settings access
- [ ] Staff can add and edit bookings

### Definition of Done
Full regression passes on physical device. Signed APK distributed to owner.

---

## Risk Register

| Risk | Phase | Mitigation |
|---|---|---|
| Off-by-one in night list (`check_out` exclusive) | 4 | Unit test night list generation before any DB work |
| Partial edit update leaving inconsistent DB state | 5 | Wrap edit sequence in try/catch; surface clear error |
| Heatmap day-of-week misalignment | 6 | Test against known months (May 2026 starts Friday) |
| Fixed revenue brackets feeling wrong for property | 6 | Note as known limitation; percentile mode is a future option |
| Property UUID mismatch (constants vs DB) | 3 | Verify with a logged query immediately after config load |
| PIN hardcoded in constants shipped to wrong person | 8 | Change PINs immediately before release build |
