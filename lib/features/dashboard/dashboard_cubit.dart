import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../shared/models/booking_group.dart';
import 'dashboard_repository.dart';
import 'models/dashboard_summary.dart';

part 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit(this._repository) : super(const DashboardInitial());

  final DashboardRepository _repository;

  Future<void> load({
    required DashboardPeriod period,
    DateTimeRange? customRange,
    String? roomId,
    required int totalRooms,
    required Map<String, String> sourceNames,
    required Map<String, String> destinationNames,
  }) async {
    if (isClosed) return;
    emit(const DashboardLoading());

    final range = _computeRange(period, customRange);
    final daysInPeriod = range.end.difference(range.start).inDays + 1;
    final roomsForCalc = roomId != null ? 1 : totalRooms.clamp(1, 9999);
    final availableRoomDays = roomsForCalc * daysInPeriod;

    try {
      final groupsFuture =
          _repository.fetchDashboardGroups(range, roomId: roomId);
      final occupiedFuture =
          _repository.fetchOccupiedRoomDays(range, roomId: roomId);

      final groups = await groupsFuture;
      final occupiedRoomDays = await occupiedFuture;

      if (isClosed) return;

      // Occupancy %
      final occupancyPct = availableRoomDays > 0
          ? (occupiedRoomDays / availableRoomDays) * 100
          : 0.0;

      // Revenue aggregation
      double grossRevenue = 0;
      double pendingReceivables = 0;
      double paymentsCollected = 0;
      int totalNights = 0;

      // Source: sourceId → revenue & unique group ids
      final sourceRevenue = <String, double>{};
      final sourceGroupIds = <String, Set<String>>{};

      // Destination: destId → collected revenue & unique group ids
      final destRevenue = <String, double>{};
      final destGroupIds = <String, Set<String>>{};

      for (final BookingGroup g in groups) {
        grossRevenue += g.totalAmount;
        if (!g.paymentReceived) {
          pendingReceivables += g.netAmount;
        } else {
          paymentsCollected += g.actualPaymentAmount ?? g.netAmount;
        }

        // Nights for ADR (day-use = 1)
        final nights = g.nights > 0 ? g.nights : 1;
        totalNights += nights;

        // Source breakdown
        final srcKey = g.bookingSourceId ?? '__none__';
        sourceRevenue[srcKey] = (sourceRevenue[srcKey] ?? 0) + g.totalAmount;
        sourceGroupIds.putIfAbsent(srcKey, () => {}).add(g.id);

        // Destination breakdown (only where payment received)
        if (g.paymentReceived) {
          final dstKey = g.paymentDestinationId ?? '__none__';
          final collected = g.actualPaymentAmount ?? g.netAmount;
          destRevenue[dstKey] = (destRevenue[dstKey] ?? 0) + collected;
          destGroupIds.putIfAbsent(dstKey, () => {}).add(g.id);
        }
      }

      // ADR = gross revenue / total room nights sold
      final adr = totalNights > 0 ? grossRevenue / totalNights : 0.0;

      // RevPAR = gross revenue / total available room-days
      final revpar =
          availableRoomDays > 0 ? grossRevenue / availableRoomDays : 0.0;

      // Build source list sorted by revenue desc, "Not specified" last
      final bySource = sourceRevenue.entries.map((e) {
        final name = e.key == '__none__'
            ? 'Not specified'
            : (sourceNames[e.key] ?? e.key);
        return SourceBreakdown(
          sourceName: name,
          revenue: e.value,
          bookingCount: sourceGroupIds[e.key]!.length,
        );
      }).toList()
        ..sort((a, b) {
          if (a.sourceName == 'Not specified') return 1;
          if (b.sourceName == 'Not specified') return -1;
          return b.revenue.compareTo(a.revenue);
        });

      // Build destination list sorted by revenue desc, "Not specified" last
      final byDestination = destRevenue.entries.map((e) {
        final name = e.key == '__none__'
            ? 'Not specified'
            : (destinationNames[e.key] ?? e.key);
        return DestinationBreakdown(
          destinationName: name,
          revenue: e.value,
          bookingCount: destGroupIds[e.key]!.length,
        );
      }).toList()
        ..sort((a, b) {
          if (a.destinationName == 'Not specified') return 1;
          if (b.destinationName == 'Not specified') return -1;
          return b.revenue.compareTo(a.revenue);
        });

      emit(DashboardLoaded(
        period: period,
        customRange: customRange,
        selectedRoomId: roomId,
        summary: DashboardSummary(
          occupancyPct: double.parse(occupancyPct.toStringAsFixed(1)),
          grossRevenue: grossRevenue,
          pendingReceivables: pendingReceivables,
          totalBookings: groups.length,
          paymentsCollected: paymentsCollected,
          adr: adr,
          revpar: revpar,
          bySource: bySource,
          byDestination: byDestination,
        ),
      ));
    } catch (e) {
      if (isClosed) return;
      emit(DashboardError(e.toString()));
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  DateTimeRange _computeRange(DashboardPeriod period, DateTimeRange? custom) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (period) {
      case DashboardPeriod.today:
        return DateTimeRange(start: today, end: today);
      case DashboardPeriod.monthToDate:
        return DateTimeRange(
          start: DateTime(today.year, today.month, 1),
          end: today,
        );
      case DashboardPeriod.lastMonth:
        // day 0 of current month = last day of previous month
        final first = DateTime(today.year, today.month - 1, 1);
        final last = DateTime(today.year, today.month, 0);
        return DateTimeRange(start: first, end: last);
      case DashboardPeriod.yearToDate:
        return DateTimeRange(
          start: DateTime(today.year, 1, 1),
          end: today,
        );
      case DashboardPeriod.custom:
        return custom ??
            DateTimeRange(
              start: DateTime(today.year, today.month, 1),
              end: today,
            );
    }
  }
}
