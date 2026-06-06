import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants.dart';
import '../../../shared/models/booking_group.dart';

class HomeRepository {
  final _client = Supabase.instance.client;

  static const _groupSelect =
      '*, booking_types(*), booking_sources(*), rooms(*)';

  /// Guests currently on property: checked in on or before [date],
  /// checking out strictly after [date] (they sleep here tonight).
  Future<List<BookingGroup>> fetchInHouse(DateTime date) async {
    final rows = await _client
        .from('booking_groups')
        .select(_groupSelect)
        .eq('property_id', AppConstants.propertyId)
        .eq('is_active', true)
        .lte('check_in', _fmt(date))
        .gt('check_out', _fmt(date))
        .order('check_in', ascending: true);
    return _parseGroups(rows as List);
  }

  Future<List<BookingGroup>> fetchCheckIns(DateTime date) async {
    final rows = await _client
        .from('booking_groups')
        .select(_groupSelect)
        .eq('property_id', AppConstants.propertyId)
        .eq('is_active', true)
        .eq('check_in', _fmt(date));
    return _parseGroups(rows as List);
  }

  Future<List<BookingGroup>> fetchCheckOuts(DateTime date) async {
    final rows = await _client
        .from('booking_groups')
        .select(_groupSelect)
        .eq('property_id', AppConstants.propertyId)
        .eq('is_active', true)
        .eq('check_out', _fmt(date));
    return _parseGroups(rows as List);
  }

  /// Bookings where payment was received on [date] (by payment_received_date).
  Future<List<BookingGroup>> fetchPaymentsReceived(DateTime date) async {
    final rows = await _client
        .from('booking_groups')
        .select(_groupSelect)
        .eq('property_id', AppConstants.propertyId)
        .eq('is_active', true)
        .eq('payment_received', true)
        .eq('payment_received_date', _fmt(date))
        .order('payment_received_date', ascending: true);
    return _parseGroups(rows as List);
  }

  // booking_date is TIMESTAMPTZ — use IST (+05:30) boundaries so a booking
  // recorded at any time on a given IST calendar day is included correctly.
  Future<List<BookingGroup>> fetchNewToday(DateTime date) async {
    final startIst = _istBoundary(date);
    final endIst = _istBoundary(date.add(const Duration(days: 1)));

    final rows = await _client
        .from('booking_groups')
        .select(_groupSelect)
        .eq('property_id', AppConstants.propertyId)
        .eq('is_active', true)
        .gte('booking_date', startIst)
        .lt('booking_date', endIst);

    return _parseGroups(rows as List);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  List<BookingGroup> _parseGroups(List<dynamic> rows) =>
      rows.map((r) => BookingGroup.fromJson(r as Map<String, dynamic>)).toList();

  String _fmt(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String _istBoundary(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-${d}T00:00:00+05:30';
  }
}
