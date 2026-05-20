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
import 'wizard_step4_review.dart';

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
  String? _bookingTypeId;
  String? _bookingSourceId;

  // Step 2 controllers
  final _customerNameController = TextEditingController();
  final _stayFlexiBookingIdController = TextEditingController();
  final _otaBookingIdController = TextEditingController();

  // Step 3 controllers (payment)
  final _amountController = TextEditingController(); // gross amount
  final _taxAmountController = TextEditingController();
  final _commissionController = TextEditingController();
  final _tdsTcsController = TextEditingController();

  // Step 4 only
  final _notesController = TextEditingController();
  bool _paymentReceived = false;
  String? _paymentDestinationId;

  @override
  void initState() {
    super.initState();
    _bookingCubit = BookingCubit(BookingRepository());

    final extras = widget.extras;
    final group = extras.existingGroup;
    final sf = extras.sfPrefill;

    _selectedRoomId = group?.roomId ?? sf?.roomId ?? extras.prefilledRoomId;
    _bookingDate = group?.bookingDate ?? sf?.bookingDate ?? DateTime.now();
    _checkIn = group?.checkIn ?? sf?.checkIn ?? extras.prefilledDate ?? _today();
    _checkOut = group?.checkOut ??
        sf?.checkOut ??
        (extras.prefilledDate ?? _today()).add(const Duration(days: 1));
    _bookingTypeId = group?.bookingTypeId ?? sf?.bookingTypeId;
    _bookingSourceId = group?.bookingSourceId ?? sf?.bookingSourceId;
    _paymentReceived = group?.paymentReceived ?? false;
    _paymentDestinationId =
        group?.paymentDestinationId ?? sf?.paymentDestinationId;
    _notesController.text = group?.notes ?? '';
    _customerNameController.text = group?.customerName ?? sf?.customerName ?? '';
    _stayFlexiBookingIdController.text =
        group?.stayFlexiBookingId ?? sf?.sfBookingId ?? '';
    _otaBookingIdController.text =
        group?.otaBookingId ?? sf?.otaBookingId ?? '';

    if (group != null && group.totalAmount > 0) {
      _amountController.text = group.totalAmount.toInt().toString();
    } else if (sf?.grossAmount != null && sf!.grossAmount! > 0) {
      _amountController.text = _fmtAmount(sf.grossAmount!);
    }
    if (group?.taxAmount != null) {
      _taxAmountController.text = group!.taxAmount!.toInt().toString();
    } else if (sf?.taxAmount != null) {
      _taxAmountController.text = _fmtAmount(sf!.taxAmount!);
    }
    if (group?.commissionInclTax != null) {
      _commissionController.text =
          group!.commissionInclTax!.toInt().toString();
    } else if (sf?.commissionInclTax != null) {
      _commissionController.text = _fmtAmount(sf!.commissionInclTax!);
    }
    if (group?.taxDeduction != null) {
      _tdsTcsController.text = group!.taxDeduction!.toInt().toString();
    } else if (sf?.taxDeduction != null) {
      _tdsTcsController.text = _fmtAmount(sf!.taxDeduction!);
    }

    final initialPage = (group != null || sf != null)
        ? 3
        : extras.prefilledRoomId != null
            ? 1
            : 0;
    _currentStep = initialPage;
    _pageController = PageController(initialPage: initialPage);

    // Rebuild when any payment amount changes (drives step 3 net display and
    // step 4 save button enablement)
    for (final c in [
      _amountController,
      _taxAmountController,
      _commissionController,
      _tdsTcsController,
    ]) {
      c.addListener(_onAmountChanged);
    }
  }

  @override
  void dispose() {
    _bookingCubit.close();
    _pageController.dispose();
    for (final c in [
      _amountController,
      _taxAmountController,
      _commissionController,
      _tdsTcsController,
    ]) {
      c
        ..removeListener(_onAmountChanged)
        ..dispose();
    }
    _notesController.dispose();
    _customerNameController.dispose();
    _stayFlexiBookingIdController.dispose();
    _otaBookingIdController.dispose();
    super.dispose();
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _fmtAmount(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toString();
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

  bool get _shouldExitOnBack {
    if (widget.extras.existingGroup != null || widget.extras.sfPrefill != null) {
      return _currentStep == 3;
    }
    return _currentStep == 0 ||
        (_currentStep == 1 && widget.extras.prefilledRoomId != null);
  }

  void _onSourceChanged(String? sourceId) {
    setState(() => _bookingSourceId = sourceId);
    if (sourceId == null) return;
    final config = context.read<ConfigCubit>().state;
    if (config is! ConfigLoaded) return;
    final source =
        config.bookingSources.where((s) => s.id == sourceId).firstOrNull;
    final destId = source?.defaultPaymentDestinationId;
    if (destId != null &&
        config.paymentDestinations.any((d) => d.id == destId && d.isActive)) {
      setState(() => _paymentDestinationId = destId);
    }
  }

  String? _nullIfEmpty(String text) {
    final t = text.trim();
    return t.isEmpty ? null : t;
  }

  double? _parseOptional(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', ''));
  }

  void _handleSave() {
    final gross =
        double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    _bookingCubit.checkAndSave(
      BookingGroupInput(
        existingGroupId: widget.extras.existingGroup?.id,
        roomId: _selectedRoomId!,
        checkIn: _checkIn,
        checkOut: _checkOut,
        totalAmount: gross,
        paymentReceived: _paymentReceived,
        bookingDate: _bookingDate,
        bookingTypeId: _bookingTypeId,
        bookingSourceId: _bookingSourceId,
        notes: _nullIfEmpty(_notesController.text),
        paymentDestinationId: _paymentDestinationId,
        customerName: _nullIfEmpty(_customerNameController.text),
        stayFlexiBookingId: _nullIfEmpty(_stayFlexiBookingIdController.text),
        otaBookingId: _nullIfEmpty(_otaBookingIdController.text),
        taxAmount: _parseOptional(_taxAmountController.text),
        commissionInclTax: _parseOptional(_commissionController.text),
        taxDeduction: _parseOptional(_tdsTcsController.text),
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
              title: Text(
                widget.extras.existingGroup != null
                    ? 'Edit Booking'
                    : 'New Booking',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
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
                WizardStep2Details(
                  bookingDate: _bookingDate,
                  checkIn: _checkIn,
                  checkOut: _checkOut,
                  types: types,
                  allSources: sources,
                  selectedTypeId: _bookingTypeId,
                  selectedSourceId: _bookingSourceId,
                  customerNameController: _customerNameController,
                  stayFlexiBookingIdController: _stayFlexiBookingIdController,
                  otaBookingIdController: _otaBookingIdController,
                  onBookingDateChanged: (date) =>
                      setState(() => _bookingDate = date),
                  onStayRangeChanged: (start, end) => setState(() {
                    _checkIn = start;
                    _checkOut = end;
                  }),
                  onTypeSelected: (id) => setState(() {
                    _bookingTypeId = id;
                    _bookingSourceId = null;
                  }),
                  onSourceChanged: _onSourceChanged,
                  onNext: () => _goToStep(2),
                ),
                WizardStep3Payment(
                  checkIn: _checkIn,
                  checkOut: _checkOut,
                  grossAmountController: _amountController,
                  taxAmountController: _taxAmountController,
                  commissionController: _commissionController,
                  tdsTcsController: _tdsTcsController,
                  onNext: () => _goToStep(3),
                ),
                WizardStep4Review(
                  rooms: rooms,
                  types: types,
                  allSources: sources,
                  selectedRoomId: _selectedRoomId,
                  bookingDate: _bookingDate,
                  checkIn: _checkIn,
                  checkOut: _checkOut,
                  grossAmountController: _amountController,
                  taxAmountController: _taxAmountController,
                  commissionController: _commissionController,
                  tdsTcsController: _tdsTcsController,
                  selectedTypeId: _bookingTypeId,
                  selectedSourceId: _bookingSourceId,
                  customerNameController: _customerNameController,
                  stayFlexiBookingIdController: _stayFlexiBookingIdController,
                  otaBookingIdController: _otaBookingIdController,
                  notesController: _notesController,
                  onRoomChanged: (id) => setState(() => _selectedRoomId = id),
                  onBookingDateChanged: (date) =>
                      setState(() => _bookingDate = date),
                  onStayRangeChanged: (start, end) => setState(() {
                    _checkIn = start;
                    _checkOut = end;
                  }),
                  onTypeSelected: (id) => setState(() {
                    _bookingTypeId = id;
                    _bookingSourceId = null;
                  }),
                  onSourceChanged: _onSourceChanged,
                  onSave: _handleSave,
                  isBusy: isBusy,
                  isEditMode: widget.extras.existingGroup != null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

