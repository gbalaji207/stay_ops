import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/booking_group.dart';
import '../../booking/booking_repository.dart';
import '../../booking/widgets/stay_flexi_search_dialog.dart';
import '../../booking/wizard/booking_wizard_extras.dart';
import '../../booking/wizard/sf_booking_prefill.dart';
import '../../config/config_cubit.dart';
import '../cubit/home_cubit.dart';
import '../repository/home_repository.dart';
import '../widgets/booking_card.dart';
import '../widgets/new_booking_row.dart';
import '../widgets/occupancy_strip.dart';
import '../widgets/upcoming_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final DateTime _today;
  bool _fabExpanded = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
  }

  int _totalRooms() {
    final config = context.read<ConfigCubit>().state;
    return config is ConfigLoaded ? config.rooms.length : 0;
  }

  Map<String, String> _roomNamesMap() {
    final config = context.read<ConfigCubit>().state;
    if (config is! ConfigLoaded) return {};
    return {for (final r in config.rooms) r.id: r.name};
  }

  Map<String, String> _sourceNamesMap() {
    final config = context.read<ConfigCubit>().state;
    if (config is! ConfigLoaded) return {};
    return {for (final s in config.bookingSources) s.id: s.name};
  }

  Future<void> _tapCard(BuildContext context, String groupId) async {
    final cubit = context.read<HomeCubit>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final group = await BookingRepository().fetchGroupById(groupId);
      if (!context.mounted) return;
      final saved = await context.push<bool>(
        '/booking/new',
        extra: BookingWizardExtras(existingGroup: group),
      );
      if ((saved ?? false) && context.mounted) {
        cubit.refresh(_today, _totalRooms());
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not load booking: $e')),
      );
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HomeCubit>(
      create: (ctx) {
        final cubit = HomeCubit(HomeRepository());
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) cubit.load(_today, _totalRooms());
        });
        return cubit;
      },
      child: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          if (state is HomeInitial || state is HomeLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (state is HomeError) {
            return _buildError(context, state.message);
          }
          if (state is HomeLoaded) {
            return _buildLoaded(context, state);
          }
          return const Scaffold(body: SizedBox.shrink());
        },
      ),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 40, color: colors.textHint),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    context.read<HomeCubit>().load(_today, _totalRooms()),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoaded(BuildContext context, HomeLoaded state) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final roomNames = _roomNamesMap();
    final sourceNames = _sourceNamesMap();

    String roomName(String id) => roomNames[id] ?? id;
    String? sourceName(String? id) => id != null ? sourceNames[id] : null;

    final pendingTotal =
        state.paymentPending.fold<double>(0, (sum, g) => sum + g.totalAmount);
    final pendingTotalStr = NumberFormat('#,##0.##').format(pendingTotal);

    return Scaffold(
      backgroundColor: colors.background,
      body: GestureDetector(
        onTap: _fabExpanded ? () => setState(() => _fabExpanded = false) : null,
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async =>
              context.read<HomeCubit>().refresh(_today, _totalRooms()),
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: _buildHeader(colors),
              ),

              // Section 1 — Occupancy
              _buildSectionHeader(
                colors: colors,
                label: 'Occupancy today',
                color: colors.textPrimary,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: OccupancyStrip(snapshot: state.occupancy),
                ),
              ),

              // Section 2 — Check-outs
              _buildSectionHeader(
                colors: colors,
                label: 'Check-outs today',
                color: colors.danger,
                count: state.checkOuts.isNotEmpty ? state.checkOuts.length : null,
              ),
              _bookingCardSliver(
                context: context,
                groups: state.checkOuts,
                roomName: roomName,
                sourceName: sourceName,
                colors: colors,
                emptyText: 'No check-outs today',
              ),

              // Section 3 — Check-ins
              _buildSectionHeader(
                colors: colors,
                label: 'Check-ins today',
                color: colors.success,
                count: state.checkIns.isNotEmpty ? state.checkIns.length : null,
              ),
              _bookingCardSliver(
                context: context,
                groups: state.checkIns,
                roomName: roomName,
                sourceName: sourceName,
                colors: colors,
                emptyText: 'No check-ins today',
              ),

              // Section 4 — Upcoming
              _buildSectionHeader(
                colors: colors,
                label: 'Upcoming check-ins',
                color: colors.textPrimary,
                subtitle: 'Next 3 days',
              ),
              if (state.upcoming.isEmpty)
                _emptySliver(colors, 'No upcoming check-ins in the next 3 days')
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final entry = state.upcoming.entries.elementAt(index);
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                        child: UpcomingCard(
                          date: entry.key,
                          groups: entry.value,
                          today: _today,
                          resolveRoomName: roomName,
                          resolveSourceName: sourceName,
                          onTap: (id) => _tapCard(context, id),
                        ),
                      );
                    },
                    childCount: state.upcoming.length,
                  ),
                ),

              // Section 5 — New today
              _buildSectionHeader(
                colors: colors,
                label: 'New today',
                color: colors.textPrimary,
                count: state.newToday.isNotEmpty ? state.newToday.length : null,
              ),
              if (state.newToday.isEmpty)
                _emptySliver(colors, 'No new bookings recorded today')
              else
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      children: state.newToday.map((g) {
                        return NewBookingRow(
                          group: g,
                          roomName: roomName(g.roomId),
                          onTap: () => _tapCard(context, g.id),
                        );
                      }).toList(),
                    ),
                  ),
                ),

              // Section 6 — Payment pending
              _buildSectionHeader(
                colors: colors,
                label: 'Payment pending',
                color: colors.warning,
                count: state.paymentPending.isNotEmpty
                    ? state.paymentPending.length
                    : null,
                subtitle: state.paymentPending.isNotEmpty
                    ? '₹$pendingTotalStr due'
                    : null,
              ),
              _bookingCardSliver(
                context: context,
                groups: state.paymentPending,
                roomName: roomName,
                sourceName: sourceName,
                colors: colors,
                emptyText: 'All payments received',
              ),

              // Bottom padding so FAB doesn't cover last card
              const SliverToBoxAdapter(child: SizedBox(height: 88)),
            ],
          ),
        ),
        ),
      ),
      floatingActionButton: _buildFab(context, colors),
    );
  }

  Widget _buildHeader(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, d MMMM yyyy').format(_today),
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colors.accentSubtle,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'StayOps',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  SliverToBoxAdapter _buildSectionHeader({
    required AppColors colors,
    required String label,
    required Color color,
    int? count,
    String? subtitle,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Row(
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
            if (subtitle != null) ...[
              const Spacer(),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bookingCardSliver({
    required BuildContext context,
    required List<BookingGroup> groups,
    required String Function(String) roomName,
    required String? Function(String?) sourceName,
    required AppColors colors,
    required String emptyText,
  }) {
    if (groups.isEmpty) return _emptySliver(colors, emptyText);
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final g = groups[index];
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: BookingCard(
              group: g,
              roomName: roomName(g.roomId),
              sourceName: sourceName(g.bookingSourceId),
              onTap: () => _tapCard(context, g.id),
            ),
          );
        },
        childCount: groups.length,
      ),
    );
  }

  SliverToBoxAdapter _emptySliver(AppColors colors, String text) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: colors.textHint,
          ),
        ),
      ),
    );
  }

  Widget _buildFab(BuildContext context, AppColors colors) {
    final cubit = context.read<HomeCubit>();
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
                        final result =
                            await showStayFlexiSearchDialog(context);
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
                            cubit.refresh(_today, _totalRooms());
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
                        final saved =
                            await context.push<bool>('/booking/new');
                        if ((saved ?? false) && context.mounted) {
                          cubit.refresh(_today, _totalRooms());
                        }
                      }
                    : null,
              ),
            ),
          ),
        ),
        // Main FAB
        FloatingActionButton(
          heroTag: 'home_fab',
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
    );
  }
}

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

