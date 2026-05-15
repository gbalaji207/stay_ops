import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/models/booking_group.dart';
import '../../../shared/models/occupancy_snapshot.dart';
import '../repository/home_repository.dart';

part 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit(this._repository) : super(const HomeInitial());

  final HomeRepository _repository;

  Future<void> load(DateTime today, int totalRooms) async {
    if (isClosed) return;
    emit(const HomeLoading());
    try {
      final results = await Future.wait([
        _repository.fetchCheckOuts(today),
        _repository.fetchCheckIns(today),
        _repository.fetchOccupancy(today, totalRooms),
        _repository.fetchUpcoming(today),
        _repository.fetchNewToday(today),
        _repository.fetchPaymentPending(),
      ]);
      if (isClosed) return;
      emit(HomeLoaded(
        checkOuts: results[0] as List<BookingGroup>,
        checkIns: results[1] as List<BookingGroup>,
        occupancy: results[2] as OccupancySnapshot,
        upcoming: results[3] as Map<DateTime, List<BookingGroup>>,
        newToday: results[4] as List<BookingGroup>,
        paymentPending: results[5] as List<BookingGroup>,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(HomeError(e.toString()));
    }
  }

  Future<void> refresh(DateTime today, int totalRooms) =>
      load(today, totalRooms);
}
