import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../shared/models/booking_group.dart';
import 'month_booking_row.dart';

class MonthlyRepository {
  final _client = Supabase.instance.client;

  Future<List<MonthBookingRow>> fetchMonthBookings(
    int year,
    int month,
  ) async {
    final start = _fmt(DateTime(year, month, 1));
    final end = _fmt(DateTime(year, month + 1, 0)); // day 0 = last day of month
    final rows = await _client
        .from('booking_days')
        .select(
          '*, booking_groups!inner(*, booking_types(*), booking_sources(*))',
        )
        .eq('property_id', AppConstants.propertyId)
        .eq('is_active', true)
        .gte('booking_date', start)
        .lte('booking_date', end);
    return (rows as List)
        .map((r) => MonthBookingRow.fromJson(r as Map<String, dynamic>))
        .toList();
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

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
