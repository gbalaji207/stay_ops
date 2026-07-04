import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

import '_web_download_stub.dart'
    if (dart.library.html) '_web_download_web.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/booking_report_row.dart';
import '../../shared/models/booking_source.dart';
import '../../shared/models/booking_type.dart';
import '../../shared/models/payment_destination.dart';
import '../../shared/models/room.dart';
import '../config/config_cubit.dart';
import 'reports_cubit.dart';
import 'reports_repository.dart';

enum _ReportPeriod { today, monthToDate, lastMonth, yearToDate, custom }

extension _ReportPeriodLabel on _ReportPeriod {
  String get label {
    switch (this) {
      case _ReportPeriod.today:
        return 'Today';
      case _ReportPeriod.monthToDate:
        return 'Month to Date';
      case _ReportPeriod.lastMonth:
        return 'Last Month';
      case _ReportPeriod.yearToDate:
        return 'Year to Date';
      case _ReportPeriod.custom:
        return 'Custom';
    }
  }
}

class BookingsListReportScreen extends StatelessWidget {
  const BookingsListReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ReportsCubit(ReportsRepository()),
      child: const _BookingsListReportView(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _BookingsListReportView extends StatefulWidget {
  const _BookingsListReportView();

  @override
  State<_BookingsListReportView> createState() =>
      _BookingsListReportViewState();
}

class _BookingsListReportViewState extends State<_BookingsListReportView> {
  _ReportPeriod _period = _ReportPeriod.monthToDate;
  DateTimeRange? _customRange;

  List<String>? _roomIds;
  List<String>? _bookingTypeIds;
  List<String>? _bookingSourceIds;
  List<String>? _paymentDestinationIds;

  static final _dateFmt   = DateFormat('d MMM');
  static final _amountFmt = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTimeRange _computeRange(_ReportPeriod period, DateTimeRange? custom) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (period) {
      case _ReportPeriod.today:
        return DateTimeRange(start: today, end: today);
      case _ReportPeriod.monthToDate:
        return DateTimeRange(
          start: DateTime(today.year, today.month, 1),
          end: today,
        );
      case _ReportPeriod.lastMonth:
        final first = DateTime(today.year, today.month - 1, 1);
        final last  = DateTime(today.year, today.month, 0);
        return DateTimeRange(start: first, end: last);
      case _ReportPeriod.yearToDate:
        return DateTimeRange(
          start: DateTime(today.year, 1, 1),
          end: today,
        );
      case _ReportPeriod.custom:
        return custom ??
            DateTimeRange(
              start: DateTime(today.year, today.month, 1),
              end: today,
            );
    }
  }

  void _load() {
    final dateRange = _computeRange(_period, _customRange);
    context.read<ReportsCubit>().loadBookingsListReport(
          dateRange: dateRange,
          roomIds: _roomIds,
          bookingTypeIds: _bookingTypeIds,
          bookingSourceIds: _bookingSourceIds,
          paymentDestinationIds: _paymentDestinationIds,
        );
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
              ..._ReportPeriod.values.map((p) => ListTile(
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
                      if (p == _ReportPeriod.custom) {
                        setState(() => _period = p);
                        _pickCustomRange(context);
                      } else {
                        setState(() {
                          _period = p;
                          _customRange = null;
                        });
                        _load();
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

  Future<void> _pickCustomRange(BuildContext context) async {
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
      _load();
    }
  }

  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
       defaultTargetPlatform == TargetPlatform.macOS ||
       defaultTargetPlatform == TargetPlatform.linux);

  int get _activeFilterCount =>
      (_roomIds               != null ? 1 : 0) +
      (_bookingTypeIds        != null ? 1 : 0) +
      (_bookingSourceIds      != null ? 1 : 0) +
      (_paymentDestinationIds != null ? 1 : 0);

  Future<void> _openFiltersSheet(
    BuildContext context, {
    required AppColors colors,
    required List<Room> rooms,
    required List<BookingType> types,
    required List<BookingSource> sources,
    required List<PaymentDestination> destinations,
  }) async {
    final result = await showModalBottomSheet<_FiltersResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FiltersSheet(
        colors: colors,
        rooms: rooms,
        bookingTypes: types,
        bookingSources: sources,
        paymentDestinations: destinations,
        selectedRoomIds: _roomIds ?? [],
        selectedTypeIds: _bookingTypeIds ?? [],
        selectedSourceIds: _bookingSourceIds ?? [],
        selectedDestIds: _paymentDestinationIds ?? [],
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _roomIds               = result.roomIds.isEmpty        ? null : result.roomIds;
      _bookingTypeIds        = result.typeIds.isEmpty        ? null : result.typeIds;
      _bookingSourceIds      = result.sourceIds.isEmpty      ? null : result.sourceIds;
      _paymentDestinationIds = result.destinationIds.isEmpty ? null : result.destinationIds;
    });
    _load();
  }

  Future<void> _exportCsv(List<BookingReportRow> rows) async {
    final dateFmt = DateFormat('yyyy-MM-dd');
    final buf = StringBuffer();

    buf.writeln(
      'Booking Date,Check-in,Check-out,Nights,Customer,Room,'
      'Type,Source,Gross (INR),Tax,Commission,TDS/TCS,Net (INR),'
      'Payment Status,Actual Received,Payment Date,Payment Account',
    );

    String escape(String? v) {
      if (v == null || v.isEmpty) return '';
      if (v.contains(',') || v.contains('"') || v.contains('\n')) {
        return '"${v.replaceAll('"', '""')}"';
      }
      return v;
    }

    for (final r in rows) {
      final parts = [
        escape(r.bookingDate != null ? dateFmt.format(r.bookingDate!) : ''),
        escape(dateFmt.format(r.checkIn)),
        escape(dateFmt.format(r.checkOut)),
        r.nights.toString(),
        escape(r.customerName),
        escape(r.roomName),
        escape(r.bookingTypeName),
        escape(r.bookingSourceName),
        r.grossAmount.toStringAsFixed(2),
        r.taxAmount.toStringAsFixed(2),
        r.commissionInclTax.toStringAsFixed(2),
        r.taxDeduction.toStringAsFixed(2),
        r.netAmount.toStringAsFixed(2),
        r.paymentReceived ? 'Received' : 'Pending',
        r.actualPaymentAmount?.toStringAsFixed(2) ?? '',
        escape(r.paymentReceivedDate != null
            ? dateFmt.format(r.paymentReceivedDate!)
            : ''),
        escape(r.paymentDestinationName),
      ];
      buf.writeln(parts.join(','));
    }

    final bytes   = utf8.encode(buf.toString());
    final dateStr = dateFmt.format(DateTime.now());
    final fname   = 'bookings_report_$dateStr.csv';

    if (kIsWeb) {
      // Direct browser download — no share dialog
      triggerWebDownload(bytes, fname);
    } else if (_isDesktop) {
      // Native "Save File" dialog on Windows / macOS / Linux
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
      // Android: native share sheet
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: fname, mimeType: 'text/csv')],
        subject: 'Bookings Report $dateStr',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors      = Theme.of(context).extension<AppColors>()!;
    final configState = context.watch<ConfigCubit>().state;
    final rooms        = configState is ConfigLoaded
        ? configState.rooms
        : <Room>[];
    final types        = configState is ConfigLoaded
        ? configState.bookingTypes
        : <BookingType>[];
    final sources      = configState is ConfigLoaded
        ? configState.bookingSources
        : <BookingSource>[];
    final destinations = configState is ConfigLoaded
        ? configState.paymentDestinations
        : <PaymentDestination>[];

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.nav,
        elevation: 0,
        leading: BackButton(color: colors.textPrimary),
        title: Text(
          'Bookings Report',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: colors.textPrimary,
          ),
        ),
        actions: [
          BlocBuilder<ReportsCubit, ReportsState>(
            builder: (context, state) {
              final rows =
                  state is BookingsListReportLoaded ? state.rows : null;
              return IconButton(
                icon: Icon(
                  (kIsWeb || _isDesktop)
                      ? Icons.download_outlined
                      : Icons.ios_share_outlined,
                  color: rows != null && rows.isNotEmpty
                      ? colors.textPrimary
                      : colors.textHint,
                ),
                tooltip: (kIsWeb || _isDesktop) ? 'Download CSV' : 'Export CSV',
                onPressed: rows != null && rows.isNotEmpty
                    ? () => _exportCsv(rows)
                    : null,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter bar ────────────────────────────────────────────
          Container(
            color: colors.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'CHECK-IN DATE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _PeriodChip(
                        colors: colors,
                        label: _period == _ReportPeriod.custom &&
                                _customRange != null
                            ? '${_dateFmt.format(_customRange!.start)} – ${_dateFmt.format(_customRange!.end)}'
                            : _period.label,
                        onTap: () => _showPeriodSheet(context, colors),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _FiltersPill(
                      activeCount: _activeFilterCount,
                      colors: colors,
                      onTap: () => _openFiltersSheet(
                        context,
                        colors: colors,
                        rooms: rooms,
                        types: types,
                        sources: sources,
                        destinations: destinations,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          // ── Body ──────────────────────────────────────────────────
          Expanded(
            child: BlocBuilder<ReportsCubit, ReportsState>(
              builder: (context, state) {
                if (state is BookingsListReportLoading ||
                    state is ReportsInitial) {
                  return _ShimmerSkeleton(colors: colors);
                }
                if (state is BookingsListReportError) {
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
                if (state is BookingsListReportLoaded) {
                  if (state.rows.isEmpty) {
                    return Center(
                      child: Text(
                        'No bookings found for the selected filters.',
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: colors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return _BookingListBody(
                    rows: state.rows,
                    grandTotalGross: state.grandTotalGross,
                    grandTotalNet: state.grandTotalNet,
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

// ─────────────────────────────────────────────────────────────────────────────
// Filter result carrier

class _FiltersResult {
  const _FiltersResult({
    required this.roomIds,
    required this.typeIds,
    required this.sourceIds,
    required this.destinationIds,
  });

  final List<String> roomIds;
  final List<String> typeIds;
  final List<String> sourceIds;
  final List<String> destinationIds;
}

// ─────────────────────────────────────────────────────────────────────────────
// Filters pill

class _FiltersPill extends StatelessWidget {
  const _FiltersPill({
    required this.activeCount,
    required this.colors,
    required this.onTap,
  });

  final int activeCount;
  final AppColors colors;
  final VoidCallback onTap;

  String get _label =>
      activeCount == 0 ? 'Filters' : 'Filters ($activeCount)';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
            Icon(Icons.tune, size: 14, color: colors.accent),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filters bottom sheet

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({
    required this.colors,
    required this.rooms,
    required this.bookingTypes,
    required this.bookingSources,
    required this.paymentDestinations,
    required this.selectedRoomIds,
    required this.selectedTypeIds,
    required this.selectedSourceIds,
    required this.selectedDestIds,
  });

  final AppColors colors;
  final List<Room> rooms;
  final List<BookingType> bookingTypes;
  final List<BookingSource> bookingSources;
  final List<PaymentDestination> paymentDestinations;
  final List<String> selectedRoomIds;
  final List<String> selectedTypeIds;
  final List<String> selectedSourceIds;
  final List<String> selectedDestIds;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late List<String> _roomIds;
  late List<String> _typeIds;
  late List<String> _sourceIds;
  late List<String> _destIds;

  @override
  void initState() {
    super.initState();
    _roomIds   = List.from(widget.selectedRoomIds);
    _typeIds   = List.from(widget.selectedTypeIds);
    _sourceIds = List.from(widget.selectedSourceIds);
    _destIds   = List.from(widget.selectedDestIds);
  }

  void _toggle(List<String> list, String id) {
    setState(() {
      if (list.contains(id)) {
        list.remove(id);
      } else {
        list.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SafeArea(
          child: Column(
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
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() {
                        _roomIds.clear();
                        _typeIds.clear();
                        _sourceIds.clear();
                        _destIds.clear();
                      }),
                      child: Text(
                        'Clear All',
                        style: TextStyle(color: colors.accent),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.border),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _section(
                      title: 'Room',
                      items: widget.rooms
                          .map((r) => (r.id, r.name))
                          .toList(),
                      selected: _roomIds,
                      colors: colors,
                    ),
                    if (widget.bookingTypes.isNotEmpty)
                      Divider(height: 1, color: colors.border),
                    _section(
                      title: 'Booking Type',
                      items: widget.bookingTypes
                          .map((t) => (t.id, t.name))
                          .toList(),
                      selected: _typeIds,
                      colors: colors,
                    ),
                    if (widget.bookingSources.isNotEmpty)
                      Divider(height: 1, color: colors.border),
                    _section(
                      title: 'Booking Source',
                      items: widget.bookingSources
                          .map((s) => (s.id, s.name))
                          .toList(),
                      selected: _sourceIds,
                      colors: colors,
                    ),
                    if (widget.paymentDestinations.isNotEmpty)
                      Divider(height: 1, color: colors.border),
                    _section(
                      title: 'Payment Account',
                      items: widget.paymentDestinations
                          .map((d) => (d.id, d.name))
                          .toList(),
                      selected: _destIds,
                      colors: colors,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      _FiltersResult(
                        roomIds:        List.from(_roomIds),
                        typeIds:        List.from(_typeIds),
                        sourceIds:      List.from(_sourceIds),
                        destinationIds: List.from(_destIds),
                      ),
                    ),
                    child: const Text('Apply'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _section({
    required String title,
    required List<(String, String)> items,
    required List<String> selected,
    required AppColors colors,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: colors.textSecondary,
            ),
          ),
        ),
        for (final (id, name) in items)
          CheckboxListTile(
            value: selected.contains(id),
            activeColor: colors.accent,
            dense: true,
            title: Text(
              name,
              style: TextStyle(fontSize: 14, color: colors.textPrimary),
            ),
            onChanged: (_) => _toggle(selected, id),
          ),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Report body

class _BookingListBody extends StatelessWidget {
  const _BookingListBody({
    required this.rows,
    required this.grandTotalGross,
    required this.grandTotalNet,
    required this.colors,
    required this.amountFmt,
  });

  final List<BookingReportRow> rows;
  final double grandTotalGross;
  final double grandTotalNet;
  final AppColors colors;
  final NumberFormat amountFmt;

  String _fmt(double v) => '₹${amountFmt.format(v)}';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Summary bar
        Container(
          color: colors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Text(
                '${rows.length} booking${rows.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                'Net ${_fmt(grandTotalNet)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Gross ${_fmt(grandTotalGross)}',
                style: TextStyle(
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: colors.border),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 700) {
                return _BookingsTable(
                  rows: rows,
                  colors: colors,
                  amountFmt: amountFmt,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _BookingCard(
                  row: rows[i],
                  colors: colors,
                  amountFmt: amountFmt,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop table view

class _BookingsTable extends StatelessWidget {
  const _BookingsTable({
    required this.rows,
    required this.colors,
    required this.amountFmt,
  });

  final List<BookingReportRow> rows;
  final AppColors colors;
  final NumberFormat amountFmt;

  static const double _stickyW = 110.0;
  static const double _rowH    = 44.0;

  static final _dateFmt = DateFormat('d MMM yy');

  String _fmtAmt(double v) => '₹${amountFmt.format(v)}';
  String _fmtOrDash(double? v) => (v == null || v == 0) ? '—' : _fmtAmt(v);
  String _dateOrDash(DateTime? d) => d == null ? '—' : _dateFmt.format(d);

  @override
  Widget build(BuildContext context) {
    final bdr = BorderSide(color: colors.border);

    // Column definitions: (header label, width, value getter, alignLeft)
    final cols = <(String, double, String Function(BookingReportRow), bool)>[
      ('DATE',      100, (r) => _dateOrDash(r.bookingDate), false),
      ('CHECK-IN',   90, (r) => _dateFmt.format(r.checkIn),  false),
      ('CHECK-OUT',  90, (r) => _dateFmt.format(r.checkOut), false),
      ('NIGHTS',     60, (r) => r.nights == 0 ? 'Day' : '${r.nights}', false),
      ('CUSTOMER',  130, (r) => r.customerName ?? '—', true),
      ('TYPE',      100, (r) => r.bookingTypeName ?? '—', true),
      ('SOURCE',    110, (r) => r.bookingSourceName ?? '—', true),
      ('GROSS ₹',   100, (r) => _fmtAmt(r.grossAmount), false),
      ('NET ₹',     100, (r) => _fmtAmt(r.netAmount), false),
      ('PAYMENT',    90, (r) => r.paymentReceived ? 'Received' : 'Pending', false),
      ('ACTUAL ₹',  100, (r) => _fmtOrDash(r.actualPaymentAmount), false),
      ('PAY DATE',   90, (r) => _dateOrDash(r.paymentReceivedDate), false),
      ('ACCOUNT',   120, (r) => r.paymentDestinationName ?? '—', true),
    ];

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
            // Sticky ROOM column
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _lc('ROOM', bdr, isHeader: true),
                for (final r in rows) _lc(r.roomName, bdr),
              ],
            ),
            // Horizontally scrollable data columns
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                      children: [
                        for (final (label, w, _, left) in cols)
                          _dc(label, w, bdr,
                              isHeader: true, alignLeft: left),
                      ],
                    ),
                    // Data rows
                    for (final r in rows)
                      Row(
                        children: [
                          for (final (_, w, getter, left) in cols)
                            _dc(
                              getter(r),
                              w,
                              bdr,
                              alignLeft: left,
                              isAccent: getter == cols[8].$3 // NET ₹ column
                                  ? true
                                  : false,
                              isPayment: getter == cols[9].$3, // PAYMENT column
                              paymentReceived: r.paymentReceived,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lc(String text, BorderSide bdr, {bool isHeader = false}) {
    return Container(
      width: _stickyW,
      height: _rowH,
      decoration: BoxDecoration(
        color: isHeader ? colors.background : null,
        border: Border(
          bottom: isHeader ? bdr : bdr,
          right: bdr,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          fontSize: isHeader ? 11 : 13,
          fontWeight: isHeader ? FontWeight.w600 : FontWeight.w400,
          color: isHeader ? colors.textSecondary : colors.textPrimary,
          letterSpacing: isHeader ? 0.6 : 0,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  Widget _dc(
    String text,
    double width,
    BorderSide bdr, {
    bool isHeader   = false,
    bool alignLeft  = false,
    bool isAccent   = false,
    bool isPayment  = false,
    bool paymentReceived = false,
  }) {
    Color textColor;
    if (isPayment) {
      textColor = paymentReceived ? colors.success : colors.warning;
    } else if (isAccent) {
      textColor = colors.accent;
    } else if (isHeader) {
      textColor = colors.textSecondary;
    } else {
      textColor = colors.textPrimary;
    }

    return Container(
      width: width,
      height: _rowH,
      decoration: BoxDecoration(
        color: isHeader ? colors.background : null,
        border: Border(bottom: bdr),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: Text(
        text,
        style: TextStyle(
          fontSize: isHeader ? 11 : 13,
          fontWeight: (isHeader || isAccent) ? FontWeight.w600 : FontWeight.w400,
          color: textColor,
          letterSpacing: isHeader ? 0.3 : 0,
        ),
        overflow: TextOverflow.ellipsis,
        textAlign: alignLeft ? TextAlign.left : TextAlign.right,
        maxLines: 1,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Booking card

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.row,
    required this.colors,
    required this.amountFmt,
  });

  final BookingReportRow row;
  final AppColors colors;
  final NumberFormat amountFmt;

  static final _dateShort = DateFormat('d MMM');
  static final _dateFull  = DateFormat('d MMM yyyy');
  static final _dateYY    = DateFormat('d MMM yy');

  String _fmt(double v) => '₹${amountFmt.format(v)}';

  @override
  Widget build(BuildContext context) {
    final checkInStr  = _dateShort.format(row.checkIn);
    final checkOutStr = _dateFull.format(row.checkOut);
    final nightsLabel = row.nights == 0
        ? 'Day use'
        : '${row.nights} night${row.nights == 1 ? '' : 's'}';

    final paymentColor = row.paymentReceived ? colors.success  : colors.warning;
    final paymentBg    = row.paymentReceived ? colors.successSubtle : colors.warningSubtle;
    final paymentLabel = row.paymentReceived ? 'Received' : 'Pending';

    final hasTaxBreakdown = row.taxAmount > 0 ||
        row.commissionInclTax > 0 ||
        row.taxDeduction > 0;

    final metaLine = [
      row.customerName ?? 'No name',
      if (row.bookingSourceName != null) row.bookingSourceName!,
      if (row.bookingTypeName   != null) row.bookingTypeName!,
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: EdgeInsets.zero,
          trailing: Icon(Icons.expand_more,
              color: colors.textHint, size: 18),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: room + date range + nights
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${row.roomName}  ·  $checkInStr → $checkOutStr',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    nightsLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Row 2: customer · source · type
              Text(
                metaLine,
                style:
                    TextStyle(fontSize: 12, color: colors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              // Row 3: amounts + payment badge
              Row(
                children: [
                  Text(
                    'Gross ${_fmt(row.grossAmount)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Net ${_fmt(row.netAmount)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.accent,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: paymentBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      paymentLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: paymentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          children: [
            Divider(height: 1, color: colors.border),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  if (row.bookingDate != null)
                    _detailRow(
                      'Booking Date',
                      _dateYY.format(row.bookingDate!),
                      colors,
                    ),
                  if (hasTaxBreakdown) ...[
                    _detailRow('Tax', _fmt(row.taxAmount), colors),
                    _detailRow(
                        'Commission', _fmt(row.commissionInclTax), colors),
                    _detailRow('TDS / TCS', _fmt(row.taxDeduction), colors),
                  ],
                  if (row.actualPaymentAmount != null)
                    _detailRow(
                      'Actual Received',
                      _fmt(row.actualPaymentAmount!),
                      colors,
                    ),
                  if (row.paymentReceivedDate != null)
                    _detailRow(
                      'Payment Date',
                      _dateYY.format(row.paymentReceivedDate!),
                      colors,
                    ),
                  if (row.paymentDestinationName != null)
                    _detailRow(
                      'Payment Account',
                      row.paymentDestinationName!,
                      colors,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: colors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private shared widgets

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.colors,
    required this.label,
    required this.onTap,
  });

  final AppColors colors;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.date_range_rounded, size: 15, color: colors.accent),
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

class _ShimmerSkeleton extends StatelessWidget {
  const _ShimmerSkeleton({required this.colors});
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(
        4,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            height: 96,
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
