import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/room_payment_summary.dart';
import '../config/config_cubit.dart';
import '_web_download_stub.dart'
    if (dart.library.html) '_web_download_web.dart';
import 'reports_cubit.dart';
import 'reports_repository.dart';

class PaymentReportScreen extends StatelessWidget {
  const PaymentReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ReportsCubit(ReportsRepository()),
      child: const _PaymentReportView(),
    );
  }
}

class _PaymentReportView extends StatefulWidget {
  const _PaymentReportView();

  @override
  State<_PaymentReportView> createState() => _PaymentReportViewState();
}

class _PaymentReportViewState extends State<_PaymentReportView> {
  late DateTime _dateFrom;
  late DateTime _dateTo;
  // null = all rooms selected
  List<String>? _selectedRoomIds;
  String? _dateError;

  static final _dateFmt = DateFormat('d MMM yyyy');
  static final _amountFmt = NumberFormat('#,##0.##');

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
    context.read<ReportsCubit>().loadPaymentReport(
          dateRange: DateTimeRange(start: _dateFrom, end: _dateTo),
          roomIds: _selectedRoomIds,
        );
  }

  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
       defaultTargetPlatform == TargetPlatform.macOS ||
       defaultTargetPlatform == TargetPlatform.linux);

  Future<void> _exportCsv(PaymentReportLoaded state) async {
    final dateFmt = DateFormat('yyyy-MM-dd');
    final buf     = StringBuffer();

    String esc(String? v) {
      if (v == null || v.isEmpty) return '';
      if (v.contains(',') || v.contains('"') || v.contains('\n')) {
        return '"${v.replaceAll('"', '""')}"';
      }
      return v;
    }

    String fmtAmt(double v) => v.toStringAsFixed(2);

    final cols = state.overallTotals;

    // Header row: Room | <dest1> | <dest2> | … | TOTAL
    buf.writeln([
      'Room',
      ...cols.map((c) => esc(c.destinationName ?? 'Not specified')),
      'TOTAL',
    ].join(','));

    // One data row per room
    for (final room in state.roomRows) {
      final byId = {for (final d in room.byDestination) d.destinationId: d.amount};
      buf.writeln([
        esc(room.roomName),
        ...cols.map((c) {
          final amt = byId[c.destinationId];
          return amt != null ? fmtAmt(amt) : '';
        }),
        fmtAmt(room.roomTotal),
      ].join(','));
    }

    // Footer totals row
    buf.writeln([
      'TOTAL',
      ...cols.map((c) => fmtAmt(c.amount)),
      fmtAmt(state.grandTotal),
    ].join(','));

    final bytes   = utf8.encode(buf.toString());
    final dateStr = dateFmt.format(DateTime.now());
    final fname   = 'payment_report_$dateStr.csv';

    if (kIsWeb) {
      triggerWebDownload(bytes, fname);
    } else if (_isDesktop) {
      final location = await getSaveLocation(
        suggestedName: fname,
        acceptedTypeGroups: [
          const XTypeGroup(label: 'CSV files', extensions: ['csv']),
        ],
      );
      if (location == null || !mounted) return;
      await XFile.fromData(bytes, name: fname, mimeType: 'text/csv')
          .saveTo(location.path);
    } else {
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: fname, mimeType: 'text/csv')],
        subject: 'Payment Report $dateStr',
      );
    }
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
          'Payment Report',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: colors.textPrimary,
          ),
        ),
        actions: [
          Builder(
            builder: (ctx) {
              final st = ctx.watch<ReportsCubit>().state;
              final loaded = st is PaymentReportLoaded && st.roomRows.isNotEmpty
                  ? st
                  : null;
              return IconButton(
                icon: Icon(
                  (kIsWeb || _isDesktop)
                      ? Icons.download_outlined
                      : Icons.ios_share_outlined,
                  color: loaded != null
                      ? colors.textPrimary
                      : colors.textHint,
                ),
                tooltip:
                    (kIsWeb || _isDesktop) ? 'Download CSV' : 'Export CSV',
                onPressed: loaded != null ? () => _exportCsv(loaded) : null,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter bar
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
                        setState(() => _selectedRoomIds =
                            ids.isEmpty ? null : ids);
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
          // Report body
          Expanded(
            child: BlocBuilder<ReportsCubit, ReportsState>(
              builder: (context, state) {
                if (state is PaymentReportLoading ||
                    state is ReportsInitial) {
                  return _ShimmerSkeleton(colors: colors);
                }
                if (state is PaymentReportError) {
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
                if (state is PaymentReportLoaded) {
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
                  return _ReportBody(
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

class _ReportBody extends StatelessWidget {
  const _ReportBody({
    required this.roomRows,
    required this.overallTotals,
    required this.grandTotal,
    required this.colors,
    required this.amountFmt,
  });

  final List<RoomPaymentSummary> roomRows;
  final List<DestinationTotal> overallTotals;
  final double grandTotal;
  final AppColors colors;
  final NumberFormat amountFmt;

  String _fmt(double amount, int count) =>
      '₹${amountFmt.format(amount)} ($count)';

  @override
  Widget build(BuildContext context) {
    final grandTotalCount =
        overallTotals.fold(0, (sum, t) => sum + t.count);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final room in roomRows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(
                    room.roomName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _fmt(room.roomTotal, room.count),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.expand_more,
                        color: colors.textSecondary,
                      ),
                    ],
                  ),
                  children: [
                    Divider(height: 1, color: colors.border),
                    for (final dest in room.byDestination)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Text(
                              dest.destinationName ?? 'Not specified',
                              style: TextStyle(
                                fontSize: 13,
                                color: dest.destinationName == null
                                    ? colors.textHint
                                    : colors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _fmt(dest.amount, dest.count),
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        // Overall summary card
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Text(
                  'OVERALL TOTAL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              Divider(height: 1, color: colors.border),
              for (final dest in overallTotals)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Text(
                        dest.destinationName ?? 'Not specified',
                        style: TextStyle(
                          fontSize: 13,
                          color: dest.destinationName == null
                              ? colors.textHint
                              : colors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _fmt(dest.amount, dest.count),
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              Divider(height: 1, color: colors.border),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Text(
                      'Grand Total',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _fmt(grandTotal, grandTotalCount),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
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
