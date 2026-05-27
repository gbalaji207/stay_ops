# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Mobile-first hospitality income tracker. Flutter Android APK + Supabase backend. Supports multiple properties per PIN.

---

## Commands

```bash
flutter pub get          # install dependencies
flutter run              # debug on connected device/emulator
flutter build apk        # release APK
flutter test             # all tests
flutter test test/widget_test.dart   # single test file
flutter analyze          # static analysis (flutter_lints)
dart analyze lib/        # faster targeted analysis
```

---

## Stack & Dependencies

```yaml
supabase_flutter: ^2.x
flutter_bloc: ^9.x       # Cubit pattern only — no full Bloc
go_router: ^17.x
intl: ^0.20
equatable: ^2.x
shared_preferences: ^2.x  # persists last selected property across sessions
```

---

## Project Structure

```
lib/
├── core/
│   ├── constants.dart          # AppConstants (propertyId/sfHotelId getters) + AppSession (mutable active property)
│   ├── supabase_config.dart
│   └── theme/app_theme.dart
├── features/
│   ├── auth/         # pin_screen, auth_cubit, auth_state
│   ├── config/       # config_cubit, config_repository, config_state (app-level, all roles)
│   ├── booking/
│   │   ├── wizard/   # booking_wizard_screen, wizard_step1–4, booking_wizard_extras,
│   │   │             # sf_booking_prefill, booking_group_input
│   │   └── widgets/  # stay_flexi_search_dialog
│   ├── daily/        # daily_screen, daily_cubit, daily_repository, room_day_status, day_booking_row
│   ├── home/
│   │   ├── cubit/        # home_cubit, home_state
│   │   ├── repository/   # home_repository
│   │   ├── screens/      # home_screen, payment_update_screen
│   │   ├── widgets/      # booking_card, occupancy_strip, upcoming_card, new_booking_row
│   │   └── payment_update_extras.dart   # route carrier for /payment/update
│   ├── monthly/      # monthly_screen, monthly_cubit, monthly_repository, month_booking_row, day_stats
│   ├── reports/      # reports_screen, payment_report_screen, booking_type_report_screen,
│   │               # booking_source_report_screen, reports_cubit, reports_repository
│   └── settings/     # owner only — rooms, booking_types, booking_sources, payment_destinations
└── shared/
    ├── models/       # room, booking_type, booking_source, booking_group, booking_day,
    │                 # payment_destination, room_payment_summary, room_category_summary,
    │                 # occupancy_snapshot, property_info
    └── widgets/      # conflict_dialog, app_text_field, app_dropdown_field,
                      # app_date_picker, app_date_range_picker
```

---

## Shared Form Widgets

All form fields use these four components. Never use raw `TextField` or `DropdownButton` in new UI — always use the shared widgets for consistent floating labels, theming, and border behavior.

| Widget | Use for |
|---|---|
| `AppTextField` | Any text input. Supports `prefixText` (e.g. `'₹ '`), `maxLines`, `fontSize`, `hintText`. |
| `AppDropdownField<T>` | Dropdowns. Generic over value type. Set `searchable: true` for large lists (opens a search dialog). Items are `AppDropdownItem<T>`. |
| `AppDatePicker` | Single date. Set `includeTime: true` for a date+time chain. Accepts `firstDate`/`lastDate`. |
| `AppDateRangePicker` | Check-in → check-out pair. Calls `showDateRangePicker`. Takes `checkIn`, `checkOut`, `onRangeSelected`. |

All four use `Theme.of(context).extension<AppColors>()!` — never static color references. When a source dropdown value depends on a filtered list, guard it:
```dart
value: filteredSources.any((s) => s.id == selectedSourceId) ? selectedSourceId : null,
```

---

## Auth

PIN verification is async — queries Supabase `pins` table. PINs are **not** hardcoded.

```dart
enum UserRole { none, staff, owner }
// States: AuthInitial | AuthLoading | AuthAuthenticated(role, properties, activePropertyId) | AuthError(message)
```

On 4th digit entered → auto-submit → emits `AuthLoading` (shows spinner) → Supabase lookup → `AuthAuthenticated` or `AuthError`. Wrong PIN → shake + error → auto-clear after 2s.

After `AuthAuthenticated` is emitted → `app.dart` `BlocListener` calls `ConfigCubit.loadConfig()` for **all roles** → GoRouter navigates to `/home`.

The PIN screen is always rendered in dark theme regardless of system setting.

