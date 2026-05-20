import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/booking_group.dart';
import '../../shared/models/room.dart';
import '../booking/wizard/booking_wizard_extras.dart';
import '../config/config_cubit.dart';
import 'day_stats.dart';
import 'monthly_cubit.dart';
import 'monthly_repository.dart';

class MonthlyScreen extends StatefulWidget {
  const MonthlyScreen({super.key});

  @override
  State<MonthlyScreen> createState() => _MonthlyScreenState();
}

class _MonthlyScreenState extends State<MonthlyScreen> {
  late int _currentYear;
  late int _currentMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentYear = now.year;
    _currentMonth = now.month;
  }

  List<Room> _rooms(BuildContext context) {
    final config = context.read<ConfigCubit>().state;
    return config is ConfigLoaded ? config.rooms : const [];
  }

  void _loadMonth(BuildContext context, int year, int month) {
    setState(() {
      _currentYear = year;
      _currentMonth = month;
    });
    context.read<MonthlyCubit>().load(year, month, _rooms(context));
  }

  void _loadPrevMonth(BuildContext context) {
    if (_currentMonth == 1) {
      _loadMonth(context, _currentYear - 1, 12);
    } else {
      _loadMonth(context, _currentYear, _currentMonth - 1);
    }
  }

  void _loadNextMonth(BuildContext context) {
    if (_currentMonth == 12) {
      _loadMonth(context, _currentYear + 1, 1);
    } else {
      _loadMonth(context, _currentYear, _currentMonth + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MonthlyCubit>(
      create: (ctx) {
        final cubit = MonthlyCubit(MonthlyRepository());
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) cubit.load(_currentYear, _currentMonth, _rooms(ctx));
        });
        return cubit;
      },
      child: BlocConsumer<MonthlyCubit, MonthlyState>(
        listener: _onState,
        builder: _buildBody,
      ),
    );
  }

  void _onState(BuildContext context, MonthlyState state) {
    if (state is MonthlyGroupFetched) {
      _openEditSheet(context, state.group, state.previous);
    }
  }

  Future<void> _openEditSheet(
    BuildContext context,
    BookingGroup group,
    MonthlyLoaded previous,
  ) async {
    final cubit = context.read<MonthlyCubit>();
    final rooms = _rooms(context);
    final saved = await context.push<bool>(
      '/booking/new',
      extra: BookingWizardExtras(existingGroup: group),
    );
    if ((saved ?? false) && mounted) cubit.load(_currentYear, _currentMonth, rooms);
  }

  Widget _buildBody(BuildContext context, MonthlyState state) {
    if (state is MonthlyInitial || state is MonthlyLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (state is MonthlyError) {
      return Scaffold(body: _buildError(context, state.message));
    }
    if (state is MonthlyLoaded) return _buildLoaded(context, state);
    if (state is MonthlyGroupFetched) return _buildLoaded(context, state.previous);
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
              onPressed: () => context
                  .read<MonthlyCubit>()
                  .load(_currentYear, _currentMonth, _rooms(context)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoaded(BuildContext context, MonthlyLoaded state) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, state, colors),
              _buildStatsBar(state, colors),
              _buildRoomFilterPills(context, state, colors),
              const SizedBox(height: 8),
              _buildHeatmapCalendar(context, state, colors),
              _buildHeatmapLegend(colors),
              if (state.selectedDay != null)
                _buildDayDetailCard(context, state, colors),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(
    BuildContext context,
    MonthlyLoaded state,
    AppColors colors,
  ) {
    final label =
        DateFormat('MMMM yyyy').format(DateTime(state.year, state.month));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
      child: Row(
        children: [
          Text(
            'Monthly',
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
            onPressed: () => _loadPrevMonth(context),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colors.textPrimary,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.chevron_right, size: 20, color: colors.textSecondary),
            onPressed: () => _loadNextMonth(context),
          ),
        ],
      ),
    );
  }

  // ─── Stats bar ──────────────────────────────────────────────────────────────

  Widget _buildStatsBar(MonthlyLoaded state, AppColors colors) {
    final revenue = _fmtRevenue(state.monthRevenue);
    final occ = '${state.avgOccupancyPct.round()}%';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          _StatChip(label: 'Month Revenue', value: revenue, colors: colors),
          const SizedBox(width: 8),
          _StatChip(label: 'Avg Occupancy', value: occ, colors: colors),
        ],
      ),
    );
  }

  String _fmtRevenue(double amount) {
    if (amount >= 1000) return '₹${(amount / 1000).round()}k';
    return '₹${amount.toInt()}';
  }

  // ─── Room filter pills ───────────────────────────────────────────────────────

  Widget _buildRoomFilterPills(
    BuildContext context,
    MonthlyLoaded state,
    AppColors colors,
  ) {
    final rooms = _rooms(context);
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: rooms.length + 1,
        separatorBuilder: (_, i) => const SizedBox(width: 8),
        itemBuilder: (ctx, index) {
          if (index == 0) {
            return _FilterPill(
              label: 'All',
              selected: state.selectedRoomId == null,
              colors: colors,
              onTap: () => context.read<MonthlyCubit>().selectRoom(null),
            );
          }
          final room = rooms[index - 1];
          return _FilterPill(
            label: room.name,
            selected: state.selectedRoomId == room.id,
            colors: colors,
            onTap: () => context.read<MonthlyCubit>().selectRoom(room.id),
          );
        },
      ),
    );
  }

  // ─── Heatmap calendar ───────────────────────────────────────────────────────

  Widget _buildHeatmapCalendar(
    BuildContext context,
    MonthlyLoaded state,
    AppColors colors,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          _buildDayHeaderRow(colors),
          const SizedBox(height: 4),
          ..._buildWeekRows(context, state, colors),
        ],
      ),
    );
  }

  Widget _buildDayHeaderRow(AppColors colors) {
    const labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Row(
      children: labels
          .map(
            (l) => Expanded(
              child: Center(
                child: Text(
                  l,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  List<Widget> _buildWeekRows(
    BuildContext context,
    MonthlyLoaded state,
    AppColors colors,
  ) {
    final offset = _sundayFirstOffset(state.year, state.month);
    final daysInMonth = DateTime(state.year, state.month + 1, 0).day;
    final totalCells = offset + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    final today = DateTime.now();
    final isCurrentMonth =
        today.year == state.year && today.month == state.month;

    return List.generate(rowCount, (rowIdx) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          children: List.generate(7, (colIdx) {
            final cellIdx = rowIdx * 7 + colIdx;
            final day = cellIdx - offset + 1;
            if (day < 1 || day > daysInMonth) {
              return const Expanded(child: SizedBox());
            }
            final stats = state.dayStats[day];
            final isToday = isCurrentMonth && day == today.day;
            final isSelected = state.selectedDay == day;
            return Expanded(
              child: _HeatmapCell(
                day: day,
                stats: stats,
                isToday: isToday,
                isSelected: isSelected,
                colors: colors,
                isDark: Theme.of(context).brightness == Brightness.dark,
                onTap: () =>
                    context.read<MonthlyCubit>().selectDate(day),
              ),
            );
          }),
        ),
      );
    });
  }

  // Sunday-first weekday offset.
  // Dart weekday: Mon=1 .. Sun=7.  Sun(7)%7=0, Mon(1)%7=1 .. Sat(6)%7=6.
  int _sundayFirstOffset(int year, int month) =>
      DateTime(year, month, 1).weekday % 7;

  // ─── Heatmap legend ─────────────────────────────────────────────────────────

  Widget _buildHeatmapLegend(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Text(
            'Low',
            style: TextStyle(fontSize: 10, color: colors.textSecondary),
          ),
          const SizedBox(width: 6),
          for (int i = 0; i < 5; i++) ...[
            _LegendBox(level: i, colors: colors),
            const SizedBox(width: 3),
          ],
          const SizedBox(width: 3),
          Text(
            'High',
            style: TextStyle(fontSize: 10, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ─── Day detail card ────────────────────────────────────────────────────────

  Widget _buildDayDetailCard(
    BuildContext context,
    MonthlyLoaded state,
    AppColors colors,
  ) {
    final day = state.selectedDay!;
    final stats = state.dayStats[day];
    final date = DateTime(state.year, state.month, day);
    final dateLabel = DateFormat('d MMMM').format(date);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: stats == null || stats.rooms.isEmpty
            ? _buildEmptyDetailState(dateLabel, colors)
            : _buildDetailRows(context, state, stats, dateLabel, date, colors),
      ),
    );
  }

  Widget _buildEmptyDetailState(String dateLabel, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'No bookings on $dateLabel',
        style: TextStyle(
          fontSize: 13,
          color: colors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildDetailRows(
    BuildContext context,
    MonthlyLoaded state,
    DayStats stats,
    String dateLabel,
    DateTime date,
    AppColors colors,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: date label + total revenue
        Row(
          children: [
            Text(
              dateLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              '₹${stats.revenue.toInt()}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Room rows
        ...stats.rooms.map(
          (row) => _DayRoomRow(
            row: row,
            colors: colors,
            onTap: () => context
                .read<MonthlyCubit>()
                .fetchGroupForDay(row.roomId, date),
          ),
        ),
      ],
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

// ─── Room filter pill ─────────────────────────────────────────────────────────

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? colors.accent : colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: selected ? null : Border.all(color: colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : colors.textPrimary,
          ),
        ),
      ),
      ),
    );
  }
}

// ─── Heatmap cell ─────────────────────────────────────────────────────────────

class _HeatmapCell extends StatelessWidget {
  const _HeatmapCell({
    required this.day,
    required this.stats,
    required this.isToday,
    required this.isSelected,
    required this.colors,
    required this.isDark,
    required this.onTap,
  });

  final int day;
  final DayStats? stats;
  final bool isToday;
  final bool isSelected;
  final AppColors colors;
  final bool isDark;
  final VoidCallback onTap;

  // Level-0 backgrounds are not covered by the token set.
  static const _level0Light = Color(0xFFF0F0F5);
  static const _level0Dark = Color(0xFF131520);

  static const _levelAlphas = [0.0, 0.20, 0.38, 0.60, 0.82];

  Color _cellBg(int level) {
    if (level == 0) return isDark ? _level0Dark : _level0Light;
    return colors.accent.withValues(alpha: _levelAlphas[level]);
  }

  @override
  Widget build(BuildContext context) {
    final level = stats?.revenueLevel ?? 0;
    final bg = _cellBg(level);
    final useWhiteText = level >= 3;

    return AspectRatio(
      aspectRatio: 1.0,
      child: Padding(
        padding: const EdgeInsets.all(1.5),
        child: GestureDetector(
          onTap: onTap,
          child: Stack(
            children: [
              // Cell background with optional today border
              Container(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(4),
                  border: isToday
                      ? Border.all(color: colors.accent, width: 1.5)
                      : null,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: useWhiteText
                              ? Colors.white
                              : colors.textPrimary,
                        ),
                      ),
                      if (level > 0 && stats != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          stats!.revenueLabel,
                          style: TextStyle(
                            fontSize: 9,
                            color: useWhiteText
                                ? Colors.white.withValues(alpha: 0.85)
                                : colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Selected ring overlay — drawn on top of today ring so both show
              if (isSelected)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border:
                            Border.all(color: colors.warning, width: 1.5),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Legend box ───────────────────────────────────────────────────────────────

class _LegendBox extends StatelessWidget {
  const _LegendBox({required this.level, required this.colors});

  final int level;
  final AppColors colors;

  static const _levelAlphas = [0.0, 0.20, 0.38, 0.60, 0.82];
  static const _level0Light = Color(0xFFF0F0F5);
  static const _level0Dark = Color(0xFF131520);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg;
    if (level == 0) {
      bg = isDark ? _level0Dark : _level0Light;
    } else {
      bg = colors.accent.withValues(alpha: _levelAlphas[level]);
    }
    return Container(
      width: 16,
      height: 12,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ─── Day detail room row ──────────────────────────────────────────────────────

class _DayRoomRow extends StatelessWidget {
  const _DayRoomRow({
    required this.row,
    required this.colors,
    required this.onTap,
  });

  final DayRoomRow row;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sourceTypeLabel = [
      if (row.sourceName != null) row.sourceName!,
      if (row.typeName != null) row.typeName!,
    ].join(' · ');

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.roomName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (sourceTypeLabel.isNotEmpty)
                    Text(
                      sourceTypeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${row.perNightAmount.toInt()}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  row.paymentReceived ? 'Received' : 'Pending',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: row.paymentReceived ? colors.success : colors.warning,
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
