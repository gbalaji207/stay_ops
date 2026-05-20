import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';

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

  int get _nightCount => checkOut.difference(checkIn).inDays;
  double get _grossAmount =>
      double.tryParse(grossAmountController.text.replaceAll(',', '')) ?? 0;
  double get _perNight => _nightCount > 0 ? _grossAmount / _nightCount : 0;
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
          _FieldLabel(text: 'Gross amount (₹)', colors: colors),
          const SizedBox(height: 6),
          TextField(
            controller: grossAmountController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: colors.textPrimary, fontSize: 15),
            decoration: _inputDecoration(
                colors: colors, hint: '0', prefix: '₹ '),
          ),
          if (_grossAmount > 0 && _nightCount > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colors.accentSubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Text(
                  '$_nightCount night${_nightCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.accent,
                  ),
                ),
                const Spacer(),
                Text(
                  '₹${_amountFmt.format(_perNight)} / night',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.accent,
                  ),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 20),
          _FieldLabel(text: 'Tax amount (₹, optional)', colors: colors),
          const SizedBox(height: 6),
          TextField(
            controller: taxAmountController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: colors.textPrimary, fontSize: 15),
            decoration: _inputDecoration(
                colors: colors, hint: '0', prefix: '₹ '),
          ),
          const SizedBox(height: 20),
          _FieldLabel(
              text: 'Commission incl. taxes (₹, optional)', colors: colors),
          const SizedBox(height: 6),
          TextField(
            controller: commissionController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: colors.textPrimary, fontSize: 15),
            decoration: _inputDecoration(
                colors: colors, hint: '0', prefix: '₹ '),
          ),
          const SizedBox(height: 20),
          _FieldLabel(text: 'TDS & TCS (₹, optional)', colors: colors),
          const SizedBox(height: 6),
          TextField(
            controller: tdsTcsController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: colors.textPrimary, fontSize: 15),
            decoration: _inputDecoration(
                colors: colors, hint: '0', prefix: '₹ '),
          ),
          if (_grossAmount > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colors.successSubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
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
              ]),
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
                    borderRadius: BorderRadius.circular(12)),
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

  InputDecoration _inputDecoration({
    required AppColors colors,
    required String hint,
    String? prefix,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: colors.border),
    );
    return InputDecoration(
      prefixText: prefix,
      prefixStyle: TextStyle(color: colors.textSecondary, fontSize: 15),
      hintText: hint,
      hintStyle: TextStyle(color: colors.textHint),
      filled: true,
      fillColor: colors.background,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: colors.accent, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

// ── Private helpers ───────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text, required this.colors});
  final String text;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
    );
  }
}
