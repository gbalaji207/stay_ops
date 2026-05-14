class MonthBookingRow {
  const MonthBookingRow({
    required this.bookingGroupId,
    required this.roomId,
    required this.bookingDate,
    required this.amount,
    required this.paymentReceived,
    this.bookingTypeId,
    this.bookingTypeName,
    this.bookingSourceId,
    this.bookingSourceName,
  });

  final String bookingGroupId;
  final String roomId;
  final DateTime bookingDate;
  final double amount;           // booking_days.amount — per-night slice
  final bool paymentReceived;    // booking_groups.payment_received
  final String? bookingTypeId;
  final String? bookingTypeName;
  final String? bookingSourceId;
  final String? bookingSourceName;

  factory MonthBookingRow.fromJson(Map<String, dynamic> json) {
    final group = json['booking_groups'] as Map<String, dynamic>;
    final typeMap = group['booking_types'] as Map<String, dynamic>?;
    final sourceMap = group['booking_sources'] as Map<String, dynamic>?;
    return MonthBookingRow(
      bookingGroupId: json['booking_group_id'] as String,
      roomId: json['room_id'] as String,
      bookingDate: DateTime.parse(json['booking_date'] as String),
      amount: (json['amount'] as num).toDouble(),
      paymentReceived: group['payment_received'] as bool? ?? false,
      bookingTypeId: group['booking_type_id'] as String?,
      bookingTypeName: typeMap?['name'] as String?,
      bookingSourceId: group['booking_source_id'] as String?,
      bookingSourceName: sourceMap?['name'] as String?,
    );
  }
}
