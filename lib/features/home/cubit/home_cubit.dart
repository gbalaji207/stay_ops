import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/models/booking_group.dart';
import '../repository/home_repository.dart';

part 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit(this._repository) : super(const HomeInitial());

  final HomeRepository _repository;

  Future<void> load(DateTime date) async {
    if (isClosed) return;
    emit(const HomeLoading());
    await _fetchAndEmit(date, HomeTab.inHouse);
  }

  Future<void> selectDate(DateTime date) async {
    if (isClosed) return;
    final currentTab =
        state is HomeLoaded ? (state as HomeLoaded).selectedTab : HomeTab.inHouse;
    emit(const HomeLoading());
    await _fetchAndEmit(date, currentTab);
  }

  void selectTab(HomeTab tab) {
    if (state is HomeLoaded) {
      emit((state as HomeLoaded).copyWith(selectedTab: tab));
    }
  }

  Future<void> refresh() async {
    if (state is HomeLoaded) {
      final loaded = state as HomeLoaded;
      emit(const HomeLoading());
      await _fetchAndEmit(loaded.selectedDate, loaded.selectedTab);
    }
  }

  Future<void> _fetchAndEmit(DateTime date, HomeTab tab) async {
    try {
      final results = await Future.wait([
        _repository.fetchInHouse(date),
        _repository.fetchNewToday(date),
        _repository.fetchCheckIns(date),
        _repository.fetchCheckOuts(date),
        _repository.fetchPaymentsReceived(date),
      ]);
      if (isClosed) return;
      emit(HomeLoaded(
        selectedDate: date,
        selectedTab: tab,
        inHouse: results[0],
        newBookings: results[1],
        checkIns: results[2],
        checkOuts: results[3],
        paymentsReceived: results[4],
      ));
    } catch (e) {
      if (isClosed) return;
      emit(HomeError(e.toString()));
    }
  }
}
