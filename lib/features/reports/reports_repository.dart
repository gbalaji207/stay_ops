import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';

class RawReportRow {
  const RawReportRow({
    required this.roomId,
    required this.roomName,
    required this.destinationId,
    required this.destinationName,
    required this.amount,
  });

  final String roomId;
  final String roomName;
  final String? destinationId;
  final String? destinationName;
  final double amount;
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
          'booking_groups!inner(payment_destination_id,is_active,'
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
      );
    }).toList();
  }

  String _fmt(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
