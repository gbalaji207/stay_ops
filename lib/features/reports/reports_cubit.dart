import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../shared/models/room_category_summary.dart';
import '../../shared/models/room_payment_summary.dart';
import 'reports_repository.dart';

part 'reports_state.dart';

class ReportsCubit extends Cubit<ReportsState> {
  ReportsCubit(this._repository) : super(const ReportsInitial());

  final ReportsRepository _repository;

  Future<void> loadPaymentReport({
    required DateTimeRange dateRange,
    List<String>? roomIds,
  }) async {
    emit(const PaymentReportLoading());
    try {
      final rawRows = await _repository.fetchPaymentReportRows(
        dateFrom: dateRange.start,
        dateTo: dateRange.end,
        roomIds: roomIds,
      );

      // Aggregate client-side: group by roomId → destinationId
      // roomId → { destinationKey → (name, total) }
      final roomMap = <String, String>{}; // roomId → roomName
      final roomDestMap =
          <String, Map<String?, double>>{}; // roomId → {destId → amount}

      for (final row in rawRows) {
        roomMap[row.roomId] = row.roomName;
        roomDestMap.putIfAbsent(row.roomId, () => {});
        roomDestMap[row.roomId]![row.destinationId] =
            (roomDestMap[row.roomId]![row.destinationId] ?? 0) + row.amount;
      }

      // Resolve destination names (null key = "Not specified")
      // Build a lookup from raw rows
      final destNames = <String?, String?>{}; // destId → destName
      for (final row in rawRows) {
        destNames[row.destinationId] = row.destinationName;
      }

      // Build RoomPaymentSummary list, sorted by room name
      final roomRows = roomMap.entries.map((entry) {
        final roomId = entry.key;
        final roomName = entry.value;
        final destTotals = roomDestMap[roomId]!;

        final byDest = destTotals.entries
            .where((e) => e.value > 0)
            .map(
              (e) => DestinationTotal(
                destinationId: e.key,
                destinationName: e.key == null ? null : destNames[e.key],
                amount: e.value,
              ),
            )
            .toList()
          ..sort((a, b) {
            // "Not specified" last, others alphabetically
            if (a.destinationName == null) return 1;
            if (b.destinationName == null) return -1;
            return a.destinationName!.compareTo(b.destinationName!);
          });

        final roomTotal = byDest.fold(0.0, (sum, d) => sum + d.amount);

        return RoomPaymentSummary(
          roomId: roomId,
          roomName: roomName,
          roomTotal: roomTotal,
          byDestination: byDest,
        );
      }).toList()
        ..sort((a, b) => a.roomName.compareTo(b.roomName));

      // Overall totals: aggregate across all rooms by destination
      final overallMap = <String?, double>{};
      for (final room in roomRows) {
        for (final d in room.byDestination) {
          overallMap[d.destinationId] =
              (overallMap[d.destinationId] ?? 0) + d.amount;
        }
      }

      final overallTotals = overallMap.entries
          .where((e) => e.value > 0)
          .map(
            (e) => DestinationTotal(
              destinationId: e.key,
              destinationName: e.key == null ? null : destNames[e.key],
              amount: e.value,
            ),
          )
          .toList()
        ..sort((a, b) {
          if (a.destinationName == null) return 1;
          if (b.destinationName == null) return -1;
          return a.destinationName!.compareTo(b.destinationName!);
        });

      final grandTotal =
          overallTotals.fold(0.0, (sum, d) => sum + d.amount);

      emit(PaymentReportLoaded(
        dateRange: dateRange,
        roomFilter: roomIds,
        roomRows: roomRows,
        overallTotals: overallTotals,
        grandTotal: grandTotal,
      ));
    } catch (e) {
      emit(PaymentReportError(e.toString()));
    }
  }

