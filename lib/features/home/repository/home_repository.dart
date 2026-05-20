import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants.dart';
import '../../../shared/models/booking_group.dart';
import '../../../shared/models/occupancy_snapshot.dart';

class HomeRepository {
  final _client = Supabase.instance.client;

  static const _groupSelect =
      '*, booking_types(*), booking_sources(*), rooms(*)';

  Future<List<BookingGroup>> fetchCheckOuts(DateTime today) async {
    final rows = await _client
        .from('booking_groups')
        .select(_groupSelect)
        .eq('property_id', AppConstants.propertyId)
        .eq('is_active', true)
        .eq('check_out', _fmt(today));
    return _parseGroups(rows as List);
  }

  Future<List<BookingGroup>> fetchCheckIns(DateTime today) async {
    final rows = await _client
        .from('booking_groups')
        .select(_groupSelect)
        .eq('property_id', AppConstants.propertyId)
        .eq('is_active', true)
        .eq('check_in', _fmt(today));
    return _parseGroups(rows as List);
  }

  Future<OccupancySnapshot> fetchOccupancy(
    DateTime today,
    int totalRooms,
  ) async {
    final rows = await _client
        .from('booking_days')
        .select('room_id')
        .eq('property_id', AppConstants.propertyId)
        .eq('is_active', true)
        .eq('booking_date', _fmt(today));

    final occupied = (rows as List)
        .map((r) => r['room_id'] as String)
        .toSet()
        .length;

    final vacant = (totalRooms - occupied).clamp(0, totalRooms);
    final pct = totalRooms > 0 ? (occupied / totalRooms) * 100 : 0.0;

    return OccupancySnapshot(
      occupied: occupied,
      vacant: vacant,
      pct: double.parse(pct.toStringAsFixed(1)),
    );
  }

  Future<Map<DateTime, List<BookingGroup>>> fetchUpcoming(
    DateTime today, {
    int days = 3,
  }) async {
    final start = today.add(const Duration(days: 1));
    final end = today.add(Duration(days: days));

    final rows = await _client
        .from('booking_groups')
        .select(_groupSelect)
        .eq('property_id', AppConstants.propertyId)
        .eq('is_active', true)
        .gte('check_in', _fmt(start))
        .lte('check_in', _fmt(end))
        .order('check_in', ascending: true);

    final groups = _parseGroups(rows as List);
    final result = <DateTime, List<BookingGroup>>{};
    for (final g in groups) {
      final key = DateTime(g.checkIn.year, g.checkIn.month, g.checkIn.day);
      result.putIfAbsent(key, () => []).add(g);
    }
    return result;
  }

  // booking_date is TIMESTAMPTZ — use IST (+05:30) boundaries so a booking
  // recorded at any time on a given IST calendar day is included correctly.
  Future<List<BookingGroup>> fetchNewToday(DateTime today) async {
    final startIst = _istBoundary(today);
    final endIst = _istBoundary(today.add(const Duration(days: 1)));

    final rows = await _client
        .from('booking_groups')
        .select(_groupSelect)
        .eq('property_id', AppConstants.propertyId)
        .eq('is_active', true)
        .gte('booking_date', startIst)
        .lt('booking_date', endIst);

    return _parseGroups(rows as List);
  }

  Future<List<BookingGroup>> fetchPaymentPending() async {
    final rows = await _client
        .from('booking_groups')
        .select(_groupSelect)
        .eq('property_id', AppConstants.propertyId)
        .eq('is_active', true)
        .eq('payment_received', false)
        .order('check_in', ascending: true);
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
