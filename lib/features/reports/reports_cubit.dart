import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
}
