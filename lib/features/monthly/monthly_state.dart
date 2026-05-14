part of 'monthly_cubit.dart';

abstract class MonthlyState extends Equatable {
  const MonthlyState();
}

class MonthlyInitial extends MonthlyState {
  const MonthlyInitial();
  @override
  List<Object?> get props => [];
}

class MonthlyLoading extends MonthlyState {
  const MonthlyLoading();
  @override
  List<Object?> get props => [];
}

class MonthlyLoaded extends MonthlyState {
  const MonthlyLoaded({
    required this.year,
    required this.month,
    required this.dayStats,
    required this.selectedDay,
    required this.selectedRoomId,
    required this.monthRevenue,
    required this.avgOccupancyPct,
  });

  final int year;
  final int month;

  /// Key = day-of-month (1..31). Days with no bookings have no entry.
  final Map<int, DayStats> dayStats;

  /// Which calendar day is tapped; null = nothing selected.
  final int? selectedDay;

  /// Active room filter; null = "All".
  final String? selectedRoomId;

  final double monthRevenue;

  /// Mean occupancy % across days that had at least one booking.
  final double avgOccupancyPct;

  static const _sentinel = Object();

  MonthlyLoaded copyWith({
    int? year,
    int? month,
    Map<int, DayStats>? dayStats,
    Object? selectedDay = _sentinel,
    Object? selectedRoomId = _sentinel,
    double? monthRevenue,
    double? avgOccupancyPct,
  }) {
    return MonthlyLoaded(
      year: year ?? this.year,
      month: month ?? this.month,
      dayStats: dayStats ?? this.dayStats,
      selectedDay: identical(selectedDay, _sentinel)
          ? this.selectedDay
          : selectedDay as int?,
      selectedRoomId: identical(selectedRoomId, _sentinel)
          ? this.selectedRoomId
          : selectedRoomId as String?,
      monthRevenue: monthRevenue ?? this.monthRevenue,
      avgOccupancyPct: avgOccupancyPct ?? this.avgOccupancyPct,
    );
  }

  @override
  List<Object?> get props => [
        year,
        month,
        dayStats,
        selectedDay,
        selectedRoomId,
        monthRevenue,
        avgOccupancyPct,
      ];
}

class MonthlyError extends MonthlyState {
  const MonthlyError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

/// Transient state: emitted when a day-detail row is tapped.
/// The cubit immediately re-emits [previous] after this, so BlocBuilder
/// never renders a blank calendar. BlocListener opens the edit sheet.
class MonthlyGroupFetched extends MonthlyState {
  const MonthlyGroupFetched({required this.group, required this.previous});
  final BookingGroup group;
  final MonthlyLoaded previous;
  @override
  List<Object?> get props => [group];
}
