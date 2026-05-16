part of 'config_cubit.dart';

abstract class ConfigState extends Equatable {
  const ConfigState();
}

class ConfigInitial extends ConfigState {
  const ConfigInitial();

  @override
  List<Object?> get props => [];
}

class ConfigLoading extends ConfigState {
  const ConfigLoading();

  @override
  List<Object?> get props => [];
}

class ConfigLoaded extends ConfigState {
  const ConfigLoaded({
    required this.rooms,
    required this.bookingTypes,
    required this.bookingSources,
    required this.paymentDestinations,
  });

  final List<Room> rooms;
  final List<BookingType> bookingTypes;
  final List<BookingSource> bookingSources;
  final List<PaymentDestination> paymentDestinations;

  @override
  List<Object?> get props =>
      [rooms, bookingTypes, bookingSources, paymentDestinations];
}

class ConfigError extends ConfigState {
  const ConfigError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
