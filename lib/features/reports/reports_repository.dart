import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../shared/models/booking_report_row.dart';

class RawReportRow {
  const RawReportRow({
    required this.roomId,
    required this.roomName,
    required this.destinationId,
    required this.destinationName,
    required this.amount,
    required this.bookingGroupId,
  });

  final String roomId;
  final String roomName;
  final String? destinationId;
  final String? destinationName;
  final double amount;
  final String bookingGroupId;
}

class RawCategoryReportRow {
  const RawCategoryReportRow({
    required this.roomId,
    required this.roomName,
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.bookingGroupId,
  });

  final String roomId;
  final String roomName;
  final String? categoryId;
  final String? categoryName;
  final double amount;
  final String bookingGroupId;
}

class ReportsRepository {
  final _client = Supabase.instance.client;

  Future<List<RawReportRow>> fetchPaymentReportRows({
    required DateTime dateFrom,
    required DateTime dateTo,
    List<String>? roomIds,
  }) async {
    var query = _client
        .from('booking_days')
        .select(
          'amount,room_id,rooms(name),'
          'booking_groups!inner(id,payment_destination_id,is_active,'
          'payment_destinations(name))',
        )
        .eq('property_id', AppConstants.propertyId)
        .gte('booking_date', _fmt(dateFrom))
        .lte('booking_date', _fmt(dateTo))
        .eq('is_active', true);

    if (roomIds != null && roomIds.isNotEmpty) {
      query = query.inFilter('room_id', roomIds);
    }

    final rows = await query;

    return (rows as List).where((row) {
      final bg = row['booking_groups'] as Map<String, dynamic>;
      return bg['is_active'] == true;
    }).map((row) {
      final roomMap = row['rooms'] as Map<String, dynamic>;
      final bg = row['booking_groups'] as Map<String, dynamic>;
      final destMap = bg['payment_destinations'] as Map<String, dynamic>?;
      return RawReportRow(
        roomId: row['room_id'] as String,
        roomName: roomMap['name'] as String,
        destinationId: bg['payment_destination_id'] as String?,
        destinationName: destMap?['name'] as String?,
        amount: (row['amount'] as num).toDouble(),
        bookingGroupId: bg['id'] as String,
      );
    }).toList();
  }

  Future<List<RawCategoryReportRow>> fetchTypeReportRows({
    required DateTime dateFrom,
    required DateTime dateTo,
    List<String>? roomIds,
  }) async {
    var query = _client
        .from('booking_days')
        .select(
          'amount,room_id,rooms(name),'
          'booking_groups!inner(id,booking_type_id,is_active,'
          'booking_types(name))',
        )
        .eq('property_id', AppConstants.propertyId)
        .gte('booking_date', _fmt(dateFrom))
        .lte('booking_date', _fmt(dateTo))
        .eq('is_active', true);

    if (roomIds != null && roomIds.isNotEmpty) {
      query = query.inFilter('room_id', roomIds);
    }

    final rows = await query;

    return (rows as List).where((row) {
      final bg = row['booking_groups'] as Map<String, dynamic>;
      return bg['is_active'] == true;
    }).map((row) {
      final roomMap = row['rooms'] as Map<String, dynamic>;
      final bg = row['booking_groups'] as Map<String, dynamic>;
      final typeMap = bg['booking_types'] as Map<String, dynamic>?;
      return RawCategoryReportRow(
        roomId: row['room_id'] as String,
        roomName: roomMap['name'] as String,
        categoryId: bg['booking_type_id'] as String?,
        categoryName: typeMap?['name'] as String?,
        amount: (row['amount'] as num).toDouble(),
        bookingGroupId: bg['id'] as String,
      );
    }).toList();
  }

  Future<List<RawCategoryReportRow>> fetchSourceReportRows({
    required DateTime dateFrom,
    required DateTime dateTo,
    List<String>? roomIds,
  }) async {
    var query = _client
        .from('booking_days')
        .select(
          'amount,room_id,rooms(name),'
          'booking_groups!inner(id,booking_source_id,is_active,'
          'booking_sources(name))',
        )
        .eq('property_id', AppConstants.propertyId)
        .gte('booking_date', _fmt(dateFrom))
        .lte('booking_date', _fmt(dateTo))
        .eq('is_active', true);

    if (roomIds != null && roomIds.isNotEmpty) {
      query = query.inFilter('room_id', roomIds);
    }

    final rows = await query;

    return (rows as List).where((row) {
      final bg = row['booking_groups'] as Map<String, dynamic>;
      return bg['is_active'] == true;
    }).map((row) {
      final roomMap = row['rooms'] as Map<String, dynamic>;
      final bg = row['booking_groups'] as Map<String, dynamic>;
      final sourceMap = bg['booking_sources'] as Map<String, dynamic>?;
      return RawCategoryReportRow(
        roomId: row['room_id'] as String,
        roomName: roomMap['name'] as String,
        categoryId: bg['booking_source_id'] as String?,
        categoryName: sourceMap?['name'] as String?,
        amount: (row['amount'] as num).toDouble(),
        bookingGroupId: bg['id'] as String,
      );
    }).toList();
  }

  Future<List<BookingReportRow>> fetchBookingsReportRows({
    required DateTime dateFrom,
    required DateTime dateTo,
    List<String>? roomIds,
    List<String>? bookingTypeIds,
    List<String>? bookingSourceIds,
    List<String>? paymentDestinationIds,
  }) async {
    var query = _client
        .from('booking_groups')
        .select(
          'id,booking_date,check_in,check_out,customer_name,'
          'total_amount,tax_amount,commission_incl_tax,tax_deduction,net_amount,'
          'payment_received,actual_payment_amount,payment_received_date,'
          'payment_destination_id,'
          'rooms(name),booking_types(name),booking_sources(name),'
          'payment_destinations(name)',
        )
        .eq('property_id', AppConstants.propertyId)
        .eq('is_active', true)
        .gte('check_in', _fmt(dateFrom))
        .lte('check_in', _fmt(dateTo));

    if (roomIds != null && roomIds.isNotEmpty) {
      query = query.inFilter('room_id', roomIds);
    }
    if (bookingTypeIds != null && bookingTypeIds.isNotEmpty) {
      query = query.inFilter('booking_type_id', bookingTypeIds);
    }
    if (bookingSourceIds != null && bookingSourceIds.isNotEmpty) {
      query = query.inFilter('booking_source_id', bookingSourceIds);
    }
    if (paymentDestinationIds != null && paymentDestinationIds.isNotEmpty) {
      query = query.inFilter('payment_destination_id', paymentDestinationIds);
    }

    final rows = await query.order('check_in', ascending: true);
    final result = (rows as List)
        .map((r) => BookingReportRow.fromJson(r as Map<String, dynamic>))
        .toList();
    result.sort((a, b) {
      final d = a.checkIn.compareTo(b.checkIn);
      if (d != 0) return d;
      return a.roomName.compareTo(b.roomName);
    });
    return result;
  }

  String _fmt(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
