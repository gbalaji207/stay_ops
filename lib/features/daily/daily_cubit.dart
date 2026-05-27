import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../shared/models/booking_group.dart';
import '../../shared/models/booking_source.dart';
import '../../shared/models/room.dart';
import 'calendar_booking.dart';
import 'daily_repository.dart';
import 'room_day_status.dart';

part 'daily_state.dart';

/// Strips time from [dt], converting to LOCAL timezone first so that
/// UTC timestamps (e.g. 2026-05-18T18:30Z = IST midnight 2026-05-19) map to
/// the correct local calendar date rather than the UTC date.
DateTime _localDateOnly(DateTime dt) {
  final local = dt.toLocal();
  return DateTime(local.year, local.month, local.day);
}

class DailyCubit extends Cubit<DailyState> {
  DailyCubit(this._repository) : super(const DailyInitial());

  final DailyRepository _repository;

  /// Load all room statuses for [date].
  /// [allRooms] and [allSources] are passed from ConfigCubit so source names
  /// are resolved at load time, not at render time.
  ///
  /// A room can now appear more than once when it has both a day-use and a
  /// night booking on the same date. The statuses list may therefore be longer
  /// than allRooms.length.
  Future<void> load(
    DateTime date,
    List<Room> allRooms,
    List<BookingSource> allSources,
  ) async {
    if (isClosed) return;
    emit(const DailyLoading());
    try {
      final rows = await _repository.fetchDayBookings(date);
      final sourceById = {for (final s in allSources) s.id: s};

      // Group rows by roomId — a room can have multiple bookings (day-use + night)
      final bookedByRoomId = <String, List<dynamic>>{};
      for (final r in rows) {
        bookedByRoomId.putIfAbsent(r.roomId, () => []).add(r);
      }

      final statuses = allRooms.expand((room) {
        final roomRows = bookedByRoomId[room.id] ?? [];
        if (roomRows.isEmpty) return [RoomDayStatus.vacant(room: room)];
        return roomRows.map((row) {
          final sourceName = row.bookingSourceId != null
              ? sourceById[row.bookingSourceId!]?.name
              : null;
          return RoomDayStatus.booked(
            room: room,
            bookingGroupId: row.bookingGroupId,
            checkIn: row.checkIn,
            checkOut: row.checkOut,
            perNightAmount: row.amount,
            paymentReceived: row.paymentReceived,
            sourceName: sourceName,
          );
        });
      }).toList();

      if (isClosed) return;
      emit(DailyLoaded(date: date, rooms: statuses));
    } catch (e) {
      if (isClosed) return;
      emit(DailyError(e.toString()));
    }
  }

  /// Fetch the full booking group for a booked card tap without replacing the
  /// loaded list. Uses [bookingGroupId] directly so the correct booking is
  /// returned even when a room has multiple bookings on the same date.
  ///
  /// Works for both [DailyLoaded] (legacy) and [DailyRangeLoaded] (calendar view).
  Future<void> fetchGroupForDay(String bookingGroupId) async {
    final previous = state;
    if (previous is! DailyLoaded && previous is! DailyRangeLoaded) return;
    try {
      final group = await _repository.fetchGroupByGroupId(bookingGroupId);
      if (isClosed) return;
      emit(DailyGroupFetched(group: group, previous: previous));
      emit(previous);
    } catch (e) {
      if (isClosed) return;
      emit(DailyError(e.toString()));
    }
  }

  /// Load all bookings visible in a [visibleDays]-wide window starting at
  /// [anchorDate]. Emits [DailyRangeLoaded] for the calendar timeline view.
  ///
  /// Fetches booking_days for the full range, then de-duplicates by
  /// bookingGroupId so multi-night bookings appear as a single span entry.
  Future<void> loadRange(
    DateTime anchorDate,
    int visibleDays,
    List<Room> allRooms,
    List<BookingSource> allSources,
  ) async {
    if (isClosed) return;
    emit(const DailyLoading());
    try {
      final endDate = anchorDate.add(Duration(days: visibleDays - 1));
      final rows = await _repository.fetchRangeBookings(anchorDate, endDate);
      final sourceById = {for (final s in allSources) s.id: s};

      // De-duplicate by bookingGroupId — a multi-night booking has one
      // booking_days row per visible date, but we want a single CalendarBooking.
      final bookingMap = <String, CalendarBooking>{};
      for (final row in rows) {
        if (bookingMap.containsKey(row.bookingGroupId)) continue;
        final roomIdx = allRooms.indexWhere((r) => r.id == row.roomId);
        if (roomIdx == -1) continue;

        // Derive LOCAL calendar dates from the TIMESTAMPTZ fields when
        // available. This avoids UTC-offset errors: e.g. a checkout stored
        // as UTC midnight (= IST 05:30 of the same day, still same date) or
        // as UTC 18:30 the previous day (= IST midnight = day boundary).
        // Falling back to the DATE columns when the timestamp is absent.
        final checkIn = _localDateOnly(row.checkInDatetime ?? row.checkIn);
        final checkOut = _localDateOnly(row.checkOutDatetime ?? row.checkOut);

        bookingMap[row.bookingGroupId] = CalendarBooking(
          bookingGroupId: row.bookingGroupId,
          room: allRooms[roomIdx],
          checkIn: checkIn,
          checkOut: checkOut,
          perNightAmount: row.amount,
          paymentReceived: row.paymentReceived,
          sourceName: row.bookingSourceId != null
              ? sourceById[row.bookingSourceId!]?.name
              : null,
          customerName: row.customerName,
          // Full local datetimes for sub-column fractional rendering.
          // Null for legacy bookings that pre-date the TIMESTAMPTZ columns.
          checkInDatetime: row.checkInDatetime?.toLocal(),
          checkOutDatetime: row.checkOutDatetime?.toLocal(),
        );
      }

      if (isClosed) return;
      emit(DailyRangeLoaded(
        anchorDate: anchorDate,
        visibleDays: visibleDays,
        rooms: allRooms.where((r) => r.isActive).toList(),
        bookings: bookingMap.values.toList(),
      ));
    } catch (e) {
      if (isClosed) return;
      emit(DailyError(e.toString()));
    }
  }
}
