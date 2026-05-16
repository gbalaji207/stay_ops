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
    this.bookingTypeId,
    this.bookingSourceId,
    this.notes,
    required this.isActive,
    this.paymentDestinationId,
    this.paymentDestinationName,
  });

  final String id;
  final String propertyId;
  final String roomId;
  final DateTime checkIn;
  final DateTime checkOut;
  final double totalAmount;
  final bool paymentReceived;
  final String? bookingTypeId;
  final String? bookingSourceId;
  final String? notes;
  final bool isActive;
  final String? paymentDestinationId;
  final String? paymentDestinationName;

  int get nights => checkOut.difference(checkIn).inDays;
  double get perNightAmount => nights > 0 ? totalAmount / nights : 0;

  factory BookingGroup.fromJson(Map<String, dynamic> json) {
    final destMap = json['payment_destinations'] as Map<String, dynamic>?;
    return BookingGroup(
      id: json['id'] as String,
      propertyId: json['property_id'] as String,
      roomId: json['room_id'] as String,
      checkIn: DateTime.parse(json['check_in'] as String),
      checkOut: DateTime.parse(json['check_out'] as String),
      totalAmount: (json['total_amount'] as num).toDouble(),
      paymentReceived: json['payment_received'] as bool,
      bookingTypeId: json['booking_type_id'] as String?,
      bookingSourceId: json['booking_source_id'] as String?,
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool,
      paymentDestinationId: json['payment_destination_id'] as String?,
      paymentDestinationName: destMap?['name'] as String?,
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
        bookingTypeId,
        bookingSourceId,
        notes,
        isActive,
        paymentDestinationId,
        paymentDestinationName,
      ];
}
