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

class BookingsListReportLoading extends ReportsState {
  const BookingsListReportLoading();

  @override
  List<Object?> get props => [];
}

class BookingsListReportLoaded extends ReportsState {
  const BookingsListReportLoaded({
    required this.dateRange,
    required this.rows,
    required this.roomFilter,
    required this.bookingTypeFilter,
    required this.bookingSourceFilter,
    required this.paymentDestinationFilter,
    required this.grandTotalGross,
    required this.grandTotalNet,
  });

  final DateTimeRange dateRange;
  final List<BookingReportRow> rows;
  final List<String>? roomFilter;
  final List<String>? bookingTypeFilter;
  final List<String>? bookingSourceFilter;
  final List<String>? paymentDestinationFilter;
  final double grandTotalGross;
  final double grandTotalNet;

  @override
  List<Object?> get props => [
        dateRange,
        rows,
        roomFilter,
        bookingTypeFilter,
        bookingSourceFilter,
        paymentDestinationFilter,
        grandTotalGross,
        grandTotalNet,
      ];
}

class BookingsListReportError extends ReportsState {
  const BookingsListReportError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
