import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../shared/models/booking_group.dart';
import 'day_booking_row.dart';

class DailyRepository {
  final _client = Supabase.instance.client;

  /// Fetches all booking_days rows whose [booking_date] falls in [start]..[end]
  /// (both inclusive). Used by the calendar timeline view.
  ///
  /// A booking that started before [start] is still returned as long as it has
  /// at least one active booking_days row in the range.
  Future<List<DayBookingRow>> fetchRangeBookings(
    DateTime start,
    DateTime end,
  ) async {
    final rows = await _client
        .from('booking_days')
        .select(
          '*, booking_groups!inner(*, booking_types(*), booking_sources(*)), rooms(*)',
        )
        .eq('property_id', AppConstants.propertyId)
        .gte('booking_date', _fmt(start))
        .lte('booking_date', _fmt(end))
        .eq('is_active', true);
    return (rows as List)
        .map((r) => DayBookingRow.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<DayBookingRow>> fetchDayBookings(DateTime date) async {
    final rows = await _client
        .from('booking_days')
        .select(
          '*, booking_groups!inner(*, booking_types(*), booking_sources(*)), rooms(*)',
        )
        .eq('property_id', AppConstants.propertyId)
        .eq('booking_date', _fmt(date))
        .eq('is_active', true);
    return (rows as List).map((r) => DayBookingRow.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Fetches a booking group by its ID. Used when tapping a card in the daily
  /// view — since a room can now have multiple bookings per day (day-use + night),
  /// we fetch by the known bookingGroupId rather than (roomId, date).
  Future<BookingGroup> fetchGroupByGroupId(String groupId) async {
    final row = await _client
        .from('booking_groups')
        .select('*')
        .eq('id', groupId)
        .eq('property_id', AppConstants.propertyId)
        .eq('is_active', true)
        .single();
    return BookingGroup.fromJson(row);
  }

  String _fmt(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
