import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/booking_group.dart';
import '../../shared/models/booking_source.dart';
import '../../shared/models/payment_destination.dart';
import '../../shared/models/room.dart';
import '../../shared/widgets/conflict_dialog.dart';
import '../config/config_cubit.dart';
import 'booking_cubit.dart';
import 'booking_group_input.dart';
import 'booking_repository.dart';

/// Opens the booking form as a modal bottom sheet.
/// Returns true if a booking was saved (caller should reload data).
Future<bool> showBookingFormSheet(
  BuildContext context, {
  BookingGroup? existingGroup,
  String? prefilledRoomId,
  DateTime? prefilledDate,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider(
      create: (_) => BookingCubit(BookingRepository()),
      child: BookingForm(
        existingGroup: existingGroup,
        prefilledRoomId: prefilledRoomId,
        prefilledDate: prefilledDate,
      ),
    ),
  );
  return result ?? false;
}

class BookingForm extends StatefulWidget {
  const BookingForm({
    super.key,
    this.existingGroup,
    this.prefilledRoomId,
    this.prefilledDate,
  });

  final BookingGroup? existingGroup;
  final String? prefilledRoomId;
  final DateTime? prefilledDate;

  @override
  State<BookingForm> createState() => _BookingFormState();
}

class _BookingFormState extends State<BookingForm> {
  late String? _roomId;
  late DateTime _checkIn;
  late DateTime _checkOut;
  late String? _typeId;
  late String? _sourceId;
  late bool _paymentReceived;
  late String? _paymentDestinationId;
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  static final _amountFmt = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    final today = _today();
    final group = widget.existingGroup;
    _roomId = group?.roomId ?? widget.prefilledRoomId;
    _checkIn = group?.checkIn ?? widget.prefilledDate ?? today;
    _checkOut = group?.checkOut ??
        (widget.prefilledDate != null
            ? widget.prefilledDate!.add(const Duration(days: 1))
            : today.add(const Duration(days: 1)));
    _typeId = group?.bookingTypeId;
    _sourceId = group?.bookingSourceId;
    _paymentReceived = group?.paymentReceived ?? false;
    _paymentDestinationId = group?.paymentDestinationId;
    _amountController.text =
        group != null && group.totalAmount > 0
            ? group.totalAmount.toInt().toString()
            : '';
    _notesController.text = group?.notes ?? '';
    _amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onAmountChanged() => setState(() {});

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  int get _nightCount => _checkOut.difference(_checkIn).inDays;
  double get _totalAmount =>
      double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
  double get _perNight =>
      _nightCount > 0 ? _totalAmount / _nightCount : 0;
  bool get _canSave =>
      _totalAmount > 0 && _nightCount > 0 && _roomId != null;

  List<BookingSource> _filteredSources(List<BookingSource> all) {
    if (_typeId == null) return [];
    return all.where((s) => s.bookingTypeId == _typeId).toList();
  }

  void _onSourceChanged(
    String? sourceId,
    List<BookingSource> sources,
    List<PaymentDestination> destinations,
  ) {
    setState(() => _sourceId = sourceId);
    if (sourceId == null) return;
    final source = sources.where((s) => s.id == sourceId).firstOrNull;
    final destId = source?.defaultPaymentDestinationId;
    if (destId != null &&
        destinations.any((d) => d.id == destId && d.isActive)) {
      setState(() => _paymentDestinationId = destId);
    }
  }

