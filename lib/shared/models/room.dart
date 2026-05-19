import 'package:equatable/equatable.dart';

class Room extends Equatable {
  const Room({
    required this.id,
    required this.propertyId,
    required this.name,
    required this.sortOrder,
    required this.isActive,
    this.sfRoomId,
  });

  final String id;
  final String propertyId;
  final String name;
  final int sortOrder;
  final bool isActive;
  final String? sfRoomId;

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      propertyId: json['property_id'] as String,
      name: json['name'] as String,
      sortOrder: json['sort_order'] as int,
      isActive: json['is_active'] as bool,
      sfRoomId: json['sf_room_id'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, propertyId, name, sortOrder, isActive, sfRoomId];
}
