part of 'reports_cubit.dart';

abstract class ReportsState extends Equatable {
  const ReportsState();
}

class ReportsInitial extends ReportsState {
  const ReportsInitial();

  @override
  List<Object?> get props => [];
}

class PaymentReportLoading extends ReportsState {
  const PaymentReportLoading();

  @override
  List<Object?> get props => [];
}

class PaymentReportLoaded extends ReportsState {
  const PaymentReportLoaded({
    required this.dateRange,
    required this.roomFilter,
    required this.roomRows,
    required this.overallTotals,
    required this.grandTotal,
  });

  final DateTimeRange dateRange;
  final List<String>? roomFilter; // null = all rooms
  final List<RoomPaymentSummary> roomRows;
  final List<DestinationTotal> overallTotals;
  final double grandTotal;

  @override
  List<Object?> get props =>
      [dateRange, roomFilter, roomRows, overallTotals, grandTotal];
}

class PaymentReportError extends ReportsState {
  const PaymentReportError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class BookingTypeReportLoading extends ReportsState {
  const BookingTypeReportLoading();

  @override
  List<Object?> get props => [];
}

class BookingTypeReportLoaded extends ReportsState {
  const BookingTypeReportLoaded({
    required this.dateRange,
    required this.roomFilter,
    required this.roomRows,
    required this.overallTotals,
    required this.grandTotal,
  });

  final DateTimeRange dateRange;
  final List<String>? roomFilter;
  final List<RoomCategorySummary> roomRows;
  final List<CategoryTotal> overallTotals;
  final double grandTotal;

  @override
  List<Object?> get props =>
      [dateRange, roomFilter, roomRows, overallTotals, grandTotal];
}

class BookingTypeReportError extends ReportsState {
  const BookingTypeReportError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class BookingSourceReportLoading extends ReportsState {
  const BookingSourceReportLoading();

  @override
  List<Object?> get props => [];
}

class BookingSourceReportLoaded extends ReportsState {
  const BookingSourceReportLoaded({
    required this.dateRange,
    required this.roomFilter,
    required this.roomRows,
    required this.overallTotals,
    required this.grandTotal,
  });

  final DateTimeRange dateRange;
  final List<String>? roomFilter;
  final List<RoomCategorySummary> roomRows;
  final List<CategoryTotal> overallTotals;
  final double grandTotal;

  @override
  List<Object?> get props =>
      [dateRange, roomFilter, roomRows, overallTotals, grandTotal];
}

class BookingSourceReportError extends ReportsState {
  const BookingSourceReportError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