### Multi-property

`AuthAuthenticated` carries `List<PropertyInfo> properties` and `String activePropertyId`. On login, the last selected property (stored in `SharedPreferences` under `last_active_property_id`) is restored if it still belongs to the PIN — otherwise defaults to `properties.first`.

`AuthCubit.switchProperty(id)` updates `AppSession`, persists the new ID, and re-emits `AuthAuthenticated`. This triggers the `app.dart` listener which reloads config for the new property.

The home screen header shows `auth.activeProperty.name` in an `accentSubtle` pill (top-right). When the PIN has more than one property, the pill shows a swap icon and opens a bottom-sheet picker (`_showPropertySwitcher`) that calls `AuthCubit.switchProperty`. Single-property PINs see a non-tappable label.

### AppSession & AppConstants

`AppConstants.propertyId` and `AppConstants.sfHotelId` are **getters** that proxy through `AppSession._activePropertyId / _activeSfHotelId` (mutable statics). Call `AppSession.setActiveProperty(PropertyInfo)` to update — all 28+ repository call-sites that use `AppConstants.propertyId` update transparently with no further changes.

### Supabase schema for auth

```
pins (id, pin TEXT, role TEXT CHECK('owner'|'staff'), is_active BOOL)
properties (id, name TEXT, sf_hotel_id TEXT, is_active BOOL)
pin_properties (pin_id FK, property_id FK, sort_order INT)  -- many-to-many
```

---

## Cubits

| Cubit | Scope | Notes |
|---|---|---|
| `AuthCubit` | App-level | PIN verification, role, property list + active property, session |
| `ConfigCubit` | App-level | Rooms + types + sources + destinations for the **active property**. Loaded/reloaded on every `AuthAuthenticated` emission. **Must be provided at app root.** |
| `BookingCubit` | Feature | Save/edit/conflict check |
| `DailyCubit` | Feature | Daily room status + fetch group by day |
| `MonthlyCubit` | Feature | Month bookings + heatmap stats |
| `ReportsCubit` | Feature | Payment, Type, and Source report aggregation (client-side grouping via shared `_aggregateCategory` helper) |
| `SettingsCubit` | Feature | Config CRUD. After every write → call `ConfigCubit.reload()`. |

Rules:
- Cubits never call Supabase directly — always go through a repository
- All state classes extend `Equatable` and override `props`
- `ConfigCubit` is the single source of truth for rooms/types/sources/destinations during a session

### Property switch flow

`AuthCubit.switchProperty()` → re-emits `AuthAuthenticated` → `app.dart` listener calls `ConfigCubit.loadConfig()` → `HomeScreen`'s `BlocListener<ConfigCubit>` detects `ConfigLoaded` and calls `HomeCubit.refresh()` (skipped on initial load when `HomeCubit` is still `HomeInitial`).

---

## Navigation

Routes live in `lib/app.dart`. GoRouter uses a `_GoRouterRefreshStream` wrapping `AuthCubit.stream` to trigger redirects on auth state changes.

```dart
// Route guard
redirect: (context, state) {
  if (auth is! AuthAuthenticated) return onPin ? null : '/pin';
  if (onPin) return '/home';
  if (state.matchedLocation.startsWith('/settings')) {
    if (auth.role != UserRole.owner) return '/home';
  }
  return null;
}
```

`AuthLoading` is not `AuthAuthenticated`, so users stay on `/pin` during Supabase verification.

Routes: `/pin`, `/home`, `/daily`, `/monthly`, `/reports`, `/reports/payment`, `/reports/booking-type`, `/reports/booking-source`, `/booking/new`, `/payment/update`, `/settings`, `/settings/rooms`, `/settings/booking-types`, `/settings/booking-sources`, `/settings/payment-destinations`.

`/booking/new` and `/payment/update` are top-level routes outside the `ShellRoute` (no bottom nav bar). Both return `bool` via `context.pop(true)` on save so the caller can refresh.

Settings tab (and Reports tab for staff) are **fully absent from the widget tree** for staff — not hidden, not greyed out. Bottom nav has 5 items for owner, 4 for staff.

---

## Booking Group — Key Rules

These are non-obvious and critical to get right:

