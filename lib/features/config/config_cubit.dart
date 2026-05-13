import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../shared/models/booking_source.dart';
import '../../shared/models/booking_type.dart';
import '../../shared/models/room.dart';
import 'config_repository.dart';

part 'config_state.dart';

class ConfigCubit extends Cubit<ConfigState> {
  ConfigCubit(this._repository) : super(const ConfigInitial());

  final ConfigRepository _repository;

  Future<void> loadConfig() async {
    emit(const ConfigLoading());
    try {
      final results = await Future.wait([
        _repository.fetchRooms(),
        _repository.fetchBookingTypes(),
        _repository.fetchBookingSources(),
      ]);
      emit(ConfigLoaded(
        rooms: results[0] as List<Room>,
        bookingTypes: results[1] as List<BookingType>,
        bookingSources: results[2] as List<BookingSource>,
      ));
    } catch (e) {
      emit(ConfigError(e.toString()));
    }
  }

  Future<void> reload() async => loadConfig();
}
