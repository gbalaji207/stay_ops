import 'package:equatable/equatable.dart';

class CategoryTotal extends Equatable {
  const CategoryTotal({
    required this.categoryId,
    required this.categoryName,
    required this.amount,
  });

  // null means "Not specified"
  final String? categoryId;
  final String? categoryName;
  final double amount;

  @override
  List<Object?> get props => [categoryId, categoryName, amount];
}

class RoomCategorySummary extends Equatable {
  const RoomCategorySummary({
    required this.roomId,
    required this.roomName,
    required this.roomTotal,
    required this.byCategory,
  });

  final String roomId;
  final String roomName;
  final double roomTotal;
  final List<CategoryTotal> byCategory;

  @override
  List<Object?> get props => [roomId, roomName, roomTotal, byCategory];
}