- **Night count:** `check_out − check_in` using **calendar dates only** — always strip time before calling `.difference().inDays` (23 h difference = 0 inDays). `check_out` is the departure day (exclusive). Single night: `check_in=May 13, check_out=May 14`.
- **Day-use bookings:** when `check_in` and `check_out` share the same calendar date (year/month/day equality), the booking is a day-use. `nightCount` = 1, `isDayUse = true`, and exactly one `booking_days` row is created for that date. Detected automatically — no `slot_type` column anywhere.
- **`check_in_datetime` / `check_out_datetime`** (`TIMESTAMPTZ`) on `booking_groups` carry the full timestamps used for overlap-based conflict detection. For night stays the defaults are 14:00 check-in / 11:00 check-out (applied in `BookingGroupInput`). For day-use, the user picks both times explicitly in the wizard. Stored as UTC; parse back with `.toLocal()` for display.
- **`booking_days` unique index:** `booking_days_group_date_unique` on `(booking_group_id, booking_date) WHERE is_active`. The old per-room-per-date index (`booking_days_active_unique`) was dropped — multiple groups on the same room+date are allowed as long as their datetime ranges don't overlap.
- **`total_amount`** on `booking_groups` is the gross amount — source of truth for the booking value.
- **`net_amount`** on `booking_groups` is stored (`NUMERIC(10,2)`). It equals `totalAmount − (commissionInclTax ?? 0) − (taxDeduction ?? 0)` for manually-entered bookings. For SF-imported bookings it is the value returned directly by the SF edge function (`net_amount` field), which may differ from the local formula. `BookingGroup.fromJson` falls back to the formula for rows that predate the column.
- **`booking_days.amount`** (per-night) stores **net per night** = `netAmount / nights`. It is computed by `BookingGroupInput.perNightAmount` at save/update time — never re-read for display.
- **Payment status:** Boolean (`payment_received`) on `booking_groups` only — not per night. Extended by three nullable payment columns: `actual_payment_amount NUMERIC(10,2)`, `payment_received_date DATE`, `payment_notes TEXT`.
- **Edit always opens full group:** Tapping any night (daily card or monthly row) fetches and opens the entire `booking_group`.
- **Delete is hard delete:** `BookingRepository.deleteBookingGroup()` issues `DELETE` on `booking_days` first (FK child), then `booking_groups`. This is triggered from the trash-icon `IconButton` in the Edit Booking AppBar (edit mode only). All other mutations use soft-delete (`is_active = false`).
- **Range shrink on edit:** Removed nights → `is_active=false` on their `booking_days` rows. Remaining rows get recalculated amount.

---

## Conflict Detection Flow

Before every save, `BookingRepository.checkConflicts()` queries `booking_groups` for **datetime-range overlap** on the same room. Two bookings conflict when:

```
existing.check_in_datetime  < new.checkOutDatetime  AND
existing.check_out_datetime > new.checkInDatetime
```

This allows multiple bookings per room on the same calendar date as long as their time ranges don't overlap (e.g. a morning day-use 08:00–12:00 and an afternoon day-use 14:00–18:00 can coexist).

`ConflictInfo` carries: `groupId`, `checkIn`/`checkOut` (date), `checkInDatetime`/`checkOutDatetime` (local, for time display), `roomName`, `bookingTypeName`, `bookingSourceName`, `customerName`. The dialog shows all of these.

If conflicts exist:
1. Emit `BookingConflict` → show `ConflictDialog`
2. User cancels → emit `BookingIdle`, stay on form
3. User confirms → `softDeleteConflicts(List<String> groupIds)` soft-deletes each conflicting group and its `booking_days` → insert new group

```
BookingIdle → BookingChecking → BookingConflict → (cancel) BookingIdle
                              → BookingSaving → BookingSaved | BookingError
```

---

## Supabase Query Conventions

Always apply both filters on every query — without exception:
- `is_active=eq.true`
- `property_id=eq.<AppConstants.propertyId>`

Key queries:

