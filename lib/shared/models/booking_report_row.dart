class BookingReportRow {
  const BookingReportRow({
    required this.id,
    required this.bookingDate,
    required this.checkIn,
    required this.checkOut,
    required this.nights,
    required this.customerName,
    required this.roomName,
    required this.bookingTypeName,
    required this.bookingSourceName,
    required this.grossAmount,
    required this.taxAmount,
    required this.commissionInclTax,
    required this.taxDeduction,
    required this.netAmount,
    required this.paymentReceived,
    required this.actualPaymentAmount,
    required this.paymentReceivedDate,
    required this.paymentDestinationName,
  });

  final String id;
  final DateTime? bookingDate;
  final DateTime checkIn;
  final DateTime checkOut;
  final int nights;
  final String? customerName;
  final String roomName;
  final String? bookingTypeName;
  final String? bookingSourceName;
  final double grossAmount;
  final double taxAmount;
  final double commissionInclTax;
  final double taxDeduction;
  final double netAmount;
  final bool paymentReceived;
  final double? actualPaymentAmount;
  final DateTime? paymentReceivedDate;
  final String? paymentDestinationName;

  factory BookingReportRow.fromJson(Map<String, dynamic> json) {
    final roomMap   = json['rooms']                as Map<String, dynamic>;
    final typeMap   = json['booking_types']         as Map<String, dynamic>?;
    final sourceMap = json['booking_sources']       as Map<String, dynamic>?;
    final destMap   = json['payment_destinations']  as Map<String, dynamic>?;

    final gross            = (json['total_amount']        as num).toDouble();
    final tax              = (json['tax_amount']           as num? ?? 0).toDouble();
    final commissionInclTax = (json['commission_incl_tax'] as num? ?? 0).toDouble();
    final taxDeduction     = (json['tax_deduction']        as num? ?? 0).toDouble();
    final net              = (json['net_amount']           as num?)?.toDouble()
        ?? (gross - commissionInclTax - taxDeduction);

    final checkIn  = DateTime.parse(json['check_in']  as String);
    final checkOut = DateTime.parse(json['check_out'] as String);

    return BookingReportRow(
      id:                     json['id'] as String,
      bookingDate:            json['booking_date'] != null
                                ? DateTime.parse(json['booking_date'] as String)
                                : null,
      checkIn:                checkIn,
      checkOut:               checkOut,
      nights:                 checkOut.difference(checkIn).inDays,
      customerName:           json['customer_name'] as String?,
      roomName:               roomMap['name'] as String,
      bookingTypeName:        typeMap?['name']   as String?,
      bookingSourceName:      sourceMap?['name'] as String?,
      grossAmount:            gross,
      taxAmount:              tax,
      commissionInclTax:      commissionInclTax,
      taxDeduction:           taxDeduction,
      netAmount:              net,
      paymentReceived:        json['payment_received'] as bool,
      actualPaymentAmount:    (json['actual_payment_amount'] as num?)?.toDouble(),
      paymentReceivedDate:    json['payment_received_date'] != null
                                ? DateTime.parse(json['payment_received_date'] as String)
                                : null,
      paymentDestinationName: destMap?['name'] as String?,
    );
  }
}
