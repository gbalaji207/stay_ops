import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';

class WizardStep2Dates extends StatelessWidget {
  const WizardStep2Dates({
    super.key,
    required this.bookingDate,
    required this.checkIn,
    required this.checkOut,
    required this.amountController,
    required this.onBookingDateChanged,
    required this.onStayRangeChanged,
    required this.onNext,
  });

  final DateTime bookingDate;
  final DateTime checkIn;
  final DateTime checkOut;
  final TextEditingController amountController;
  final ValueChanged<DateTime> onBookingDateChanged;
  final void Function(DateTime checkIn, DateTime checkOut) onStayRangeChanged;
  final VoidCallback onNext;

  static final _amountFmt = NumberFormat('#,##0.##');

  int get _nightCount => checkOut.difference(checkIn).inDays;
  double get _totalAmount =>
      double.tryParse(amountController.text.replaceAll(',', '')) ?? 0;
  double get _perNight => _nightCount > 0 ? _totalAmount / _nightCount : 0;
  bool get _canNext => _totalAmount > 0 && _nightCount > 0;

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickBookingDate(BuildContext context) async {
    final today = _today();
    final picked = await showDatePicker(
      context: context,
      initialDate: bookingDate,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 30)),
    );
    if (picked == null || !context.mounted) return;
    onBookingDateChanged(picked);
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

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(text: 'Booking date', colors: colors),
          const SizedBox(height: 6),
          _DateTile(
            label: dateFmt.format(bookingDate),
            onTap: () => _pickBookingDate(context),
            colors: colors,
          ),
          const SizedBox(height: 20),
          _FieldLabel(text: 'Stay dates', colors: colors),
          const SizedBox(height: 6),
          _DateRangeTile(
            checkIn: checkIn,
            checkOut: checkOut,
            dateFmt: dateFmt,
            onTap: () => _pickStayRange(context),
            colors: colors,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          const SizedBox(height: 20),
          _FieldLabel(text: 'Total amount (₹)', colors: colors),
          const SizedBox(height: 6),
          TextField(
            controller: amountController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: colors.textPrimary, fontSize: 15),
            decoration: _inputDecoration(
              colors: colors,
              hint: '0',
              prefix: '₹ ',
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _canNext ? onNext : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Next',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
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
    required this.onTap,
    required this.colors,
  });
  final String label;
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
          Icon(Icons.calendar_today_outlined,
              size: 15, color: colors.textSecondary),
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
