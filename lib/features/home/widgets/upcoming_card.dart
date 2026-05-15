import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/booking_group.dart';

class UpcomingCard extends StatelessWidget {
  const UpcomingCard({
    super.key,
    required this.date,
    required this.groups,
    required this.today,
    required this.resolveRoomName,
    required this.resolveSourceName,
    required this.onTap,
  });

  final DateTime date;
  final List<BookingGroup> groups;
  final DateTime today;
  final String Function(String roomId) resolveRoomName;
  final String? Function(String? sourceId) resolveSourceName;
  final void Function(String groupId) onTap;

  String _dateHeader() {
    final tomorrow = today.add(const Duration(days: 1));
    final dayAfter = today.add(const Duration(days: 2));
    final dayLabel = DateFormat('d MMM').format(date).toUpperCase();
    if (date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day) {
      return 'TOMORROW · $dayLabel';
    }
    if (date.year == dayAfter.year &&
        date.month == dayAfter.month &&
        date.day == dayAfter.day) {
      return 'DAY AFTER · $dayLabel';
    }
    return dayLabel;
  }

  static final _amtFmt = NumberFormat('#,##0.##');

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _dateHeader(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: colors.accent,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          ...groups.map((g) {
            final roomName = resolveRoomName(g.roomId);
            final sourceName = resolveSourceName(g.bookingSourceId);
            final nights = g.nights;
            return GestureDetector(
              onTap: () => onTap(g.id),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        sourceName != null
                            ? '$roomName · $sourceName'
                            : roomName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$nights ${nights == 1 ? 'night' : 'nights'}  '
                      '₹${_amtFmt.format(g.totalAmount)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
