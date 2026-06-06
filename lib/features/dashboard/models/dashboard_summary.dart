import 'package:equatable/equatable.dart';

class SourceBreakdown extends Equatable {
  const SourceBreakdown({
    required this.sourceName,
    required this.revenue,
    required this.bookingCount,
  });

  final String sourceName;
  final double revenue;
  final int bookingCount;

  @override
  List<Object?> get props => [sourceName, revenue, bookingCount];
}

class DestinationBreakdown extends Equatable {
  const DestinationBreakdown({
    required this.destinationName,
    required this.revenue,
    required this.bookingCount,
  });

  final String destinationName;
  final double revenue; // net collected (actual_payment_amount where received)
  final int bookingCount;

  @override
  List<Object?> get props => [destinationName, revenue, bookingCount];
}

class DashboardSummary extends Equatable {
  const DashboardSummary({
    required this.occupancyPct,
    required this.grossRevenue,
    required this.pendingReceivables,
    required this.totalBookings,
    required this.paymentsCollected,
    required this.adr,
    required this.revpar,
    required this.bySource,
    required this.byDestination,
  });

  final double occupancyPct;
  final double grossRevenue;
  final double pendingReceivables;
  final int totalBookings;
  final double paymentsCollected;

  /// Average Daily Rate = gross revenue / total room nights sold
  final double adr;

  /// Revenue Per Available Room = gross revenue / (rooms × days in period)
  final double revpar;

  final List<SourceBreakdown> bySource;
  final List<DestinationBreakdown> byDestination;

  @override
  List<Object?> get props => [
        occupancyPct,
        grossRevenue,
        pendingReceivables,
        totalBookings,
        paymentsCollected,
        adr,
        revpar,
        bySource,
        byDestination,
      ];
}
