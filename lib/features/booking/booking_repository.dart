import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import 'booking_group_input.dart';

class ConflictInfo {
  const ConflictInfo({required this.date, required this.roomName});
  final DateTime date;
  final String roomName;
}

class BookingRepository {
  final _client = Supabase.instance.client;

  Future<List<ConflictInfo>> checkConflicts(
      String roomId, List<DateTime> nights) async {
    if (nights.isEmpty) return [];
    final dates = nights.map(_fmt).toList();
    final rows = await _client
        .from('booking_days')
        .select('booking_date, rooms(name)')
        .eq('room_id', roomId)
        .inFilter('booking_date', dates)
        .eq('is_active', true);
    return (rows as List).map((row) {
      final roomMap = row['rooms'] as Map<String, dynamic>;
      return ConflictInfo(
        date: DateTime.parse(row['booking_date'] as String),
        roomName: roomMap['name'] as String,
      );
    }).toList();
  }

  Future<void> saveBookingGroup(BookingGroupInput input) async {
    final groupRow = await _client.from('booking_groups').insert({
      'property_id': AppConstants.propertyId,
      'room_id': input.roomId,
      'check_in': _fmt(input.checkIn),
      'check_out': _fmt(input.checkOut),
      'total_amount': input.totalAmount,
      'payment_received': input.paymentReceived,
      'booking_type_id': input.bookingTypeId,
      'booking_source_id': input.bookingSourceId,
      'notes': input.notes,
    }).select('id').single();

    final groupId = groupRow['id'] as String;
    final perNight = input.perNightAmount;

    final daysPayload = input.nights.map((date) => {
          'booking_group_id': groupId,
          'property_id': AppConstants.propertyId,
          'room_id': input.roomId,
          'booking_date': _fmt(date),
          'amount': perNight,
          'is_active': true,
        }).toList();

    await _client.from('booking_days').insert(daysPayload);
  }

  Future<void> softDeleteConflicts(
      String roomId, List<DateTime> dates) async {
    if (dates.isEmpty) return;
    final formattedDates = dates.map(_fmt).toList();

    // Find which group IDs are affected before deleting
    final conflictRows = await _client
        .from('booking_days')
        .select('booking_group_id')
        .eq('room_id', roomId)
        .inFilter('booking_date', formattedDates)
        .eq('is_active', true);

    final groupIds = (conflictRows as List)
        .map((r) => r['booking_group_id'] as String)
        .toSet()
        .toList();

    // Soft-delete the conflict booking_days
    await _client
        .from('booking_days')
        .update({'is_active': false})
        .eq('room_id', roomId)
        .inFilter('booking_date', formattedDates)
        .eq('is_active', true);

    // Cascade: soft-delete parent groups that now have no active days
    for (final groupId in groupIds) {
      final activeDays = await _client
          .from('booking_days')
          .select('id')
          .eq('booking_group_id', groupId)
          .eq('is_active', true);
      if ((activeDays as List).isEmpty) {
        await _client
            .from('booking_groups')
            .update({'is_active': false})
            .eq('id', groupId);
      }
    }
  }

  String _fmt(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
