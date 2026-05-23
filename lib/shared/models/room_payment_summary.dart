import 'package:equatable/equatable.dart';

class DestinationTotal extends Equatable {
  const DestinationTotal({
    required this.destinationId,
    required this.destinationName,
    required this.amount,
    required this.count,
  });

  // null means "Not specified" (booking had no destination set)
  final String? destinationId;
  final String? destinationName;
  final double amount;
  final int count;

  @override
  List<Object?> get props => [destinationId, destinationName, amount, count];
}

class RoomPaymentSummary extends Equatable {
  const RoomPaymentSummary({
    required this.roomId,
    required this.roomName,
    required this.roomTotal,
    required this.byDestination,
    required this.count,
  });

  final String roomId;
  final String roomName;
  final double roomTotal;
  final List<DestinationTotal> byDestination;
  final int count;

  @override
  List<Object?> get props =>
      [roomId, roomName, roomTotal, byDestination, count];
}
