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
import 'calendar_grid.dart';
import 'daily_cubit.dart';
import 'daily_repository.dart';

// ─── DailyScreen ─────────────────────────────────────────────────────────────

class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key, this.headerToggle});

  /// Optional toggle widget injected by [BookingsScreen].
  /// When present it replaces the "Daily" title in the header row.
  final Widget? headerToggle;

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
              titleWidget: widget.headerToggle,
            ),
            // ── day column headers row ──────────────────────────────────────
            Container(
              height: kCalHeaderH,
              color: colors.surface,
              child: Row(
                children: [
                  // corner "Rooms" label
                  SizedBox(
                    width: kCalRoomColW,
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
                            return CalendarDayHeader(
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
                    child: CalendarGrid(
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
    this.titleWidget,
  });

  final DateTime anchorDate;
  final int visibleDays;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onDatePicked;
  /// When provided (injected from BookingsScreen) replaces the "Daily" label.
  final Widget? titleWidget;

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
          titleWidget ??
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

