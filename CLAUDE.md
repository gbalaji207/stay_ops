# CLAUDE.md — StayOps

Mobile-first hospitality income tracker. Flutter Android APK + Supabase backend. Single property per install.

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
│   ├── constants.dart          # PROPERTY_ID, ownerPin, staffPin
│   ├── supabase_config.dart
│   └── theme/app_theme.dart
├── features/
│   ├── auth/         # pin_screen, auth_cubit
│   ├── config/       # config_cubit, config_repository (app-level, all roles)
│   ├── booking/      # entry_screen, booking_form (shared widget), booking_cubit
│   ├── daily/        # daily_screen, daily_cubit
│   ├── monthly/      # monthly_screen, monthly_cubit
│   └── settings/     # owner only — rooms, booking_types, booking_sources
└── shared/
    ├── models/       # room, booking_type, booking_source, booking_group, booking_day
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

---

## Cubits

| Cubit | Scope | Notes |
|---|---|---|
| `AuthCubit` | App-level | PIN, role, session |
| `ConfigCubit` | App-level | Rooms + types + sources. Loaded once post-auth. **Must be provided at app root.** |
| `BookingCubit` | Feature | Save/edit/conflict check |
| `DailyCubit` | Feature | Daily room status + fetch group by day |
| `MonthlyCubit` | Feature | Month bookings + heatmap stats |
| `SettingsCubit` | Feature | Config CRUD. After every write → call `ConfigCubit.reload()`. |

Rules:
- Cubits never call Supabase directly — always go through a repository
- All state classes extend `Equatable` and override `props`
- `ConfigCubit` is the single source of truth for rooms/types/sources during a session

---

## Navigation

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

Settings tab is **fully absent from the widget tree** for staff — not hidden, not greyed out.

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
```

---

## Theming

`ThemeMode.system` — follows OS. All widgets use semantic `ThemeData` tokens. **Never hardcode hex values in widget code.**

Key tokens (defined once in `app_theme.dart`):

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

## BookingForm Widget

Single widget reused for new entry and edit. Receives `BookingGroup?` — non-null = edit mode.

- Booking source dropdown: filtered by selected type chip. **Hidden entirely** if selected type has no active sources.
- Save disabled when: `amount == 0` OR `check_out <= check_in`.
- Button label: "Save booking" (new) / "Save changes" (edit).
- Presented as a bottom sheet (modal).

---

## Settings — Config Sub-Screens

- Edit pattern: **inline expand-in-place** — no separate edit screen.
- Inactive items (`is_active=false`): rendered at 45% opacity, still shown, restorable.
- Booking sources screen has type-filter pills (OTA / Offline / Direct) above the list.
- After any write: `SettingsCubit` → `ConfigCubit.reload()` — mandatory.
