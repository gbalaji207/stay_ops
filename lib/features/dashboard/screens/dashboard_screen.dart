import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/room.dart';
import '../../config/config_cubit.dart';
import '../dashboard_cubit.dart';
import '../dashboard_repository.dart';
import '../models/dashboard_summary.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardPeriod _period = DashboardPeriod.today;
  DateTimeRange? _customRange;
  String? _selectedRoomId; // null = all rooms

  static final _amtFmt = NumberFormat('#,##0.##');
  static final _pctFmt = NumberFormat('0.0');

  void _load(BuildContext context) {
    final configState = context.read<ConfigCubit>().state;
    if (configState is! ConfigLoaded) return;
    _loadWithCubit(context.read<DashboardCubit>(),
        configState: configState);
  }

  void _loadWithCubit(DashboardCubit cubit, {ConfigLoaded? configState}) {
    // configState may be passed directly to avoid reading context after async gap
    ConfigLoaded? cfg = configState;
    if (cfg == null) return; // caller must supply config when context is unavailable

    cubit.load(
      period: _period,
      customRange: _customRange,
      roomId: _selectedRoomId,
      totalRooms: cfg.rooms.length,
      sourceNames: {for (final s in cfg.bookingSources) s.id: s.name},
      destinationNames: {
        for (final d in cfg.paymentDestinations) d.id: d.name
      },
    );
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final cubit = context.read<DashboardCubit>();
    final configState = context.read<ConfigCubit>().state as ConfigLoaded?;
    final colors = Theme.of(context).extension<AppColors>()!;
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _customRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: DateTime(now.year, now.month, now.day),
          ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: colors.accent,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _customRange = DateTimeRange(
          start: DateTime(
              picked.start.year, picked.start.month, picked.start.day),
          end: DateTime(picked.end.year, picked.end.month, picked.end.day),
        );
      });
      if (mounted) _loadWithCubit(cubit, configState: configState);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DashboardCubit>(
      create: (ctx) {
        final cubit = DashboardCubit(DashboardRepository());
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final configState = context.read<ConfigCubit>().state;
          if (configState is ConfigLoaded) {
            _loadWithCubit(cubit, configState: configState);
          }
        });
        return cubit;
      },
      child: BlocListener<ConfigCubit, ConfigState>(
        listenWhen: (_, curr) => curr is ConfigLoaded,
        listener: (context, _) {
          final cubit = context.read<DashboardCubit>();
          if (cubit.state is! DashboardInitial) _load(context);
        },
        child: BlocBuilder<DashboardCubit, DashboardState>(
          builder: (context, state) {
            final colors = Theme.of(context).extension<AppColors>()!;
            return Scaffold(
              backgroundColor: colors.background,
              body: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Text(
                        'Dashboard',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    // Filters
                    _buildFilters(context, colors),
                    const Divider(height: 1),
                    // Body
                    Expanded(
                      child: _buildBody(context, state, colors),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilters(BuildContext context, AppColors colors) {
    final configState = context.read<ConfigCubit>().state;
    final rooms = configState is ConfigLoaded ? configState.rooms : <Room>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          // Period dropdown
          Expanded(
            child: _FilterChip(
              colors: colors,
              label: _period == DashboardPeriod.custom && _customRange != null
                  ? '${DateFormat('d MMM').format(_customRange!.start)} – ${DateFormat('d MMM').format(_customRange!.end)}'
                  : _period.label,
              icon: Icons.date_range_rounded,
              onTap: () => _showPeriodSheet(context, colors),
            ),
          ),
          const SizedBox(width: 10),
          // Room dropdown
          Expanded(
            child: _FilterChip(
              colors: colors,
              label: _selectedRoomId == null
                  ? 'All Rooms'
                  : _roomName(rooms, _selectedRoomId!),
              icon: Icons.meeting_room_outlined,
              onTap: rooms.isEmpty
                  ? null
                  : () => _showRoomSheet(context, colors, rooms),
            ),
          ),
        ],
      ),
    );
  }

  String _roomName(List<Room> rooms, String id) {
    final idx = rooms.indexWhere((r) => r.id == id);
    return idx >= 0 ? rooms[idx].name : id;
  }

  void _showPeriodSheet(BuildContext context, AppColors colors) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  'Select Period',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              ...DashboardPeriod.values.map((p) => ListTile(
                    title: Text(
                      p.label,
                      style: TextStyle(
                        color: _period == p
                            ? colors.accent
                            : colors.textPrimary,
                        fontWeight: _period == p
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: _period == p
                        ? Icon(Icons.check_rounded,
                            color: colors.accent, size: 18)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      if (p == DashboardPeriod.custom) {
                        setState(() => _period = p);
                        _pickCustomRange(context);
                      } else {
                        setState(() {
                          _period = p;
                          _customRange = null;
                        });
                        _load(context);
                      }
                    },
                  )),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showRoomSheet(
      BuildContext context, AppColors colors, List<Room> rooms) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.5,
            minChildSize: 0.3,
            maxChildSize: 0.85,
            builder: (_, scrollController) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Text(
                      'Select Room',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  Divider(height: 1, color: colors.border),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        // All rooms option
                        ListTile(
                          title: Text(
                            'All Rooms',
                            style: TextStyle(
                              color: _selectedRoomId == null
                                  ? colors.accent
                                  : colors.textPrimary,
                              fontWeight: _selectedRoomId == null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          trailing: _selectedRoomId == null
                              ? Icon(Icons.check_rounded,
                                  color: colors.accent, size: 18)
                              : null,
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            setState(() => _selectedRoomId = null);
                            _load(context);
                          },
                        ),
                        ...rooms.map((r) => ListTile(
                              title: Text(
                                r.name,
                                style: TextStyle(
                                  color: _selectedRoomId == r.id
                                      ? colors.accent
                                      : colors.textPrimary,
                                  fontWeight: _selectedRoomId == r.id
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              trailing: _selectedRoomId == r.id
                                  ? Icon(Icons.check_rounded,
                                      color: colors.accent, size: 18)
                                  : null,
                              onTap: () {
                                Navigator.pop(sheetCtx);
                                setState(() => _selectedRoomId = r.id);
                                _load(context);
                              },
                            )),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBody(
      BuildContext context, DashboardState state, AppColors colors) {
    if (state is DashboardInitial || state is DashboardLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is DashboardError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 40, color: colors.textHint),
              const SizedBox(height: 12),
              Text(
                state.message,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary),
              ),
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
    if (state is DashboardLoaded) {
      return RefreshIndicator(
        onRefresh: () async => _load(context),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // Metric cards row
            _buildMetricCards(state.summary, colors),
            const SizedBox(height: 20),
            // Revenue summary section
            _buildSectionLabel('Revenue Summary', colors),
            const SizedBox(height: 8),
            _buildRevenueSummary(state.summary, colors),
            const SizedBox(height: 20),
            // Booking source section
            _buildSectionLabel('Booking Sources', colors),
            const SizedBox(height: 8),
            _buildSourceTable(state.summary.bySource, colors),
            const SizedBox(height: 20),
            // Payment details section
            _buildSectionLabel('Payment Accounts', colors),
            const SizedBox(height: 8),
            _buildDestinationTable(state.summary.byDestination, colors),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildMetricCards(DashboardSummary summary, AppColors colors) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            colors: colors,
            label: 'Occupancy',
            value: '${_pctFmt.format(summary.occupancyPct)}%',
            icon: Icons.bed_rounded,
            color: colors.accent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            colors: colors,
            label: 'Revenue',
            value: '₹${_amtFmt.format(summary.grossRevenue)}',
            icon: Icons.trending_up_rounded,
            color: colors.success,
            hint: 'Gross',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            colors: colors,
            label: 'Receivables',
            value: '₹${_amtFmt.format(summary.pendingReceivables)}',
            icon: Icons.pending_actions_rounded,
            color: colors.warning,
            hint: 'Pending',
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueSummary(DashboardSummary summary, AppColors colors) {
    final rows = [
      ('Total Bookings', '${summary.totalBookings}'),
      (
        'Payments Collected',
        '₹${_amtFmt.format(summary.paymentsCollected)}'
      ),
      ('ADR', '₹${_amtFmt.format(summary.adr)}'),
      ('RevPAR', '₹${_amtFmt.format(summary.revpar)}'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final (label, value) = entry.value;
          final isLast = entry.key == rows.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 11),
                child: Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast) Divider(height: 1, color: colors.border),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSourceTable(
      List<SourceBreakdown> items, AppColors colors) {
    if (items.isEmpty) {
      return _emptyNote('No bookings in this period', colors);
    }
    return _BreakdownTable(
      colors: colors,
      headers: const ['Source', 'Revenue', 'Bookings'],
      rows: items
          .map((s) => [
                s.sourceName,
                '₹${_amtFmt.format(s.revenue)}',
                '${s.bookingCount}',
              ])
          .toList(),
    );
  }

  Widget _buildDestinationTable(
      List<DestinationBreakdown> items, AppColors colors) {
    if (items.isEmpty) {
      return _emptyNote('No payments collected in this period', colors);
    }
    return _BreakdownTable(
      colors: colors,
      headers: const ['Account', 'Collected', 'Bookings'],
      rows: items
          .map((d) => [
                d.destinationName,
                '₹${_amtFmt.format(d.revenue)}',
                '${d.bookingCount}',
              ])
          .toList(),
    );
  }

  Widget _buildSectionLabel(String label, AppColors colors) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: colors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _emptyNote(String text, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontStyle: FontStyle.italic,
          color: colors.textHint,
        ),
      ),
    );
  }
}

// ── Filter Chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.colors,
    required this.label,
    required this.icon,
    this.onTap,
  });

  final AppColors colors;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: colors.accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_drop_down_rounded,
                size: 18, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ── Metric Card ───────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.colors,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.hint,
  });

  final AppColors colors;
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (hint != null)
            Text(
              hint!,
              style: TextStyle(fontSize: 10, color: colors.textHint),
            ),
        ],
      ),
    );
  }
}

