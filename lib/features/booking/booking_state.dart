part of 'booking_cubit.dart';

abstract class BookingState extends Equatable {
  const BookingState();
}

class BookingIdle extends BookingState {
  const BookingIdle();
  @override
  List<Object?> get props => [];
}

class BookingChecking extends BookingState {
  const BookingChecking();
  @override
  List<Object?> get props => [];
}

class BookingConflict extends BookingState {
  const BookingConflict({
    required this.conflicts,
    required this.pendingInput,
  });

  final List<ConflictInfo> conflicts;
  // pendingInput held here so confirmOverwrite() can read it without extra args
  final BookingGroupInput pendingInput;

  @override
  List<Object?> get props => [conflicts];
}

class BookingSaving extends BookingState {
  const BookingSaving();
  @override
  List<Object?> get props => [];
}

class BookingSaved extends BookingState {
  const BookingSaved();
  @override
  List<Object?> get props => [];
}

class BookingError extends BookingState {
  const BookingError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
