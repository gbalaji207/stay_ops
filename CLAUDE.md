# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Mobile-first hospitality income tracker. Flutter Android APK + Supabase backend. Single property per install.

---

## Commands

```bash
flutter pub get          # install dependencies
flutter run              # debug on connected device/emulator
flutter build apk        # release APK
flutter test             # all tests
flutter test test/widget_test.dart   # single test file
flutter analyze          # static analysis (flutter_lints)
```

---

## Stack & Dependencies

```yaml
supabase_flutter: ^2.x
flutter_bloc: ^9.x       # Cubit pattern only — no full Bloc
go_router: ^17.x
intl: ^0.20
equatable: ^2.x
```

---

## Project Structure

```
lib/
├── core/
│   ├── constants.dart          # propertyId, sfHotelId, ownerPin, staffPin
│   ├── supabase_config.dart
│   └── theme/app_theme.dart
├── features/
│   ├── auth/         # pin_screen, auth_cubit
│   ├── config/       # config_cubit, config_repository (app-level, all roles)
│   ├── booking/
│   │   ├── wizard/   # booking_wizard_screen, wizard_step1–4, booking_wizard_extras,
│   │   │             # sf_booking_prefill
│   │   └── widgets/  # stay_flexi_search_dialog
│   ├── daily/        # daily_screen, daily_cubit
│   ├── home/         # home_screen, home_cubit, home_repository
│   ├── monthly/      # monthly_screen, monthly_cubit
│   ├── reports/      # reports_screen, payment_report_screen, reports_cubit
│   └── settings/     # owner only — rooms, booking_types, booking_sources, payment_destinations
└── shared/
    ├── models/       # room, booking_type, booking_source, booking_group, booking_day,
    │                 # payment_destination, room_payment_summary
    └── widgets/      # stat_card, conflict_dialog
```

---

## Auth

Fully local — no network call. Two hardcoded PINs in `constants.dart`.

```dart
enum UserRole { none, staff, owner }
// States: AuthInitial | AuthAuthenticated(role) | AuthError(message)
```

On 4th digit entered → auto-submit (no confirm button). Wrong PIN → shake + error → auto-clear after 2s.

After `AuthAuthenticated` is emitted → immediately call `ConfigCubit.loadConfig()` for **all roles** → navigate `/daily`.

The PIN screen is always rendered in dark theme regardless of system setting.

---

## Cubits

| Cubit | Scope | Notes |
|---|---|---|
| `AuthCubit` | App-level | PIN, role, session |
| `ConfigCubit` | App-level | Rooms + types + sources + destinations. Loaded once post-auth. **Must be provided at app root.** |
| `BookingCubit` | Feature | Save/edit/conflict check |
| `DailyCubit` | Feature | Daily room status + fetch group by day |
| `MonthlyCubit` | Feature | Month bookings + heatmap stats |
| `ReportsCubit` | Feature | Payment report aggregation (client-side grouping) |
| `SettingsCubit` | Feature | Config CRUD. After every write → call `ConfigCubit.reload()`. |

Rules:
- Cubits never call Supabase directly — always go through a repository
- All state classes extend `Equatable` and override `props`
- `ConfigCubit` is the single source of truth for rooms/types/sources/destinations during a session

---

## Navigation

Routes live in `lib/app.dart`. GoRouter uses a `_GoRouterRefreshStream` wrapping `AuthCubit.stream` to trigger redirects on auth state changes.

```dart
// Route guard
redirect: (context, state) {
  if (auth is! AuthAuthenticated) return '/pin';
  if (state.matchedLocation.startsWith('/settings')) {
    if (auth.role != UserRole.owner) return '/daily';
  }
  return null;
}
```

Routes: `/pin`, `/home`, `/daily`, `/monthly`, `/reports`, `/reports/payment`, `/settings`, `/settings/rooms`, `/settings/booking-types`, `/settings/booking-sources`, `/settings/payment-destinations`.

Settings tab (and Reports tab for staff) are **fully absent from the widget tree** for staff — not hidden, not greyed out. Bottom nav has 5 items for owner, 4 for staff.

---

## Booking Group — Key Rules

