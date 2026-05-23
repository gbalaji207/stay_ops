class SfBookingPrefill {
  const SfBookingPrefill({
    this.roomId,
    this.checkIn,
    this.checkOut,
    this.bookingDate,
    this.customerName,
    this.sfBookingId,
    this.otaBookingId,
    this.bookingTypeId,
    this.bookingSourceId,
    this.paymentDestinationId,
    this.grossAmount,
    this.taxAmount,
    this.commissionInclTax,
    this.taxDeduction,
    this.netAmount,
  });

  final String? roomId;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final DateTime? bookingDate;
  final String? customerName;
  final String? sfBookingId;
  final String? otaBookingId;
  final String? bookingTypeId;
  final String? bookingSourceId;
  final String? paymentDestinationId;
  final double? grossAmount;
  final double? taxAmount;
  final double? commissionInclTax;
  final double? taxDeduction;
  final double? netAmount;

  static DateTime? _parseDate(String? s) {
    if (s == null) return null;
    return DateTime.tryParse(s);
  }

  static DateTime? _dateOnly(DateTime? dt) {
    if (dt == null) return null;
    return DateTime(dt.year, dt.month, dt.day);
  }

  static String? _matchSourceId(
    String? sourceName,
    List<dynamic> activeSources,
  ) {
    if (sourceName == null) return null;
    final upper = sourceName.toUpperCase();
    for (final s in activeSources) {
      if ((s.name as String).toUpperCase() == upper) return s.id as String;
    }
    return null;
  }

  factory SfBookingPrefill.fromJson(
    Map<String, dynamic> json, {
    required List<dynamic> activeSources,
    required List<dynamic> activeDestinations,
  }) {
    final sourceName = json['booking_source'] as String?;
    final sourceId = _matchSourceId(sourceName, activeSources);

    String? bookingTypeId;
    String? paymentDestinationId;
    if (sourceId != null) {
      final source = activeSources.firstWhere((s) => s.id == sourceId);
      bookingTypeId = source.bookingTypeId as String?;
      final destId = source.defaultPaymentDestinationId as String?;
      if (destId != null &&
          activeDestinations.any((d) => d.id == destId && (d.isActive as bool))) {
        paymentDestinationId = destId;
      }
    }

    return SfBookingPrefill(
      roomId: json['internal_room_id'] as String?,
      checkIn: _dateOnly(_parseDate(json['checkin'] as String?)),
      checkOut: _dateOnly(_parseDate(json['checkout'] as String?)),
      bookingDate: _parseDate(json['booking_made_on'] as String?),
      customerName: json['customer_name'] as String?,
      sfBookingId: json['sfBookingId'] as String?,
      otaBookingId: json['ota_booking_id'] as String?,
      bookingTypeId: bookingTypeId,
      bookingSourceId: sourceId,
      paymentDestinationId: paymentDestinationId,
      grossAmount: (json['ota_gross_amount'] as num?)?.toDouble(),
      taxAmount: (json['ota_tax_amount'] as num?)?.toDouble(),
      commissionInclTax: (json['ota_commission'] as num?)?.toDouble(),
      taxDeduction: (json['tax_deduction'] as num?)?.toDouble(),
      netAmount: (json['net_amount'] as num?)?.toDouble(),
    );
  }
}
