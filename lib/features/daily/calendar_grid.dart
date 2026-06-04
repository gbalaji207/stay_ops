import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/room.dart';
import 'calendar_booking.dart';
import 'daily_cubit.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const double kCalRoomColW        = 110.0;
const double kCalHeaderH         = 52.0;
const double kCalLaneH           = 46.0;
const double kCalLaneMinH        = 52.0;
const double kCalSpanH           = 38.0;
const double kCalSpanPad         = 3.0;
const double kCalChipMinForText  = 22.0;
const double kCalChipMinForAvatar = 52.0;

/// Fractional column offset of [localDt] from [anchorMidnight].
/// 1.0 = one full day. Uses inMinutes to avoid integer truncation across
/// day boundaries that .inDays would introduce.
double _colFrac(DateTime localDt, DateTime anchorMidnight) =>
    localDt.difference(anchorMidnight).inMinutes / (24.0 * 60.0);

// ─── CalendarGrid ─────────────────────────────────────────────────────────────

class CalendarGrid extends StatelessWidget {
  const CalendarGrid({
    super.key,
    required this.state,
    required this.colors,
    required this.onTapBooking,
    required this.onTapVacant,
  });

  final DailyRangeLoaded state;
  final AppColors colors;
  final ValueChanged<String> onTapBooking;
  final void Function(Room room, DateTime date) onTapVacant;

  // ── lane algorithm ─────────────────────────────────────────────────────────

  static List<List<CalendarBooking>> _computeLanes(
      List<CalendarBooking> bookings) {
    final lanes = <List<CalendarBooking>>[];
    for (final b in bookings) {
      bool placed = false;
      for (final lane in lanes) {
        if (!lane.any((e) => _overlap(b, e))) {
          lane.add(b);
          placed = true;
          break;
        }
      }
      if (!placed) lanes.add([b]);
    }
    return lanes;
  }

