import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_text_field.dart';

/// Tappable date (optionally date+time) field styled like [AppTextField].
///
/// Wraps [showDatePicker] (and optionally [showTimePicker]) behind an
/// [AbsorbPointer] + [GestureDetector] so the keyboard never appears.
class AppDatePicker extends StatefulWidget {
  const AppDatePicker({
    super.key,
    required this.label,
    this.hintText,
    this.controller,
    this.selectedDate,
    this.onDateSelected,
    this.firstDate,
    this.lastDate,
    this.enabled = true,
    this.includeTime = false,
    this.dateFormatter,
  });

  final String label;
  final String? hintText;

  /// Optional external controller. If omitted one is managed internally.
  final TextEditingController? controller;

  final DateTime? selectedDate;
  final ValueChanged<DateTime>? onDateSelected;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool enabled;

  /// When true, a [showTimePicker] follows the date picker and the formatted
  /// value includes hours and minutes.
  final bool includeTime;

  /// Override the display format. Receives the picked [DateTime].
  final String Function(DateTime)? dateFormatter;

  @override
  State<AppDatePicker> createState() => _AppDatePickerState();
}

class _AppDatePickerState extends State<AppDatePicker> {
  late final TextEditingController _controller;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _selectedDate = widget.selectedDate;
    if (_selectedDate != null) _controller.text = _format(_selectedDate!);
  }

  @override
  void didUpdateWidget(AppDatePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate &&
        widget.selectedDate != _selectedDate) {
      _selectedDate = widget.selectedDate;
      _controller.text =
          _selectedDate != null ? _format(_selectedDate!) : '';
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  String _format(DateTime date) {
    if (widget.dateFormatter != null) return widget.dateFormatter!(date);
    return widget.includeTime
        ? DateFormat('d MMM yyyy, HH:mm').format(date)
        : DateFormat('d MMM yyyy').format(date);
  }

  Future<void> _pick() async {
    if (!widget.enabled) return;

    final now = DateTime.now();
    final first = widget.firstDate ?? DateTime(now.year - 100);
    final last = widget.lastDate ?? now;
    final initial = (_selectedDate != null &&
            !_selectedDate!.isBefore(first) &&
            !_selectedDate!.isAfter(last))
        ? _selectedDate!
        : last;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (pickedDate == null || !mounted) return;

    DateTime picked = pickedDate;

    if (widget.includeTime) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _selectedDate != null
            ? TimeOfDay(
                hour: _selectedDate!.hour, minute: _selectedDate!.minute)
            : TimeOfDay.now(),
      );
      if (!mounted) return;
      final t = pickedTime ?? TimeOfDay.now();
      picked = DateTime(
          pickedDate.year, pickedDate.month, pickedDate.day, t.hour, t.minute);
    }

    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _selectedDate = picked;
      _controller.text = _format(picked);
    });
    widget.onDateSelected?.call(picked);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.enabled ? _pick : null,
      child: AbsorbPointer(
        child: AppTextField(
          controller: _controller,
          label: widget.label,
          hintText: widget.hintText ?? 'Select date',
          enabled: widget.enabled,
          suffixIcon: Icon(
            widget.includeTime
                ? Icons.schedule_outlined
                : Icons.calendar_month_outlined,
            size: 18,
          ),
        ),
      ),
    );
  }
}
