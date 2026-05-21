import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../shared/models/property_info.dart';

part 'auth_state.dart';

const _kLastPropertyKey = 'last_active_property_id';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(const AuthInitial());

  Future<void> verifyPin(String pin) async {
    if (state is AuthLoading) return;
    emit(const AuthLoading());
    try {
      final row = await Supabase.instance.client
          .from('pins')
          .select(
              'role, pin_properties(sort_order, properties(id, name, sf_hotel_id))')
          .eq('pin', pin)
          .eq('is_active', true)
          .maybeSingle();

      if (row == null) {
        emit(const AuthError('Incorrect PIN. Try again.'));
        return;
      }

      final role =
          row['role'] == 'owner' ? UserRole.owner : UserRole.staff;

      final rawPinProperties =
          (row['pin_properties'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();
      rawPinProperties.sort(
        (a, b) =>
            (a['sort_order'] as int).compareTo(b['sort_order'] as int),
      );
      final properties = rawPinProperties
          .where((pp) => pp['properties'] != null)
          .map((pp) =>
              PropertyInfo.fromJson(pp['properties'] as Map<String, dynamic>))
          .toList();

      if (properties.isEmpty) {
        emit(const AuthError('No properties linked to this PIN.'));
        return;
      }

      // Restore last selected property if it still belongs to this PIN.
      final prefs = await SharedPreferences.getInstance();
      final lastId = prefs.getString(_kLastPropertyKey);
      final initialProperty = properties.firstWhere(
        (p) => p.id == lastId,
        orElse: () => properties.first,
      );

      AppSession.setActiveProperty(initialProperty);
      emit(AuthAuthenticated(
        role: role,
        properties: properties,
        activePropertyId: initialProperty.id,
      ));
    } catch (_) {
      emit(const AuthError('Verification failed. Check connection.'));
    }
  }

  void switchProperty(String propertyId) {
    final current = state;
    if (current is! AuthAuthenticated) return;
    final property =
        current.properties.firstWhere((p) => p.id == propertyId);
    AppSession.setActiveProperty(property);
    // Persist so the next login restores this selection.
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString(_kLastPropertyKey, propertyId),
    );
    emit(current.copyWithActiveProperty(propertyId));
  }

  void resetError() => emit(const AuthInitial());

  void logout() => emit(const AuthInitial());
}
