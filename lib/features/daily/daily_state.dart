part of 'daily_cubit.dart';

abstract class DailyState extends Equatable {
  const DailyState();
}

class DailyInitial extends DailyState {
  const DailyInitial();
  @override
  List<Object?> get props => [];
}

class DailyLoading extends DailyState {
  const DailyLoading();
  @override
  List<Object?> get props => [];
}

class DailyLoaded extends DailyState {
  const DailyLoaded({required this.date, required this.rooms});
  final DateTime date;
  final List<RoomDayStatus> rooms;
  @override
  List<Object?> get props => [date, rooms];
}

class DailyError extends DailyState {
  const DailyError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

// Transient state emitted when a booked card is tapped.
// The cubit immediately re-emits [previous] after this, so BlocBuilder
// never renders a blank list. BlocListener opens the edit sheet.
// [previous] is typed as [DailyState] to support both DailyLoaded (legacy)
// and DailyRangeLoaded (calendar view).
class DailyGroupFetched extends DailyState {
  const DailyGroupFetched({required this.group, required this.previous});
  final BookingGroup group;
  final DailyState previous;
  @override
  List<Object?> get props => [group];
}

/// State emitted by [DailyCubit.loadRange] for the calendar timeline view.
/// Contains all bookings across [visibleDays] columns starting at [anchorDate].
class DailyRangeLoaded extends DailyState {
  const DailyRangeLoaded({
    required this.anchorDate,
    required this.visibleDays,
    required this.rooms,
    required this.bookings,
  });

  /// First visible column (start of the range, date only — time stripped).
  final DateTime anchorDate;

  /// Number of day columns shown: 3 (small screen) or 7 (large screen).
  final int visibleDays;

  /// Active rooms in sort order.
  final List<Room> rooms;

  /// All bookings whose booking_days overlap the visible range.
  /// One entry per booking group (de-duplicated).
  final List<CalendarBooking> bookings;

  @override
  List<Object?> get props => [anchorDate, visibleDays, rooms, bookings];
}
