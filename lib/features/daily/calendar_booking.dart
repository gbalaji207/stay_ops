import '../../shared/models/room.dart';

/// A de-duplicated booking record used by the calendar timeline view.
/// Built by [DailyCubit.loadRange] — one instance per booking group,
/// regardless of how many nights (booking_days rows) fall in the visible range.
class CalendarBooking {
  const CalendarBooking({
    required this.bookingGroupId,
    required this.room,
    required this.checkIn,
    required this.checkOut,
    required this.perNightAmount,
    required this.paymentReceived,
    this.sourceName,
    this.customerName,
    this.checkInDatetime,
    this.checkOutDatetime,
  });

  final String bookingGroupId;
  final Room room;

  /// Calendar date of check-in (midnight, time stripped). Used for date math.
  final DateTime checkIn;

  /// Calendar date of check-out (midnight, inclusive last occupied day).
  /// For day-use bookings [checkIn] == [checkOut] (same calendar date).
  final DateTime checkOut;

  final double perNightAmount;
  final bool paymentReceived;
  final String? sourceName;
  final String? customerName;

  /// Full local datetime of check-in (with time component).
  /// Used for sub-column fractional positioning and datetime-precision lane
  /// overlap detection. Null for legacy bookings without the TIMESTAMPTZ field.
  final DateTime? checkInDatetime;

  /// Full local datetime of check-out (with time component). See [checkInDatetime].
  final DateTime? checkOutDatetime;

  /// True when [checkIn] and [checkOut] share the same calendar date.
  bool get isDayUse =>
      checkIn.year == checkOut.year &&
      checkIn.month == checkOut.month &&
      checkIn.day == checkOut.day;
}
