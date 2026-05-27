import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/booking_source.dart';
import '../../../shared/models/booking_type.dart';
import '../../../shared/models/room.dart';
import '../../../shared/widgets/app_date_picker.dart';
import '../../../shared/widgets/app_dropdown_field.dart';
import '../../../shared/widgets/app_text_field.dart';

class WizardStep4Review extends StatefulWidget {
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
    required this.onCheckInChanged,
    required this.onCheckOutChanged,
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
  final ValueChanged<DateTime> onCheckInChanged;
  final ValueChanged<DateTime> onCheckOutChanged;
  final ValueChanged<String?> onTypeSelected;
  final ValueChanged<String?> onSourceChanged;
  final VoidCallback onSave;
  final bool isBusy;
  final bool isEditMode;
  final VoidCallback? onUpdatePayment;
  final bool paymentAlreadyReceived;
  final double? overrideNetAmount;

  @override
  State<WizardStep4Review> createState() => _WizardStep4ReviewState();
}

class _WizardStep4ReviewState extends State<WizardStep4Review> {
  bool _bookingDetailsExpanded = false;
  bool _paymentExpanded = false;

  static final _amountFmt = NumberFormat('#,##0.##');

  // ── Computed properties ───────────────────────────────────────────────────

  int get _nightCount {
    final inDate  = DateTime(widget.checkIn.year,  widget.checkIn.month,  widget.checkIn.day);
    final outDate = DateTime(widget.checkOut.year, widget.checkOut.month, widget.checkOut.day);
    return outDate.difference(inDate).inDays;
  }

  bool get _isSameDay =>
      widget.checkIn.year  == widget.checkOut.year  &&
      widget.checkIn.month == widget.checkOut.month &&
      widget.checkIn.day   == widget.checkOut.day;

  // Day-use counts as 1 slot so save is enabled and per-use amount is correct
  int get _slotCount => _isSameDay ? 1 : _nightCount;

  double get _grossAmount =>
      double.tryParse(widget.grossAmountController.text.replaceAll(',', '')) ?? 0;

  double get _perNight => _slotCount > 0 ? _grossAmount / _slotCount : 0;

  double get _commissionAmount =>
      double.tryParse(widget.commissionController.text.replaceAll(',', '')) ?? 0;

  double get _tdsTcsAmount =>
      double.tryParse(widget.tdsTcsController.text.replaceAll(',', '')) ?? 0;

  double get _netAmount =>
      widget.overrideNetAmount ?? (_grossAmount - _commissionAmount - _tdsTcsAmount);

  bool get _canSave =>
      _grossAmount > 0 && _slotCount > 0 && widget.selectedRoomId != null;

  bool get _isOtaType {
    if (widget.selectedTypeId == null) return false;
    final idx = widget.types.indexWhere((t) => t.id == widget.selectedTypeId);
    if (idx == -1) return false;
    return widget.types[idx].name.toLowerCase().contains('ota');
  }

  List<BookingSource> get _filteredSources {
    if (widget.selectedTypeId == null) return [];
    return widget.allSources
        .where((s) => s.bookingTypeId == widget.selectedTypeId && s.isActive)
        .toList();
  }

  // ── Name lookups for collapsed summaries ─────────────────────────────────

  String? get _typeName {
    if (widget.selectedTypeId == null) return null;
    final idx = widget.types.indexWhere((t) => t.id == widget.selectedTypeId);
    return idx == -1 ? null : widget.types[idx].name;
  }

