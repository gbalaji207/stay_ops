import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../shared/models/booking_source.dart';
import '../../shared/models/booking_type.dart';
import '../../shared/models/room.dart';
import '../config/config_cubit.dart';
import 'settings_repository.dart';

part 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._repository, this._configCubit)
      : super(const SettingsInitial());

  final SettingsRepository _repository;
  final ConfigCubit _configCubit;

  Future<void> loadAll() async {
    emit(const SettingsLoading());
    try {
      final results = await Future.wait([
        _repository.fetchPropertyName(),
        _repository.fetchAllRooms(),
        _repository.fetchAllBookingTypes(),
        _repository.fetchAllBookingSources(),
      ]);
      emit(SettingsLoaded(
        propertyName: results[0] as String,
        rooms: results[1] as List<Room>,
        bookingTypes: results[2] as List<BookingType>,
        bookingSources: results[3] as List<BookingSource>,
      ));
    } catch (e) {
      emit(SettingsError(e.toString()));
    }
  }

  Future<void> _reloadAfterWrite() async {
    await _configCubit.reload();
    await loadAll();
  }

  // ── Rooms ──────────────────────────────────────────────────────────────────

  Future<void> addRoom(String name) async {
    final state = this.state;
    if (state is! SettingsLoaded) return;
    final nextOrder =
        state.rooms.isEmpty ? 1 : state.rooms.last.sortOrder + 1;
    await _repository.addRoom(name, nextOrder);
    await _reloadAfterWrite();
  }

  Future<void> updateRoom(String id, String name) async {
    await _repository.updateRoom(id, name);
    await _reloadAfterWrite();
  }

  Future<void> setRoomActive(String id, {required bool isActive}) async {
    await _repository.setRoomActive(id, isActive: isActive);
    await _reloadAfterWrite();
  }

  // ── Booking types ──────────────────────────────────────────────────────────

  Future<void> addBookingType(String name) async {
    final state = this.state;
    if (state is! SettingsLoaded) return;
    final nextOrder =
        state.bookingTypes.isEmpty ? 1 : state.bookingTypes.last.sortOrder + 1;
    await _repository.addBookingType(name, nextOrder);
    await _reloadAfterWrite();
  }

  Future<void> updateBookingType(String id, String name) async {
    await _repository.updateBookingType(id, name);
    await _reloadAfterWrite();
  }

  Future<void> setBookingTypeActive(
    String id, {
    required bool isActive,
  }) async {
    await _repository.setBookingTypeActive(id, isActive: isActive);
    await _reloadAfterWrite();
  }

  // ── Booking sources ────────────────────────────────────────────────────────

  Future<void> addBookingSource(String name, String bookingTypeId) async {
    final state = this.state;
    if (state is! SettingsLoaded) return;
    final sourcesForType = state.bookingSources
        .where((s) => s.bookingTypeId == bookingTypeId)
        .toList();
    final nextOrder =
        sourcesForType.isEmpty ? 1 : sourcesForType.last.sortOrder + 1;
    await _repository.addBookingSource(name, bookingTypeId, nextOrder);
    await _reloadAfterWrite();
  }

  Future<void> updateBookingSource(String id, String name) async {
    await _repository.updateBookingSource(id, name);
    await _reloadAfterWrite();
  }

  Future<void> setBookingSourceActive(
    String id, {
    required bool isActive,
  }) async {
    await _repository.setBookingSourceActive(id, isActive: isActive);
    await _reloadAfterWrite();
  }
}
