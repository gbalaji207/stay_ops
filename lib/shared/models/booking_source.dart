import 'package:equatable/equatable.dart';

class BookingSource extends Equatable {
  const BookingSource({
    required this.id,
    required this.propertyId,
    required this.name,
    this.bookingTypeId,
    required this.sortOrder,
    required this.isActive,
    this.defaultPaymentDestinationId,
    this.defaultPaymentDestinationName,
  });

  final String id;
  final String propertyId;
  final String name;
  // nullable: ON DELETE SET NULL in DB schema
  final String? bookingTypeId;
  final int sortOrder;
  final bool isActive;
  final String? defaultPaymentDestinationId;
  final String? defaultPaymentDestinationName;

  factory BookingSource.fromJson(Map<String, dynamic> json) {
    final destMap = json['payment_destinations'] as Map<String, dynamic>?;
    return BookingSource(
      id: json['id'] as String,
      propertyId: json['property_id'] as String,
      name: json['name'] as String,
      bookingTypeId: json['booking_type_id'] as String?,
      sortOrder: json['sort_order'] as int,
      isActive: json['is_active'] as bool,
      defaultPaymentDestinationId:
          json['default_payment_destination_id'] as String?,
      defaultPaymentDestinationName: destMap?['name'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        propertyId,
        name,
        bookingTypeId,
        sortOrder,
        isActive,
        defaultPaymentDestinationId,
        defaultPaymentDestinationName,
      ];
}