  String? get _sourceName {
    if (widget.selectedSourceId == null) return null;
    final idx = widget.allSources.indexWhere((s) => s.id == widget.selectedSourceId);
    return idx == -1 ? null : widget.allSources[idx].name;
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  // ── Collapsed summary parts ───────────────────────────────────────────────

  List<String> get _bookingDetailsParts {
    final parts = <String>[];
    final type = _typeName;
    if (type != null) parts.add(type);
    final source = _sourceName;
    if (source != null) parts.add(source);
    final customer = widget.customerNameController.text.trim();
    if (customer.isNotEmpty) parts.add(customer);
    return parts;
  }

  List<String> get _paymentParts {
    if (_grossAmount <= 0) return [];
    return [
      '₹${_amountFmt.format(_grossAmount)} gross',
      '₹${_amountFmt.format(_netAmount)} net',
      if (_slotCount > 0)
        '₹${_amountFmt.format(_perNight)} / ${_isSameDay ? "use" : "night"}',
    ];
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
                  items: widget.rooms
                      .map((r) => AppDropdownItem(value: r.id, label: r.name))
                      .toList(),
                  value: widget.selectedRoomId,
                  onChanged: widget.onRoomChanged,
                ),
                const SizedBox(height: 16),
                AppDatePicker(
                  label: 'Booking date & time',
                  selectedDate: widget.bookingDate,
                  onDateSelected: widget.onBookingDateChanged,
                  includeTime: true,
                  firstDate: today.subtract(const Duration(days: 365)),
                  lastDate: today.add(const Duration(days: 30)),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AppDatePicker(
                        label: 'Check-in',
                        selectedDate: widget.checkIn,
                        onDateSelected: widget.onCheckInChanged,
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
                        selectedDate: widget.checkOut,
                        onDateSelected: widget.onCheckOutChanged,
                        includeTime: true,
                        firstDate: today.subtract(const Duration(days: 365)),
                        lastDate: today.add(const Duration(days: 730)),
                        dateFormatter: (dt) => DateFormat('d MMM, h:mm a').format(dt),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _NightsSummary(
                  isSameDay: _isSameDay,
                  nightCount: _nightCount,
                  colors: colors,
                ),

                // ── BOOKING DETAILS (accordion) ───────────────────
                const SizedBox(height: 28),
                _SectionHeader(
                  title: 'Booking details',
                  colors: colors,
                  isExpanded: _bookingDetailsExpanded,
                  onTap: () => setState(
                      () => _bookingDetailsExpanded = !_bookingDetailsExpanded),
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 200),
                  sizeCurve: Curves.easeInOut,
                  crossFadeState: _bookingDetailsExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: _CollapsedSummary(
                    parts: _bookingDetailsParts,
                    colors: colors,
                  ),
                  secondChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: AppDropdownField<String?>(
                              label: 'Booking type *',
                              items: widget.types
                                  .map((t) =>
                                      AppDropdownItem(value: t.id, label: t.name))
                                  .toList(),
                              value: widget.selectedTypeId,
                              onChanged: widget.onTypeSelected,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppDropdownField<String>(
                              label: 'Booking source',
                              items: filteredSources
                                  .map((s) =>
                                      AppDropdownItem(value: s.id, label: s.name))
                                  .toList(),
                              value: filteredSources
                                      .any((s) => s.id == widget.selectedSourceId)
                                  ? widget.selectedSourceId
                                  : null,
                              enabled: filteredSources.isNotEmpty,
                              hintText: widget.selectedTypeId == null
                                  ? 'Select type first'
                                  : 'None available',
                              onChanged: widget.onSourceChanged,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: widget.customerNameController,
                        label: 'Customer name (optional)',
                        textCapitalization: TextCapitalization.words,
                      ),
                      if (_isOtaType) ...[
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: widget.stayFlexiBookingIdController,
                                label: 'Stay Flexi ID (optional)',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppTextField(
                                controller: widget.otaBookingIdController,
                                label: 'OTA booking ID (optional)',
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                    ],
                  ),
                ),

                // ── PAYMENT (accordion) ───────────────────────────
                const SizedBox(height: 20),
                _SectionHeader(
                  title: 'Payment',
                  colors: colors,
                  isExpanded: _paymentExpanded,
                  onTap: () =>
                      setState(() => _paymentExpanded = !_paymentExpanded),
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 200),
                  sizeCurve: Curves.easeInOut,
                  crossFadeState: _paymentExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: _CollapsedSummary(
                    parts: _paymentParts,
                    colors: colors,
                  ),
                  secondChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: widget.grossAmountController,
                              label: 'Gross amount (₹)',
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              prefixText: '₹ ',
                              fontSize: 15,
                            ),
                          ),
                          if (_grossAmount > 0) ...[
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
                                _isSameDay
                                    ? '₹${_amountFmt.format(_perNight)} / use'
                                    : '₹${_amountFmt.format(_perNight)} / night',
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
                            child: AppTextField(
                              controller: widget.taxAmountController,
                              label: 'Tax (₹, optional)',
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              prefixText: '₹ ',
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              controller: widget.tdsTcsController,
                              label: 'TDS & TCS (₹, optional)',
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              prefixText: '₹ ',
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: widget.commissionController,
                        label: 'Commission incl. taxes (₹, optional)',
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
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
                              if (widget.onUpdatePayment != null)
                                TextButton(
                                  onPressed: widget.onUpdatePayment,
                                  style: TextButton.styleFrom(
                                    foregroundColor: colors.success,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    textStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  child: Text(widget.paymentAlreadyReceived
                                      ? 'Payment Status'
                                      : 'Update Receival'),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                    ],
                  ),
                ),

                // ── NOTES ────────────────────────────────────────
                const SizedBox(height: 20),
                AppTextField(
                  controller: widget.notesController,
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
              onPressed: _canSave && !widget.isBusy ? widget.onSave : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: widget.isBusy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.isEditMode ? 'Save changes' : 'Save booking',
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

class _CollapsedSummary extends StatelessWidget {
  const _CollapsedSummary({required this.parts, required this.colors});

  final List<String> parts;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final text = parts.isEmpty ? '—' : parts.join('  ·  ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          color: colors.textSecondary,
        ),
      ),
    );
  }
}

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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.colors,
    this.isExpanded,
    this.onTap,
  });

  final String title;
  final AppColors colors;
  final bool? isExpanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const Spacer(),
          if (isExpanded != null)
            AnimatedRotation(
              turns: isExpanded! ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: colors.textSecondary,
              ),
            ),
        ],
      ),
    );

    if (onTap == null) return content;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}
