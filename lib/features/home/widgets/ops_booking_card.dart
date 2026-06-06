import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/booking_group.dart';

class OpsBookingCard extends StatelessWidget {
  const OpsBookingCard({
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

  static final _dateFmt = DateFormat('d MMM');
  static final _timeFmt = DateFormat('HH:mm');

  String _formatDatetime(DateTime? dt, DateTime fallback) {
    if (dt != null) {
      return '${_dateFmt.format(dt)}, ${_timeFmt.format(dt)}';
    }
    return _dateFmt.format(fallback);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    final checkInStr = _formatDatetime(group.checkInDatetime, group.checkIn);
    final checkOutStr =
        _formatDatetime(group.checkOutDatetime, group.checkOut);
    final customer = (group.customerName?.trim().isNotEmpty ?? false)
        ? group.customerName!
        : 'Guest';

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
            // Row 1: customer name + source avatar/pill
            Row(
              children: [
                Expanded(
                  child: Text(
                    customer,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (sourceName != null) ...[
                  const SizedBox(width: 8),
                  _SourceBadge(name: sourceName!, colors: colors),
                ],
              ],
            ),
            const SizedBox(height: 6),
            // Row 2: room name
            Row(
              children: [
                Icon(Icons.meeting_room_outlined,
                    size: 13, color: colors.textHint),
                const SizedBox(width: 4),
                Text(
                  roomName,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            // Row 3: check-in → check-out times
            Row(
              children: [
                Icon(Icons.login_rounded, size: 13, color: colors.success),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    checkInStr,
                    style:
                        TextStyle(fontSize: 12, color: colors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 11, color: colors.textHint),
                ),
                Icon(Icons.logout_rounded, size: 13, color: colors.danger),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    checkOutStr,
                    style:
                        TextStyle(fontSize: 12, color: colors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows an OTA logo for known sources, or a styled text pill for others.
class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.name, required this.colors});

  final String name;
  final AppColors colors;

  static const Map<String, String> _assets = {
    'makemytrip': 'assets/images/go-mmt.png',
    'mmt': 'assets/images/go-mmt.png',
    'go-mmt': 'assets/images/go-mmt.png',
    'goibibo': 'assets/images/goibibo.png',
    'agoda': 'assets/images/agoda.png',
    'airbnb': 'assets/images/airbnb.png',
  };

  @override
  Widget build(BuildContext context) {
    final key = name.toLowerCase().trim();
    final assetPath = _assets[key];

    if (assetPath != null) {
      // Known OTA: logo inside a white rounded square
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colors.border),
        ),
        alignment: Alignment.center,
        child: Image.asset(
          assetPath,
          width: 18,
          height: 18,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _fallbackPill(),
        ),
      );
    }

    return _fallbackPill();
  }

  Widget _fallbackPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colors.accentSubtle,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: colors.accent,
        ),
      ),
    );
  }
}
