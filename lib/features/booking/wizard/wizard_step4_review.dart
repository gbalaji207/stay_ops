import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/booking_source.dart';
import '../../../shared/models/booking_type.dart';
import '../../../shared/models/room.dart';
import '../../../shared/widgets/app_date_picker.dart';
import '../../../shared/widgets/app_date_range_picker.dart';
import '../../../shared/widgets/app_dropdown_field.dart';
import '../../../shared/widgets/app_text_field.dart';

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
    this.onUpdatePayment,
    this.paymentAlreadyReceived = false,
    this.overrideNetAmount,
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
  final VoidCallback? onUpdatePayment;
  final bool paymentAlreadyReceived;
  final double? overrideNetAmount;

  static final _amountFmt = NumberFormat('#,##0.##');

  int get _nightCount => checkOut.difference(checkIn).inDays;

  double get _grossAmount =>
      double.tryParse(grossAmountController.text.replaceAll(',', '')) ?? 0;

  double get _perNight => _nightCount > 0 ? _grossAmount / _nightCount : 0;

  double get _commissionAmount =>
      double.tryParse(commissionController.text.replaceAll(',', '')) ?? 0;

  double get _tdsTcsAmount =>
      double.tryParse(tdsTcsController.text.replaceAll(',', '')) ?? 0;

  double get _netAmount =>
      overrideNetAmount ?? (_grossAmount - _commissionAmount - _tdsTcsAmount);

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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final filteredSources = _filteredSources;
    final today = _today();

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
                AppDropdownField<String>(
                  label: 'Room',
                  items: rooms
                      .map((r) => AppDropdownItem(value: r.id, label: r.name))
                      .toList(),
                  value: selectedRoomId,
                  onChanged: onRoomChanged,
                ),
                const SizedBox(height: 16),
                AppDatePicker(
                  label: 'Booking date & time',
                  selectedDate: bookingDate,
                  onDateSelected: onBookingDateChanged,
                  includeTime: true,
                  firstDate: today.subtract(const Duration(days: 365)),
                  lastDate: today.add(const Duration(days: 30)),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AppDateRangePicker(
                        label: 'Stay dates',
                        checkIn: checkIn,
                        checkOut: checkOut,
                        onRangeSelected: onStayRangeChanged,
                        firstDate: today.subtract(const Duration(days: 365)),
                        lastDate: today.add(const Duration(days: 730)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
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
                  ],
                ),

                // ── BOOKING DETAILS ───────────────────────────────
                const SizedBox(height: 28),
                _SectionHeader(title: 'Booking details', colors: colors),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppDropdownField<String?>(
                        label: 'Booking type',
                        items: [
                          const AppDropdownItem(
                            value: null,
                            label: '— Not specified —',
                          ),
                          ...types.map(
                            (t) => AppDropdownItem(value: t.id, label: t.name),
                          ),
                        ],
                        value: selectedTypeId,
                        onChanged: onTypeSelected,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppDropdownField<String>(
                        label: 'Booking source',
                        items: filteredSources
                            .map(
                              (s) =>
                                  AppDropdownItem(value: s.id, label: s.name),
                            )
                            .toList(),
                        value:
                            filteredSources.any((s) => s.id == selectedSourceId)
                            ? selectedSourceId
                            : null,
                        enabled: filteredSources.isNotEmpty,
                        hintText: selectedTypeId == null
                            ? 'Select type first'
                            : 'None available',
                        onChanged: onSourceChanged,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: customerNameController,
                  label: 'Customer name (optional)',
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppTextField(
                            controller: stayFlexiBookingIdController,
                            label: 'Stay Flexi ID (optional)',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppTextField(
                            controller: otaBookingIdController,
                            label: 'OTA booking ID (optional)',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ── PAYMENT ──────────────────────────────────────
                const SizedBox(height: 28),
                _SectionHeader(title: 'Payment', colors: colors),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: grossAmountController,
                        label: 'Gross amount (₹)',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        prefixText: '₹ ',
                        fontSize: 15,
                      ),
                    ),
                    if (_grossAmount > 0 && _nightCount > 0) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accentSubtle,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '₹${_amountFmt.format(_perNight)} / night',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colors.accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppTextField(
                            controller: taxAmountController,
                            label: 'Tax (₹, optional)',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            prefixText: '₹ ',
                            fontSize: 15,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppTextField(
                            controller: tdsTcsController,
                            label: 'TDS & TCS (₹, optional)',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            prefixText: '₹ ',
                            fontSize: 15,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: commissionController,
                  label: 'Commission incl. taxes (₹, optional)',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  prefixText: '₹ ',
                  fontSize: 15,
                ),
                if (_grossAmount > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.only(
                      left: 14,
                      right: 4,
                      top: 4,
                      bottom: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.successSubtle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Net amount',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colors.success,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '₹${_amountFmt.format(_netAmount)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.success,
                          ),
                        ),
                        const Spacer(),
                        if (onUpdatePayment != null)
                          TextButton(
                            onPressed: onUpdatePayment,
                            style: TextButton.styleFrom(
                              foregroundColor: colors.success,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: Text(paymentAlreadyReceived
                                ? 'Payment Status'
                                : 'Update Receival'),
                          ),
                      ],
                    ),
                  ),
                ],

                // ── NOTES ────────────────────────────────────────
                const SizedBox(height: 28),
                AppTextField(
                  controller: notesController,
                  label: 'Notes',
                  maxLines: 3,
                  fontSize: 13,
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
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isBusy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      isEditMode ? 'Save changes' : 'Save booking',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ],
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
