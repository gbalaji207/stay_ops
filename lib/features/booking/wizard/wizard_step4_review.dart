import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/booking_source.dart';
import '../../../shared/models/booking_type.dart';
import '../../../shared/models/room.dart';

class WizardStep4Review extends StatelessWidget {
  const WizardStep4Review({
    super.key,
    required this.rooms,
    required this.types,
    required this.allSources,
    required this.selectedRoomId,
    required this.bookingDate,
    required this.checkIn,
    required this.checkOut,
    required this.grossAmountController,
    required this.taxAmountController,
    required this.commissionController,
    required this.tdsTcsController,
    required this.selectedTypeId,
    required this.selectedSourceId,
    required this.customerNameController,
    required this.stayFlexiBookingIdController,
    required this.otaBookingIdController,
    required this.notesController,
    required this.onRoomChanged,
    required this.onBookingDateChanged,
    required this.onStayRangeChanged,
    required this.onTypeSelected,
    required this.onSourceChanged,
    required this.onSave,
    required this.isBusy,
    required this.isEditMode,
  });

  final List<Room> rooms;
  final List<BookingType> types;
  final List<BookingSource> allSources;
  final String? selectedRoomId;
  final DateTime bookingDate;
  final DateTime checkIn;
  final DateTime checkOut;
  final TextEditingController grossAmountController;
  final TextEditingController taxAmountController;
  final TextEditingController commissionController;
  final TextEditingController tdsTcsController;
  final String? selectedTypeId;
  final String? selectedSourceId;
  final TextEditingController customerNameController;
  final TextEditingController stayFlexiBookingIdController;
  final TextEditingController otaBookingIdController;
  final TextEditingController notesController;
  final ValueChanged<String?> onRoomChanged;
  final ValueChanged<DateTime> onBookingDateChanged;
  final void Function(DateTime checkIn, DateTime checkOut) onStayRangeChanged;
  final ValueChanged<String?> onTypeSelected;
  final ValueChanged<String?> onSourceChanged;
  final VoidCallback onSave;
  final bool isBusy;
  final bool isEditMode;

  static final _amountFmt = NumberFormat('#,##0.##');

  int get _nightCount => checkOut.difference(checkIn).inDays;
  double get _grossAmount =>
      double.tryParse(grossAmountController.text.replaceAll(',', '')) ?? 0;
  double get _perNight => _nightCount > 0 ? _grossAmount / _nightCount : 0;
  double get _commissionAmount =>
      double.tryParse(commissionController.text.replaceAll(',', '')) ?? 0;
  double get _tdsTcsAmount =>
      double.tryParse(tdsTcsController.text.replaceAll(',', '')) ?? 0;
  double get _netAmount => _grossAmount - _commissionAmount - _tdsTcsAmount;
  bool get _canSave =>
      _grossAmount > 0 && _nightCount > 0 && selectedRoomId != null;