  Future<void> loadBookingTypeReport({
    required DateTimeRange dateRange,
    List<String>? roomIds,
  }) async {
    emit(const BookingTypeReportLoading());
    try {
      final rawRows = await _repository.fetchTypeReportRows(
        dateFrom: dateRange.start,
        dateTo: dateRange.end,
        roomIds: roomIds,
      );
      emit(_aggregateCategory(
        rawRows: rawRows,
        dateRange: dateRange,
        roomIds: roomIds,
        toLoaded: (rows, totals, grand) => BookingTypeReportLoaded(
          dateRange: dateRange,
          roomFilter: roomIds,
          roomRows: rows,
          overallTotals: totals,
          grandTotal: grand,
        ),
      ));
    } catch (e) {
      emit(BookingTypeReportError(e.toString()));
    }
  }

  Future<void> loadBookingSourceReport({
    required DateTimeRange dateRange,
    List<String>? roomIds,
  }) async {
    emit(const BookingSourceReportLoading());
    try {
      final rawRows = await _repository.fetchSourceReportRows(
        dateFrom: dateRange.start,
        dateTo: dateRange.end,
        roomIds: roomIds,
      );
      emit(_aggregateCategory(
        rawRows: rawRows,
        dateRange: dateRange,
        roomIds: roomIds,
        toLoaded: (rows, totals, grand) => BookingSourceReportLoaded(
          dateRange: dateRange,
          roomFilter: roomIds,
          roomRows: rows,
          overallTotals: totals,
          grandTotal: grand,
        ),
      ));
    } catch (e) {
      emit(BookingSourceReportError(e.toString()));
    }
  }

  ReportsState _aggregateCategory({
    required List<RawCategoryReportRow> rawRows,
    required DateTimeRange dateRange,
    required List<String>? roomIds,
    required ReportsState Function(
      List<RoomCategorySummary>,
      List<CategoryTotal>,
      double,
    ) toLoaded,
  }) {
    final roomMap = <String, String>{};
    final roomCatMap = <String, Map<String?, double>>{};

    for (final row in rawRows) {
      roomMap[row.roomId] = row.roomName;
      roomCatMap.putIfAbsent(row.roomId, () => {});
      roomCatMap[row.roomId]![row.categoryId] =
          (roomCatMap[row.roomId]![row.categoryId] ?? 0) + row.amount;
    }

    final catNames = <String?, String?>{};
    for (final row in rawRows) {
      catNames[row.categoryId] = row.categoryName;
    }

    final roomRows = roomMap.entries.map((entry) {
      final roomId = entry.key;
      final roomName = entry.value;
      final catTotals = roomCatMap[roomId]!;

      final byCat = catTotals.entries
          .where((e) => e.value > 0)
          .map(
            (e) => CategoryTotal(
              categoryId: e.key,
              categoryName: e.key == null ? null : catNames[e.key],
              amount: e.value,
            ),
          )
          .toList()
        ..sort((a, b) {
          if (a.categoryName == null) return 1;
          if (b.categoryName == null) return -1;
          return a.categoryName!.compareTo(b.categoryName!);
        });

      final roomTotal = byCat.fold(0.0, (sum, c) => sum + c.amount);

      return RoomCategorySummary(
        roomId: roomId,
        roomName: roomName,
        roomTotal: roomTotal,
        byCategory: byCat,
      );
    }).toList()
      ..sort((a, b) => a.roomName.compareTo(b.roomName));

    final overallMap = <String?, double>{};
    for (final room in roomRows) {
      for (final c in room.byCategory) {
        overallMap[c.categoryId] = (overallMap[c.categoryId] ?? 0) + c.amount;
      }
    }

    final overallTotals = overallMap.entries
        .where((e) => e.value > 0)
        .map(
          (e) => CategoryTotal(
            categoryId: e.key,
            categoryName: e.key == null ? null : catNames[e.key],
            amount: e.value,
          ),
        )
        .toList()
      ..sort((a, b) {
        if (a.categoryName == null) return 1;
        if (b.categoryName == null) return -1;
        return a.categoryName!.compareTo(b.categoryName!);
      });

    final grandTotal = overallTotals.fold(0.0, (sum, c) => sum + c.amount);

    return toLoaded(roomRows, overallTotals, grandTotal);
  }
}
