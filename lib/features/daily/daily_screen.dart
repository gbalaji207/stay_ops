import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/booking_group.dart';
import '../../shared/models/booking_source.dart';
import '../../shared/models/room.dart';
import '../booking/wizard/booking_wizard_extras.dart';
import '../config/config_cubit.dart';
import 'calendar_booking.dart';
import 'daily_cubit.dart';
import 'daily_repository.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const double _kRoomColW = 110.0; // fixed left sticky column width
const double _kHeaderH = 52.0; // day-column header row height
const double _kLaneH = 46.0; // height per booking lane in a room row
const double _kLaneMinH = 52.0; // minimum room row height (1 lane)
const double _kSpanH = 38.0; // booking chip height within a lane
const double _kSpanPad = 3.0; // horizontal padding on each side of chip
const double _kChipMinForText = 22.0; // chip px threshold: below → coloured bar only
const double _kChipMinForAvatar = 52.0; // chip px threshold: below → text only, no avatar

// ─── DailyScreen ─────────────────────────────────────────────────────────────

class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  late DateTime _anchorDate;

  /// Last successfully loaded state — kept so the grid skeleton stays visible
  /// while new data is loading (prevents full-screen spinner flash).
  DailyRangeLoaded? _lastRangeState;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _anchorDate = DateTime(now.year, now.month, now.day);
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  int _visibleDays(BuildContext context) =>
      MediaQuery.of(context).size.width < 600 ? 3 : 7;

  List<Room> _rooms(BuildContext context) {
    final cfg = context.read<ConfigCubit>().state;
    return cfg is ConfigLoaded ? cfg.rooms : const [];
  }

  List<BookingSource> _sources(BuildContext context) {
    final cfg = context.read<ConfigCubit>().state;
    return cfg is ConfigLoaded ? cfg.bookingSources : const [];
  }

  void _load(BuildContext context) {
    context.read<DailyCubit>().loadRange(
          _anchorDate,
          _visibleDays(context),
          _rooms(context),
          _sources(context),
        );
  }

  void _shiftAnchor(BuildContext context, int days) {
    setState(() => _anchorDate = _anchorDate.add(Duration(days: days)));
    _load(context);
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DailyCubit>(
      create: (ctx) {
        final cubit = DailyCubit(DailyRepository());
        // Call the cubit directly — ctx is the *parent* context (above the
        // BlocProvider) so ctx.read<DailyCubit>() would throw.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            cubit.loadRange(
              _anchorDate,
              _visibleDays(ctx),
              _rooms(ctx),
              _sources(ctx),
            );
          }
        });
        return cubit;
      },
      child: BlocConsumer<DailyCubit, DailyState>(
        listener: _onState,
        builder: _buildBody,
      ),
    );
  }

  void _onState(BuildContext context, DailyState state) {
    if (state is DailyGroupFetched) {
      _openEditWizard(context, state.group);
    } else if (state is DailyError) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(state.message)));
    }
  }

  Future<void> _openEditWizard(
      BuildContext context, BookingGroup group) async {
    final cubit = context.read<DailyCubit>();
    final rooms = _rooms(context);
    final sources = _sources(context);
    final vd = _visibleDays(context);
    final anchor = _anchorDate;

    final saved = await context.push<bool>(
      '/booking/new',
      extra: BookingWizardExtras(existingGroup: group),
    );
    if ((saved ?? false) && mounted) {
      cubit.loadRange(anchor, vd, rooms, sources);
    }
  }

  Widget _buildBody(BuildContext context, DailyState state) {
    // Cache the last loaded state so we can show the skeleton during reload.
    if (state is DailyRangeLoaded) _lastRangeState = state;

    // Resolve which grid data to display and whether to show loading overlay.
    final DailyRangeLoaded? display = switch (state) {
      DailyRangeLoaded s => s,
      DailyGroupFetched s when s.previous is DailyRangeLoaded =>
        s.previous as DailyRangeLoaded,
      DailyLoading _ || DailyInitial _ => _lastRangeState,
      _ => null,
    };

    if (state is DailyError && display == null) {
      return Scaffold(body: _buildError(context, state.message));
    }

    if (display == null) {
      // First-ever load — no skeleton to show yet.
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bool isLoading =
        state is DailyLoading || state is DailyInitial;

    return _buildCalendar(context, display, isLoading: isLoading);
  }

  Widget _buildError(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _load(context),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ── calendar layout ────────────────────────────────────────────────────────

  Widget _buildCalendar(
    BuildContext context,
    DailyRangeLoaded state, {
    bool isLoading = false,
  }) {
    final colors = Theme.of(context).extension<AppColors>()!;
    // visibleDays from the current screen width — may differ from state if the
    // user rotated between loads; header always reflects current layout.
    final vd = _visibleDays(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── title + date-range navigation ──────────────────────────────
            _CalendarHeader(
              // Use _anchorDate (updates immediately on navigation tap).
              anchorDate: _anchorDate,
              visibleDays: vd,
              onPrev: () => _shiftAnchor(context, -vd),
              onNext: () => _shiftAnchor(context, vd),
              onDatePicked: (picked) {
                setState(() => _anchorDate = picked);
                _load(context);
              },
            ),
            // ── day column headers row ──────────────────────────────────────
            Container(
              height: _kHeaderH,
              color: colors.surface,
              child: Row(
                children: [
                  // corner "Rooms" label
                  SizedBox(
                    width: _kRoomColW,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Rooms',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.textHint,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (_, box) {
                        final colW = box.maxWidth / vd;
                        // Use _anchorDate so headers update immediately.
                        return Row(
                          children: List.generate(vd, (i) {
                            final day = _anchorDate.add(Duration(days: i));
                            return _DayHeader(
                              day: day,
                              width: colW,
                              colors: colors,
                            );
                          }),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: colors.border),
            // ── scrollable grid body (keeps skeleton while loading) ─────────
            Expanded(
              child: Stack(
                children: [
                  // White grid background
                  Positioned.fill(child: ColoredBox(color: colors.surface)),
                  SingleChildScrollView(
                    child: _CalendarGrid(
                      state: state,
                      colors: colors,
                      onTapBooking: (bookingGroupId) => context
                          .read<DailyCubit>()
                          .fetchGroupForDay(bookingGroupId),
                      onTapVacant: (room, date) async {
                        final cubit = context.read<DailyCubit>();
                        final rooms = _rooms(context);
                        final sources = _sources(context);
                        final saved = await context.push<bool>(
                          '/booking/new',
                          extra: BookingWizardExtras(
                            prefilledRoomId: room.id,
                            prefilledDate: date,
                          ),
                        );
                        if ((saved ?? false) && mounted) {
                          cubit.loadRange(_anchorDate, vd, rooms, sources);
                        }
                      },
                    ),
                  ),
                  // Translucent overlay + spinner while reloading
                  if (isLoading)
                    Positioned.fill(
                      child: ColoredBox(
                        color: colors.surface.withValues(alpha: 0.65),
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── CalendarHeader ───────────────────────────────────────────────────────────

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.anchorDate,
    required this.visibleDays,
    required this.onPrev,
    required this.onNext,
    required this.onDatePicked,
  });

  final DateTime anchorDate;
  final int visibleDays;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onDatePicked;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final endDate = anchorDate.add(Duration(days: visibleDays - 1));

    final startStr = DateFormat('MMM d').format(anchorDate);
    final endStr = anchorDate.month == endDate.month
        ? DateFormat('d').format(endDate)
        : DateFormat('MMM d').format(endDate);
    final rangeLabel = '$startStr – $endStr';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
      child: Row(
        children: [
          Text(
            'Daily',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const Spacer(),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.chevron_left,
                size: 20, color: colors.textSecondary),
            onPressed: onPrev,
          ),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: anchorDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                onDatePicked(
                    DateTime(picked.year, picked.month, picked.day));
              }
            },
            child: Text(
              rangeLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.chevron_right,
                size: 20, color: colors.textSecondary),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

// ─── DayHeader cell ──────────────────────────────────────────────────────────

class _DayHeader extends StatelessWidget {
  const _DayHeader({
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

// ─── CalendarGrid ─────────────────────────────────────────────────────────────

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
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

  /// Fractional column position of [localDt] relative to [anchorMidnight].
  ///
  /// `anchorMidnight + 0.0 days` = midnight of anchor date.
  /// `anchorMidnight + 1.0 days` = midnight of anchor + 1 day.
  /// Example: May 30 11:00 with anchor May 27 00:00 → 3.458.
  ///
  /// Uses `inMinutes / 1440` to avoid the integer truncation of `.inDays`.
  static double _colFrac(DateTime localDt, DateTime anchorMidnight) =>
      localDt.difference(anchorMidnight).inMinutes / (24.0 * 60.0);

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Sticky room name column ──────────────────────────────────────────
        SizedBox(
          width: _kRoomColW,
          child: Column(
            children: state.rooms.map((room) {
              final lanes = _computeLanes(
                  state.bookings.where((b) => b.room.id == room.id).toList());
              final rowH = _rowHeight(lanes);
              return _RoomLabel(room: room, height: rowH, colors: colors);
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
                  return _RoomRow(
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
      lanes.isEmpty ? _kLaneMinH : lanes.length * _kLaneH;
}

// ─── RoomLabel (sticky left cell) ────────────────────────────────────────────

class _RoomLabel extends StatelessWidget {
  const _RoomLabel({
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
      width: _kRoomColW,
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

// ─── RoomRow (one row of the grid for a single room) ─────────────────────────

class _RoomRow extends StatelessWidget {
  const _RoomRow({
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
      height: _kLaneMinH,
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
      height: _kLaneH,
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
      // _colFrac: fractional column offset from anchorDate midnight.
      startFrac = _CalendarGrid._colFrac(inDt,  anchorDate)
          .clamp(0.0, visibleDays.toDouble());
      endFrac   = _CalendarGrid._colFrac(outDt, anchorDate)
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

    final left  = startFrac * colWidth + _kSpanPad;
    final width = ((endFrac - startFrac) * colWidth - _kSpanPad * 2)
        .clamp(0.0, double.infinity);
    const top = (_kLaneH - _kSpanH) / 2.0; // vertically centred in lane

    return Positioned(
      left: left,
      width: width,
      top: top,
      height: _kSpanH,
      child: _BookingSpan(
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

// ─── BookingSpan ──────────────────────────────────────────────────────────────

class _BookingSpan extends StatelessWidget {
  const _BookingSpan({
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
    //   < _kChipMinForText  → coloured bar only (no text, no icon)
    //   < _kChipMinForAvatar → customer name only (no source avatar)
    //   ≥ _kChipMinForAvatar → full row: avatar + name
    final showText   = chipWidth >= _kChipMinForText;
    final showAvatar = chipWidth >= _kChipMinForAvatar &&
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
                    _SourceAvatar(name: booking.sourceName!),
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

// ─── SourceAvatar ─────────────────────────────────────────────────────────────
//
// Shows a known OTA logo (image asset) or a 2-letter fallback circle.

class _SourceAvatar extends StatelessWidget {
  const _SourceAvatar({required this.name});

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
