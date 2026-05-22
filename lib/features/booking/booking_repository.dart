import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../shared/models/booking_group.dart';
import 'booking_group_input.dart';

class ConflictInfo {
  const ConflictInfo({required this.date, required this.roomName});
  final DateTime date;
  final String roomName;
}

class BookingRepository {
  final _client = Supabase.instance.client;

  Future<List<ConflictInfo>> checkConflicts(
    String roomId,
    List<DateTime> nights, {
    String? excludeGroupId,
  }) async {
    if (nights.isEmpty) return [];
    final dates = nights.map(_fmt).toList();
    var query = _client
        .from('booking_days')
        .select('booking_date, booking_group_id, rooms(name)')
        .eq('room_id', roomId)
        .inFilter('booking_date', dates)
        .eq('is_active', true);
    if (excludeGroupId != null) {
      query = query.neq('booking_group_id', excludeGroupId);
    }
    final rows = await query;
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
      'booking_date': input.bookingDate?.toIso8601String(),
      'booking_type_id': input.bookingTypeId,
      'booking_source_id': input.bookingSourceId,
      'notes': input.notes,
      'payment_destination_id': input.paymentDestinationId,
      'customer_name': input.customerName,
      'stay_flexi_booking_id': input.stayFlexiBookingId,
      'ota_booking_id': input.otaBookingId,
      'tax_amount': input.taxAmount,
      'commission_incl_tax': input.commissionInclTax,
      'tax_deduction': input.taxDeduction,
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

  Future<void> updateBookingGroup(BookingGroupInput input) async {
    final groupId = input.existingGroupId!;

    // 1. Fetch currently active nights for this group
    final activeRows = await _client
        .from('booking_days')
        .select('booking_date')
        .eq('booking_group_id', groupId)
        .eq('is_active', true);
    final currentDates = (activeRows as List)
        .map((r) => DateTime.parse(r['booking_date'] as String))
        .toSet();
    final newDates = input.nights.toSet();

    // 2. Soft-delete removed nights
    final removedDates = currentDates.difference(newDates);
    if (removedDates.isNotEmpty) {
      await _client
          .from('booking_days')
          .update({'is_active': false})
          .eq('booking_group_id', groupId)
          .inFilter('booking_date', removedDates.map(_fmt).toList());
    }

    // 3. INSERT added nights (stay extension)
    final addedDates = newDates.difference(currentDates);
    if (addedDates.isNotEmpty) {
      final perNight = input.perNightAmount;
      await _client.from('booking_days').insert(
            addedDates
                .map((date) => {
                      'booking_group_id': groupId,
                      'property_id': AppConstants.propertyId,
                      'room_id': input.roomId,
                      'booking_date': _fmt(date),
                      'amount': perNight,
                      'is_active': true,
                    })
                .toList(),
          );
    }

    // 4. PATCH booking_groups metadata
    await _client.from('booking_groups').update({
      'check_in': _fmt(input.checkIn),
      'check_out': _fmt(input.checkOut),
      'total_amount': input.totalAmount,
      'payment_received': input.paymentReceived,
      'booking_date': input.bookingDate?.toIso8601String(),
      'booking_type_id': input.bookingTypeId,
      'booking_source_id': input.bookingSourceId,
      'notes': input.notes,
      'payment_destination_id': input.paymentDestinationId,
      'customer_name': input.customerName,
      'stay_flexi_booking_id': input.stayFlexiBookingId,
      'ota_booking_id': input.otaBookingId,
      'tax_amount': input.taxAmount,
      'commission_incl_tax': input.commissionInclTax,
      'tax_deduction': input.taxDeduction,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', groupId);

    // 5. Recalculate per-night amount on all remaining active days
    await _client
        .from('booking_days')
        .update({'amount': input.perNightAmount})
        .eq('booking_group_id', groupId)
        .eq('is_active', true);
  }

  Future<bool> stayFlexiBookingExists(String sfBookingId) async {
    final rows = await _client
        .from('booking_groups')
        .select('id')
        .eq('stay_flexi_booking_id', sfBookingId)
        .eq('property_id', AppConstants.propertyId)
        .eq('is_active', true)
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  Future<void> updatePaymentDetails({
    required String groupId,
    required bool paymentReceived,
    required double? actualPaymentAmount,
    required String? paymentDestinationId,
    required DateTime? paymentReceivedDate,
    required String? paymentNotes,
  }) async {
    final notes = paymentNotes?.trim();
    await _client.from('booking_groups').update({
      'payment_received': paymentReceived,
      'actual_payment_amount': actualPaymentAmount,
      'payment_destination_id': paymentDestinationId,
      'payment_received_date':
          paymentReceivedDate != null ? _fmt(paymentReceivedDate) : null,
      'payment_notes': (notes?.isEmpty ?? true) ? null : notes,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', groupId).eq('property_id', AppConstants.propertyId);
  }

  Future<BookingGroup> fetchGroupById(String groupId) async {
    final row = await _client
        .from('booking_groups')
        .select('*')
        .eq('id', groupId)
        .eq('property_id', AppConstants.propertyId)
        .eq('is_active', true)
        .single();
    return BookingGroup.fromJson(row);
  }

  Future<BookingGroup?> fetchGroupByOtaId(String otaId) async {
    final rows = await _client
        .from('booking_groups')
        .select('*')
        .eq('ota_booking_id', otaId.trim())
        .eq('property_id', AppConstants.propertyId)
        .eq('is_active', true)
        .limit(1);
    if ((rows as List).isEmpty) return null;
    return BookingGroup.fromJson(rows.first);
  }

  String _fmt(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
