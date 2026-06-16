import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../shared/models/booking_group.dart';
import 'booking_group_input.dart';

class ConflictInfo {
  const ConflictInfo({
    required this.groupId,
    required this.checkIn,
    required this.checkOut,
    this.checkInDatetime,
    this.checkOutDatetime,
    required this.roomName,
    this.bookingTypeName,
    this.bookingSourceName,
    this.customerName,
  });

  /// ID of the conflicting booking_group — used by confirmOverwrite to soft-delete it.
  final String groupId;
  final DateTime checkIn;
  final DateTime checkOut;
  /// Local datetimes — used to display times for day-use conflicts.
  final DateTime? checkInDatetime;
  final DateTime? checkOutDatetime;
  final String roomName;
  final String? bookingTypeName;
  final String? bookingSourceName;
  final String? customerName;
}

class BookingRepository {
  final _client = Supabase.instance.client;

  /// Checks for time-range overlap on booking_groups for the same room.
  /// Two bookings conflict when:
  ///   existing.check_in_datetime  < new.checkOutDatetime  AND
  ///   existing.check_out_datetime > new.checkInDatetime
  Future<List<ConflictInfo>> checkConflicts(
    String roomId,
    DateTime checkInDatetime,
    DateTime checkOutDatetime, {
    String? excludeGroupId,
  }) async {
    var query = _client
        .from('booking_groups')
        .select(
          'id, check_in, check_out, check_in_datetime, check_out_datetime, '
          'customer_name, rooms!inner(name), booking_types(name), booking_sources(name)',
        )
        .eq('room_id', roomId)
        .eq('property_id', AppConstants.propertyId)
        .eq('is_active', true)
        .lt('check_in_datetime', checkOutDatetime.toUtc().toIso8601String())
        .gt('check_out_datetime', checkInDatetime.toUtc().toIso8601String());

    if (excludeGroupId != null) {
      query = query.neq('id', excludeGroupId);
    }

    final rows = await query;
    return (rows as List).map((row) {
      final roomMap = row['rooms'] as Map<String, dynamic>;
      return ConflictInfo(
        groupId: row['id'] as String,
        checkIn: DateTime.parse(row['check_in'] as String),
        checkOut: DateTime.parse(row['check_out'] as String),
        checkInDatetime: row['check_in_datetime'] != null
            ? DateTime.parse(row['check_in_datetime'] as String).toLocal()
            : null,
        checkOutDatetime: row['check_out_datetime'] != null
            ? DateTime.parse(row['check_out_datetime'] as String).toLocal()
            : null,
        roomName: roomMap['name'] as String,
        bookingTypeName:
            (row['booking_types'] as Map<String, dynamic>?)?['name'] as String?,
        bookingSourceName:
            (row['booking_sources'] as Map<String, dynamic>?)?['name'] as String?,
        customerName: row['customer_name'] as String?,
      );
    }).toList();
  }

  Future<void> saveBookingGroup(BookingGroupInput input) async {
    final groupRow = await _client.from('booking_groups').insert({
      'property_id': AppConstants.propertyId,
      'room_id': input.roomId,
      'check_in': _fmt(input.checkIn),
      'check_out': _fmt(input.checkOut),
      'check_in_datetime': input.checkInDatetime.toUtc().toIso8601String(),
      'check_out_datetime': input.checkOutDatetime.toUtc().toIso8601String(),
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
      'net_amount': input.netAmount,
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

  /// Soft-deletes conflicting booking groups (and their booking_days) by group ID.
  /// Called when the user confirms overwriting detected conflicts.
  Future<void> softDeleteConflicts(List<String> groupIds) async {
    if (groupIds.isEmpty) return;
    for (final groupId in groupIds) {
      await _client
          .from('booking_days')
          .update({'is_active': false})
          .eq('booking_group_id', groupId);
      await _client
          .from('booking_groups')
          .update({'is_active': false})
          .eq('id', groupId);
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
      'room_id': input.roomId,
      'check_in': _fmt(input.checkIn),
      'check_out': _fmt(input.checkOut),
      'check_in_datetime': input.checkInDatetime.toUtc().toIso8601String(),
      'check_out_datetime': input.checkOutDatetime.toUtc().toIso8601String(),
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
      'net_amount': input.netAmount,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', groupId);

    // 5. Recalculate per-night amount on all remaining active days
    await _client
        .from('booking_days')
        .update({'amount': input.perNightAmount, 'room_id': input.roomId})
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

  Future<void> deleteBookingGroup(String groupId) async {
    // Hard-delete all booking_days for this group
    await _client
        .from('booking_days')
        .delete()
        .eq('booking_group_id', groupId)
        .eq('property_id', AppConstants.propertyId);

    // Hard-delete the booking_group itself
    await _client
        .from('booking_groups')
        .delete()
        .eq('id', groupId)
        .eq('property_id', AppConstants.propertyId);
  }

  String _fmt(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
