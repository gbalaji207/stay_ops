import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_text_field.dart';

/// Tappable date-range field styled like [AppTextField] with a floating label.
///
/// Displays check-in → check-out as a single text value and opens
/// [showDateRangePicker] on tap.
class AppDateRangePicker extends StatefulWidget {
  const AppDateRangePicker({
    super.key,
    required this.label,
    required this.checkIn,
    required this.checkOut,
    this.onRangeSelected,
    this.firstDate,
    this.lastDate,
    this.enabled = true,
  });

  final String label;
  final DateTime checkIn;
  final DateTime checkOut;
  final void Function(DateTime checkIn, DateTime checkOut)? onRangeSelected;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool enabled;

  @override
  State<AppDateRangePicker> createState() => _AppDateRangePickerState();
}

class _AppDateRangePickerState extends State<AppDateRangePicker> {
  static final _fmt = DateFormat('d MMM');
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format());
  }

  @override
  void didUpdateWidget(AppDateRangePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.checkIn != oldWidget.checkIn ||
        widget.checkOut != oldWidget.checkOut) {
      _controller.text = _format();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _format() =>
      '${_fmt.format(widget.checkIn)}  →  ${_fmt.format(widget.checkOut)}';

  Future<void> _pick() async {
    if (!widget.enabled) return;

    final now = DateTime.now();
    final first =
        widget.firstDate ?? DateTime(now.year - 1, now.month, now.day);
    final last =
        widget.lastDate ?? DateTime(now.year + 2, now.month, now.day);

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange:
          DateTimeRange(start: widget.checkIn, end: widget.checkOut),
      firstDate: first,
      lastDate: last,
    );
    if (picked == null || !mounted) return;

    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    FocusScope.of(context).unfocus();

    widget.onRangeSelected?.call(picked.start, picked.end);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.enabled ? _pick : null,
      child: AbsorbPointer(
        child: AppTextField(
          controller: _controller,
          label: widget.label,
          enabled: widget.enabled,
          suffixIcon: const Icon(Icons.date_range_outlined, size: 18),
        ),
      ),
    );
  }
}
