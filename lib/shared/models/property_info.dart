import 'package:equatable/equatable.dart';

class PropertyInfo extends Equatable {
  const PropertyInfo({
    required this.id,
    required this.name,
    this.sfHotelId,
  });

  final String id;
  final String name;
  final String? sfHotelId;

  factory PropertyInfo.fromJson(Map<String, dynamic> json) {
    return PropertyInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      sfHotelId: json['sf_hotel_id'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, name, sfHotelId];
}
