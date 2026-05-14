class DayBookingRow {
  const DayBookingRow({
    required this.bookingGroupId,
    required this.roomId,
    required this.amount,
    required this.checkIn,
    required this.checkOut,
    required this.paymentReceived,
    this.bookingTypeId,
    this.bookingSourceId,
  });

  final String bookingGroupId;
  final String roomId;
  final double amount; // booking_days.amount for this specific date
  final DateTime checkIn; // from booking_groups.check_in
  final DateTime checkOut; // from booking_groups.check_out
  final bool paymentReceived; // from booking_groups.payment_received
  final String? bookingTypeId;
  final String? bookingSourceId;

  factory DayBookingRow.fromJson(Map<String, dynamic> json) {
    final group = json['booking_groups'] as Map<String, dynamic>;
    return DayBookingRow(
      bookingGroupId: json['booking_group_id'] as String,
      roomId: json['room_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      checkIn: DateTime.parse(group['check_in'] as String),
      checkOut: DateTime.parse(group['check_out'] as String),
      paymentReceived: group['payment_received'] as bool? ?? false,
      bookingTypeId: group['booking_type_id'] as String?,
      bookingSourceId: group['booking_source_id'] as String?,
    );
  }
}
