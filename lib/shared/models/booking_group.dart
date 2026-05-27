import 'package:equatable/equatable.dart';

class BookingGroup extends Equatable {
  const BookingGroup({
    required this.id,
    required this.propertyId,
    required this.roomId,
    required this.checkIn,
    required this.checkOut,
    required this.totalAmount,
    required this.paymentReceived,
    required this.netAmount,
    this.bookingDate,
    this.bookingTypeId,
    this.bookingSourceId,
    this.notes,
    required this.isActive,
    this.paymentDestinationId,
    this.paymentDestinationName,
    this.customerName,
    this.stayFlexiBookingId,
    this.otaBookingId,
    this.taxAmount,
    this.commissionInclTax,
    this.taxDeduction,
    this.actualPaymentAmount,
    this.paymentReceivedDate,
    this.paymentNotes,
    this.checkInDatetime,
    this.checkOutDatetime,
  });

  final String id;
  final String propertyId;
  final String roomId;
  final DateTime checkIn;
  final DateTime checkOut;
  final double totalAmount;
  final bool paymentReceived;
  final double netAmount;
  final DateTime? bookingDate;
  final String? bookingTypeId;
  final String? bookingSourceId;
  final String? notes;
  final bool isActive;
  final String? paymentDestinationId;
  final String? paymentDestinationName;
  final String? customerName;
  final String? stayFlexiBookingId;
  final String? otaBookingId;
  final double? taxAmount;
  final double? commissionInclTax;
  final double? taxDeduction;
  final double? actualPaymentAmount;
  final DateTime? paymentReceivedDate;
  final String? paymentNotes;
  final DateTime? checkInDatetime;
  final DateTime? checkOutDatetime;

  int get nights => checkOut.difference(checkIn).inDays;
  double get perNightAmount => nights > 0 ? totalAmount / nights : 0;

  // True when check-in and check-out fall on the same calendar date (day-use booking).
  bool get isDayUse =>
      checkIn.year == checkOut.year &&
      checkIn.month == checkOut.month &&
      checkIn.day == checkOut.day;

  factory BookingGroup.fromJson(Map<String, dynamic> json) {
    final destMap = json['payment_destinations'] as Map<String, dynamic>?;
    final totalAmount = (json['total_amount'] as num).toDouble();
    final commissionInclTax =
        (json['commission_incl_tax'] as num?)?.toDouble();
    final taxDeduction = (json['tax_deduction'] as num?)?.toDouble();
    // Use stored net_amount; fall back to computed for rows predating the column
    final netAmount = (json['net_amount'] as num?)?.toDouble() ??
        (totalAmount - (commissionInclTax ?? 0) - (taxDeduction ?? 0));
    return BookingGroup(
      id: json['id'] as String,
      propertyId: json['property_id'] as String,
      roomId: json['room_id'] as String,
      checkIn: DateTime.parse(json['check_in'] as String),
      checkOut: DateTime.parse(json['check_out'] as String),
      totalAmount: totalAmount,
      paymentReceived: json['payment_received'] as bool,
      netAmount: netAmount,
      bookingDate: json['booking_date'] != null
          ? DateTime.parse(json['booking_date'] as String)
          : null,
      bookingTypeId: json['booking_type_id'] as String?,
      bookingSourceId: json['booking_source_id'] as String?,
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool,
      paymentDestinationId: json['payment_destination_id'] as String?,
      paymentDestinationName: destMap?['name'] as String?,
      customerName: json['customer_name'] as String?,
      stayFlexiBookingId: json['stay_flexi_booking_id'] as String?,
      otaBookingId: json['ota_booking_id'] as String?,
      taxAmount: (json['tax_amount'] as num?)?.toDouble(),
      commissionInclTax: commissionInclTax,
      taxDeduction: taxDeduction,
      actualPaymentAmount:
          (json['actual_payment_amount'] as num?)?.toDouble(),
      paymentReceivedDate: json['payment_received_date'] != null
          ? DateTime.parse(json['payment_received_date'] as String)
          : null,
      paymentNotes: json['payment_notes'] as String?,
      checkInDatetime: json['check_in_datetime'] != null
          ? DateTime.parse(json['check_in_datetime'] as String).toLocal()
          : null,
      checkOutDatetime: json['check_out_datetime'] != null
          ? DateTime.parse(json['check_out_datetime'] as String).toLocal()
          : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        propertyId,
        roomId,
        checkIn,
        checkOut,
        totalAmount,
        paymentReceived,
        netAmount,
        bookingDate,
        bookingTypeId,
        bookingSourceId,
        notes,
        isActive,
        paymentDestinationId,
        paymentDestinationName,
        customerName,
        stayFlexiBookingId,
        otaBookingId,
        taxAmount,
        commissionInclTax,
        taxDeduction,
        actualPaymentAmount,
        paymentReceivedDate,
        paymentNotes,
        checkInDatetime,
        checkOutDatetime,
      ];
}
