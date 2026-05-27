import 'package:equatable/equatable.dart';

class DayRoomRow extends Equatable {
  const DayRoomRow({
    required this.roomId,
    required this.roomName,
    required this.bookingGroupId,
    required this.perNightAmount,
    required this.paymentReceived,
    this.sourceName,
    this.typeName,
  });

  final String roomId;
  final String roomName;
  final String bookingGroupId;
  final double perNightAmount;
  final bool paymentReceived;
  final String? sourceName;
  final String? typeName;

  @override
  List<Object?> get props => [roomId, roomName, bookingGroupId, perNightAmount, paymentReceived, sourceName, typeName];
}

class DayStats extends Equatable {
  const DayStats({
    required this.date,
    required this.revenue,
    required this.bookedCount,
    required this.totalRooms,
    required this.rooms,
  });

  final DateTime date;
  final double revenue;
  final int bookedCount;
  final int totalRooms;       // 1 when room filter active; full room count otherwise
  final List<DayRoomRow> rooms;

  double get occupancyPct =>
      totalRooms > 0 ? (bookedCount / totalRooms) * 100 : 0;

  // Revenue level 0–4 for heatmap colour
  int get revenueLevel {
    if (revenue <= 0) return 0;
    if (revenue < 8000) return 1;
    if (revenue < 14000) return 2;
    if (revenue < 22000) return 3;
    return 4;
  }

  // Revenue label shown inside heatmap cell (empty for level 0)
  String get revenueLabel {
    if (revenue <= 0) return '';
    if (revenue >= 1000) return '₹${(revenue / 1000).toStringAsFixed(1)}k';
    return '₹${revenue.toInt()}';
  }

  @override
  List<Object?> get props => [date, revenue, bookedCount, totalRooms, rooms];
}
