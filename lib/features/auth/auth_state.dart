part of 'auth_cubit.dart';

abstract class AuthState extends Equatable {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();

  @override
  List<Object?> get props => [];
}

class AuthLoading extends AuthState {
  const AuthLoading();

  @override
  List<Object?> get props => [];
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({
    required this.role,
    required this.properties,
    required this.activePropertyId,
  });

  final UserRole role;
  final List<PropertyInfo> properties;
  final String activePropertyId;

  PropertyInfo get activeProperty =>
      properties.firstWhere((p) => p.id == activePropertyId);

  AuthAuthenticated copyWithActiveProperty(String id) => AuthAuthenticated(
        role: role,
        properties: properties,
        activePropertyId: id,
      );

  @override
  List<Object?> get props => [role, properties, activePropertyId];
}

class AuthError extends AuthState {
  const AuthError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
