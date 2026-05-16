import 'package:equatable/equatable.dart';

class DestinationTotal extends Equatable {
  const DestinationTotal({
    required this.destinationId,
    required this.destinationName,
    required this.amount,
  });

  // null means "Not specified" (booking had no destination set)
  final String? destinationId;
  final String? destinationName;
  final double amount;

  @override
  List<Object?> get props => [destinationId, destinationName, amount];
}

class RoomPaymentSummary extends Equatable {
  const RoomPaymentSummary({
    required this.roomId,
    required this.roomName,
    required this.roomTotal,
    required this.byDestination,
  });

  final String roomId;
  final String roomName;
  final double roomTotal;
  final List<DestinationTotal> byDestination;

  @override
  List<Object?> get props => [roomId, roomName, roomTotal, byDestination];
}
