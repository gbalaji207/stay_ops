import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'booking_group_input.dart';
import 'booking_repository.dart';

part 'booking_state.dart';

class BookingCubit extends Cubit<BookingState> {
  BookingCubit(this._repository) : super(const BookingIdle());

  final BookingRepository _repository;

  Future<void> checkAndSave(BookingGroupInput input) async {
    if (isClosed) return;
    emit(const BookingChecking());
    try {
      final conflicts = await _repository.checkConflicts(
        input.roomId,
        input.checkInDatetime,
        input.checkOutDatetime,
        excludeGroupId: input.existingGroupId, // null for new bookings
      );
      if (isClosed) return;
      if (conflicts.isEmpty) {
        await _executeSave(input);
      } else {
        emit(BookingConflict(conflicts: conflicts, pendingInput: input));
      }
    } catch (e) {
      if (isClosed) return;
      emit(BookingError(e.toString()));
    }
  }

  Future<void> confirmOverwrite() async {
    final current = state;
    if (current is! BookingConflict) return;
    final input = current.pendingInput;
    if (isClosed) return;
    emit(const BookingSaving());
    try {
      final conflictGroupIds =
          current.conflicts.map((c) => c.groupId).toList();
      await _repository.softDeleteConflicts(conflictGroupIds);
      await _executeSave(input);
    } catch (e) {
      if (isClosed) return;
      emit(BookingError(e.toString()));
    }
  }

  void reset() {
    if (!isClosed) emit(const BookingIdle());
  }

  Future<void> _executeSave(BookingGroupInput input) async {
    if (isClosed) return;
    emit(const BookingSaving());
    try {
      if (input.existingGroupId != null) {
        await _repository.updateBookingGroup(input);
      } else {
        await _repository.saveBookingGroup(input);
      }
      if (isClosed) return;
      emit(const BookingSaved());
    } catch (e) {
      if (isClosed) return;
      emit(BookingError(e.toString()));
    }
  }
}
