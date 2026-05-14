import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../shared/models/booking_group.dart';
import 'day_booking_row.dart';

class DailyRepository {
  final _client = Supabase.instance.client;

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

  Future<BookingGroup> fetchGroupByDay(String roomId, DateTime date) async {
    final rows = await _client
        .from('booking_days')
        .select('booking_groups!inner(*)')
        .eq('room_id', roomId)
        .eq('booking_date', _fmt(date))
        .eq('is_active', true)
        .limit(1);

    if ((rows as List).isEmpty) {
      throw Exception('No active booking found for room on $date');
    }
    final groupMap = rows.first['booking_groups'] as Map<String, dynamic>;
    return BookingGroup.fromJson(groupMap);
  }

  String _fmt(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