  Future<void> _pickDate(BuildContext context, bool isCheckIn) async {
    final today = _today();
    final initial = isCheckIn ? _checkIn : _checkOut;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 730)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isCheckIn) {
        _checkIn = picked;
        if (!_checkOut.isAfter(_checkIn)) {
          _checkOut = _checkIn.add(const Duration(days: 1));
        }
      } else {
        if (picked.isAfter(_checkIn)) {
          _checkOut = picked;
        }
      }
    });
  }

  void _handleSave(BuildContext context) {
    if (!_canSave) return;
    final input = BookingGroupInput(
      existingGroupId: widget.existingGroup?.id,
      roomId: _roomId!,
      checkIn: _checkIn,
      checkOut: _checkOut,
      totalAmount: _totalAmount,
      paymentReceived: _paymentReceived,
      bookingTypeId: _typeId,
      bookingSourceId: _sourceId,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      paymentDestinationId: _paymentDestinationId,
    );
    context.read<BookingCubit>().checkAndSave(input);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final configState = context.watch<ConfigCubit>().state;
    if (configState is! ConfigLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final rooms = configState.rooms;
    final types = configState.bookingTypes;
    final filteredSources = _filteredSources(configState.bookingSources);
    final destinations = configState.paymentDestinations;
    final isEditMode = widget.existingGroup != null;

    String? roomName;
    if (_roomId != null) {
      final matches = rooms.where((r) => r.id == _roomId);
      if (matches.isNotEmpty) roomName = matches.first.name;
    }

    return BlocConsumer<BookingCubit, BookingState>(
      listener: (context, state) {
        if (state is BookingSaved) {
          Navigator.of(context).pop(true);
        } else if (state is BookingConflict) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => ConflictDialog(
              conflicts: state.conflicts,
              onCancel: () {
                Navigator.of(context).pop();
                context.read<BookingCubit>().reset();
              },
              onConfirm: () {
                Navigator.of(context).pop();
                context.read<BookingCubit>().confirmOverwrite();
              },
            ),
          );
        } else if (state is BookingError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
          context.read<BookingCubit>().reset();
        }
      },
      builder: (context, bookingState) {
        final isBusy = bookingState is BookingChecking ||
            bookingState is BookingSaving;

        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 28,
                      height: 3,
                      decoration: BoxDecoration(
                        color: colors.sheetHandle,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        isEditMode && roomName != null
                            ? 'Edit booking — $roomName'
                            : 'New booking',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel(text: 'Room', colors: colors),
                          const SizedBox(height: 6),
                          _RoomDropdown(
                            rooms: rooms,
                            selectedId: _roomId,
                            onChanged: (id) =>
                                setState(() => _roomId = id),
                            colors: colors,
                          ),
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel(
                                      text: 'Check-in',
                                      colors: colors),
                                  const SizedBox(height: 6),
                                  _DateTile(
                                    date: _checkIn,
                                    onTap: () =>
                                        _pickDate(context, true),
                                    colors: colors,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel(
                                      text: 'Check-out',
                                      colors: colors),
                                  const SizedBox(height: 6),
                                  _DateTile(
                                    date: _checkOut,
                                    onTap: () =>
                                        _pickDate(context, false),
                                    colors: colors,
                                  ),
                                ],
                              ),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: colors.accentSubtle,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(children: [
                              Text(
                                '$_nightCount night${_nightCount == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: colors.accent,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _nightCount > 0 && _totalAmount > 0
                                    ? '₹${_amountFmt.format(_perNight)} / night'
                                    : '—',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: colors.accent,
                                ),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 16),
                          _FieldLabel(
                              text: 'Total amount (₹)',
                              colors: colors),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _amountController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 15),
                            decoration: _inputDecoration(
                              colors: colors,
                              hint: '0',
                              prefix: '₹ ',
                            ),
                          ),
                          const SizedBox(height: 16),
                          _FieldLabel(
                              text: 'Booking type', colors: colors),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: types.map((type) {
                              final selected = _typeId == type.id;
                              return _TypeChip(
                                label: type.name,
                                selected: selected,
                                onTap: () => setState(() {
                                  _typeId = type.id;
                                  _sourceId = null;
                                }),
                                colors: colors,
                              );
                            }).toList(),
                          ),
                          if (filteredSources.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _FieldLabel(
                                text: 'Booking source',
                                colors: colors),
                            const SizedBox(height: 6),
                            _SourceDropdown(
                              sources: filteredSources,
                              selectedId: _sourceId,
                              onChanged: (id) => _onSourceChanged(
                                id,
                                configState.bookingSources,
                                destinations,
                              ),
                              colors: colors,
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Payment received',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Mark if full payment is settled',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: colors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _paymentReceived,
                              activeThumbColor: colors.success,
                              activeTrackColor: colors.successSubtle,
                              onChanged: (v) =>
                                  setState(() => _paymentReceived = v),
                            ),
                          ]),
                          const SizedBox(height: 16),
                          _FieldLabel(
                              text: 'Payment destination',
                              colors: colors),
                          const SizedBox(height: 6),
                          _DestinationDropdown(
                            destinations: destinations,
                            selectedId: _paymentDestinationId,
                            onChanged: (id) =>
                                setState(() => _paymentDestinationId = id),
                            colors: colors,
                          ),
                          const SizedBox(height: 16),
                          _FieldLabel(
                              text: 'Notes (optional)',
                              colors: colors),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _notesController,
                            maxLines: 2,
                            style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 13),
                            decoration: _inputDecoration(
                              colors: colors,
                              hint: 'Add any notes...',
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _canSave && !isBusy
                            ? () => _handleSave(context)
                            : null,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12)),
                        ),
                        child: isBusy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : Text(
                                isEditMode
                                    ? 'Save changes'
                                    : 'Save booking',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration({
    required AppColors colors,
    required String hint,
    String? prefix,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: colors.border),
    );
    return InputDecoration(
      prefixText: prefix,
      prefixStyle: TextStyle(color: colors.textSecondary, fontSize: 15),
      hintText: hint,
      hintStyle: TextStyle(color: colors.textHint),
      filled: true,
      fillColor: colors.background,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: colors.accent, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

// ── Private helper widgets ────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text, required this.colors});
  final String text;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: colors.textSecondary,
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.date,
    required this.onTap,
    required this.colors,
  });
  final DateTime date;
  final VoidCallback onTap;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_outlined,
              size: 15, color: colors.textSecondary),
          const SizedBox(width: 8),
          Text(
            fmt.format(date),
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary),
          ),
        ]),
      ),
    );
  }
}

