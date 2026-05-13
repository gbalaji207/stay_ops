import 'package:equatable/equatable.dart';

class BookingDay extends Equatable {
  const BookingDay({
    required this.id,
    required this.bookingGroupId,
    required this.propertyId,
    required this.roomId,
    required this.bookingDate,
    required this.amount,
    required this.isActive,
  });

  final String id;
  final String bookingGroupId;
  final String propertyId;
  final String roomId;
  final DateTime bookingDate;
  final double amount;
  final bool isActive;

  factory BookingDay.fromJson(Map<String, dynamic> json) {
    return BookingDay(
      id: json['id'] as String,
      bookingGroupId: json['booking_group_id'] as String,
      propertyId: json['property_id'] as String,
      roomId: json['room_id'] as String,
      bookingDate: DateTime.parse(json['booking_date'] as String),
      amount: (json['amount'] as num).toDouble(),
      isActive: json['is_active'] as bool,
    );
  }

  @override
  List<Object?> get props =>
      [id, bookingGroupId, propertyId, roomId, bookingDate, amount, isActive];
}
