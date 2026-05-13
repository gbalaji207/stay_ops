# StayOps — Architecture & High-Level Design

**Product:** StayOps — Hospitality Income Tracker
**Stack:** Flutter (Android APK) · Supabase (Cloud BaaS)
**Version:** 1.1
**Date:** May 2026

---

## Table of Contents

1. [Product Overview](#1-product-overview)
2. [System Context](#2-system-context)
3. [Architecture Decisions](#3-architecture-decisions)
4. [High-Level Architecture](#4-high-level-architecture)
5. [Database Design](#5-database-design)
6. [Booking Group Design](#6-booking-group-design)
7. [Flutter App Architecture](#7-flutter-app-architecture)
8. [Authentication Design](#8-authentication-design)
9. [State Management — Cubit Pattern](#9-state-management--cubit-pattern)
10. [Screen & Navigation Design](#10-screen--navigation-design)
11. [Data Flow Diagrams](#11-data-flow-diagrams)
12. [Configuration & Settings Design](#12-configuration--settings-design)
13. [Role-Based Access Control](#13-role-based-access-control)
14. [API Contract](#14-api-contract)
15. [Non-Functional Requirements](#15-non-functional-requirements)
16. [Future Considerations](#16-future-considerations)

---

## 1. Product Overview

StayOps is a mobile-first income tracking app for small hospitality operators. It enables room-level booking entry (single day or multi-day), daily/monthly revenue visibility, and source attribution (OTA, offline, direct).

### Goals

- Track daily room bookings across configurable rooms per property
- Support multi-night bookings with equal per-night amount split
- Capture booking source (OTA platform, offline, direct) and payment status at group level
- Provide a heatmap monthly calendar and daily snapshot view
- Support owner and staff with separate access levels
- Keep it simple: APK distribution, no login/signup, PIN-based access

### Constraints

- Online-only (no offline cache in v1)
- APK distribution only (no Play Store)
- Single property per app install (property ID hardcoded in constants)
- No complex auth — 4-digit PIN only

---

## 2. System Context

```
┌─────────────────────────────────────────────────────────────┐
│                    StayOps App                            │
│                 Flutter Android APK                          │
│                                                              │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │  PIN Auth   │  │  Booking     │  │  Monthly/Daily   │   │
│  │  (local)    │  │  Entry/Edit  │  │  Views           │   │
│  └─────────────┘  └──────────────┘  └──────────────────┘   │
└──────────────────────────┬──────────────────────────────────┘
                           │ HTTPS / REST
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    Supabase Cloud                            │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────┐    │
│  │  PostgreSQL  │  │  PostgREST   │  │  Auth (unused) │    │
│  │  Database    │  │  Auto API    │  │  (PIN is local)│    │
│  └──────────────┘  └──────────────┘  └────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

**Actors:**

| Actor | Description |
|-------|-------------|
| Owner | Full access — bookings, settings, room/OTA/type config |
| Staff | Booking entry, edit, daily view, monthly view. No settings access |

---

## 3. Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Frontend | Flutter | Cross-platform, single codebase, APK distribution |
| Backend | Supabase | Managed Postgres + auto REST API, no server code needed |
| Auth | Hardcoded 4-digit PIN (local) | No user accounts needed, single-device use |
| State management | Cubit (flutter_bloc) | Explicit states, less boilerplate than full Bloc, clean async handling |
| Multi-property | Property ID hardcoded in app constants | Backend supports multi-property; app scope is fixed per install |
| Online-only | No local cache | Simplicity for v1 |
| Booking model | Hybrid — one DB row per night + booking_group | Simple per-day queries; group tracks total amount and payment status |
| Amount split | Equal split across nights, decimal allowed | e.g. ₹9900 / 3 nights = ₹3300.00 per night |
| Payment status | Boolean at group level | Settled per booking group, not per night |
| Config loading | Loaded at session start post-auth, for all roles | Staff needs config for Entry form dropdowns |
| Conflict handling | Show warning → user confirms → overwrite | Operator has authority over their own data |
| OTA/source config | Stored in Supabase per property | Owner manages from Settings screen |
| APK distribution | Direct APK file share | No Play Store overhead for internal-use app |

---

## 4. High-Level Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                    Flutter App (Android)                        │
│                                                                 │
│  ┌───────────────────────────────────────────────────────┐     │
│  │  Presentation Layer (Screens + Widgets)                │     │
│  │  PINScreen · EntryScreen · DailyScreen                 │     │
│  │  MonthlyScreen · SettingsScreen (owner only)           │     │
│  └───────────────────────┬───────────────────────────────┘     │
│                          │                                      │
│  ┌───────────────────────▼───────────────────────────────┐     │
│  │  State Layer (Cubits)                                  │     │
│  │  AuthCubit · ConfigCubit · BookingCubit                │     │
│  │  DailyCubit · MonthlyCubit · SettingsCubit             │     │
│  └───────────────────────┬───────────────────────────────┘     │
│                          │                                      │
│  ┌───────────────────────▼───────────────────────────────┐     │
│  │  Repository Layer                                      │     │
│  │  BookingRepository · ConfigRepository                  │     │
│  └───────────────────────┬───────────────────────────────┘     │
│                          │                                      │
│  ┌───────────────────────▼───────────────────────────────┐     │
│  │  Data Source                                           │     │
│  │  SupabaseClient (supabase_flutter)                     │     │
│  └───────────────────────┬───────────────────────────────┘     │
└──────────────────────────┼─────────────────────────────────────┘
                           │ HTTPS
                           ▼
┌────────────────────────────────────────────────────────────────┐
│                       Supabase                                  │
│                                                                 │
│  properties → rooms → booking_groups → booking_days            │
│  booking_types · booking_sources                                │
└────────────────────────────────────────────────────────────────┘
```

---

## 5. Database Design

### 5.1 Entity Relationship

```
properties
    │
    ├── rooms (1:N)
    │       │
    │       └── booking_days (1:N) ──→ booking_groups (N:1)
    │
    ├── booking_types (1:N)
    └── booking_sources (1:N)
```

### 5.2 Table Definitions

#### `properties`

```sql
CREATE TABLE properties (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name       TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

---

#### `rooms`

```sql
CREATE TABLE rooms (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  sort_order  INT DEFAULT 0,
  is_active   BOOLEAN DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT now()
);
```

---

#### `booking_types`

Configurable per property. Defaults: OTA, Offline, Direct.

```sql
CREATE TABLE booking_types (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  sort_order  INT DEFAULT 0,
  is_active   BOOLEAN DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT now()
);
```

---

#### `booking_sources`

Configurable OTA/vendor names per property. Linked to a booking type.

```sql
CREATE TABLE booking_sources (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id     UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  booking_type_id UUID REFERENCES booking_types(id) ON DELETE SET NULL,
  name            TEXT NOT NULL,
  sort_order      INT DEFAULT 0,
  is_active       BOOLEAN DEFAULT true,
  created_at      TIMESTAMPTZ DEFAULT now()
);
```

---

#### `booking_groups`

One record per booking entry session. Holds the group-level metadata: total amount, payment status, check-in/check-out.

```sql
CREATE TABLE booking_groups (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id       UUID NOT NULL REFERENCES properties(id),
  room_id           UUID NOT NULL REFERENCES rooms(id),
  check_in          DATE NOT NULL,   -- first night (inclusive)
  check_out         DATE NOT NULL,   -- departure date (exclusive)
  total_amount      NUMERIC(10,2),
  payment_received  BOOLEAN DEFAULT false,
  booking_type_id   UUID REFERENCES booking_types(id),
  booking_source_id UUID REFERENCES booking_sources(id),
  notes             TEXT,
  is_active         BOOLEAN DEFAULT true,   -- soft-delete at group level
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now(),

  CONSTRAINT check_dates CHECK (check_out > check_in)
);
```

> `check_out > check_in` enforced by DB constraint. A single night booking: check_in = May 13, check_out = May 14.

---

#### `booking_days`

One record per night per group. Amount is the equal split of `total_amount`.
This table drives all calendar and daily view queries.

```sql
CREATE TABLE booking_days (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_group_id UUID NOT NULL REFERENCES booking_groups(id) ON DELETE CASCADE,
  property_id      UUID NOT NULL REFERENCES properties(id),
  room_id          UUID NOT NULL REFERENCES rooms(id),
  booking_date     DATE NOT NULL,
  amount           NUMERIC(10,2),    -- total_amount / nights, decimal allowed
  is_active        BOOLEAN DEFAULT true,  -- soft-delete individual nights
  created_at       TIMESTAMPTZ DEFAULT now(),

  UNIQUE (room_id, booking_date)     -- one active record per room per day
);
```

> **Note on UNIQUE constraint:** The `UNIQUE (room_id, booking_date)` applies across all rows including soft-deleted ones. To allow re-booking after soft-delete, the constraint should be a partial unique index on active rows only:

```sql
-- Replace the table UNIQUE with a partial index
CREATE UNIQUE INDEX booking_days_active_unique
  ON booking_days (room_id, booking_date)
  WHERE is_active = true;
```

---

### 5.3 Relationship Summary

| Table | Purpose |
|-------|---------|
| `booking_groups` | One per booking entry. Holds total amount, payment, check-in/out |
| `booking_days` | One per night. Holds split amount. Used by calendar and daily views |

---

### 5.4 Seed Data

```sql
-- Default booking types
INSERT INTO booking_types (property_id, name, sort_order) VALUES
  ('<pid>', 'OTA',     1),
  ('<pid>', 'Offline', 2),
  ('<pid>', 'Direct',  3);

-- Default OTA sources (linked to OTA type)
INSERT INTO booking_sources (property_id, booking_type_id, name, sort_order) VALUES
  ('<pid>', '<ota_type_id>', 'MakeMyTrip',  1),
  ('<pid>', '<ota_type_id>', 'Goibibo',     2),
  ('<pid>', '<ota_type_id>', 'OYO',         3),
  ('<pid>', '<ota_type_id>', 'Airbnb',      4),
  ('<pid>', '<ota_type_id>', 'Booking.com', 5);

-- Default rooms
INSERT INTO rooms (property_id, name, sort_order) VALUES
  ('<pid>', 'Room 101', 1),
  ('<pid>', 'Room 102', 2),
  ('<pid>', 'Room 103', 3),
  ('<pid>', 'Room 104', 4),
  ('<pid>', 'Room 105', 5);
```

---

## 6. Booking Group Design

### 6.1 How Multi-Night Booking is Stored

**Example:** Room 101, May 13 (check-in) → May 16 (check-out), ₹9900 total.

**Nights:** May 13, 14, 15 → 3 nights (check-out date excluded).
**Per-night amount:** ₹9900 / 3 = ₹3300.00

```
booking_groups row:
  room_id       = Room 101
  check_in      = 2026-05-13
  check_out     = 2026-05-16
  total_amount  = 9900.00
  payment_received = false
  booking_type  = OTA
  booking_source = MakeMyTrip

booking_days rows (3):
  room_id = Room 101, date = 2026-05-13, amount = 3300.00, is_active = true
  room_id = Room 101, date = 2026-05-14, amount = 3300.00, is_active = true
  room_id = Room 101, date = 2026-05-15, amount = 3300.00, is_active = true
```

### 6.2 Amount Split Logic (App-Side)

```dart
double perNightAmount(double total, int nights) {
  // Decimal division — no rounding, stored as-is
  return total / nights;
}

// e.g. 9900 / 3 = 3300.0
// e.g. 10000 / 3 = 3333.3333...  → stored as NUMERIC(10,2) = 3333.33
```

> No remainder redistribution. The sum of stored day amounts may differ from `total_amount` by rounding noise (max ±1 paisa per booking). The `total_amount` on `booking_groups` is the source of truth for payment settlement.

### 6.3 Edit Flow — Full Group Edit

When a user taps a date in Daily view or Monthly calendar that belongs to a booking group, the app opens the **full group edit form**, not a single-day form.

```
User taps Room 101 on May 14
        │
        ▼
DailyCubit.loadGroupForDay(roomId, date)
        │
        ▼
BookingRepository.fetchGroupByDay(roomId, date)
  → SELECT booking_groups.* 
    FROM booking_groups
    JOIN booking_days ON booking_days.booking_group_id = booking_groups.id
    WHERE booking_days.room_id = :roomId
      AND booking_days.booking_date = :date
      AND booking_days.is_active = true
        │
        ▼
Edit form opens pre-filled:
  Room: Room 101
  Check-in: May 13  |  Check-out: May 16
  Amount: ₹9900
  Source: MakeMyTrip
  Payment: Pending
```

### 6.4 Edit — Date Range Change

If the user shortens the stay (e.g. check-out changes from May 16 to May 15):

```
Old nights: 13, 14, 15
New nights: 13, 14

App action:
  1. Soft-delete booking_days where date NOT IN (new nights)
     → May 15 row: is_active = false, amount unchanged
  2. Update booking_groups: check_out = May 15, total_amount = new total
  3. Recalculate per-night amount for remaining active days
     → Update booking_days for May 13, 14 with new amount
```

### 6.5 Conflict Detection

Before saving a new booking group, the app queries for conflicts:

```sql
SELECT booking_date, rooms.name
FROM booking_days
JOIN rooms ON rooms.id = booking_days.room_id
WHERE booking_days.room_id = :roomId
  AND booking_days.booking_date = ANY(:nightDates)
  AND booking_days.is_active = true
```

If any rows are returned:

```
⚠ Conflict Warning Dialog

"Room 101 already has bookings on:
  • May 14
  • May 15

Saving will overwrite these dates.
Continue?"

[Cancel]   [Overwrite]
```

On Overwrite:
1. Soft-delete conflicting `booking_days` rows (`is_active = false`)
2. Soft-delete their parent `booking_groups` if all days are now inactive (`is_active = false`)
3. Insert new `booking_group` and `booking_days`

### 6.6 Single-Night Booking

A single-night booking is just a group with 1 night:
- check_in = May 13, check_out = May 14
- 1 `booking_days` row
- per-night amount = total amount

The entry form behaves identically — date range picker just has same-day selection resulting in 1 night.

---

## 7. Flutter App Architecture

### 7.1 Folder Structure

```
lib/
├── main.dart
├── app.dart                          # MaterialApp, go_router setup
│
├── core/
│   ├── constants.dart                # PROPERTY_ID, PIN constants
│   ├── supabase_config.dart          # URL + anon key
│   └── theme/
│       └── app_theme.dart
│
├── features/
│   ├── auth/
│   │   ├── screens/
│   │   │   └── pin_screen.dart
│   │   ├── cubit/
│   │   │   ├── auth_cubit.dart
│   │   │   └── auth_state.dart
│   │
│   ├── config/                       # Session-level config for ALL roles
│   │   ├── cubit/
│   │   │   ├── config_cubit.dart
│   │   │   └── config_state.dart
│   │   └── repository/
│   │       └── config_repository.dart
│   │
│   ├── booking/
│   │   ├── screens/
│   │   │   └── entry_screen.dart
│   │   ├── widgets/
│   │   │   └── booking_form.dart     # Shared by Entry + Daily tap + Monthly tap
│   │   ├── cubit/
│   │   │   ├── booking_cubit.dart
│   │   │   └── booking_state.dart
│   │   └── repository/
│   │       └── booking_repository.dart
│   │
│   ├── daily/
│   │   ├── screens/
│   │   │   └── daily_screen.dart
│   │   └── cubit/
│   │       ├── daily_cubit.dart
│   │       └── daily_state.dart
│   │
│   ├── monthly/
│   │   ├── screens/
│   │   │   └── monthly_screen.dart
│   │   └── cubit/
│   │       ├── monthly_cubit.dart
│   │       └── monthly_state.dart
│   │
│   └── settings/                     # Owner only
│       ├── screens/
│       │   ├── settings_screen.dart
│       │   ├── room_config_screen.dart
│       │   ├── booking_type_config_screen.dart
│       │   └── booking_source_config_screen.dart
│       └── cubit/
│           ├── settings_cubit.dart
│           └── settings_state.dart
│
└── shared/
    ├── models/
    │   ├── room.dart
    │   ├── booking_type.dart
    │   ├── booking_source.dart
    │   ├── booking_group.dart
    │   └── booking_day.dart
    └── widgets/
        ├── stat_card.dart
        └── conflict_dialog.dart
```

### 7.2 Key Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.x
  flutter_bloc: ^9.x          # Cubit
  go_router: ^17.x            # Navigation + route guards
  intl: ^0.20                 # Date/currency formatting
  equatable: ^2.x             # State equality for Cubit
```

---

## 8. Authentication Design

### 8.1 Overview

Authentication is fully local — no network call. Two hardcoded 4-digit PINs in `constants.dart`. Session role is held in `AuthCubit` (in-memory) and cleared when the app is closed.

### 8.2 PIN Constants

```dart
// lib/core/constants.dart
class AppConstants {
  static const String propertyId = 'YOUR-PROPERTY-UUID-HERE';
  static const String ownerPin   = '1234';   // change before APK build
  static const String staffPin   = '5678';   // change before APK build
}
```

### 8.3 Auth Flow

```
App Launch
    │
    ▼
PIN Screen
    │
    ├── Match ownerPin → AuthCubit.authenticated(role: owner)
    │       └── Load ConfigCubit → Navigate to /daily
    │
    ├── Match staffPin → AuthCubit.authenticated(role: staff)
    │       └── Load ConfigCubit → Navigate to /daily
    │
    └── No match → AuthCubit.error("Incorrect PIN") → show error, stay on PIN screen
```

### 8.4 AuthCubit

```dart
enum UserRole { none, staff, owner }

// States
class AuthInitial extends AuthState {}
class AuthAuthenticated extends AuthState {
  final UserRole role;
}
class AuthError extends AuthState {
  final String message;
}

// Cubit
class AuthCubit extends Cubit<AuthState> {
  void submitPin(String pin) {
    if (pin == AppConstants.ownerPin) {
      emit(AuthAuthenticated(role: UserRole.owner));
    } else if (pin == AppConstants.staffPin) {
      emit(AuthAuthenticated(role: UserRole.staff));
    } else {
      emit(AuthError('Incorrect PIN. Please try again.'));
    }
  }

  void logout() => emit(AuthInitial());
}
```

### 8.5 Post-Auth Config Load

Immediately after `AuthAuthenticated` is emitted, the app triggers `ConfigCubit.loadConfig()` before navigating to the home screen. This ensures all roles have rooms, booking types, and booking sources available for the session.

```dart
// In app.dart or a listener
BlocListener<AuthCubit, AuthState>(
  listener: (context, state) {
    if (state is AuthAuthenticated) {
      context.read<ConfigCubit>().loadConfig();  // load for ALL roles
      context.go('/daily');
    }
  },
)
```

### 8.6 Route Guard

```dart
redirect: (context, state) {
  final auth = ref.read(authCubit).state;
  if (auth is! AuthAuthenticated) return '/pin';

  if (state.matchedLocation.startsWith('/settings')) {
    if ((auth as AuthAuthenticated).role != UserRole.owner) return '/daily';
  }
  return null;
}
```

---

## 9. State Management — Cubit Pattern

### 9.1 Cubit Inventory

| Cubit | Scope | Responsibility |
|-------|-------|----------------|
| `AuthCubit` | App-level | PIN verification, role, session |
| `ConfigCubit` | App-level | Rooms, booking types, sources — loaded once post-auth |
| `BookingCubit` | Feature-level | Save, edit, conflict check for booking groups |
| `DailyCubit` | Feature-level | Load daily room status, fetch group by day |
| `MonthlyCubit` | Feature-level | Load month bookings, compute day stats |
| `SettingsCubit` | Feature-level | CRUD for rooms, types, sources (owner only) |

### 9.2 ConfigCubit — Session Config for All Roles

```dart
// States
class ConfigLoading extends ConfigState {}
class ConfigLoaded extends ConfigState {
  final List<Room> rooms;
  final List<BookingType> bookingTypes;
  final List<BookingSource> bookingSources;
}
class ConfigError extends ConfigState {
  final String message;
}

// Cubit
class ConfigCubit extends Cubit<ConfigState> {
  final ConfigRepository _repo;

  Future<void> loadConfig() async {
    emit(ConfigLoading());
    try {
      final rooms   = await _repo.fetchRooms(AppConstants.propertyId);
      final types   = await _repo.fetchBookingTypes(AppConstants.propertyId);
      final sources = await _repo.fetchBookingSources(AppConstants.propertyId);
      emit(ConfigLoaded(rooms: rooms, bookingTypes: types, bookingSources: sources));
    } catch (e) {
      emit(ConfigError(e.toString()));
    }
  }

  // Called by SettingsCubit after any config change to refresh session state
  Future<void> reload() => loadConfig();
}
```

> `ConfigCubit` is provided at app root so both Entry form and Settings screen read from the same cached state.

### 9.3 BookingCubit — Save & Edit

```dart
// States
class BookingIdle extends BookingState {}
class BookingChecking extends BookingState {}       // conflict check in progress
class BookingConflict extends BookingState {
  final List<ConflictInfo> conflicts;               // dates + room names
}
class BookingSaving extends BookingState {}
class BookingSaved extends BookingState {}
class BookingError extends BookingState {
  final String message;
}

// Key methods
class BookingCubit extends Cubit<BookingState> {

  Future<void> checkAndSave(BookingGroupInput input) async {
    emit(BookingChecking());
    final conflicts = await _repo.checkConflicts(input);
    if (conflicts.isNotEmpty) {
      emit(BookingConflict(conflicts: conflicts));
      return; // UI shows warning dialog
    }
    await _save(input);
  }

  Future<void> confirmOverwrite(BookingGroupInput input) async {
    // User confirmed conflict dialog
    await _repo.softDeleteConflicts(input);
    await _save(input);
  }

  Future<void> _save(BookingGroupInput input) async {
    emit(BookingSaving());
    try {
      await _repo.saveBookingGroup(input);
      emit(BookingSaved());
    } catch (e) {
      emit(BookingError(e.toString()));
    }
  }
}
```

---

## 10. Screen & Navigation Design

### 10.1 Screen Map

```
PINScreen
    │
    └── HomeShell (Bottom Nav: Entry | Daily | Monthly | Settings*)
            │
            ├── EntryScreen
            │       └── BookingForm (modal bottom sheet)
            │               ├── Date range picker (check-in / check-out)
            │               ├── Room dropdown
            │               ├── Booking Type selector
            │               ├── Booking Source selector (filtered by type)
            │               ├── Total Amount field (₹)
            │               ├── Payment Received toggle (group level)
            │               └── Notes field
            │
            ├── DailyScreen
            │       └── Room card tap → BookingForm (pre-filled with full group)
            │
            ├── MonthlyScreen
            │       └── Date tap → DayDetailCard → Group row tap → BookingForm
            │
            └── SettingsScreen  [OWNER ONLY]
                    ├── RoomConfigScreen
                    ├── BookingTypeConfigScreen
                    └── BookingSourceConfigScreen

* Settings tab hidden for STAFF role
```

### 10.2 Bottom Navigation

| Tab | Icon | Visible To |
|-----|------|------------|
| Entry | ✏️ | Owner, Staff |
| Daily | 📅 | Owner, Staff |
| Monthly | 🗓 | Owner, Staff |
| Settings | ⚙️ | Owner only (hidden for Staff) |

### 10.3 Entry / Edit Form — BookingForm

The same `BookingForm` widget is used for new entry and editing an existing group. It receives an optional `BookingGroup?` — if non-null, all fields are pre-filled.

**Fields:**

| Field | Type | Notes |
|-------|------|-------|
| Room | Dropdown | From `ConfigCubit` rooms |
| Check-in date | Date picker | Defaults to today |
| Check-out date | Date picker | Must be > check-in |
| Nights (computed) | Display only | check-out − check-in |
| Total Amount (₹) | Number field | Group-level total |
| Per-night Amount | Display only | Total ÷ Nights |
| Booking Type | Selector chips | From `ConfigCubit` booking_types |
| Booking Source | Dropdown | Filtered by selected type |
| Payment Received | Toggle | Group-level boolean |
| Notes | Text field | Optional |

### 10.4 Daily Screen

- Date picker at top (defaults to today)
- Room cards: one per active room
- Card shows: status pill, type badge, source name, total group amount, payment status
- **Tapping any card** (booked or vacant) opens `BookingForm` as a bottom sheet
  - If booked: pre-filled with the full `booking_group` for that room/date
  - If vacant: empty form with room and date pre-filled

### 10.5 Monthly Screen

- Month navigation header
- Room filter pill row (All Rooms + individual rooms)
- Heatmap calendar — each cell shows revenue and occupancy %
- Tap a date → `DayDetailCard` slides in below calendar
  - Shows room-by-room rows for that date
  - Each row shows: room, source, amount, payment status
  - Tapping a row opens `BookingForm` pre-filled with full group

---

## 11. Data Flow Diagrams

### 11.1 Save New Booking Group

```
User fills BookingForm and taps Save
        │
        ▼
BookingCubit.checkAndSave(input)
        │
        ▼
BookingRepository.checkConflicts(roomId, nightDates)
        │
        ├── No conflicts
        │       └── BookingRepository.saveBookingGroup(input)
        │               1. INSERT booking_groups row
        │               2. INSERT booking_days rows (one per night)
        │                  amount = total / nights
        │               └── Emit BookingSaved → UI pops form, refreshes view
        │
        └── Conflicts found
                └── Emit BookingConflict → UI shows ConflictDialog
                        │
                        ├── User cancels → Emit BookingIdle → stay on form
                        │
                        └── User confirms overwrite
                                └── BookingRepository.softDeleteConflicts()
                                    + saveBookingGroup()
                                    └── Emit BookingSaved
```

### 11.2 Edit Booking — Daily View Tap

```
User taps Room 101 on Daily view (date = May 14)
        │
        ▼
DailyCubit.fetchGroupForDay(roomId: Room101, date: May 14)
        │
        ▼
SELECT booking_groups.*
FROM booking_groups
JOIN booking_days ON booking_days.booking_group_id = booking_groups.id
WHERE booking_days.room_id = :roomId
  AND booking_days.booking_date = :date
  AND booking_days.is_active = true
        │
        ▼
BookingForm opens pre-filled:
  Room: Room 101
  Check-in: May 13  |  Check-out: May 16
  Total: ₹9900  |  Per-night: ₹3300
  Source: MakeMyTrip | Payment: Pending
        │
        ▼
User edits and saves → same conflict check + save flow as 11.1
```

### 11.3 Edit — Date Range Shortened

```
User changes check-out from May 16 → May 15 (removes May 15 night)
        │
        ▼
BookingCubit.save(updatedGroup)
        │
        ▼
BookingRepository.updateBookingGroup(group):
  1. Compute removed nights: {May 15}
  2. Soft-delete booking_days WHERE booking_group_id = :id AND date IN {May 15}
     → is_active = false (amount preserved)
  3. UPDATE booking_groups SET check_out = May 15, total_amount = new total
  4. UPDATE remaining booking_days amounts (recalculate split)
```

### 11.4 Load Monthly Calendar

```
User opens Monthly tab or changes month/room filter
        │
        ▼
MonthlyCubit.load(year, month, roomFilter)
        │
        ▼
BookingRepository.fetchMonthDays(propertyId, start, end, roomId?)
  SELECT booking_days.*, booking_groups.*, rooms.*,
         booking_types.*, booking_sources.*
  FROM booking_days
  JOIN booking_groups ON booking_groups.id = booking_days.booking_group_id
  JOIN rooms ON rooms.id = booking_days.room_id
  LEFT JOIN booking_types ON ...
  LEFT JOIN booking_sources ON ...
  WHERE booking_days.property_id = :pid
    AND booking_days.booking_date BETWEEN :start AND :end
    AND booking_days.is_active = true
    AND booking_groups.is_active = true
    AND (:roomId IS NULL OR booking_days.room_id = :roomId)
        │
        ▼
Map to DayStats per date:
  { date → { bookedCount, revenue, occupancyPct, sourceBreakdown } }
        │
        ▼
MonthlyScreen renders heatmap
```

### 11.5 Config Load (Post-Auth, All Roles)

```
AuthCubit emits AuthAuthenticated
        │
        ▼
ConfigCubit.loadConfig()
        │
        ├── fetchRooms(propertyId)        → WHERE is_active = true ORDER BY sort_order
        ├── fetchBookingTypes(propertyId) → WHERE is_active = true ORDER BY sort_order
        └── fetchBookingSources(propertyId) → WHERE is_active = true ORDER BY sort_order
        │
        ▼
ConfigLoaded state — cached for entire session
        │
        ▼
Entry form, Daily form, Monthly filter all read from ConfigCubit
```

---

## 12. Configuration & Settings Design

### 12.1 Configurable Entities

| Entity | Editable By | Stored In |
|--------|-------------|-----------|
| Room names + order | Owner | `rooms` table |
| Booking types | Owner | `booking_types` table |
| Booking sources (OTA names) | Owner | `booking_sources` table |

### 12.2 Config in Entry Form

```
BookingType chips  ←  ConfigCubit.bookingTypes (all active types)
        │
        └── On type selected:
BookingSource dropdown  ←  ConfigCubit.bookingSources
                           .where(source.bookingTypeId == selectedType.id)
                           (hidden if no sources for selected type)
```

### 12.3 Settings → Config Refresh

After any settings change (add/edit/delete/reorder), `SettingsCubit` calls `ConfigCubit.reload()` to refresh the session cache. Staff users on the Entry screen will see updated options on next form open.

### 12.4 Soft-Delete Behaviour in Config

When a booking type or source is soft-deleted (`is_active = false`):
- It disappears from Entry form dropdowns
- Existing `booking_groups` referencing it are **not affected** — historical data is preserved
- The item remains visible in Settings list with a visual "inactive" state, and can be restored

---

## 13. Role-Based Access Control

| Feature | Owner | Staff |
|---------|-------|-------|
| PIN login | ✅ (owner PIN) | ✅ (staff PIN) |
| Add booking | ✅ | ✅ |
| Edit booking | ✅ | ✅ |
| Daily view | ✅ | ✅ |
| Monthly view | ✅ | ✅ |
| Config loaded at session start | ✅ | ✅ |
| Settings — view/edit rooms | ✅ | ❌ |
| Settings — view/edit types | ✅ | ❌ |
| Settings — view/edit sources | ✅ | ❌ |
| Bottom nav — Settings tab | ✅ visible | ❌ hidden |

> Role is in-memory only (AuthCubit). All Supabase queries use the same anon key scoped to `property_id`. No server-side role enforcement in v1.

---

## 14. API Contract

All calls use `supabase_flutter` client. No Edge Functions needed in v1.

### 14.1 Fetch Config

```
GET /rooms?property_id=eq.<id>&is_active=eq.true&order=sort_order.asc
GET /booking_types?property_id=eq.<id>&is_active=eq.true&order=sort_order.asc
GET /booking_sources?property_id=eq.<id>&is_active=eq.true&order=sort_order.asc
```

### 14.2 Fetch Daily View

```
GET /booking_days
  ?property_id=eq.<id>
  &booking_date=eq.<date>
  &is_active=eq.true
  &select=*,booking_groups!inner(*,booking_types(*),booking_sources(*)),rooms(*)
  &booking_groups.is_active=eq.true
```

### 14.3 Fetch Monthly View

```
GET /booking_days
  ?property_id=eq.<id>
  &booking_date=gte.<start>&booking_date=lte.<end>
  &is_active=eq.true
  &select=*,booking_groups!inner(*,booking_types(*),booking_sources(*)),rooms(*)
  [&room_id=eq.<room_id>]
```

### 14.4 Conflict Check

```
GET /booking_days
  ?room_id=eq.<room_id>
  &booking_date=in.(<date1>,<date2>,...)
  &is_active=eq.true
  &select=booking_date,rooms(name)
```

### 14.5 Save Booking Group

```
POST /booking_groups  → INSERT booking_groups row, returns id

POST /booking_days    → INSERT multiple rows (one per night)
  Body: [
    { booking_group_id, property_id, room_id, booking_date, amount, is_active: true },
    ...
  ]
```

### 14.6 Soft-Delete Conflict Days

```
PATCH /booking_days
  ?room_id=eq.<room_id>&booking_date=in.(<dates>)&is_active=eq.true
  Body: { is_active: false }

PATCH /booking_groups
  ?id=eq.<group_id>  (if all its days are now inactive)
  Body: { is_active: false }
```

### 14.7 Update Booking Group (Edit)

```
PATCH /booking_groups?id=eq.<id>
  Body: { check_in, check_out, total_amount, payment_received,
          booking_type_id, booking_source_id, notes, updated_at }

PATCH /booking_days?booking_group_id=eq.<id>&booking_date=in.(<removed_dates>)
  Body: { is_active: false }

PATCH /booking_days?booking_group_id=eq.<id>&is_active=eq.true
  Body: { amount: <new_per_night_amount> }
```

---

## 15. Non-Functional Requirements

| Requirement | Target | Approach |
|-------------|--------|----------|
| App launch to PIN screen | < 2s | Supabase init deferred to post-auth |
| Config load time | < 1s | 3 small queries, cached for session |
| Monthly load time | < 1.5s | Single JOIN query for full month |
| Daily load time | < 0.5s | Single date filter query |
| APK size | < 25 MB | Flutter release build, no heavy assets |
| Supabase plan | Free tier | Sufficient for single property volume |
| Data backup | Automatic | Supabase managed Postgres daily backups |

---

## 16. Future Considerations

| Feature | How Architecture Supports It |
|---------|-------------------------------|
| Multiple properties | `property_id` on all tables; swap constant per APK build |
| Partial payment tracking | Add `amount_received` column to `booking_groups` |
| Export to Excel/PDF | Dart-side export from `booking_days` query |
| Staff activity log | Add `created_by_role` to `booking_groups` |
| iOS support | Flutter codebase is already cross-platform |
| Secure PIN storage | Replace `constants.dart` with `flutter_secure_storage` |
| Multi-device sync | Supabase Realtime on `booking_days` table |

---

## Appendix A — Supabase Setup Checklist

- [ ] Create Supabase project
- [ ] Run table creation SQL (Section 5.2)
- [ ] Run partial unique index SQL for `booking_days`
- [ ] Run seed data SQL (Section 5.4)
- [ ] Copy project URL and anon key into `supabase_config.dart`
- [ ] Copy generated property UUID into `constants.dart`
- [ ] Disable Row Level Security on all tables
- [ ] Verify REST API via Supabase Table Editor

## Appendix B — Flutter Build Checklist

- [ ] Set `ownerPin` and `staffPin` in `constants.dart`
- [ ] Set `propertyId` in `constants.dart`
- [ ] Set Supabase URL and anon key in `supabase_config.dart`
- [ ] Run `flutter build apk --release`
- [ ] Test on target Android device
- [ ] Distribute APK via WhatsApp / Google Drive / direct share

## Appendix C — Booking Group: Key Rules Summary

| Rule | Detail |
|------|--------|
| Nights calculation | check_out − check_in (exclusive end) |
| Amount split | total / nights, decimal stored as NUMERIC(10,2) |
| Payment status | Boolean on `booking_groups`, not per night |
| Edit opens full group | Tapping any night shows the whole booking group |
| Soft-delete on range change | Removed nights set is_active = false, amount preserved |
| Conflict resolution | Warning dialog → user confirms → overwrite (soft-delete old, insert new) |
| Single-night booking | Same model — 1 night group, 1 booking_days row |
