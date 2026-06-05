import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../auth/auth_cubit.dart';
import '../config/config_cubit.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.nav,
        elevation: 0,
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: colors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: BlocBuilder<ConfigCubit, ConfigState>(
          builder: (context, configState) {
            final activeRooms =
                configState is ConfigLoaded ? configState.rooms.length : 0;
            final activeTypes = configState is ConfigLoaded
                ? configState.bookingTypes.length
                : 0;
            final activeSources = configState is ConfigLoaded
                ? configState.bookingSources.length
                : 0;
            final activeDestinations = configState is ConfigLoaded
                ? configState.paymentDestinations.length
                : 0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PropertyCard(colors: colors),
                const SizedBox(height: 24),
                _SectionHeader('Configuration', colors: colors),
                const SizedBox(height: 8),
                _ConfigSection(
                  colors: colors,
                  rows: [
                    _ConfigRow(
                      icon: Icons.meeting_room_outlined,
                      label: 'Rooms',
                      subtitle: '$activeRooms active',
                      onTap: () => context.go('/settings/rooms'),
                      colors: colors,
                    ),
                    _ConfigRow(
                      icon: Icons.category_outlined,
                      label: 'Booking types',
                      subtitle: '$activeTypes active',
                      onTap: () => context.go('/settings/booking-types'),
                      colors: colors,
                    ),
                    _ConfigRow(
                      icon: Icons.share_outlined,
                      label: 'Booking sources',
                      subtitle: '$activeSources active',
                      onTap: () => context.go('/settings/booking-sources'),
                      colors: colors,
                    ),
                    _ConfigRow(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Payment destinations',
                      subtitle: '$activeDestinations active',
                      onTap: () =>
                          context.go('/settings/payment-destinations'),
                      colors: colors,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _SectionHeader('Integrations', colors: colors),
                const SizedBox(height: 8),
                _ConfigSection(
                  colors: colors,
                  rows: [
                    _ConfigRow(
                      icon: Icons.token_outlined,
                      label: 'Channel manager',
                      subtitle: 'API token',
                      onTap: () => context.go('/settings/channel-manager'),
                      colors: colors,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _SectionHeader('Session', colors: colors),
                const SizedBox(height: 8),
                _ConfigSection(
                  colors: colors,
                  rows: [_SignOutRow(colors: colors)],
                ),
                const SizedBox(height: 32),
                Center(
                  child: Text(
                    'StayOps v1.3 · May 2026',
                    style: TextStyle(fontSize: 11, color: colors.textHint),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({required this.colors});
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.accentSubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.domain, color: colors.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Elite Inn',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "Mahindra World City, Chennai",
                style: TextStyle(
                  fontSize: 11,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label, {required this.colors});
  final String label;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ConfigSection extends StatelessWidget {
  const _ConfigSection({required this.colors, required this.rows});
  final AppColors colors;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1)
              Divider(height: 1, thickness: 1, color: colors.border),
          ],
        ],
      ),
    );
  }
}

class _ConfigRow extends StatelessWidget {
  const _ConfigRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    required this.colors,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 14, color: colors.textPrimary),
                  ),
                  Text(
                    subtitle,
                    style:
                        TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: colors.textHint),
          ],
        ),
      ),
    );
  }
}

class _SignOutRow extends StatelessWidget {
  const _SignOutRow({required this.colors});
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.read<AuthCubit>().logout(),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.logout, size: 20, color: colors.danger),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sign out',
                style: TextStyle(fontSize: 14, color: colors.danger),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: colors.textHint),
          ],
        ),
      ),
    );
  }
}
