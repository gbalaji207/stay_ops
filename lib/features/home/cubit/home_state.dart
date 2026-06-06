part of 'home_cubit.dart';

enum HomeTab { newBookings, inHouse, checkIns, checkOuts, paymentsReceived }

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
    required this.selectedDate,
    required this.selectedTab,
    required this.inHouse,
    required this.newBookings,
    required this.checkIns,
    required this.checkOuts,
    required this.paymentsReceived,
  });

  final DateTime selectedDate;
  final HomeTab selectedTab;
  final List<BookingGroup> inHouse;
  final List<BookingGroup> newBookings;
  final List<BookingGroup> checkIns;
  final List<BookingGroup> checkOuts;
  final List<BookingGroup> paymentsReceived;

  List<BookingGroup> get activeList {
    switch (selectedTab) {
      case HomeTab.newBookings:
        return newBookings;
      case HomeTab.inHouse:
        return inHouse;
      case HomeTab.checkIns:
        return checkIns;
      case HomeTab.checkOuts:
        return checkOuts;
      case HomeTab.paymentsReceived:
        return paymentsReceived;
    }
  }

  HomeLoaded copyWith({
    DateTime? selectedDate,
    HomeTab? selectedTab,
    List<BookingGroup>? inHouse,
    List<BookingGroup>? newBookings,
    List<BookingGroup>? checkIns,
    List<BookingGroup>? checkOuts,
    List<BookingGroup>? paymentsReceived,
  }) {
    return HomeLoaded(
      selectedDate: selectedDate ?? this.selectedDate,
      selectedTab: selectedTab ?? this.selectedTab,
      inHouse: inHouse ?? this.inHouse,
      newBookings: newBookings ?? this.newBookings,
      checkIns: checkIns ?? this.checkIns,
      checkOuts: checkOuts ?? this.checkOuts,
      paymentsReceived: paymentsReceived ?? this.paymentsReceived,
    );
  }

  @override
  List<Object?> get props => [
        selectedDate,
        selectedTab,
        inHouse,
        newBookings,
        checkIns,
        checkOuts,
        paymentsReceived,
      ];
}

class HomeError extends HomeState {
  const HomeError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
