import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/booking_group.dart';

class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.group,
    required this.roomName,
    this.sourceName,
    required this.onTap,
  });

  final BookingGroup group;
  final String roomName;
  final String? sourceName;
  final VoidCallback onTap;

  static final _amtFmt = NumberFormat('#,##0.##');

  static String _dateRange(DateTime checkIn, DateTime checkOut, int nights) {
    final inFmt = DateFormat('MMM d');
    final sameMonth = checkIn.month == checkOut.month &&
        checkIn.year == checkOut.year;
    final outStr = sameMonth
        ? DateFormat('d').format(checkOut)
        : DateFormat('MMM d').format(checkOut);
    final label = nights == 1 ? 'night' : 'nights';
    return '${inFmt.format(checkIn)} → $outStr · $nights $label';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final nights = group.nights;
    final paid = group.paymentReceived;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    roomName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '₹${_amtFmt.format(group.totalAmount)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _dateRange(group.checkIn, group.checkOut, nights),
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                if (sourceName != null) ...[
                  _Pill(
                    label: sourceName!,
                    bg: colors.accentSubtle,
                    fg: colors.accent,
                  ),
                  const SizedBox(width: 6),
                ],
                _Pill(
                  label: paid ? 'Paid' : 'Pending',
                  bg: paid ? colors.successSubtle : colors.warningSubtle,
                  fg: paid ? colors.success : colors.warning,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }
}
