import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(const AuthInitial());

  void verifyPin(String pin) {
    if (pin == AppConstants.ownerPin) {
      emit(const AuthAuthenticated(UserRole.owner));
    } else if (pin == AppConstants.staffPin) {
      emit(const AuthAuthenticated(UserRole.staff));
    } else {
      emit(const AuthError('Incorrect PIN. Try again.'));
    }
  }

  void resetError() => emit(const AuthInitial());

  void logout() => emit(const AuthInitial());
}
