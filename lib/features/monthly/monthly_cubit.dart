import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../shared/models/booking_group.dart';
import '../../shared/models/room.dart';
import 'day_stats.dart';
import 'month_booking_row.dart';
import 'monthly_repository.dart';

part 'monthly_state.dart';

class MonthlyCubit extends Cubit<MonthlyState> {
  MonthlyCubit(this._repository) : super(const MonthlyInitial());

  final MonthlyRepository _repository;

  // Retained across selectRoom calls so re-filtering doesn't re-fetch.
  List<MonthBookingRow> _rawRows = [];
  List<Room> _allRooms = [];
  int _loadedYear = 0;
  int _loadedMonth = 0;

  /// Fetch all active booking_days for [year]/[month].
  /// Preserves the active room filter across month navigation.
  /// Always resets the selected day.
  Future<void> load(int year, int month, List<Room> allRooms) async {
    if (isClosed) return;
    final prevSelectedRoomId =
        state is MonthlyLoaded ? (state as MonthlyLoaded).selectedRoomId : null;
    emit(const MonthlyLoading());
    try {
      _rawRows = await _repository.fetchMonthBookings(year, month);
      _allRooms = allRooms;
      _loadedYear = year;
      _loadedMonth = month;
      if (isClosed) return;
      emit(_buildLoaded(
        year: year,
        month: month,
        selectedDay: null,
        selectedRoomId: prevSelectedRoomId,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(MonthlyError(e.toString()));
    }
  }

  /// Toggle the selected calendar day. Tapping the same day again deselects.
  void selectDate(int day) {
    final current = state;
    if (current is! MonthlyLoaded) return;
    final newDay = current.selectedDay == day ? null : day;
    emit(current.copyWith(selectedDay: newDay));
  }

  /// Apply a room filter without re-fetching. [roomId] == null means "All".
  void selectRoom(String? roomId) {
    final current = state;
    if (current is! MonthlyLoaded) return;
    if (current.selectedRoomId == roomId) return;
    emit(_buildLoaded(
      year: _loadedYear,
      month: _loadedMonth,
      selectedDay: current.selectedDay,
      selectedRoomId: roomId,
    ));
  }

  /// Fetch the full booking group for an edit tap in the day-detail card.
  /// Uses [bookingGroupId] directly so the correct booking is returned even
  /// when a room has multiple bookings on the same date (day-use + night).
  /// Emits [MonthlyGroupFetched] (transient) then re-emits the previous
  /// [MonthlyLoaded] so the calendar stays visible while the sheet is open.
  Future<void> fetchGroupForDay(String bookingGroupId) async {
    final previous = state;
    if (previous is! MonthlyLoaded) return;
    try {
      final group = await _repository.fetchGroupByGroupId(bookingGroupId);
      if (isClosed) return;
      emit(MonthlyGroupFetched(group: group, previous: previous));
      emit(previous);
    } catch (e) {
      if (isClosed) return;
      emit(MonthlyError(e.toString()));
    }
  }

  // ─── Private ────────────────────────────────────────────────────────────────

  MonthlyLoaded _buildLoaded({
    required int year,
    required int month,
    required int? selectedDay,
    required String? selectedRoomId,
  }) {
    final filtered = selectedRoomId == null
        ? _rawRows
        : _rawRows.where((r) => r.roomId == selectedRoomId).toList();

    final totalRooms = selectedRoomId == null ? _allRooms.length : 1;

    // Group filtered rows by day-of-month
    final Map<int, List<MonthBookingRow>> byDay = {};
    for (final row in filtered) {
      byDay.putIfAbsent(row.bookingDate.day, () => []).add(row);
    }

    // Build DayStats for each day that has at least one booking
    final Map<int, DayStats> dayStats = {};
    for (final entry in byDay.entries) {
      final day = entry.key;
      final rows = entry.value;

      final revenue = rows.fold<double>(0, (s, r) => s + r.amount);

      final roomRows = rows.map((row) {
        final room = _allRooms.firstWhere(
          (r) => r.id == row.roomId,
          orElse: () => Room(
            id: row.roomId,
            propertyId: '',
            name: row.roomId,
            sortOrder: 999,
            isActive: true,
          ),
        );
        return DayRoomRow(
          roomId: row.roomId,
          roomName: room.name,
          bookingGroupId: row.bookingGroupId,
          perNightAmount: row.amount,
          paymentReceived: row.paymentReceived,
          sourceName: row.bookingSourceName,
          typeName: row.bookingTypeName,
        );
      }).toList()
        ..sort((a, b) {
          final ia = _allRooms.indexWhere((r) => r.id == a.roomId);
          final ib = _allRooms.indexWhere((r) => r.id == b.roomId);
          if (ia == -1) return 1;
          if (ib == -1) return -1;
          return ia.compareTo(ib);
        });

      // bookedCount = unique rooms occupied (a room with day-use + night stay
      // has 2 rows but is only 1 occupied room for occupancy purposes)
      final uniqueOccupiedRooms = rows.map((r) => r.roomId).toSet().length;

      dayStats[day] = DayStats(
        date: DateTime(year, month, day),
        revenue: revenue,
        bookedCount: uniqueOccupiedRooms,
        totalRooms: totalRooms,
        rooms: roomRows,
      );
    }

    // Month-level aggregation
    final monthRevenue =
        dayStats.values.fold<double>(0, (s, d) => s + d.revenue);

    final bookedDays = dayStats.values.where((d) => d.bookedCount > 0).toList();
    final avgOccupancyPct = bookedDays.isEmpty
        ? 0.0
        : bookedDays.fold<double>(0, (s, d) => s + d.occupancyPct) /
            bookedDays.length;

    return MonthlyLoaded(
      year: year,
      month: month,
      dayStats: dayStats,
      selectedDay: selectedDay,
      selectedRoomId: selectedRoomId,
      monthRevenue: monthRevenue,
      avgOccupancyPct: avgOccupancyPct,
    );
  }
}
