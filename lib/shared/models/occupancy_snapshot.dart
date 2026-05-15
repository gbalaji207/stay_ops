import 'package:equatable/equatable.dart';

class OccupancySnapshot extends Equatable {
  const OccupancySnapshot({
    required this.occupied,
    required this.vacant,
    required this.pct,
  });

  final int occupied;
  final int vacant;
  final double pct;

  @override
  List<Object?> get props => [occupied, vacant, pct];
}
