import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_text_field.dart';

class WizardStep3Payment extends StatelessWidget {
  const WizardStep3Payment({
    super.key,
    required this.checkIn,
    required this.checkOut,
    required this.grossAmountController,
    required this.taxAmountController,
    required this.commissionController,
    required this.tdsTcsController,
    required this.onNext,
  });

  final DateTime checkIn;
  final DateTime checkOut;
  final TextEditingController grossAmountController;
  final TextEditingController taxAmountController;
  final TextEditingController commissionController;
  final TextEditingController tdsTcsController;
  final VoidCallback onNext;

  static final _amountFmt = NumberFormat('#,##0.##');

  int get _nightCount {
    final inDate  = DateTime(checkIn.year,  checkIn.month,  checkIn.day);
    final outDate = DateTime(checkOut.year, checkOut.month, checkOut.day);
    return outDate.difference(inDate).inDays;
  }

  bool get _isSameDay =>
      checkIn.year  == checkOut.year  &&
      checkIn.month == checkOut.month &&
      checkIn.day   == checkOut.day;

  int get _slotCount => _isSameDay ? 1 : _nightCount;
  double get _grossAmount =>
      double.tryParse(grossAmountController.text.replaceAll(',', '')) ?? 0;
  double get _perNight => _grossAmount / _slotCount;
  double get _commissionAmount =>
      double.tryParse(commissionController.text.replaceAll(',', '')) ?? 0;
  double get _tdsTcsAmount =>
      double.tryParse(tdsTcsController.text.replaceAll(',', '')) ?? 0;
  double get _netAmount => _grossAmount - _commissionAmount - _tdsTcsAmount;
  bool get _canNext => _grossAmount > 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: grossAmountController,
                  label: 'Gross amount (₹)',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  prefixText: '₹ ',
                  fontSize: 15,
                ),
              ),
              if (_grossAmount > 0) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colors.accentSubtle,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _isSameDay
                        ? '₹${_amountFmt.format(_perNight)} / use'
                        : '₹${_amountFmt.format(_perNight)} / night',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.accent,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  controller: taxAmountController,
                  label: 'Tax (₹, optional)',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  prefixText: '₹ ',
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  controller: tdsTcsController,
                  label: 'TDS & TCS (₹, optional)',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  prefixText: '₹ ',
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: commissionController,
            label: 'Commission incl. taxes (₹, optional)',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefixText: '₹ ',
            fontSize: 15,
          ),
          if (_grossAmount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: colors.successSubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    'Net received',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.success,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '₹${_amountFmt.format(_netAmount)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _canNext ? onNext : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Next',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