These are non-obvious and critical to get right:

- **Night count:** `check_out − check_in`. `check_out` is the departure day (exclusive). Single night: `check_in=May 13, check_out=May 14`.
- **Amount split:** `total_amount / nights` — decimal, no rounding redistribution. `NUMERIC(10,2)` handles precision. `total_amount` on `booking_groups` is the source of truth.
- **Payment status:** Boolean on `booking_groups` only — not per night.
- **Edit always opens full group:** Tapping any night (daily card or monthly row) fetches and opens the entire `booking_group`.
- **Soft-delete only:** Never hard-delete. Set `is_active = false`.
- **Range shrink on edit:** Removed nights → `is_active=false` on their `booking_days` rows. Remaining rows get recalculated amount.

---

## Conflict Detection Flow

Before every save, query active `booking_days` for the target room + night dates. If conflicts exist:
1. Emit `BookingConflict` → show `ConflictDialog` (lists conflicting dates)
2. User cancels → emit `BookingIdle`, stay on form
3. User confirms → soft-delete conflicting `booking_days` (and their parent `booking_groups` if all days inactive) → insert new group

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

# Save: POST /booking_groups → get id → POST /booking_days (array, one per night)

# Edit update sequence:
PATCH /booking_groups?id=eq.<id>          -- update metadata
PATCH /booking_days (removed nights)      -- is_active=false
PATCH /booking_days (remaining nights)    -- recalculated amount

# Reports: joins booking_days → booking_groups → payment_destinations, aggregated client-side
GET /booking_days?property_id=eq.<id>&booking_date=gte.<start>&booking_date=lte.<end>&is_active=eq.true
  &select=amount,room_id,rooms(name),booking_groups!inner(payment_destination_id,payment_destinations(*))
  &booking_groups.is_active=eq.true
```

Reports aggregation happens **client-side** in `ReportsRepository` — raw rows are grouped by room → destination into `RoomPaymentSummary` objects. Null `payment_destination_id` is displayed as "Not specified".

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

Steps: 1 = Room, 2 = Dates + Guest + Type/Source, 3 = Payment amounts, 4 = Review + Save.

- Step 4 save button: disabled when `grossAmount == 0` OR `checkOut <= checkIn`.
- Booking source dropdown: filtered by selected type. **Hidden entirely** if selected type has no active sources.
- Payment destination: auto-filled from source's `defaultPaymentDestinationId` when source is changed; always shown.
- Back navigation: edit/SF prefill mode exits on back from step 4 (doesn't step back through wizard).

---

## Stay Flexi Integration

Home screen FAB is expandable — **Manual** launches the plain wizard, **Stay Flexi ID** opens `showStayFlexiSearchDialog`.

Dialog flow:
1. Check `booking_groups` for existing active record with same `stay_flexi_booking_id` → show error if found (`BookingRepository.stayFlexiBookingExists`)
2. Call edge function `get-booking-info-from-sf` with `{ sfBookingId, hotelId: AppConstants.sfHotelId }`
3. Parse response into `SfBookingPrefill.fromJson(json, activeSources, activeDestinations)` — matches `booking_source` string against config sources (case-insensitive) to resolve `bookingSourceId` + `bookingTypeId` + default payment destination
4. Push `/booking/new` with `BookingWizardExtras(sfPrefill: prefill)` → lands on step 4

SF JSON → wizard field mapping:
- `internal_room_id` → room, `checkin`/`checkout` → stay dates (date part only), `booking_made_on` → booking date
- `ota_gross_amount` → gross, `ota_tax_amount` → tax, `ota_commission` → commission, `tax_deduction` → TDS/TCS
- `customer_name`, `sfBookingId`, `ota_booking_id` → respective text fields

---

## Settings — Config Sub-Screens

- Edit pattern: **inline expand-in-place** — no separate edit screen.
- Inactive items (`is_active=false`): rendered at 45% opacity, still shown, restorable.
- Booking sources screen has type-filter pills (OTA / Offline / Direct) above the list.
- After any write: `SettingsCubit` → `ConfigCubit.reload()` — mandatory.
- Payment destinations screen follows the same inline-expand pattern as other sub-screens.
