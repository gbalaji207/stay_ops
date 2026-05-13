import 'package:equatable/equatable.dart';

class BookingSource extends Equatable {
  const BookingSource({
    required this.id,
    required this.propertyId,
    required this.name,
    required this.bookingTypeId,
    required this.sortOrder,
    required this.isActive,
  });

  final String id;
  final String propertyId;
  final String name;
  final String bookingTypeId;
  final int sortOrder;
  final bool isActive;

  factory BookingSource.fromJson(Map<String, dynamic> json) {
    return BookingSource(
      id: json['id'] as String,
      propertyId: json['property_id'] as String,
      name: json['name'] as String,
      bookingTypeId: json['booking_type_id'] as String,
      sortOrder: json['sort_order'] as int,
      isActive: json['is_active'] as bool,
    );
  }

  @override
  List<Object?> get props => [id, propertyId, name, bookingTypeId, sortOrder, isActive];
}