  List<BookingSource> get _filteredSources {
    if (selectedTypeId == null) return [];
    return allSources
        .where((s) => s.bookingTypeId == selectedTypeId && s.isActive)
        .toList();
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickBookingDateTime(BuildContext context) async {
    final today = _today();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate:
          DateTime(bookingDate.year, bookingDate.month, bookingDate.day),
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 30)),
    );
    if (pickedDate == null || !context.mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay(hour: bookingDate.hour, minute: bookingDate.minute),
    );
    if (!context.mounted) return;

    final t = pickedTime ??
        TimeOfDay(hour: bookingDate.hour, minute: bookingDate.minute);
    onBookingDateChanged(DateTime(
      pickedDate.year, pickedDate.month, pickedDate.day, t.hour, t.minute,
    ));
  }

  Future<void> _pickStayRange(BuildContext context) async {
    final today = _today();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: checkIn, end: checkOut),
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 730)),
    );
    if (picked == null || !context.mounted) return;
    onStayRangeChanged(picked.start, picked.end);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final dateFmt = DateFormat('d MMM');
    final dtFmt = DateFormat('d MMM yyyy, HH:mm');
    final filteredSources = _filteredSources;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── BOOKING ──────────────────────────────────────
                _SectionHeader(title: 'Booking', colors: colors),
                _FieldLabel(text: 'Room', colors: colors),
                const SizedBox(height: 6),
                _RoomDropdown(
                  rooms: rooms,
                  selectedId: selectedRoomId,
                  onChanged: onRoomChanged,
                  colors: colors,
                ),
                const SizedBox(height: 16),
                _FieldLabel(text: 'Booking date & time', colors: colors),
                const SizedBox(height: 6),
                _DateTile(
                  label: dtFmt.format(bookingDate),
                  icon: Icons.schedule_outlined,
                  onTap: () => _pickBookingDateTime(context),
                  colors: colors,
                ),

                // ── STAY ─────────────────────────────────────────
                const SizedBox(height: 28),
                _SectionHeader(title: 'Stay', colors: colors),
                _FieldLabel(text: 'Stay dates', colors: colors),
                const SizedBox(height: 6),
                _DateRangeTile(
                  checkIn: checkIn,
                  checkOut: checkOut,
                  dateFmt: dateFmt,
                  onTap: () => _pickStayRange(context),
                  colors: colors,
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: colors.accentSubtle,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_nightCount night${_nightCount == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.accent,
                    ),
                  ),
                ),

                // ── PAYMENT ──────────────────────────────────────
                const SizedBox(height: 28),
                _SectionHeader(title: 'Payment', colors: colors),
                _FieldLabel(text: 'Gross amount (₹)', colors: colors),
                const SizedBox(height: 6),
                TextField(
                  controller: grossAmountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style:
                      TextStyle(color: colors.textPrimary, fontSize: 15),
                  decoration: _inputDecoration(
                      colors: colors, hint: '0', prefix: '₹ '),
                ),
                if (_grossAmount > 0 && _nightCount > 0) ...[
                  const SizedBox(height: 10),
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
                        '₹${_amountFmt.format(_perNight)} / night',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colors.accent,
                        ),
                      ),
                    ]),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel(
                              text: 'Tax (₹, optional)', colors: colors),
                          const SizedBox(height: 6),
                          TextField(
                            controller: taxAmountController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            style: TextStyle(
                                color: colors.textPrimary, fontSize: 15),
                            decoration: _inputDecoration(
                                colors: colors, hint: '0', prefix: '₹ '),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel(
                              text: 'TDS & TCS (₹, optional)',
                              colors: colors),
                          const SizedBox(height: 6),
                          TextField(
                            controller: tdsTcsController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            style: TextStyle(
                                color: colors.textPrimary, fontSize: 15),
                            decoration: _inputDecoration(
                                colors: colors, hint: '0', prefix: '₹ '),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _FieldLabel(
                    text: 'Commission incl. taxes (₹, optional)',
                    colors: colors),
                const SizedBox(height: 6),
                TextField(
                  controller: commissionController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style:
                      TextStyle(color: colors.textPrimary, fontSize: 15),
                  decoration: _inputDecoration(
                      colors: colors, hint: '0', prefix: '₹ '),
                ),
                if (_grossAmount > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: colors.successSubtle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      Text(
                        'Net received',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colors.success,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '₹${_amountFmt.format(_netAmount)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.success,
                        ),
                      ),
                    ]),
                  ),
                ],

                // ── BOOKING DETAILS ───────────────────────────────
                const SizedBox(height: 28),
                _SectionHeader(title: 'Booking details', colors: colors),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel(
                              text: 'Booking type', colors: colors),
                          const SizedBox(height: 6),
                          _TypeDropdown(
                            types: types,
                            selectedId: selectedTypeId,
                            onChanged: onTypeSelected,
                            colors: colors,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel(
                              text: 'Booking source', colors: colors),
                          const SizedBox(height: 6),
                          _SourceDropdown(
                            sources: filteredSources,
                            selectedId: selectedSourceId,
                            selectedTypeId: selectedTypeId,
                            onChanged: filteredSources.isEmpty
                                ? null
                                : onSourceChanged,
                            colors: colors,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _FieldLabel(
                    text: 'Customer name (optional)', colors: colors),
                const SizedBox(height: 6),
                TextField(
                  controller: customerNameController,
                  textCapitalization: TextCapitalization.words,
                  style:
                      TextStyle(color: colors.textPrimary, fontSize: 14),
                  decoration: _inputDecoration(
                      colors: colors, hint: 'e.g. John Smith'),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel(
                              text: 'Stay Flexi ID (optional)',
                              colors: colors),
                          const SizedBox(height: 6),
                          TextField(
                            controller: stayFlexiBookingIdController,
                            style: TextStyle(
                                color: colors.textPrimary, fontSize: 14),
                            decoration: _inputDecoration(
                                colors: colors, hint: 'e.g. SF-123456'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel(
                              text: 'OTA booking ID (optional)',
                              colors: colors),
                          const SizedBox(height: 6),
                          TextField(
                            controller: otaBookingIdController,
                            style: TextStyle(
                                color: colors.textPrimary, fontSize: 14),
                            decoration: _inputDecoration(
                                colors: colors, hint: 'e.g. MMT-987654'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ── NOTES ────────────────────────────────────────
                const SizedBox(height: 28),
                _SectionHeader(title: 'Notes', colors: colors),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13),
                  decoration:
                      _inputDecoration(colors: colors, hint: 'Add any notes...'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // ── Save button ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _canSave && !isBusy ? onSave : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: isBusy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      isEditMode ? 'Save changes' : 'Save booking',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ),
      ],
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

// ── Private helpers ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.colors});
  final String title;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: colors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text, required this.colors});
  final String text;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.colors,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border),
        ),
        child: Row(children: [
          Icon(icon, size: 15, color: colors.textSecondary),
          const SizedBox(width: 8),
          Text(
            label,
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

class _DateRangeTile extends StatelessWidget {
  const _DateRangeTile({
    required this.checkIn,
    required this.checkOut,
    required this.dateFmt,
    required this.onTap,
    required this.colors,
  });
  final DateTime checkIn;
  final DateTime checkOut;
  final DateFormat dateFmt;
  final VoidCallback onTap;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border),
        ),
        child: Row(children: [
          Icon(Icons.date_range_outlined,
              size: 15, color: colors.textSecondary),
          const SizedBox(width: 8),
          Text(
            dateFmt.format(checkIn),
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward,
                size: 14, color: colors.textSecondary),
          ),
          Text(
            dateFmt.format(checkOut),
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
              .map((r) => DropdownMenuItem(value: r.id, child: Text(r.name)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _TypeDropdown extends StatelessWidget {
  const _TypeDropdown({
    required this.types,
    required this.selectedId,
    required this.onChanged,
    required this.colors,
  });
  final List<BookingType> types;
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
          hint: Text('Select type',
              style: TextStyle(color: colors.textHint, fontSize: 14)),
          dropdownColor: colors.surface,
          style: TextStyle(color: colors.textPrimary, fontSize: 14),
          iconEnabledColor: colors.textSecondary,
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text('— Not specified —',
                  style: TextStyle(color: colors.textHint)),
            ),
            ...types.map((t) =>
                DropdownMenuItem<String>(value: t.id, child: Text(t.name))),
          ],
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
    required this.selectedTypeId,
    required this.onChanged,
    required this.colors,
  });
  final List<BookingSource> sources;
  final String? selectedId;
  final String? selectedTypeId;
  final ValueChanged<String?>? onChanged;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onChanged != null && sources.isNotEmpty;
    final validId = sources.any((s) => s.id == selectedId) ? selectedId : null;
    final disabledText = selectedTypeId == null
        ? '— Select type first —'
        : '— None available —';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: isEnabled ? validId : null,
          isExpanded: true,
          hint: Text('Select source',
              style: TextStyle(color: colors.textHint, fontSize: 14)),
          disabledHint: Text(disabledText,
              style: TextStyle(color: colors.textHint, fontSize: 13)),
          dropdownColor: colors.surface,
          style: TextStyle(color: colors.textPrimary, fontSize: 14),
          iconEnabledColor: colors.textSecondary,
          iconDisabledColor: colors.textHint,
          items: isEnabled
              ? sources
                  .map((s) =>
                      DropdownMenuItem(value: s.id, child: Text(s.name)))
                  .toList()
              : null,
          onChanged: isEnabled ? onChanged : null,
        ),
      ),
    );
  }
}
