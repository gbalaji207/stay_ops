import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../shared/models/booking_group.dart';
import '../../shared/models/booking_source.dart';
import '../../shared/models/room.dart';
import 'daily_repository.dart';
import 'room_day_status.dart';

part 'daily_state.dart';

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
  Future<void> fetchGroupForDay(String bookingGroupId) async {
    final previous = state;
    if (previous is! DailyLoaded) return;
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
}
