import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/room_category_summary.dart';
import '../config/config_cubit.dart';
import 'reports_cubit.dart';
import 'reports_repository.dart';

class BookingTypeReportScreen extends StatelessWidget {
  const BookingTypeReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ReportsCubit(ReportsRepository()),
      child: const _BookingTypeReportView(),
    );
  }
}

class _BookingTypeReportView extends StatefulWidget {
  const _BookingTypeReportView();

  @override
  State<_BookingTypeReportView> createState() => _BookingTypeReportViewState();
}

class _BookingTypeReportViewState extends State<_BookingTypeReportView> {
  late DateTime _dateFrom;
  late DateTime _dateTo;
  List<String>? _selectedRoomIds;
  String? _dateError;

  static final _dateFmt = DateFormat('d MMM yyyy');
  static final _amountFmt = NumberFormat('#,##0');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateFrom = DateTime(now.year, now.month, 1);
    _dateTo = DateTime(now.year, now.month, now.day);
    _load();
  }

  void _load() {
    if (_dateFrom.isAfter(_dateTo)) {
      setState(() => _dateError = 'End date must be after start date');
      return;
    }
    setState(() => _dateError = null);
    context.read<ReportsCubit>().loadBookingTypeReport(
          dateRange: DateTimeRange(start: _dateFrom, end: _dateTo),
          roomIds: _selectedRoomIds,
        );
  }

  Future<void> _pickDate(bool isFrom) async {
    final initial = isFrom ? _dateFrom : _dateTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
      } else {
        _dateTo = picked;
      }
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final configState = context.watch<ConfigCubit>().state;
    final rooms = configState is ConfigLoaded ? configState.rooms : [];

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.nav,
        elevation: 0,
        leading: BackButton(color: colors.textPrimary),
        title: Text(
          'Booking Type Report',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: colors.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: colors.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _DatePill(
                        label: _dateFmt.format(_dateFrom),
                        colors: colors,
                        onTap: () => _pickDate(true),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '→',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    ),
                    Expanded(
                      child: _DatePill(
                        label: _dateFmt.format(_dateTo),
                        colors: colors,
                        onTap: () => _pickDate(false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RoomFilterPill(
                      rooms: rooms,
                      selectedIds: _selectedRoomIds,
                      colors: colors,
                      onChanged: (ids) {
                        setState(() =>
                            _selectedRoomIds = ids.isEmpty ? null : ids);
                        _load();
                      },
                    ),
                  ],
                ),
                if (_dateError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _dateError!,
                    style: TextStyle(fontSize: 12, color: colors.danger),
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          Expanded(
            child: BlocBuilder<ReportsCubit, ReportsState>(
              builder: (context, state) {
                if (state is BookingTypeReportLoading ||
                    state is ReportsInitial) {
                  return _ShimmerSkeleton(colors: colors);
                }
                if (state is BookingTypeReportError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        state.message,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (state is BookingTypeReportLoaded) {
                  if (state.roomRows.isEmpty) {
                    return Center(
                      child: Text(
                        'No bookings found for the selected period.',
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: colors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return _TableReportBody(
                    roomRows: state.roomRows,
                    overallTotals: state.overallTotals,
                    grandTotal: state.grandTotal,
                    colors: colors,
                    amountFmt: _amountFmt,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({
    required this.label,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: colors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _RoomFilterPill extends StatelessWidget {
  const _RoomFilterPill({
    required this.rooms,
    required this.selectedIds,
    required this.colors,
    required this.onChanged,
  });

  final List rooms;
  final List<String>? selectedIds;
  final AppColors colors;
  final ValueChanged<List<String>> onChanged;

  String get _label {
    if (selectedIds == null || selectedIds!.isEmpty) return 'All Rooms';
    if (selectedIds!.length == 1) {
      final idx = rooms.indexWhere((r) => r.id == selectedIds!.first);
      return idx != -1 ? rooms[idx].name as String : '1 Room';
    }
    return '${selectedIds!.length} Rooms';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await showModalBottomSheet<List<String>>(
          context: context,
          builder: (_) => _RoomPickerSheet(
            rooms: rooms,
            selectedIds: selectedIds ?? [],
            colors: colors,
          ),
        );
        if (result != null) onChanged(result);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colors.accentSubtle,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _label,
              style: TextStyle(
                fontSize: 13,
                color: colors.accent,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: colors.accent),
          ],
        ),
      ),
    );
  }
}

class _RoomPickerSheet extends StatefulWidget {
  const _RoomPickerSheet({
    required this.rooms,
    required this.selectedIds,
    required this.colors,
  });

  final List rooms;
  final List<String> selectedIds;
  final AppColors colors;

  @override
  State<_RoomPickerSheet> createState() => _RoomPickerSheetState();
}

class _RoomPickerSheetState extends State<_RoomPickerSheet> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 28,
            height: 3,
            decoration: BoxDecoration(
              color: colors.sheetHandle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Filter by Room',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _selected = []),
                  child: Text(
                    'All',
                    style: TextStyle(color: colors.accent),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: widget.rooms.map((room) {
                final isSelected = _selected.contains(room.id);
                return CheckboxListTile(
                  value: isSelected,
                  activeColor: colors.accent,
                  title: Text(
                    room.name,
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.textPrimary,
                    ),
                  ),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selected.add(room.id);
                      } else {
                        _selected.remove(room.id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_selected),
                child: const Text('Apply'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableReportBody extends StatelessWidget {
  const _TableReportBody({
    required this.roomRows,
    required this.overallTotals,
    required this.grandTotal,
    required this.colors,
    required this.amountFmt,
  });

  final List<RoomCategorySummary> roomRows;
  final List<CategoryTotal> overallTotals;
  final double grandTotal;
  final AppColors colors;
  final NumberFormat amountFmt;

  static const double _roomColW = 110.0;
  static const double _dataColW = 100.0;
  static const double _rowH = 44.0;

  String _fmt(double v) => '₹${amountFmt.format(v)}';
  String _fmtOrDash(double? v) => (v == null || v == 0) ? '—' : _fmt(v);

  @override
  Widget build(BuildContext context) {
    final bdr = BorderSide(color: colors.border);
    final amts = {
      for (final r in roomRows)
        r.roomId: {for (final c in r.byCategory) c.categoryId: c.amount},
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sticky Room column
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _lc('ROOM', bdr, isHeader: true),
                for (final r in roomRows) _lc(r.roomName, bdr),
                _lc('TOTAL', bdr, isFoot: true),
              ],
            ),
            // Horizontally scrollable data columns
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      for (final col in overallTotals)
                        _dc(col.categoryName ?? 'Not specified', bdr,
                            isHeader: true),
                      _dc('TOTAL', bdr, isHeader: true, isTotalCol: true),
                    ]),
                    for (final r in roomRows)
                      Row(children: [
                        for (final col in overallTotals)
                          _dc(_fmtOrDash(amts[r.roomId]?[col.categoryId]),
                              bdr),
                        _dc(_fmt(r.roomTotal), bdr,
                            isBold: true, isTotalCol: true),
                      ]),
                    Row(children: [
                      for (final col in overallTotals)
                        _dc(_fmt(col.amount), bdr,
                            isFoot: true, isBold: true),
                      _dc(_fmt(grandTotal), bdr,
                          isFoot: true, isTotalCol: true, isBold: true),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Sticky label cell (Room column)
  Widget _lc(
    String text,
    BorderSide bdr, {
    bool isHeader = false,
    bool isFoot = false,
  }) {
    return Container(
      width: _roomColW,
      height: _rowH,
      decoration: BoxDecoration(
        color: (isHeader || isFoot) ? colors.background : null,
        border: Border(
          bottom: isFoot ? BorderSide.none : bdr,
          right: bdr,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          fontSize: (isHeader || isFoot) ? 11 : 13,
          fontWeight: (isHeader || isFoot) ? FontWeight.w600 : FontWeight.w400,
          color: isHeader ? colors.textSecondary : colors.textPrimary,
          letterSpacing: (isHeader || isFoot) ? 0.6 : 0,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  // Data cell (category columns + total column)
  Widget _dc(
    String text,
    BorderSide bdr, {
    bool isHeader = false,
    bool isFoot = false,
    bool isTotalCol = false,
    bool isBold = false,
  }) {
    final isAccent = isFoot && isTotalCol;
    return Container(
      width: _dataColW,
      height: _rowH,
      decoration: BoxDecoration(
        color: (isHeader || isFoot || isTotalCol) ? colors.background : null,
        border: Border(bottom: isFoot ? BorderSide.none : bdr),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerRight,
      child: Text(
        text,
        style: TextStyle(
          fontSize: isHeader ? 11 : 13,
          fontWeight: (isHeader || isBold) ? FontWeight.w600 : FontWeight.w400,
          color: isAccent
              ? colors.accent
              : isHeader
                  ? colors.textSecondary
                  : colors.textPrimary,
          letterSpacing: isHeader ? 0.3 : 0,
        ),
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        maxLines: 1,
      ),
    );
  }
}

class _ShimmerSkeleton extends StatelessWidget {
  const _ShimmerSkeleton({required this.colors});
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(
        3,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
          ),
        ),
      ),
    );
  }
}
