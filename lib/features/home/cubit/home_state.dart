part of 'home_cubit.dart';

abstract class HomeState extends Equatable {
  const HomeState();
}

class HomeInitial extends HomeState {
  const HomeInitial();
  @override
  List<Object?> get props => [];
}

class HomeLoading extends HomeState {
  const HomeLoading();
  @override
  List<Object?> get props => [];
}

class HomeLoaded extends HomeState {
  const HomeLoaded({
    required this.checkOuts,
    required this.checkIns,
    required this.occupancy,
    required this.upcoming,
    required this.newToday,
    required this.paymentPending,
  });

  final List<BookingGroup> checkOuts;
  final List<BookingGroup> checkIns;
  final OccupancySnapshot occupancy;
  final Map<DateTime, List<BookingGroup>> upcoming;
  final List<BookingGroup> newToday;
  final List<BookingGroup> paymentPending;

  @override
  List<Object?> get props => [
        checkOuts,
        checkIns,
        occupancy,
        upcoming,
        newToday,
        paymentPending,
      ];
}

class HomeError extends HomeState {
  const HomeError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
