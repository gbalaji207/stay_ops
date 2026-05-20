class BookingGroupInput {
  const BookingGroupInput({
    this.existingGroupId,
    required this.roomId,
    required this.checkIn,
    required this.checkOut,
    required this.totalAmount,
    required this.paymentReceived,
    this.bookingDate,
    this.bookingTypeId,
    this.bookingSourceId,
    this.notes,
    this.paymentDestinationId,
    this.customerName,
    this.stayFlexiBookingId,
    this.otaBookingId,
    this.taxAmount,
    this.commissionInclTax,
    this.taxDeduction,
  });

  // null = new booking, non-null = editing existing group
  final String? existingGroupId;
  final String roomId;
  final DateTime checkIn;
  final DateTime checkOut;
  final double totalAmount; // gross amount
  final bool paymentReceived;
  final DateTime? bookingDate; // includes time
  final String? bookingTypeId;
  final String? bookingSourceId;
  final String? notes;
  final String? paymentDestinationId;
  final String? customerName;
  final String? stayFlexiBookingId;
  final String? otaBookingId;
  final double? taxAmount;
  final double? commissionInclTax;
  final double? taxDeduction;

  // [checkIn, checkIn+1, ..., checkOut-1] — checkOut is exclusive
  List<DateTime> get nights {
    final list = <DateTime>[];
    var current = DateTime(checkIn.year, checkIn.month, checkIn.day);
    final end = DateTime(checkOut.year, checkOut.month, checkOut.day);
    while (current.isBefore(end)) {
      list.add(current);
      current = current.add(const Duration(days: 1));
    }
    return list;
  }

  int get nightCount => checkOut.difference(checkIn).inDays;
  double get perNightAmount => nightCount > 0 ? totalAmount / nightCount : 0;
  double get netAmount =>
      totalAmount - (commissionInclTax ?? 0) - (taxDeduction ?? 0);
}
