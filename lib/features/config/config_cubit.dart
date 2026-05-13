import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'config_state.dart';

class ConfigCubit extends Cubit<ConfigState> {
  ConfigCubit() : super(const ConfigInitial());

  Future<void> loadConfig() async {
    // Phase 3: replace with repository call to fetch rooms/types/sources.
    emit(const ConfigLoading());
    emit(const ConfigLoaded());
  }

  Future<void> reload() async => loadConfig();
}