```
# Daily view
GET /booking_days?property_id=eq.<id>&booking_date=eq.<date>&is_active=eq.true
  &select=*,booking_groups!inner(*,booking_types(*),booking_sources(*)),rooms(*)
  &booking_groups.is_active=eq.true

# Monthly view (add &room_id=eq.<id> for room filter)
GET /booking_days?property_id=eq.<id>&booking_date=gte.<start>&booking_date=lte.<end>&is_active=eq.true
  &select=*,booking_groups!inner(*,booking_types(*),booking_sources(*)),rooms(*)

# Fetch group by day (for edit)
SELECT booking_groups.* FROM booking_groups
JOIN booking_days ON booking_days.booking_group_id = booking_groups.id
WHERE booking_days.room_id = :roomId AND booking_days.booking_date = :date AND booking_days.is_active = true

# Conflict check (datetime overlap on booking_groups — NOT booking_days dates)
GET /booking_groups?room_id=eq.<id>&property_id=eq.<pid>&is_active=eq.true
  &check_in_datetime=lt.<newCheckOutUtc>&check_out_datetime=gt.<newCheckInUtc>
  &select=id,check_in,check_out,check_in_datetime,check_out_datetime,customer_name,
          rooms!inner(name),booking_types(name),booking_sources(name)
  (optionally &id=neq.<excludeGroupId> when editing)

# Save: POST /booking_groups (includes check_in_datetime, check_out_datetime, net_amount)
#   → get id → POST /booking_days (array, one per night, amount = net per night)

# Edit update sequence:
PATCH /booking_groups?id=eq.<id>          -- update metadata including net_amount
PATCH /booking_days (removed nights)      -- is_active=false
PATCH /booking_days (remaining nights)    -- recalculated net per-night amount

# Delete (hard delete — from Edit Booking trash button):
DELETE /booking_days?booking_group_id=eq.<id>&property_id=eq.<pid>
DELETE /booking_groups?id=eq.<id>&property_id=eq.<pid>

# Payment-only update (does NOT touch booking_days):
PATCH /booking_groups?id=eq.<id>&property_id=eq.<pid>
  -- payment_received, actual_payment_amount, payment_destination_id,
  -- payment_received_date, payment_notes, updated_at

# Payment report: booking_days → booking_groups → payment_destinations
GET /booking_days?property_id=eq.<id>&booking_date=gte.<start>&booking_date=lte.<end>&is_active=eq.true
  &select=amount,room_id,rooms(name),booking_groups!inner(id,payment_destination_id,is_active,payment_destinations(name))
  &booking_groups.is_active=eq.true

# Type report: booking_days → booking_groups → booking_types
GET /booking_days?...&select=amount,room_id,rooms(name),booking_groups!inner(id,booking_type_id,is_active,booking_types(name))

# Source report: booking_days → booking_groups → booking_sources
GET /booking_days?...&select=amount,room_id,rooms(name),booking_groups!inner(id,booking_source_id,is_active,booking_sources(name))

# Fetch group by OTA booking ID (for payment update search FAB):
GET /booking_groups?ota_booking_id=eq.<id>&property_id=eq.<pid>&is_active=eq.true&limit=1

# PIN verification (auth):
GET /pins?pin=eq.<pin>&is_active=eq.true
  &select=role,pin_properties(sort_order,properties(id,name,sf_hotel_id))
  (single row — .maybeSingle())
```

All three reports aggregate **client-side** in `ReportsCubit` (the repository only fetches raw rows). Payment report groups into `RoomPaymentSummary` (room → destination). Type and Source reports use the shared `_aggregateCategory` helper in `ReportsCubit`, producing `RoomCategorySummary` (room → type/source). Null FK values are displayed as "Not specified" in all reports.

---

## Payment Destinations

`payment_destinations` is a settings-managed table (owner only). Each `booking_source` can have a default `payment_destination_id`. When creating a booking, the destination is pre-filled from the source default but overridable per booking. Stored as a nullable FK on `booking_groups`.

---

## Theming

`ThemeMode.system` — follows OS. All widgets use semantic `ThemeData` tokens. **Never hardcode hex values in widget code.**

Colors are accessed via `Theme.of(context).extension<AppColors>()`. Key tokens (defined once in `app_theme.dart`):

| Token | Light | Dark |
|---|---|---|
| Background | `#F5F5F7` | `#0D0F1A` |
| Surface | `#FFFFFF` | `#1C1F2E` |
| Accent | `#534AB7` | `#7F77DD` |
| Success | `#1D9E75` | `#5DCAA5` |
| Warning | `#D4820A` | `#EF9F27` |
| Danger | `#C0392B` | `#E24B4A` |

- Booked pill → success-tinted. Vacant pill → danger-tinted.
- Source tags → accent-tinted chip.
- Computed row in booking form (nights + per-night amount) → accent-tinted bg.
- Heatmap: 5 opacity levels of accent (0 = empty, 4 = highest revenue).
- Today ring = accent. Selected date ring = warning (amber).

---

## Booking Wizard

All booking entry and editing goes through the unified 4-step wizard at `/booking/new` (`BookingWizardScreen`). The launch mode is controlled by `BookingWizardExtras`:

