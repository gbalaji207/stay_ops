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
class DailyGroupFetched extends DailyState {
  const DailyGroupFetched({required this.group, required this.previous});
  final BookingGroup group;
  final DailyLoaded previous;
  @override
  List<Object?> get props => [group];
}
