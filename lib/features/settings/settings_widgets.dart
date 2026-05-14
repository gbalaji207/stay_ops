import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class SettingsAddRow extends StatelessWidget {
  const SettingsAddRow({
    super.key,
    required this.controller,
    required this.isSaving,
    required this.colors,
    required this.hint,
    required this.onAdd,
  });

  final TextEditingController controller;
  final bool isSaving;
  final AppColors colors;
  final String hint;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.add, size: 18, color: colors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(fontSize: 14, color: colors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                hintText: hint,
                hintStyle: TextStyle(fontSize: 14, color: colors.textHint),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => onAdd(),
            ),
          ),
          TextButton(
            onPressed: isSaving ? null : onAdd,
            child: Text('Add', style: TextStyle(color: colors.accent)),
          ),
        ],
      ),
    );
  }
}

class SettingsErrorView extends StatelessWidget {
  const SettingsErrorView({
    super.key,
    required this.message,
    required this.colors,
    required this.onRetry,
  });

  final String message;
  final AppColors colors;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: colors.danger),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(fontSize: 13, color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
