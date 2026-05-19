import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/booking_group.dart';
import '../../shared/models/booking_source.dart';
import '../../shared/models/room.dart';
import '../booking/booking_form.dart';
import '../booking/wizard/booking_wizard_extras.dart';
import '../config/config_cubit.dart';
import 'daily_cubit.dart';
import 'daily_repository.dart';
import 'room_day_status.dart';

class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  List<Room> _rooms(BuildContext context) {
    final config = context.read<ConfigCubit>().state;
    return config is ConfigLoaded ? config.rooms : const [];
  }

  List<BookingSource> _sources(BuildContext context) {
    final config = context.read<ConfigCubit>().state;
    return config is ConfigLoaded ? config.bookingSources : const [];
  }

  void _loadDate(BuildContext context, DateTime date) {
    setState(() => _selectedDate = date);
    context.read<DailyCubit>().load(date, _rooms(context), _sources(context));
  }

  void _reload(BuildContext context) {
    context
        .read<DailyCubit>()
        .load(_selectedDate, _rooms(context), _sources(context));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DailyCubit>(
      create: (ctx) {
        final cubit = DailyCubit(DailyRepository());
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) cubit.load(_selectedDate, _rooms(ctx), _sources(ctx));
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
      _openEditSheet(context, state.group);
    } else if (state is DailyError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.message)),
      );
    }
  }

  Future<void> _openEditSheet(BuildContext context, BookingGroup group) async {
    final cubit = context.read<DailyCubit>();
    final rooms = _rooms(context);
    final sources = _sources(context);
    final saved = await showBookingFormSheet(context, existingGroup: group);
    if (saved && mounted) cubit.load(_selectedDate, rooms, sources);
  }

  Widget _buildBody(BuildContext context, DailyState state) {
    if (state is DailyInitial || state is DailyLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (state is DailyError) {
      return Scaffold(body: _buildError(context, state.message));
    }
    if (state is DailyLoaded) return _buildLoaded(context, state);
    if (state is DailyGroupFetched) return _buildLoaded(context, state.previous);
    return const Scaffold(body: SizedBox.shrink());
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
              onPressed: () => _reload(context),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoaded(BuildContext context, DailyLoaded state) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, state.date),
            _buildStatsBar(context, state.rooms),
            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: state.rooms.length,
                itemBuilder: (context, index) =>
                    _buildRoomCard(context, state.rooms[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, DateTime date) {
    final colors = Theme.of(context).extension<AppColors>()!;
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
            icon: Icon(Icons.chevron_left, size: 20, color: colors.textSecondary),
            onPressed: () =>
                _loadDate(context, date.subtract(const Duration(days: 1))),
          ),
          GestureDetector(
            onTap: () async {
              final cubit = context.read<DailyCubit>();
              final rooms = _rooms(context);
              final sources = _sources(context);
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null && mounted) {
                setState(() => _selectedDate = picked);
                cubit.load(picked, rooms, sources);
              }
            },
            child: Text(
              DateFormat('d MMM yyyy').format(date),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.chevron_right, size: 20, color: colors.textSecondary),
            onPressed: () =>
                _loadDate(context, date.add(const Duration(days: 1))),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(BuildContext context, List<RoomDayStatus> rooms) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final booked = rooms.where((r) => r.isBooked).toList();
    final revenue =
        booked.fold<double>(0, (sum, r) => sum + (r.perNightAmount ?? 0));
    final occupiedCount = booked.length;
    final occupancyPct =
        rooms.isEmpty ? 0 : (occupiedCount / rooms.length * 100).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          _StatChip(
            label: 'Revenue',
            value: _fmtRevenue(revenue),
            colors: colors,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Occupied',
            value: '$occupiedCount / ${rooms.length}',
            colors: colors,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Occupancy',
            value: '$occupancyPct%',
            colors: colors,
          ),
        ],
      ),
    );
  }

  String _fmtRevenue(double amount) {
    if (amount >= 1000) {
      final k = amount / 1000;
      final rounded = (k * 10).round() / 10;
      return rounded == rounded.truncateToDouble()
          ? '₹${rounded.toInt()}k'
          : '₹${rounded}k';
    }
    return '₹${amount.toInt()}';
  }

  Widget _buildRoomCard(BuildContext context, RoomDayStatus status) {
    if (status.isBooked) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _BookedCard(
          status: status,
          onTap: () => context
              .read<DailyCubit>()
              .fetchGroupForDay(status.room.id, _selectedDate),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _VacantCard(
        status: status,
        onTap: () async {
          final cubit = context.read<DailyCubit>();
          final rooms = _rooms(context);
          final sources = _sources(context);
          final saved = await context.push<bool>(
            '/booking/new',
            extra: BookingWizardExtras(
              prefilledRoomId: status.room.id,
              prefilledDate: _selectedDate,
            ),
          );
          if ((saved ?? false) && mounted) {
            cubit.load(_selectedDate, rooms, sources);
          }
        },
      ),
    );
  }
}

// ─── Stat chip ────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.colors,
  });

  final String label;
  final String value;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Booked card ─────────────────────────────────────────────────────────────

class _BookedCard extends StatelessWidget {
  const _BookedCard({required this.status, required this.onTap});

  final RoomDayStatus status;
  final VoidCallback onTap;

  static final _amtFmt = NumberFormat('#,##0.##');

  /// "May 13 → 16 · 3 nights"  (same month)
  /// "May 31 → Jun 1 · 1 night" (cross-month)
  static String _dateRange(DateTime checkIn, DateTime checkOut, int nights) {
    final inFmt = DateFormat('MMM d');
    final outSameMonth = checkIn.month == checkOut.month;
    final outStr = outSameMonth
        ? DateFormat('d').format(checkOut)
        : DateFormat('MMM d').format(checkOut);
    final label = nights == 1 ? 'night' : 'nights';
    return '${inFmt.format(checkIn)} → $outStr · $nights $label';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final checkIn = status.checkIn!;
    final checkOut = status.checkOut!;
    final nights = status.nightCount ?? 0;
    final amount = status.perNightAmount ?? 0;
    final paid = status.paymentReceived ?? false;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: room name + "Booked" pill
            Row(
              children: [
                Expanded(
                  child: Text(
                    status.room.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                _Pill(
                  label: 'Booked',
                  bg: colors.successSubtle,
                  fg: colors.success,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 2: date range (left) + amount (right)
            Row(
              children: [
                Expanded(
                  child: Text(
                    _dateRange(checkIn, checkOut, nights),
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ),
                Text(
                  '₹${_amtFmt.format(amount)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 3: source chip (left) + payment text (right)
            Row(
              children: [
                if (status.sourceName != null) ...[
                  _Pill(
                    label: status.sourceName!,
                    bg: colors.accentSubtle,
                    fg: colors.accent,
                  ),
                ],
                const Spacer(),
                Text(
                  paid ? 'Received' : 'Pending',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: paid ? colors.success : colors.warning,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Vacant card ─────────────────────────────────────────────────────────────

class _VacantCard extends StatelessWidget {
  const _VacantCard({required this.status, required this.onTap});

  final RoomDayStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.danger.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    status.room.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                _Pill(
                  label: 'Vacant',
                  bg: colors.dangerSubtle,
                  fg: colors.danger,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tap to add booking',
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: colors.textHint,
                    ),
                  ),
                ),
                Text(
                  '—',
                  style:
                      TextStyle(fontSize: 15, color: colors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pill ─────────────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w500),
      ),
    );
  }
}
