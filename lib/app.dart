import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/constants.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_cubit.dart';
import 'features/home/screens/home_screen.dart';
import 'features/config/config_cubit.dart';
import 'features/config/config_repository.dart';
import 'features/daily/bookings_screen.dart';
import 'features/reports/booking_source_report_screen.dart';
import 'features/reports/booking_type_report_screen.dart';
import 'features/reports/payment_report_screen.dart';
import 'features/reports/reports_screen.dart';
import 'features/settings/booking_source_config_screen.dart';
import 'features/settings/booking_type_config_screen.dart';
import 'features/settings/payment_destination_config_screen.dart';
import 'features/settings/room_config_screen.dart';
import 'features/settings/settings_cubit.dart';
import 'features/settings/settings_repository.dart';
import 'features/settings/settings_screen.dart';
import 'features/auth/pin_screen.dart';
import 'features/booking/wizard/booking_wizard_extras.dart';
import 'features/booking/wizard/booking_wizard_screen.dart';
import 'features/home/payment_update_extras.dart';
import 'features/home/screens/payment_update_screen.dart';

// Adapts a Cubit/Bloc stream to the Listenable interface required by GoRouter.
class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

GoRouter _buildRouter(AuthCubit authCubit) {
  return GoRouter(
    initialLocation: '/pin',
    refreshListenable: _GoRouterRefreshStream(authCubit.stream),
    redirect: (context, state) {
      final auth = authCubit.state;
      final onPin = state.matchedLocation == '/pin';

      if (auth is! AuthAuthenticated) return onPin ? null : '/pin';
      // Authenticated: block back-navigation to /pin
      if (onPin) return '/home';
      // Settings guard
      if (state.matchedLocation.startsWith('/settings')) {
        if (auth.role != UserRole.owner) return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/pin',
        builder: (_, _) => const PinScreen(),
      ),
      GoRoute(
        path: '/booking/new',
        builder: (context, state) {
          final extras = state.extra as BookingWizardExtras?;
          return BookingWizardScreen(
              extras: extras ?? const BookingWizardExtras());
        },
      ),
      GoRoute(
        path: '/payment/update',
        builder: (context, state) {
          final extras = state.extra as PaymentUpdateExtras;
          return PaymentUpdateScreen(extras: extras);
        },
      ),
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) => const HomeScreen(),
          ),
          GoRoute(
            path: '/bookings',
            builder: (_, _) => const BookingsScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (_, _) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/reports/payment',
            builder: (_, _) => const PaymentReportScreen(),
          ),
          GoRoute(
            path: '/reports/booking-type',
            builder: (_, _) => const BookingTypeReportScreen(),
          ),
          GoRoute(
            path: '/reports/booking-source',
            builder: (_, _) => const BookingSourceReportScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, _) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'rooms',
                builder: (context, _) => BlocProvider(
                  create: (ctx) => SettingsCubit(
                    SettingsRepository(),
                    ctx.read<ConfigCubit>(),
                  ),
                  child: const RoomConfigScreen(),
                ),
              ),
              GoRoute(
                path: 'booking-types',
                builder: (context, _) => BlocProvider(
                  create: (ctx) => SettingsCubit(
                    SettingsRepository(),
                    ctx.read<ConfigCubit>(),
                  ),
                  child: const BookingTypeConfigScreen(),
                ),
              ),
              GoRoute(
                path: 'booking-sources',
                builder: (context, _) => BlocProvider(
                  create: (ctx) => SettingsCubit(
                    SettingsRepository(),
                    ctx.read<ConfigCubit>(),
                  ),
                  child: const BookingSourceConfigScreen(),
                ),
              ),
              GoRoute(
                path: 'payment-destinations',
                builder: (context, _) => BlocProvider(
                  create: (ctx) => SettingsCubit(
                    SettingsRepository(),
                    ctx.read<ConfigCubit>(),
                  ),
                  child: const PaymentDestinationConfigScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        final isOwner = authState is AuthAuthenticated &&
            authState.role == UserRole.owner;
        final location = GoRouterState.of(context).matchedLocation;
        final currentIndex = _indexFromLocation(location, isOwner);

        return Scaffold(
          body: BlocBuilder<ConfigCubit, ConfigState>(
            builder: (context, configState) {
              if (configState is ConfigLoading || configState is ConfigInitial) {
                return const Center(child: CircularProgressIndicator());
              }
              if (configState is ConfigError) {
                return _ConfigErrorView(message: configState.message);
              }

              return child;
            },
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: (index) => _onTap(context, index, isOwner),
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_rounded),
                label: 'Home',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.calendar_month),
                label: 'Bookings',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_rounded),
                label: 'Reports',
              ),
              if (isOwner)
                const BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
            ],
          ),
        );
      },
    );
  }

  int _indexFromLocation(String location, bool isOwner) {
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/bookings') ||
        location.startsWith('/daily') ||
        location.startsWith('/monthly')) return 1;
    if (location.startsWith('/reports')) return 2;
    if (isOwner && location.startsWith('/settings')) return 3;
    return 0;
  }

  void _onTap(BuildContext context, int index, bool isOwner) {
    final paths = ['/home', '/bookings', '/reports'];
    if (isOwner) paths.add('/settings');
    if (index < paths.length) context.go(paths[index]);
  }
}

class _ConfigErrorView extends StatelessWidget {
  const _ConfigErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: colors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'Could not load configuration',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again.',
              style: TextStyle(fontSize: 13, color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.read<ConfigCubit>().loadConfig(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class StayOpsApp extends StatefulWidget {
  const StayOpsApp({super.key});

  @override
  State<StayOpsApp> createState() => _StayOpsAppState();
}

class _StayOpsAppState extends State<StayOpsApp> {
  late final AuthCubit _authCubit;
  late final ConfigCubit _configCubit;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authCubit = AuthCubit();
    _configCubit = ConfigCubit(ConfigRepository());
    _router = _buildRouter(_authCubit);
  }

  @override
  void dispose() {
    _authCubit.close();
    _configCubit.close();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: _authCubit),
        BlocProvider<ConfigCubit>.value(value: _configCubit),
      ],
      child: BlocListener<AuthCubit, AuthState>(
        bloc: _authCubit,
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            _configCubit.loadConfig();
          }
        },
        child: MaterialApp.router(
          title: 'StayOps',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.system,
          routerConfig: _router,
        ),
      ),
    );
  }
}
