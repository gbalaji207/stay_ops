import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/booking_group.dart';
import '../../../shared/models/payment_destination.dart';
import '../../auth/auth_cubit.dart';
import '../../booking/booking_repository.dart';
import '../../booking/wizard/booking_wizard_extras.dart';
import '../../config/config_cubit.dart';
import '../cubit/home_cubit.dart';
import '../payment_update_extras.dart';
import '../repository/home_repository.dart';
import '../widgets/ops_booking_card.dart';
import '../../booking/widgets/stay_flexi_search_dialog.dart';
import '../../booking/wizard/sf_booking_prefill.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DateTime _today;
  bool _fabExpanded = false;
  // Keeps the last successfully loaded state so we can show it under a
  // translucent overlay while reloading (date switch, refresh, etc.)
  HomeLoaded? _lastLoaded;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
  }

  Map<String, String> _sourceNamesMap() {
    final config = context.read<ConfigCubit>().state;
    if (config is! ConfigLoaded) return {};
    return {for (final s in config.bookingSources) s.id: s.name};
  }

  String _roomName(BookingGroup g) {
    final config = context.read<ConfigCubit>().state;
    if (config is! ConfigLoaded) return g.roomId;
    final idx = config.rooms.indexWhere((r) => r.id == g.roomId);
    return idx >= 0 ? config.rooms[idx].name : g.roomId;
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
        cubit.refresh();
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not load booking: $e')),
      );
    }
  }

  Future<void> _showOtaPaymentDialog(BuildContext context) async {
    final cubit = context.read<HomeCubit>();
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
        cubit.refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HomeCubit>(
      create: (ctx) {
        final cubit = HomeCubit(HomeRepository());
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) cubit.load(_today);
        });
        return cubit;
      },
      child: BlocListener<ConfigCubit, ConfigState>(
        listenWhen: (_, curr) => curr is ConfigLoaded,
        listener: (context, _) {
          final cubit = context.read<HomeCubit>();
          if (cubit.state is! HomeInitial) {
            cubit.refresh();
          }
        },
        child: BlocBuilder<HomeCubit, HomeState>(
          builder: (context, state) {
            final colors = Theme.of(context).extension<AppColors>()!;

            // Cache the latest loaded state for overlay-loading UX
            if (state is HomeLoaded) _lastLoaded = state;

            // First-ever load: full-screen spinner
            if ((state is HomeInitial || state is HomeLoading) &&
                _lastLoaded == null) {
              return Scaffold(
                backgroundColor: colors.background,
                body: const Center(child: CircularProgressIndicator()),
              );
            }
            if (state is HomeError) {
              return _buildError(context, state.message, colors);
            }

            // Use last known loaded state for display (covers reloading too)
            final display = state is HomeLoaded ? state : _lastLoaded!;
            final isReloading = state is HomeLoading;
            return _buildLoaded(context, display, colors,
                isReloading: isReloading);
          },
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String message, AppColors colors) {
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
                onPressed: () => context.read<HomeCubit>().load(_today),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoaded(
      BuildContext context, HomeLoaded state, AppColors colors,
      {bool isReloading = false}) {
    final sourceNames = _sourceNamesMap();
    String? sourceName(String? id) => id != null ? sourceNames[id] : null;

    return Scaffold(
      backgroundColor: colors.background,
      body: GestureDetector(
        onTap: _fabExpanded ? () => setState(() => _fabExpanded = false) : null,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  // ── Date nav bar ──────────────────────────────────────
                  _buildDateBar(context, state, colors),
                  // ── Tab count cards ───────────────────────────────────
                  _buildTabCards(context, state, colors),
                  const SizedBox(height: 4),
                  // ── Booking list ──────────────────────────────────────
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async =>
                          context.read<HomeCubit>().refresh(),
                      child: state.activeList.isEmpty
                          ? _buildEmptyList(state.selectedTab, colors)
                          : _buildCardList(
                              context, state, sourceName, colors),
                    ),
                  ),
                ],
              ),
            ),
            // Translucent loading overlay — shown during date switches /
            // refreshes so the existing content stays visible.
            if (isReloading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.18),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: _buildFab(context, colors),
    );
  }

  Widget _buildCardList(
    BuildContext context,
    HomeLoaded state,
    String? Function(String?) sourceName,
    AppColors colors,
  ) {
    final items = state.activeList;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = w >= 900 ? 3 : w >= 600 ? 2 : 1;

        if (cols == 1) {
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final g = items[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OpsBookingCard(
                  group: g,
                  roomName: _roomName(g),
                  sourceName: sourceName(g.bookingSourceId),
                  onTap: () => _tapCard(context, g.id),
                ),
              );
            },
          );
        }

        // 2- or 3-column grid, centred with a sensible max-width
        final maxWidth = cols == 3 ? 1100.0 : 800.0;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 12,
                mainAxisSpacing: 8,
                mainAxisExtent: 100,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final g = items[index];
                return OpsBookingCard(
                  group: g,
                  roomName: _roomName(g),
                  sourceName: sourceName(g.bookingSourceId),
                  onTap: () => _tapCard(context, g.id),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateBar(
      BuildContext context, HomeLoaded state, AppColors colors) {
    final dateLbl = DateFormat('EEE, d MMM yyyy').format(state.selectedDate);
    final cubit = context.read<HomeCubit>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 12, 6),
      child: Row(
        children: [
          // Prev arrow
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            color: colors.textSecondary,
            onPressed: () => cubit
                .selectDate(state.selectedDate.subtract(const Duration(days: 1))),
          ),
          // Date label — tap to open date picker
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: state.selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null && context.mounted) {
                  cubit.selectDate(
                      DateTime(picked.year, picked.month, picked.day));
                }
              },
              child: Text(
                dateLbl,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),
          // Next arrow
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            color: colors.textSecondary,
            onPressed: () => cubit
                .selectDate(state.selectedDate.add(const Duration(days: 1))),
          ),
          // Property pill
          BlocBuilder<AuthCubit, AuthState>(
            builder: (_, authState) {
              final auth =
                  authState is AuthAuthenticated ? authState : null;
              if (auth == null) return const SizedBox.shrink();
              return GestureDetector(
                onTap: auth.properties.length > 1
                    ? () => _showPropertySwitcher(context, auth)
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: colors.accentSubtle,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        auth.activeProperty.name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.accent,
                        ),
                      ),
                      if (auth.properties.length > 1) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.swap_horiz_rounded,
                            size: 13, color: colors.accent),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabCards(
      BuildContext context, HomeLoaded state, AppColors colors) {
    // New Bookings first, In-House second (In-House is selected by default)
    final tabs = [
      (HomeTab.newBookings, 'New', state.newBookings.length),
      (HomeTab.inHouse, 'In-House', state.inHouse.length),
      (HomeTab.checkIns, 'Check-ins', state.checkIns.length),
      (HomeTab.checkOuts, 'Check-outs', state.checkOuts.length),
      (HomeTab.paymentsReceived, 'Paid', state.paymentsReceived.length),
    ];

    // Responsive: equal-width cards filling the row on mobile,
    // centred max-width container on wide screens.
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;
        final children = <Widget>[];
        for (int i = 0; i < tabs.length; i++) {
          final (tab, label, count) = tabs[i];
          if (i > 0) children.add(const SizedBox(width: 8));
          children.add(Expanded(
            child: _TabCard(
              label: label,
              count: count,
              selected: state.selectedTab == tab,
              onTap: () => context.read<HomeCubit>().selectTab(tab),
              colors: colors,
              activeColor: tab == HomeTab.paymentsReceived
                  ? colors.success
                  : colors.accent,
            ),
          ));
        }
        final row = Row(children: children);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: wide
              ? Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: row,
                  ),
                )
              : row,
        );
      },
    );
  }

  Widget _buildEmptyList(HomeTab tab, AppColors colors) {
    const labels = {
      HomeTab.newBookings: 'No new bookings',
      HomeTab.inHouse: 'No guests in-house',
      HomeTab.checkIns: 'No check-ins',
      HomeTab.checkOuts: 'No check-outs',
      HomeTab.paymentsReceived: 'No payments received',
    };
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 48),
          child: Center(
            child: Text(
              labels[tab] ?? 'Nothing to show',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: colors.textHint,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showPropertySwitcher(BuildContext context, AuthAuthenticated auth) {
    final colors = Theme.of(context).extension<AppColors>()!;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  'Switch Property',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              ...auth.properties.map(
                (p) => ListTile(
                  title: Text(
                    p.name,
                    style: TextStyle(
                      fontWeight: p.id == auth.activePropertyId
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: p.id == auth.activePropertyId
                          ? colors.accent
                          : colors.textPrimary,
                    ),
                  ),
                  trailing: p.id == auth.activePropertyId
                      ? Icon(Icons.check_rounded,
                          color: colors.accent, size: 18)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    if (p.id != auth.activePropertyId) {
                      context.read<AuthCubit>().switchProperty(p.id);
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
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
                            cubit.refresh();
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
                          cubit.refresh();
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
        ),
      ],
    );
  }
}

// ── Tab Count Card ────────────────────────────────────────────────────────────

class _TabCard extends StatelessWidget {
  const _TabCard({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    required this.colors,
    required this.activeColor,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final AppColors colors;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.10)
              : colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? activeColor : colors.border,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: selected ? activeColor : colors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: selected ? activeColor : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── OTA Search Dialog ─────────────────────────────────────────────────────────

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

// ── FAB Option ────────────────────────────────────────────────────────────────

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
