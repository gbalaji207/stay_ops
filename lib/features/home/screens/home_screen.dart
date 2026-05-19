import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/booking_group.dart';
import '../../booking/booking_form.dart';
import '../../booking/booking_repository.dart';
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
      final saved = await showBookingFormSheet(context, existingGroup: group);
      if (saved && context.mounted) {
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
      body: SafeArea(
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
    return FloatingActionButton(
      heroTag: 'home_fab',
      backgroundColor: colors.accent,
      foregroundColor: Colors.white,
      elevation: 4,
      onPressed: () async {
        final saved = await context.push<bool>('/booking/new');
        if ((saved ?? false) && context.mounted) {
          cubit.refresh(_today, _totalRooms());
        }
      },
      child: const Icon(Icons.add, size: 24),
    );
  }
}

