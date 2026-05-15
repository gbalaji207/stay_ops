import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/occupancy_snapshot.dart';

class OccupancyStrip extends StatelessWidget {
  const OccupancyStrip({super.key, required this.snapshot});

  final OccupancySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final total = snapshot.occupied + snapshot.vacant;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _Block(
                label: 'Occupied',
                value: snapshot.occupied.toString(),
                color: colors.success,
                fraction: total > 0 ? snapshot.occupied / total : 0,
                showBar: true,
              ),
            ),
            VerticalDivider(color: colors.border, width: 1, thickness: 1),
            Expanded(
              child: _Block(
                label: 'Vacant',
                value: snapshot.vacant.toString(),
                color: colors.danger,
                fraction: total > 0 ? snapshot.vacant / total : 0,
                showBar: true,
              ),
            ),
            VerticalDivider(color: colors.border, width: 1, thickness: 1),
            Expanded(
              child: _Block(
                label: 'Occupancy',
                value: '${snapshot.pct.toStringAsFixed(0)}%',
                color: colors.accent,
                fraction: snapshot.pct / 100,
                showBar: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.label,
    required this.value,
    required this.color,
    required this.fraction,
    required this.showBar,
  });

  final String label;
  final String value;
  final Color color;
  final double fraction;
  final bool showBar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).extension<AppColors>()!.textSecondary,
            ),
          ),
          if (showBar) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0),
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