// ── Breakdown Table ───────────────────────────────────────────────────────────

class _BreakdownTable extends StatelessWidget {
  const _BreakdownTable({
    required this.colors,
    required this.headers,
    required this.rows,
  });

  final AppColors colors;
  final List<String> headers;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: _TableRow(
              cells: headers,
              colors: colors,
              isHeader: true,
            ),
          ),
          Divider(height: 1, color: colors.border),
          // Data rows
          ...rows.asMap().entries.map((entry) {
            final isLast = entry.key == rows.length - 1;
            return Column(
              children: [
                _TableRow(
                  cells: entry.value,
                  colors: colors,
                  isHeader: false,
                ),
                if (!isLast) Divider(height: 1, color: colors.border),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.cells,
    required this.colors,
    required this.isHeader,
  });

  final List<String> cells;
  final AppColors colors;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: cells.asMap().entries.map((entry) {
          final isFirst = entry.key == 0;
          return Expanded(
            flex: isFirst ? 3 : 2,
            child: Text(
              entry.value,
              textAlign: isFirst ? TextAlign.left : TextAlign.right,
              style: TextStyle(
                fontSize: isHeader ? 11 : 13,
                fontWeight:
                    isHeader ? FontWeight.w600 : FontWeight.w400,
                color: isHeader ? colors.textSecondary : colors.textPrimary,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
