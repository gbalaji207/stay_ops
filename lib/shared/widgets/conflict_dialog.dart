import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../features/booking/booking_repository.dart';

class ConflictDialog extends StatelessWidget {
  const ConflictDialog({
    super.key,
    required this.conflicts,
    required this.onCancel,
    required this.onConfirm,
  });

  final List<ConflictInfo> conflicts;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  static String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final dateFmt = DateFormat('d MMM');

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Row(children: [
              Icon(Icons.warning_amber_rounded,
                  color: colors.warning, size: 22),
              const SizedBox(width: 8),
              Text(
                'Booking conflict',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Text(
              '${conflicts.first.roomName} already has bookings:',
              style: TextStyle(fontSize: 13, color: colors.textPrimary),
            ),
            const SizedBox(height: 8),

            // ── Conflict list ───────────────────────────────────────────────
            ...conflicts.map((c) {
              final isDayUse = c.checkIn.year == c.checkOut.year &&
                  c.checkIn.month == c.checkOut.month &&
                  c.checkIn.day == c.checkOut.day;

              // Date / time line
              String dateLabel;
              if (isDayUse) {
                dateLabel = dateFmt.format(c.checkIn);
                if (c.checkInDatetime != null && c.checkOutDatetime != null) {
                  dateLabel +=
                      ' · ${_fmtTime(c.checkInDatetime!)} – ${_fmtTime(c.checkOutDatetime!)}';
                }
                dateLabel += ' (Day Use)';
              } else {
                dateLabel =
                    '${dateFmt.format(c.checkIn)} → ${dateFmt.format(c.checkOut)}';
              }

              // Secondary detail line: type · source · customer
              final detailParts = <String>[
                if (c.bookingTypeName?.isNotEmpty == true) c.bookingTypeName!,
                if (c.bookingSourceName?.isNotEmpty == true)
                  c.bookingSourceName!,
                if (c.customerName?.isNotEmpty == true) c.customerName!,
              ];
              final detailLine =
                  detailParts.isEmpty ? null : detailParts.join(' · ');

              return Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Icon(Icons.circle,
                          size: 5, color: colors.textSecondary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateLabel,
                            style: TextStyle(
                                fontSize: 13, color: colors.textSecondary),
                          ),
                          if (detailLine != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              detailLine,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textSecondary
                                    .withValues(alpha: 0.65),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 8),
            Text(
              'Saving will overwrite these bookings.',
              style: TextStyle(fontSize: 13, color: colors.textSecondary),
            ),
            const SizedBox(height: 24),

            // ── Actions ─────────────────────────────────────────────────────
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onConfirm,
                  style: FilledButton.styleFrom(
                      backgroundColor: colors.danger),
                  child: const Text('Overwrite'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
