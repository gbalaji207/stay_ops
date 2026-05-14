import '../../shared/models/room.dart';

enum RoomOccupancy { booked, vacant }

class RoomDayStatus {
  const RoomDayStatus._({
    required this.room,
    required this.occupancy,
    this.bookingGroupId,
    this.checkIn,
    this.checkOut,
    this.perNightAmount,
    this.paymentReceived,
    this.sourceName,
  });

  final Room room;
  final RoomOccupancy occupancy;

  // Booked-only fields (null when vacant)
  final String? bookingGroupId;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final double? perNightAmount;
  final bool? paymentReceived;
  final String? sourceName;

  bool get isBooked => occupancy == RoomOccupancy.booked;
  int? get nightCount => (checkIn != null && checkOut != null)
      ? checkOut!.difference(checkIn!).inDays
      : null;

  const RoomDayStatus.booked({
    required Room room,
    required String bookingGroupId,
    required DateTime checkIn,
    required DateTime checkOut,
    required double perNightAmount,
    required bool paymentReceived,
    String? sourceName,
  }) : this._(
          room: room,
          occupancy: RoomOccupancy.booked,
          bookingGroupId: bookingGroupId,
          checkIn: checkIn,
          checkOut: checkOut,
          perNightAmount: perNightAmount,
          paymentReceived: paymentReceived,
          sourceName: sourceName,
        );

  const RoomDayStatus.vacant({required Room room})
      : this._(room: room, occupancy: RoomOccupancy.vacant);
}
