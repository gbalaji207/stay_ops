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
    this.netAmountOverride,
  });

  // null = new booking, non-null = editing existing group
  final String? existingGroupId;
  final String roomId;
  // Full datetimes — carry both calendar date and check-in/out time.
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
  // When set, overrides the computed net amount (e.g. value from SF edge function)
  final double? netAmountOverride;

  // [checkIn-date, checkIn-date+1, ..., checkOut-date-1] — checkOut date is exclusive.
  // For same-date (day-use) bookings, returns [checkIn-date] so exactly one
  // booking_day row is created — required for reports and calendar views.
  List<DateTime> get nights {
    var current = DateTime(checkIn.year, checkIn.month, checkIn.day);
    final end    = DateTime(checkOut.year, checkOut.month, checkOut.day);
    if (!current.isBefore(end)) return [current]; // same-date → 1 slot
    final list = <DateTime>[];
    while (current.isBefore(end)) {
      list.add(current);
      current = current.add(const Duration(days: 1));
    }
    return list;
  }

  // Calendar-day count. Day-use = 1 so perNightAmount = netAmount (no ÷0).
  int get nightCount {
    final inDate  = DateTime(checkIn.year,  checkIn.month,  checkIn.day);
    final outDate = DateTime(checkOut.year, checkOut.month, checkOut.day);
    final diff = outDate.difference(inDate).inDays;
    return diff <= 0 ? 1 : diff;
  }

  bool get isDayUse =>
      checkIn.year  == checkOut.year  &&
      checkIn.month == checkOut.month &&
      checkIn.day   == checkOut.day;

  double get perNightAmount => netAmount / nightCount;

  double get netAmount =>
      netAmountOverride ??
      (totalAmount - (commissionInclTax ?? 0) - (taxDeduction ?? 0));

  // checkIn and checkOut already carry the full datetime — direct pass-through.
  DateTime get checkInDatetime  => checkIn;
  DateTime get checkOutDatetime => checkOut;
}