  static bool _overlap(CalendarBooking a, CalendarBooking b) {
    final aDt  = a.checkInDatetime;
    final aEnd = a.checkOutDatetime;
    final bDt  = b.checkInDatetime;
    final bEnd = b.checkOutDatetime;

    if (aDt != null && aEnd != null && bDt != null && bEnd != null) {
      // Datetime-precision overlap: two bookings share a lane only when their
      // actual time windows intersect. Non-overlapping same-day bookings
      // (e.g. 12:00–16:00 and 18:00–21:00) go into the SAME lane so they
      // render side-by-side.
      return aDt.isBefore(bEnd) && bDt.isBefore(aEnd);
    }
    // Fallback for legacy bookings without TIMESTAMPTZ fields.
    return !a.checkIn.isAfter(b.checkOut) && !b.checkIn.isAfter(a.checkOut);
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Sticky room name column ──────────────────────────────────────────
        SizedBox(
          width: kCalRoomColW,
          child: Column(
            children: state.rooms.map((room) {
              final lanes = _computeLanes(
                  state.bookings.where((b) => b.room.id == room.id).toList());
              final rowH = _rowHeight(lanes);
              return CalendarRoomLabel(room: room, height: rowH, colors: colors);
            }).toList(),
          ),
        ),
        // ── Grid columns ─────────────────────────────────────────────────────
        Expanded(
          child: LayoutBuilder(
            builder: (_, box) {
              final colW = box.maxWidth / state.visibleDays;
              return Column(
                children: state.rooms.map((room) {
                  final lanes = _computeLanes(
                      state.bookings
                          .where((b) => b.room.id == room.id)
                          .toList());
                  return CalendarRoomRow(
                    room: room,
                    lanes: lanes,
                    anchorDate: state.anchorDate,
                    visibleDays: state.visibleDays,
                    colWidth: colW,
                    colors: colors,
                    onTapBooking: onTapBooking,
                    onTapVacant: onTapVacant,
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  static double _rowHeight(List<List<CalendarBooking>> lanes) =>
      lanes.isEmpty ? kCalLaneMinH : lanes.length * kCalLaneH;
}

// ─── CalendarDayHeader ────────────────────────────────────────────────────────

class CalendarDayHeader extends StatelessWidget {
  const CalendarDayHeader({
    super.key,
    required this.day,
    required this.width,
    required this.colors,
  });

  final DateTime day;
  final double width;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            DateFormat('E').format(day), // "Mon"
            style: TextStyle(
              fontSize: 10,
              color: colors.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            DateFormat('d').format(day), // "20"
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── CalendarRoomLabel (sticky left cell) ────────────────────────────────────

class CalendarRoomLabel extends StatelessWidget {
  const CalendarRoomLabel({
    super.key,
    required this.room,
    required this.height,
    required this.colors,
  });

  final Room room;
  final double height;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: kCalRoomColW,
      height: height,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.border),
          right: BorderSide(color: colors.border),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: Text(
        room.name,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: colors.textPrimary,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
    );
  }
}

// ─── CalendarRoomRow (one row of the grid for a single room) ─────────────────

class CalendarRoomRow extends StatelessWidget {
  const CalendarRoomRow({
    super.key,
    required this.room,
    required this.lanes,
    required this.anchorDate,
    required this.visibleDays,
    required this.colWidth,
    required this.colors,
    required this.onTapBooking,
    required this.onTapVacant,
  });

  final Room room;
  final List<List<CalendarBooking>> lanes;
  final DateTime anchorDate;
  final int visibleDays;
  final double colWidth; // pixels per day-column, from LayoutBuilder
  final AppColors colors;
  final ValueChanged<String> onTapBooking;
  final void Function(Room room, DateTime date) onTapVacant;

  @override
  Widget build(BuildContext context) {
    // Set of date keys that have at least one booking — used to suppress
    // vacant-tap on any date already covered by a booking in another lane.
    final bookedDates = <String>{};
    for (final lane in lanes) {
      for (final b in lane) {
        var d = b.checkIn;
        while (!d.isAfter(b.checkOut)) {
          bookedDates.add('${d.year}-${d.month}-${d.day}');
          d = d.add(const Duration(days: 1));
        }
      }
    }

    return DecoratedBox(
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: colors.border))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: lanes.isEmpty
            ? [_buildVacantLane(bookedDates)]
            : lanes.map((lane) => _buildLaneRow(lane, bookedDates)).toList(),
      ),
    );
  }

  // ── all-vacant row (no bookings for this room) ──────────────────────────────

  Widget _buildVacantLane(Set<String> bookedDates) {
    return SizedBox(
      height: kCalLaneMinH,
      child: Row(
        children: List.generate(
          visibleDays,
          (i) => Expanded(
            child: _vacantCell(anchorDate.add(Duration(days: i)), bookedDates),
          ),
        ),
      ),
    );
  }

  // ── one booking lane ────────────────────────────────────────────────────────
  //
  // Layer 1 (background): a Row of Expanded GestureDetectors — one per column
  // — acting as vacant-cell tap targets with column border dividers.
  // Layer 2 (foreground): Stack of Positioned booking chips at fractional
  // sub-column pixel positions derived from checkInDatetime/checkOutDatetime.

  Widget _buildLaneRow(
      List<CalendarBooking> laneBookings, Set<String> bookedDates) {
    return SizedBox(
      height: kCalLaneH,
      child: Stack(
        children: [
          // Background: column dividers + vacant tap targets
          Row(
            children: List.generate(
              visibleDays,
              (i) => Expanded(
                child: _vacantCell(
                    anchorDate.add(Duration(days: i)), bookedDates),
              ),
            ),
          ),
          // Foreground: booking chips at fractional pixel positions
          for (final booking in laneBookings) _positionedChip(booking),
        ],
      ),
    );
  }

  // ── fractional-pixel chip positioning ──────────────────────────────────────
  //
  // When checkInDatetime / checkOutDatetime are available, the chip is placed
  // at the exact time fraction within each column:
  //   • A 12:00–16:00 booking starts at 50% and ends at 66.7% of its column.
  //   • A multi-night booking that checks out at 11:00 ends at the 45.8%
  //     position within the checkout column.
  //
  // When datetime fields are absent (legacy bookings), the chip falls back to
  // spanning whole columns, matching the previous behaviour.

  Widget _positionedChip(CalendarBooking booking) {
    double startFrac, endFrac;

    final inDt  = booking.checkInDatetime;
    final outDt = booking.checkOutDatetime;

    if (inDt != null && outDt != null) {
      startFrac = _colFrac(inDt,  anchorDate)
          .clamp(0.0, visibleDays.toDouble());
      endFrac   = _colFrac(outDt, anchorDate)
          .clamp(0.0, visibleDays.toDouble());
    } else {
      // Date-level fallback: chip fills whole start→end columns.
      startFrac = booking.checkIn
          .difference(anchorDate)
          .inDays
          .clamp(0, visibleDays - 1)
          .toDouble();
      endFrac   = (booking.checkOut.difference(anchorDate).inDays + 1.0)
          .clamp(1.0, visibleDays.toDouble());
    }

    final left  = startFrac * colWidth + kCalSpanPad;
    final width = ((endFrac - startFrac) * colWidth - kCalSpanPad * 2)
        .clamp(0.0, double.infinity);
    const top = (kCalLaneH - kCalSpanH) / 2.0; // vertically centred in lane

    return Positioned(
      left: left,
      width: width,
      top: top,
      height: kCalSpanH,
      child: CalendarBookingSpan(
        booking: booking,
        colors: colors,
        chipWidth: width,
        onTap: () => onTapBooking(booking.bookingGroupId),
      ),
    );
  }

  // ── single vacant column cell ───────────────────────────────────────────────

  Widget _vacantCell(DateTime day, Set<String> bookedDates) {
    final key = '${day.year}-${day.month}-${day.day}';
    final alreadyBooked = bookedDates.contains(key);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: alreadyBooked ? null : () => onTapVacant(room, day),
      child: Container(
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: colors.border)),
        ),
      ),
    );
  }
}

// ─── CalendarBookingSpan ──────────────────────────────────────────────────────

class CalendarBookingSpan extends StatelessWidget {
  const CalendarBookingSpan({
    super.key,
    required this.booking,
    required this.colors,
    required this.chipWidth,
    required this.onTap,
  });