class _RoomDropdown extends StatelessWidget {
  const _RoomDropdown({
    required this.rooms,
    required this.selectedId,
    required this.onChanged,
    required this.colors,
  });
  final List<Room> rooms;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedId,
          isExpanded: true,
          hint: Text('Select room',
              style: TextStyle(color: colors.textHint, fontSize: 14)),
          dropdownColor: colors.surface,
          style: TextStyle(color: colors.textPrimary, fontSize: 14),
          iconEnabledColor: colors.textSecondary,
          items: rooms
              .map((r) => DropdownMenuItem(
                    value: r.id,
                    child: Text(r.name),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _SourceDropdown extends StatelessWidget {
  const _SourceDropdown({
    required this.sources,
    required this.selectedId,
    required this.onChanged,
    required this.colors,
  });
  final List<BookingSource> sources;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    // If selected source is no longer in list (type changed), clear it
    final validId =
        sources.any((s) => s.id == selectedId) ? selectedId : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: validId,
          isExpanded: true,
          hint: Text('Select source',
              style: TextStyle(color: colors.textHint, fontSize: 14)),
          dropdownColor: colors.surface,
          style: TextStyle(color: colors.textPrimary, fontSize: 14),
          iconEnabledColor: colors.textSecondary,
          items: sources
              .map((s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(s.name),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _DestinationDropdown extends StatelessWidget {
  const _DestinationDropdown({
    required this.destinations,
    required this.selectedId,
    required this.onChanged,
    required this.colors,
  });
  final List<PaymentDestination> destinations;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedId,
          isExpanded: true,
          hint: Text(
            '— Not specified —',
            style: TextStyle(color: colors.textHint, fontSize: 14),
          ),
          dropdownColor: colors.surface,
          style: TextStyle(color: colors.textPrimary, fontSize: 14),
          iconEnabledColor: colors.textSecondary,
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(
                '— Not specified —',
                style: TextStyle(color: colors.textHint),
              ),
            ),
            ...destinations.map(
              (d) => DropdownMenuItem<String>(
                value: d.id,
                child: Text(d.name),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.colors,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colors.accent : colors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? colors.accent : colors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.w400,
            color:
                selected ? Colors.white : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
