import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../monthly/monthly_screen.dart';
import 'daily_screen.dart';

/// Combines the Week (Daily) and Month calendar views under a single
/// "Bookings" nav tab.  The two screens live in an [IndexedStack] so their
/// state (anchor date / selected month) is preserved across toggles.
class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  bool _showWeek = true;

  @override
  Widget build(BuildContext context) {
    final toggle = _ViewToggle(
      showWeek: _showWeek,
      onToggle: (showWeek) => setState(() => _showWeek = showWeek),
    );

    return IndexedStack(
      index: _showWeek ? 0 : 1,
      children: [
        DailyScreen(headerToggle: toggle),
        MonthlyScreen(headerToggle: toggle),
      ],
    );
  }
}

// ─── Toggle widget ─────────────────────────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({
    required this.showWeek,
    required this.onToggle,
  });

  final bool showWeek;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Segment(
            label: 'Week',
            selected: showWeek,
            isLeft: true,
            colors: colors,
            onTap: () => onToggle(true),
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: colors.border,
            indent: 6,
            endIndent: 6,
          ),
          _Segment(
            label: 'Month',
            selected: !showWeek,
            isLeft: false,
            colors: colors,
            onTap: () => onToggle(false),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.isLeft,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isLeft;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = isLeft
        ? const BorderRadius.only(
            topLeft: Radius.circular(7),
            bottomLeft: Radius.circular(7),
          )
        : const BorderRadius.only(
            topRight: Radius.circular(7),
            bottomRight: Radius.circular(7),
          );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        width: 64,
        height: 32,
        decoration: BoxDecoration(
          color: selected ? colors.accentSubtle : Colors.transparent,
          borderRadius: radius,
        ),
        alignment: Alignment.center,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? colors.accent : colors.textSecondary,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
