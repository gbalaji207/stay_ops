part of 'settings_cubit.dart';

abstract class SettingsState extends Equatable {
  const SettingsState();
}

class SettingsInitial extends SettingsState {
  const SettingsInitial();

  @override
  List<Object?> get props => [];
}

class SettingsLoading extends SettingsState {
  const SettingsLoading();

  @override
  List<Object?> get props => [];
}

class SettingsLoaded extends SettingsState {
  const SettingsLoaded({
    required this.propertyName,
    required this.rooms,
    required this.bookingTypes,
    required this.bookingSources,
  });

  final String propertyName;
  final List<Room> rooms;
  final List<BookingType> bookingTypes;
  final List<BookingSource> bookingSources;

  @override
  List<Object?> get props =>
      [propertyName, rooms, bookingTypes, bookingSources];
}

class SettingsError extends SettingsState {
  const SettingsError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
