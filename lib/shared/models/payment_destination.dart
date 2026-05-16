import 'package:equatable/equatable.dart';

class PaymentDestination extends Equatable {
  const PaymentDestination({
    required this.id,
    required this.propertyId,
    required this.name,
    required this.sortOrder,
    required this.isActive,
  });

  final String id;
  final String propertyId;
  final String name;
  final int sortOrder;
  final bool isActive;

  factory PaymentDestination.fromJson(Map<String, dynamic> json) {
    return PaymentDestination(
      id: json['id'] as String,
      propertyId: json['property_id'] as String,
      name: json['name'] as String,
      sortOrder: json['sort_order'] as int,
      isActive: json['is_active'] as bool,
    );
  }

  @override
  List<Object?> get props => [id, propertyId, name, sortOrder, isActive];
}
