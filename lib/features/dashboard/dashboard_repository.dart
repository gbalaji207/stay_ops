import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../shared/models/booking_group.dart';

class DashboardRepository {
  final _client = Supabase.instance.client;

  static const _groupSelect =
      '*, booking_types(*), booking_sources(*), rooms(*)';

  /// Fetches booking groups where check_in falls within [range].
  /// Optionally filters to a single [roomId].
  Future<List<BookingGroup>> fetchDashboardGroups(
    DateTimeRange range, {
    String? roomId,
  }) async {
    var query = _client
        .from('booking_groups')
        .select(_groupSelect)
        .eq('property_id', AppConstants.propertyId)
        .eq('is_active', true)
        .gte('check_in', _fmt(range.start))
        .lte('check_in', _fmt(range.end));

    if (roomId != null) {
      query = query.eq('room_id', roomId);
    }

    final rows = await query.order('check_in', ascending: true);
    return (rows as List)
        .map((r) => BookingGroup.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Counts distinct occupied room-days within [range] for occupancy calculation.
  /// Returns a set of (roomId, date) pairs represented as their count.
  Future<int> fetchOccupiedRoomDays(
    DateTimeRange range, {
    String? roomId,
  }) async {
    var query = _client
        .from('booking_days')
        .select('room_id, booking_date')
        .eq('property_id', AppConstants.propertyId)
        .eq('is_active', true)
        .gte('booking_date', _fmt(range.start))
        .lte('booking_date', _fmt(range.end));

    if (roomId != null) {
      query = query.eq('room_id', roomId);
    }

    final rows = await query;
    // Count distinct (room_id, booking_date) pairs
    final pairs = (rows as List)
        .map((r) => '${r['room_id']}_${r['booking_date']}')
        .toSet();
    return pairs.length;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _fmt(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