| Field | Effect |
|---|---|
| `existingGroup: BookingGroup` | Edit mode — starts at step 4 pre-populated, AppBar shows "Edit Booking" |
| `sfPrefill: SfBookingPrefill` | Stay Flexi import — starts at step 4 pre-populated, AppBar shows "New Booking" |
| `prefilledRoomId` | New booking with room pre-selected — starts at step 2 |
| *(none)* | New booking — starts at step 1 |

Steps: 1 = Room (`wizard_step1_room.dart`), 2 = Dates + Guest + Type/Source (`wizard_step2_dates.dart` → class `WizardStep2Details`), 3 = Payment amounts (`wizard_step3_type_source.dart` → class `WizardStep3Payment`), 4 = Review + Save (`wizard_step4_review.dart`).

- Step 4 is a `StatefulWidget`. The **BOOKING** section (room + dates) is always expanded. **BOOKING DETAILS** (type, source, customer, OTA IDs) and **PAYMENT** (amounts) are accordion sections — collapsed by default showing a one-line read-only summary, expandable via a chevron header. Uses `AnimatedCrossFade` with `sizeCurve: Curves.easeInOut`. Each accordion's `secondChild` starts with `SizedBox(height: 8)` to prevent `ClipRect` from cutting off floating label tops.
- Step 4 save button: disabled when `grossAmount == 0` OR `checkOut <= checkIn`.
- Booking source dropdown: filtered by selected type. **Hidden entirely** if selected type has no active sources.
- Payment destination: auto-filled from source's `defaultPaymentDestinationId` when source is changed; always shown.
- Back navigation: edit/SF prefill mode exits on back from step 4 (doesn't step back through wizard).
- **Edit mode only — payment shortcut:** Step 4's "Net amount" row includes a `TextButton` on the right edge. Label is **"Update Receival"** when `paymentReceived == false`, **"Payment Status"** when already received. Tapping pushes `/payment/update`; if payment is saved the wizard pops with `true`. Wired via `onUpdatePayment: VoidCallback?` + `paymentAlreadyReceived: bool` params on `WizardStep4Review` — both are `null`/`false` for new bookings.
- **Edit mode only — delete:** The AppBar shows a `Icons.delete_outline_rounded` `IconButton` (in `colors.danger`) that calls `BookingRepository.deleteBookingGroup()` after an `AlertDialog` confirmation, then pops with `true`.
- **Net amount display and save:** `_BookingWizardScreenState` holds `double? _netAmountOverride`, seeded in `initState` from `existingGroup?.netAmount ?? sfPrefill?.netAmount`. This is passed as `overrideNetAmount` to `WizardStep4Review` (for display) and as `netAmountOverride` to `BookingGroupInput` (for save). `_onAmountChanged` clears it to `null` on the first keystroke in any amount field, at which point both display and saved value switch to the live formula.

---

## Stay Flexi Integration

Home screen has **two FABs** that always sit side-by-side at the bottom-right:
- **Search FAB** (small, `colors.surface` bg, `Icons.manage_search_rounded`): opens `_OtaSearchDialog` — user enters an OTA Booking ID, `BookingRepository.fetchGroupByOtaId()` searches `booking_groups.ota_booking_id`, then pushes `/payment/update` on match. The dialog is a `StatefulWidget` that owns its `TextEditingController`; do **not** use `StatefulBuilder` here as it has no `dispose()`.
- **Add FAB** (standard, accent bg): expandable — **Manual** launches the plain wizard, **Stay Flexi ID** opens `showStayFlexiSearchDialog`.

Dialog flow:
1. Check `booking_groups` for existing active record with same `stay_flexi_booking_id` → show error if found (`BookingRepository.stayFlexiBookingExists`)
2. Call edge function `get-booking-info-from-sf` with `{ sfBookingId, hotelId: AppConstants.sfHotelId }`
3. Parse response into `SfBookingPrefill.fromJson(json, activeSources, activeDestinations)` — matches `booking_source` string against config sources (case-insensitive) to resolve `bookingSourceId` + `bookingTypeId` + default payment destination
4. Push `/booking/new` with `BookingWizardExtras(sfPrefill: prefill)` → lands on step 4

SF JSON → wizard field mapping:
- `internal_room_id` → room, `checkin`/`checkout` → stay dates (date part only), `booking_made_on` → booking date
- `ota_gross_amount` → gross, `ota_tax_amount` → tax, `ota_commission` → commission, `tax_deduction` → TDS/TCS, `net_amount` → `SfBookingPrefill.netAmount`
- `customer_name`, `sfBookingId`, `ota_booking_id` → respective text fields

---

## Payment Update Workflow

`/payment/update` (not the booking wizard) is reached from three entry points:
1. Tapping a card in the "Payment Pending" section of the Home screen.
2. The **"Update Receival" / "Payment Status"** TextButton in step 4 of the Edit Booking wizard.
3. The **OTA Booking ID search FAB** on the Home screen — finds any active booking by `ota_booking_id`.

The route carrier is `PaymentUpdateExtras` (carries `BookingGroup` + `List<PaymentDestination>`).

`PaymentUpdateScreen` is a lightweight stateful screen — **no cubit**, direct `BookingRepository.updatePaymentDetails()` call. It PATCHes only payment fields on `booking_groups`; `booking_days` are never touched.

Fields captured:
| Field | Pre-fill source |
|---|---|
| Amount received | `group.netAmount` (stored value) |
| Payment destination | `group.paymentDestinationId` (guarded against active list) |
| Payment received date | Today; `lastDate: DateTime.now()` |
| Payment notes | `group.paymentNotes` |
| Mark as received (Switch) | Defaults `true` (launched from pending list) |

The read-only reference card at the top (surface/border container) shows — in order — OTA ID (with clipboard copy), dates, source · type, customer name. Fields absent from the booking are silently omitted. Type and source names are resolved from `ConfigCubit` state via `context.read<ConfigCubit>()` in `build()`.

`BookingRepository.updatePaymentDetails()` is a separate method that only PATCHes the five payment columns + `updated_at`. Do **not** route payment-only updates through `updateBookingGroup()`.

---

## Home Screen — Amounts Displayed

`BookingCard` (used in check-outs, check-ins, and payment pending sections) displays `group.netAmount` — not `totalAmount`. The "Payment pending" section header subtitle (`₹X due`) also sums `netAmount` across pending groups. This is intentional: `netAmount` is the actual receivable after commission and TDS/TCS deductions.

---

## Reports — Table View Pattern

Booking Type Report (`/reports/booking-type`) and Booking Source Report (`/reports/booking-source`) render as a sticky-column table, not expansion tiles:

- **Layout:** `Row` with a fixed-width sticky Room column (`_roomColW = 110`) + `Expanded(SingleChildScrollView(horizontal))` for the category columns. Both scroll vertically together inside an outer `SingleChildScrollView`.
- **Columns:** one per unique category derived from `overallTotals`, plus a TOTAL column on the right. Data column width `_dataColW = 130`.
- **Rows:** one per room, plus a TOTAL footer row. Header and footer rows use `colors.background`; data rows use `colors.surface`. The TOTAL column uses `colors.background` throughout to distinguish it visually. Grand total cell uses `colors.accent`.
- **Empty cells:** rooms with no bookings for a given category show `—` (not `₹0`).
- **Amounts + counts:** each non-empty cell shows `₹X,XXX (N)` where N = number of unique `booking_group` records. Multi-night bookings count as 1, not N. Counting is done by deduplicating `booking_group_id` via `Set<String>` per room×category during aggregation.

### Report data models

`CategoryTotal` and `DestinationTotal` carry a `count: int` field (unique booking groups for that cell). `RoomCategorySummary` and `RoomPaymentSummary` carry a `count: int` equal to the sum of their breakdown counts (valid because each booking belongs to exactly one category/destination). Grand total count is computed inline: `overallTotals.fold(0, (s, t) => s + t.count)`.

The `_aggregateCategory` private method in `ReportsCubit` handles grouping for both table reports. Payment report uses the same counting approach inside `loadPaymentReport`. All three methods track `Map<roomId, Map<categoryId?, Set<bookingGroupId>>>` to count unique groups per cell.

**Do not use `firstWhere(orElse: () => null)` on `List rooms`** — at runtime it's `List<Room>` and `Null` is not a valid return type. Use `indexWhere` instead.

---

## Settings — Config Sub-Screens

- Edit pattern: **inline expand-in-place** — no separate edit screen.
- Inactive items (`is_active=false`): rendered at 45% opacity, still shown, restorable.
- Booking sources screen has type-filter pills (OTA / Offline / Direct) above the list.
- After any write: `SettingsCubit` → `ConfigCubit.reload()` — mandatory.
- Payment destinations screen follows the same inline-expand pattern as other sub-screens.