  final CalendarBooking booking;
  final AppColors colors;

  /// Pixel width of the Positioned chip — used to adapt visible content so
  /// the inner Row never overflows its bounds.
  final double chipWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Paid → solid success green, pending → solid warning amber.
    final bg = booking.paymentReceived ? colors.success : colors.warning;

    // Narrow chips adapt progressively:
    //   < kCalChipMinForText   → coloured bar only (no text, no icon)
    //   < kCalChipMinForAvatar → customer name only (no source avatar)
    //   ≥ kCalChipMinForAvatar → full row: avatar + name
    final showText   = chipWidth >= kCalChipMinForText;
    final showAvatar = chipWidth >= kCalChipMinForAvatar &&
        booking.sourceName != null;
    final hPad = showText ? 6.0 : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        // Clip.hardEdge is the essential safety net: even if the Row's intrinsic
        // minimum width exceeds chipWidth (e.g. during a window resize frame),
        // content is silently clipped rather than triggering a layout overflow.
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 3),
        child: showText
            ? Row(
                children: [
                  if (showAvatar) ...[
                    CalendarSourceAvatar(name: booking.sourceName!),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      booking.customerName?.isNotEmpty == true
                          ? booking.customerName!
                          : 'Guest',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              )
            : const SizedBox.shrink(), // too narrow for text — just the bar
      ),
    );
  }
}

// ─── CalendarSourceAvatar ─────────────────────────────────────────────────────
//
// Shows a known OTA logo (image asset) or a 2-letter fallback circle.

class CalendarSourceAvatar extends StatelessWidget {
  const CalendarSourceAvatar({super.key, required this.name});

  final String name;

  /// Maps lower-cased source names to bundled asset paths.
  static const Map<String, String> _assets = {
    'makemytrip': 'assets/images/go-mmt.png',
    'mmt': 'assets/images/go-mmt.png',
    'go-mmt': 'assets/images/go-mmt.png',
    'goibibo': 'assets/images/goibibo.png',
    'agoda': 'assets/images/agoda.png',
    'airbnb': 'assets/images/airbnb.png',
  };

  @override
  Widget build(BuildContext context) {
    final assetPath = _assets[name.toLowerCase().trim()];
    final child = assetPath != null
        ? Image.asset(
            assetPath,
            width: 14,
            height: 14,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, st) => _fallbackLabel(),
          )
        : _fallbackLabel();

    // White rounded-corner container so the logo is always legible
    // regardless of the chip background colour.
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _fallbackLabel() {
    final label = name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name.toUpperCase();
    return Text(
      label,
      style: const TextStyle(
        fontSize: 7,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
    );
  }
}
