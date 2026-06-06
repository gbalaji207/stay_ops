part of 'dashboard_cubit.dart';

enum DashboardPeriod { today, monthToDate, lastMonth, yearToDate, custom }

extension DashboardPeriodLabel on DashboardPeriod {
  String get label {
    switch (this) {
      case DashboardPeriod.today:
        return 'Today';
      case DashboardPeriod.monthToDate:
        return 'Month to Date';
      case DashboardPeriod.lastMonth:
        return 'Last Month';
      case DashboardPeriod.yearToDate:
        return 'Year to Date';
      case DashboardPeriod.custom:
        return 'Custom';
    }
  }
}

abstract class DashboardState extends Equatable {
  const DashboardState();
}

class DashboardInitial extends DashboardState {
  const DashboardInitial();
  @override
  List<Object?> get props => [];
}

class DashboardLoading extends DashboardState {
  const DashboardLoading();
  @override
  List<Object?> get props => [];
}

class DashboardLoaded extends DashboardState {
  const DashboardLoaded({
    required this.period,
    required this.customRange,
    required this.selectedRoomId,
    required this.summary,
  });

  final DashboardPeriod period;
  final DateTimeRange? customRange;
  final String? selectedRoomId;
  final DashboardSummary summary;

  @override
  List<Object?> get props => [period, customRange, selectedRoomId, summary];
}

class DashboardError extends DashboardState {
  const DashboardError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
