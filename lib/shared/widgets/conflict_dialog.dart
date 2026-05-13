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
              '${conflicts.first.roomName} already has bookings on:',
              style: TextStyle(fontSize: 13, color: colors.textPrimary),
            ),
            const SizedBox(height: 8),
            ...conflicts.map((c) => Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Row(children: [
                    Icon(Icons.circle, size: 5, color: colors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      dateFmt.format(c.date),
                      style: TextStyle(
                          fontSize: 13, color: colors.textSecondary),
                    ),
                  ]),
                )),
            const SizedBox(height: 8),
            Text(
              'Saving will overwrite these dates.',
              style: TextStyle(fontSize: 13, color: colors.textSecondary),
            ),
            const SizedBox(height: 24),
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
