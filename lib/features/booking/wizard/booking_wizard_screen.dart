import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/conflict_dialog.dart';
import '../../config/config_cubit.dart';
import '../booking_cubit.dart';
import '../booking_group_input.dart';
import '../booking_repository.dart';
import 'booking_wizard_extras.dart';
import 'wizard_step1_room.dart';
import 'wizard_step2_dates.dart';
import 'wizard_step3_type_source.dart';

class BookingWizardScreen extends StatefulWidget {
  const BookingWizardScreen({super.key, required this.extras});

  final BookingWizardExtras extras;

  @override
  State<BookingWizardScreen> createState() => _BookingWizardScreenState();
}

class _BookingWizardScreenState extends State<BookingWizardScreen> {
  late final BookingCubit _bookingCubit;
  late final PageController _pageController;
  late int _currentStep;

  String? _selectedRoomId;
  late DateTime _bookingDate;
  late DateTime _checkIn;
  late DateTime _checkOut;
  final _amountController = TextEditingController();
  String? _bookingTypeId;
  String? _bookingSourceId;

  @override
  void initState() {
    super.initState();
    _bookingCubit = BookingCubit(BookingRepository());

    final extras = widget.extras;
    final today = _today();

    _selectedRoomId = extras.prefilledRoomId;
    _bookingDate = today;
    _checkIn = extras.prefilledDate ?? today;
    _checkOut =
        (extras.prefilledDate ?? today).add(const Duration(days: 1));

    final initialPage = extras.prefilledRoomId != null ? 1 : 0;
    _currentStep = initialPage;
    _pageController = PageController(initialPage: initialPage);

    _amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _bookingCubit.close();
    _pageController.dispose();
    _amountController
      ..removeListener(_onAmountChanged)
      ..dispose();
    super.dispose();
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void _onAmountChanged() => setState(() {});

  void _goToStep(int step) {
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
    setState(() => _currentStep = step);
  }

  bool get _shouldExitOnBack =>
      _currentStep == 0 ||
      (_currentStep == 1 && widget.extras.prefilledRoomId != null);

  void _handleSave() {
    final amount =
        double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    _bookingCubit.checkAndSave(
      BookingGroupInput(
        roomId: _selectedRoomId!,
        checkIn: _checkIn,
        checkOut: _checkOut,
        totalAmount: amount,
        paymentReceived: false,
        bookingDate: _bookingDate,
        bookingTypeId: _bookingTypeId,
        bookingSourceId: _bookingSourceId,
        notes: null,
        paymentDestinationId: null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final configState = context.watch<ConfigCubit>().state;

    return BlocConsumer<BookingCubit, BookingState>(
      bloc: _bookingCubit,
      listener: (context, state) {
        if (state is BookingSaved) {
          context.pop(true);
        } else if (state is BookingConflict) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => ConflictDialog(
              conflicts: state.conflicts,
              onCancel: () {
                Navigator.of(context).pop();
                _bookingCubit.reset();
              },
              onConfirm: () {
                Navigator.of(context).pop();
                _bookingCubit.confirmOverwrite();
              },
            ),
          );
        } else if (state is BookingError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
          _bookingCubit.reset();
        }
      },
      builder: (context, bookingState) {
        final isBusy =
            bookingState is BookingChecking || bookingState is BookingSaving;

        if (configState is! ConfigLoaded) {
          return Scaffold(
            backgroundColor: colors.background,
            appBar: AppBar(
              backgroundColor: colors.surface,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final rooms = configState.rooms.where((r) => r.isActive).toList();
        final types =
            configState.bookingTypes.where((t) => t.isActive).toList();
        final sources =
            configState.bookingSources.where((s) => s.isActive).toList();

        return PopScope(
          canPop: _shouldExitOnBack,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _goToStep(_currentStep - 1);
          },
          child: Scaffold(
            backgroundColor: colors.background,
            appBar: AppBar(
              backgroundColor: colors.surface,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (_shouldExitOnBack) {
                    context.pop();
                  } else {
                    _goToStep(_currentStep - 1);
                  }
                },
              ),
              title: _StepIndicator(currentStep: _currentStep, colors: colors),
              centerTitle: true,
            ),
            body: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                WizardStep1Room(
                  rooms: rooms,
                  selectedRoomId: _selectedRoomId,
                  onRoomSelected: (id) {
                    setState(() => _selectedRoomId = id);
                    _goToStep(1);
                  },
                ),
                WizardStep2Dates(
                  bookingDate: _bookingDate,
                  checkIn: _checkIn,
                  checkOut: _checkOut,
                  amountController: _amountController,
                  onBookingDateChanged: (date) =>
                      setState(() => _bookingDate = date),
                  onStayRangeChanged: (start, end) => setState(() {
                    _checkIn = start;
                    _checkOut = end;
                  }),
                  onNext: () => _goToStep(2),
                ),
                WizardStep3TypeSource(
                  types: types,
                  allSources: sources,
                  selectedTypeId: _bookingTypeId,
                  selectedSourceId: _bookingSourceId,
                  onTypeSelected: (id) => setState(() {
                    _bookingTypeId = id;
                    _bookingSourceId = null;
                  }),
                  onSourceChanged: (id) =>
                      setState(() => _bookingSourceId = id),
                  onSave: _handleSave,
                  isBusy: isBusy,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Step progress indicator ───────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep, required this.colors});
  final int currentStep;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final isActive = i == currentStep;
        final isVisited = i < currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: (isActive || isVisited) ? colors.accent : colors.border,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
