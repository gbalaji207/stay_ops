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
  const ConfigLoaded();

  @override
  List<Object?> get props => [];
}

class ConfigError extends ConfigState {
  const ConfigError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
