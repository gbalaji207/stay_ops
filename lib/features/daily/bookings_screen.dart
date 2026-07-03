import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/booking_group.dart';
import '../../shared/models/payment_destination.dart';
import '../booking/booking_repository.dart';
import '../booking/wizard/booking_wizard_extras.dart';
import '../booking/wizard/sf_booking_prefill.dart';
import '../booking/widgets/stay_flexi_search_dialog.dart';
import '../config/config_cubit.dart';
import '../home/payment_update_extras.dart';
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
  bool _fabExpanded = false;

  final _dailyKey = GlobalKey<DailyScreenState>();
  final _monthlyKey = GlobalKey<MonthlyScreenState>();

  /// Reloads both calendar views — they stay mounted simultaneously in the
  /// [IndexedStack], so a booking added/updated from either FAB should be
  /// visible immediately regardless of which view the user switches to.
  void _refreshCalendars() {
    _dailyKey.currentState?.refreshData();
    _monthlyKey.currentState?.refreshData();
  }

  Future<void> _showOtaPaymentDialog(BuildContext context) async {
    final configState = context.read<ConfigCubit>().state;
    final activeDestinations = configState is ConfigLoaded
        ? configState.paymentDestinations
            .where((d) => d.isActive)
            .toList()
            .cast<PaymentDestination>()
        : <PaymentDestination>[];

    final group = await showDialog<BookingGroup>(
      context: context,
      builder: (_) => _OtaSearchDialog(activeDestinations: activeDestinations),
    );

    if (group != null && context.mounted) {
      final saved = await context.push<bool>(
        '/payment/update',
        extra: PaymentUpdateExtras(
            group: group, activeDestinations: activeDestinations),
      );
      if ((saved ?? false) && context.mounted) {
        _refreshCalendars();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final toggle = _ViewToggle(
      showWeek: _showWeek,
      onToggle: (showWeek) => setState(() => _showWeek = showWeek),
    );

    return Scaffold(
      body: GestureDetector(
        onTap: _fabExpanded ? () => setState(() => _fabExpanded = false) : null,
        behavior: HitTestBehavior.translucent,
        child: IndexedStack(
          index: _showWeek ? 0 : 1,
          children: [
            DailyScreen(key: _dailyKey, headerToggle: toggle),
            MonthlyScreen(key: _monthlyKey, headerToggle: toggle),
          ],
        ),
      ),
      floatingActionButton: _buildFab(context, colors),
    );
  }

  Widget _buildFab(BuildContext context, AppColors colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Stay Flexi ID option
        AnimatedOpacity(
          opacity: _fabExpanded ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedSlide(
            offset: _fabExpanded ? Offset.zero : const Offset(0, 0.4),
            duration: const Duration(milliseconds: 200),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _FabOption(
                colors: colors,
                label: 'Stay Flexi ID',
                icon: Icons.receipt_long_outlined,
                onTap: _fabExpanded
                    ? () async {
                        setState(() => _fabExpanded = false);
                        if (!context.mounted) return;
                        final result = await showStayFlexiSearchDialog(context);
                        if (result != null && context.mounted) {
                          final configState =
                              context.read<ConfigCubit>().state;
                          final activeSources = configState is ConfigLoaded
                              ? configState.bookingSources
                                  .where((s) => s.isActive)
                                  .toList()
                              : <dynamic>[];
                          final activeDestinations =
                              configState is ConfigLoaded
                                  ? configState.paymentDestinations
                                      .where((d) => d.isActive)
                                      .toList()
                                  : <dynamic>[];
                          final prefill = SfBookingPrefill.fromJson(
                            result,
                            activeSources: activeSources,
                            activeDestinations: activeDestinations,
                          );
                          if (!context.mounted) return;
                          final saved = await context.push<bool>(
                            '/booking/new',
                            extra: BookingWizardExtras(sfPrefill: prefill),
                          );
                          if ((saved ?? false) && context.mounted) {
                            _refreshCalendars();
                          }
                        }
                      }
                    : null,
              ),
            ),
          ),
        ),
        // Manual option
        AnimatedOpacity(
          opacity: _fabExpanded ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: AnimatedSlide(
            offset: _fabExpanded ? Offset.zero : const Offset(0, 0.4),
            duration: const Duration(milliseconds: 150),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _FabOption(
                colors: colors,
                label: 'Manual',
                icon: Icons.edit_note_rounded,
                onTap: _fabExpanded
                    ? () async {
                        setState(() => _fabExpanded = false);
                        if (!context.mounted) return;
                        final saved = await context.push<bool>('/booking/new');
                        if ((saved ?? false) && context.mounted) {
                          _refreshCalendars();
                        }
                      }
                    : null,
              ),
            ),
          ),
        ),
        // FAB row: OTA payment search + main add FAB
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Tooltip(
              message: 'Find by OTA ID',
              child: FloatingActionButton.small(
                heroTag: 'ota_payment_fab',
                backgroundColor: colors.surface,
                foregroundColor: colors.accent,
                elevation: 2,
                onPressed: () async {
                  if (_fabExpanded) setState(() => _fabExpanded = false);
                  if (!context.mounted) return;
                  await _showOtaPaymentDialog(context);
                },
                child: const Icon(Icons.manage_search_rounded, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            FloatingActionButton(
              heroTag: 'bookings_fab',
              backgroundColor: colors.accent,
              foregroundColor: Colors.white,
              elevation: 4,
              onPressed: () => setState(() => _fabExpanded = !_fabExpanded),
              child: AnimatedRotation(
                turns: _fabExpanded ? 0.125 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.add, size: 24),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── OTA Search Dialog ─────────────────────────────────────────────────────────

class _OtaSearchDialog extends StatefulWidget {
  const _OtaSearchDialog({required this.activeDestinations});

  final List<PaymentDestination> activeDestinations;

  @override
  State<_OtaSearchDialog> createState() => _OtaSearchDialogState();
}

class _OtaSearchDialogState extends State<_OtaSearchDialog> {
  final _controller = TextEditingController();
  String? _errorText;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final otaId = _controller.text.trim();
    if (otaId.isEmpty) {
      setState(() => _errorText = 'Enter an OTA Booking ID');
      return;
    }
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final group = await BookingRepository().fetchGroupByOtaId(otaId);
      if (!mounted) return;
      if (group == null) {
        setState(() {
          _loading = false;
          _errorText = 'No booking found with this OTA ID';
        });
        return;
      }
      Navigator.of(context).pop(group);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorText = 'Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(
        'Update Payment Status',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter OTA Booking ID to find and update the payment status.',
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            style: TextStyle(color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Enter OTA booking ID',
              hintStyle: TextStyle(color: colors.textHint),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: colors.border),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: colors.accent),
              ),
            ),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorText!,
              style: TextStyle(fontSize: 12, color: colors.danger),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
        ),
        if (_loading)
          const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          TextButton(
            onPressed: _search,
            child: Text('Search', style: TextStyle(color: colors.accent)),
          ),
      ],
    );
  }
}

// ─── FAB Option ────────────────────────────────────────────────────────────────

class _FabOption extends StatelessWidget {
  const _FabOption({
    required this.colors,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final AppColors colors;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FloatingActionButton.small(
          heroTag: 'fab_$label',
          backgroundColor: colors.accent,
          foregroundColor: Colors.white,
          elevation: 2,
          onPressed: onTap,
          child: Icon(icon, size: 20),
        ),
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
