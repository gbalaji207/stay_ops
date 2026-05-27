import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/booking_source.dart';
import '../../../shared/models/booking_type.dart';
import '../../../shared/widgets/app_date_picker.dart';
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
    required this.onCheckInChanged,
    required this.onCheckOutChanged,
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
  final ValueChanged<DateTime> onCheckInChanged;
  final ValueChanged<DateTime> onCheckOutChanged;
  final ValueChanged<String?> onTypeSelected;
  final ValueChanged<String?> onSourceChanged;
  final VoidCallback onNext;

  // ── Computed properties ───────────────────────────────────────────────────

  bool get _isSameDay =>
      checkIn.year  == checkOut.year  &&
      checkIn.month == checkOut.month &&
      checkIn.day   == checkOut.day;

  int get _nightCount {
    final inDate  = DateTime(checkIn.year,  checkIn.month,  checkIn.day);
    final outDate = DateTime(checkOut.year, checkOut.month, checkOut.day);
    return outDate.difference(inDate).inDays;
  }

  // Booking type is mandatory + checkOut must not be before checkIn
  bool get _canNext =>
      selectedTypeId != null && !checkOut.isBefore(checkIn);

  // OTA type: show Stay Flexi / OTA booking ID fields
  bool get _isOtaType {
    if (selectedTypeId == null) return false;
    final idx = types.indexWhere((t) => t.id == selectedTypeId);
    if (idx == -1) return false;
    return types[idx].name.toLowerCase().contains('ota');
  }

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
        20, // ← extra top padding
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
          // ── Check-in & Check-out side by side ─────────────────────────
          Row(
            children: [
              Expanded(
                child: AppDatePicker(
                  label: 'Check-in',
                  selectedDate: checkIn,
                  onDateSelected: onCheckInChanged,
                  includeTime: true,
                  firstDate: today.subtract(const Duration(days: 365)),
                  lastDate: today.add(const Duration(days: 730)),
                  dateFormatter: (dt) => DateFormat('d MMM, h:mm a').format(dt),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppDatePicker(
                  label: 'Check-out',
                  selectedDate: checkOut,
                  onDateSelected: onCheckOutChanged,
                  includeTime: true,
                  firstDate: today.subtract(const Duration(days: 365)),
                  lastDate: today.add(const Duration(days: 730)),
                  dateFormatter: (dt) => DateFormat('d MMM, h:mm a').format(dt),
                ),
              ),
            ],
          ),
          // ── Nights / Day-use summary (full width) ─────────────────────
          const SizedBox(height: 8),
          _NightsSummary(
            isSameDay: _isSameDay,
            nightCount: _nightCount,
            colors: colors,
          ),
          const SizedBox(height: 16),
          // ── Booking type (mandatory) & source ─────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppDropdownField<String?>(
                  label: 'Booking type *',
                  items: types
                      .map((t) => AppDropdownItem(value: t.id, label: t.name))
                      .toList(),
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
          // ── OTA-only fields ────────────────────────────────────────────
          if (_isOtaType) ...[
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
          ],
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

// ── Nights / Day-use summary ──────────────────────────────────────────────────

class _NightsSummary extends StatelessWidget {
  const _NightsSummary({
    required this.isSameDay,
    required this.nightCount,
    required this.colors,
  });

  final bool isSameDay;
  final int nightCount;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final label = isSameDay
        ? 'Day Use'
        : '$nightCount night${nightCount == 1 ? '' : 's'}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.accentSubtle,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colors.accent,
        ),
      ),
    );
  }
}
