import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/booking_group.dart';
import '../../../shared/widgets/app_date_picker.dart';
import '../../../shared/widgets/app_dropdown_field.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../booking/booking_repository.dart';
import '../../config/config_cubit.dart';
import '../payment_update_extras.dart';

class PaymentUpdateScreen extends StatefulWidget {
  const PaymentUpdateScreen({super.key, required this.extras});

  final PaymentUpdateExtras extras;

  @override
  State<PaymentUpdateScreen> createState() => _PaymentUpdateScreenState();
}

class _PaymentUpdateScreenState extends State<PaymentUpdateScreen> {
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  String? _destinationId;
  DateTime _paymentDate = DateTime.now();
  bool _paymentReceived = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final group = widget.extras.group;
    final net = group.netAmount;
    final fmt = NumberFormat('#,##0.##');
    _amountController = TextEditingController(
      text: net > 0 ? fmt.format(net) : '',
    );
    _notesController = TextEditingController(text: group.paymentNotes ?? '');

    final destinations = widget.extras.activeDestinations;
    final hasDestination = group.paymentDestinationId != null &&
        destinations.any((d) => d.id == group.paymentDestinationId);
    _destinationId = hasDestination ? group.paymentDestinationId : null;

    if (group.paymentReceivedDate != null) {
      _paymentDate = group.paymentReceivedDate!;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _amountController.text.replaceAll(',', '').trim();
    final amount = double.tryParse(raw);
    if (amount == null) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await BookingRepository().updatePaymentDetails(
        groupId: widget.extras.group.id,
        paymentReceived: _paymentReceived,
        actualPaymentAmount: amount,
        paymentDestinationId: _destinationId,
        paymentReceivedDate: _paymentDate,
        paymentNotes: _notesController.text,
      );
      if (mounted) context.pop(true);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Could not save: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final group = widget.extras.group;
    final destinations = widget.extras.activeDestinations;
    final configState = context.read<ConfigCubit>().state;
    String? typeName;
    String? sourceName;
    if (configState is ConfigLoaded) {
      for (final t in configState.bookingTypes) {
        if (t.id == group.bookingTypeId) { typeName = t.name; break; }
      }
      for (final s in configState.bookingSources) {
        if (s.id == group.bookingSourceId) { sourceName = s.name; break; }
      }
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Record Payment',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: colors.textPrimary,
          onPressed: () => context.pop(false),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BookingRefCard(
                    group: group,
                    typeName: typeName,
                    sourceName: sourceName,
                    colors: colors,
                  ),
                  const SizedBox(height: 20),
                  AppTextField(
                    label: 'Amount received',
                    controller: _amountController,
                    prefixText: '₹ ',
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[\d,.]')),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (destinations.isNotEmpty)
                    AppDropdownField<String>(
                      label: 'Payment destination',
                      value: _destinationId,
                      items: destinations
                          .map((d) =>
                              AppDropdownItem(value: d.id, label: d.name))
                          .toList(),
                      onChanged: (v) => setState(() => _destinationId = v),
                    ),
                  if (destinations.isNotEmpty) const SizedBox(height: 14),
                  AppDatePicker(
                    label: 'Payment received date',
                    selectedDate: _paymentDate,
                    lastDate: DateTime.now(),
                    onDateSelected: (d) => setState(() => _paymentDate = d),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Payment notes',
                    controller: _notesController,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                  ),
                  const SizedBox(height: 20),
                  _PaymentStatusRow(
                    value: _paymentReceived,
                    colors: colors,
                    onChanged: (v) => setState(() => _paymentReceived = v),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.danger,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                  ],
                  FilledButton(
                    onPressed: _loading ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _loading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          )
                        : const Text(
                            'Save Payment',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingRefCard extends StatelessWidget {
  const _BookingRefCard({
    required this.group,
    required this.typeName,
    required this.sourceName,
    required this.colors,
  });

  final BookingGroup group;
  final String? typeName;
  final String? sourceName;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final checkInStr = DateFormat('d MMM').format(group.checkIn);
    final checkOutStr = DateFormat('d MMM yyyy').format(group.checkOut);
    final nights = group.nights;
    final dateStr =
        '$checkInStr → $checkOutStr · $nights ${nights == 1 ? 'night' : 'nights'}';

    final sourceType = [?sourceName, ?typeName].join(' · ');

    final rows = <Widget>[
      ?_otaRowOrNull(context, group.otaBookingId),
      _buildTextRow(dateStr),
      if (sourceType.isNotEmpty) _buildTextRow(sourceType),
      ?_textRowOrNull(group.customerName),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(height: 14, thickness: 0.5, color: colors.border),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget? _otaRowOrNull(BuildContext context, String? otaId) {
    if (otaId == null || otaId.isEmpty) return null;
    return _buildOtaRow(context, otaId);
  }

  Widget? _textRowOrNull(String? text) {
    if (text == null || text.isEmpty) return null;
    return _buildTextRow(text);
  }

  Widget _buildOtaRow(BuildContext context, String otaId) {
    return Row(
      children: [
        Text(
          'OTA ID  ',
          style: TextStyle(fontSize: 11, color: colors.textHint),
        ),
        Expanded(
          child: Text(
            otaId,
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
        ),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: otaId));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('OTA ID copied'),
                duration: Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: Icon(Icons.copy_rounded, size: 14, color: colors.textHint),
        ),
      ],
    );
  }

  Widget _buildTextRow(String text) {
    return Text(
      text,
      style: TextStyle(fontSize: 13, color: colors.textSecondary),
    );
  }
}

class _PaymentStatusRow extends StatelessWidget {
  const _PaymentStatusRow({
    required this.value,
    required this.colors,
    required this.onChanged,
  });

  final bool value;
  final AppColors colors;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mark as received',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value ? 'Payment received' : 'Payment still pending',
                  style: TextStyle(
                    fontSize: 12,
                    color: value ? colors.success : colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: colors.success,
            activeTrackColor: colors.success.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}
