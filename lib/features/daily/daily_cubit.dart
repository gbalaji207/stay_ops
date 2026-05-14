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
  Future<void> load(
    DateTime date,
    List<Room> allRooms,
    List<BookingSource> allSources,
  ) async {
    if (isClosed) return;
    emit(const DailyLoading());
    try {
      final rows = await _repository.fetchDayBookings(date);
      final bookedByRoomId = {for (final r in rows) r.roomId: r};
      final sourceById = {for (final s in allSources) s.id: s};

      final statuses = allRooms.map((room) {
        final row = bookedByRoomId[room.id];
        if (row != null) {
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
        }
        return RoomDayStatus.vacant(room: room);
      }).toList();

      if (isClosed) return;
      emit(DailyLoaded(date: date, rooms: statuses));
    } catch (e) {
      if (isClosed) return;
      emit(DailyError(e.toString()));
    }
  }

  /// Fetch the full booking group for a booked card tap without replacing
  /// the loaded list. Emits [DailyGroupFetched] (transient) then re-emits
  /// the previous [DailyLoaded] so the list stays visible.
  Future<void> fetchGroupForDay(String roomId, DateTime date) async {
    final previous = state;
    if (previous is! DailyLoaded) return;
    try {
      final group = await _repository.fetchGroupByDay(roomId, date);
      if (isClosed) return;
      emit(DailyGroupFetched(group: group, previous: previous));
      emit(previous);
    } catch (e) {
      if (isClosed) return;
      emit(DailyError(e.toString()));
    }
  }
}
