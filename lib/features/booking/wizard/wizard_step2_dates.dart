import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/booking_source.dart';
import '../../../shared/models/booking_type.dart';
import '../../../shared/widgets/app_date_picker.dart';
import '../../../shared/widgets/app_date_range_picker.dart';
import '../../../shared/widgets/app_dropdown_field.dart';
import '../../../shared/widgets/app_text_field.dart';

class WizardStep2Details extends StatelessWidget {
  const WizardStep2Details({
    super.key,
    required this.bookingDate,
    required this.checkIn,
    required this.checkOut,
    required this.types,
    required this.allSources,
    required this.selectedTypeId,
    required this.selectedSourceId,
    required this.customerNameController,
    required this.stayFlexiBookingIdController,
    required this.otaBookingIdController,
    required this.onBookingDateChanged,
    required this.onStayRangeChanged,
    required this.onTypeSelected,
    required this.onSourceChanged,
    required this.onNext,
  });

  final DateTime bookingDate;
  final DateTime checkIn;
  final DateTime checkOut;
  final List<BookingType> types;
  final List<BookingSource> allSources;
  final String? selectedTypeId;
  final String? selectedSourceId;
  final TextEditingController customerNameController;
  final TextEditingController stayFlexiBookingIdController;
  final TextEditingController otaBookingIdController;
  final ValueChanged<DateTime> onBookingDateChanged;
  final void Function(DateTime checkIn, DateTime checkOut) onStayRangeChanged;
  final ValueChanged<String?> onTypeSelected;
  final ValueChanged<String?> onSourceChanged;
  final VoidCallback onNext;

  int get _nightCount => checkOut.difference(checkIn).inDays;
  bool get _canNext => _nightCount > 0;

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
          const SizedBox(height: 16),
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
                      .map((s) => AppDropdownItem(value: s.id, label: s.name))
                      .toList(),
                  value: filteredSources.any((s) => s.id == selectedSourceId)
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
            hintText: 'e.g. John Smith',
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  controller: stayFlexiBookingIdController,
                  label: 'Stay Flexi ID (optional)',
                  hintText: 'e.g. SF-123456',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  controller: otaBookingIdController,
                  label: 'OTA booking ID (optional)',
                  hintText: 'e.g. MMT-987654',
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _canNext ? onNext : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
}
