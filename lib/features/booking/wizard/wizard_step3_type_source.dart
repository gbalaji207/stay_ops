import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/booking_source.dart';
import '../../../shared/models/booking_type.dart';

class WizardStep3TypeSource extends StatelessWidget {
  const WizardStep3TypeSource({
    super.key,
    required this.types,
    required this.allSources,
    required this.selectedTypeId,
    required this.selectedSourceId,
    required this.onTypeSelected,
    required this.onSourceChanged,
    required this.onSave,
    required this.isBusy,
  });

  final List<BookingType> types;
  final List<BookingSource> allSources;
  final String? selectedTypeId;
  final String? selectedSourceId;
  final ValueChanged<String> onTypeSelected;
  final ValueChanged<String?> onSourceChanged;
  final VoidCallback onSave;
  final bool isBusy;

  List<BookingSource> get _filteredSources {
    if (selectedTypeId == null) return [];
    return allSources
        .where((s) => s.bookingTypeId == selectedTypeId && s.isActive)
        .toList();
  }

  bool get _canSave {
    final filtered = _filteredSources;
    if (filtered.isNotEmpty && selectedSourceId == null) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final filteredSources = _filteredSources;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(text: 'Booking type', colors: colors),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: types.map((type) {
              final selected = selectedTypeId == type.id;
              return _TypeChip(
                label: type.name,
                selected: selected,
                onTap: () => onTypeSelected(type.id),
                colors: colors,
              );
            }).toList(),
          ),
          if (filteredSources.isNotEmpty) ...[
            const SizedBox(height: 20),
            _FieldLabel(text: 'Booking source', colors: colors),
            const SizedBox(height: 6),
            _SourceDropdown(
              sources: filteredSources,
              selectedId: selectedSourceId,
              onChanged: onSourceChanged,
              colors: colors,
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (isBusy || !_canSave) ? null : onSave,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: isBusy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Save booking',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
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

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.colors,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colors.accent : colors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? colors.accent : colors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? Colors.white : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _SourceDropdown extends StatelessWidget {
  const _SourceDropdown({
    required this.sources,
    required this.selectedId,
    required this.onChanged,
    required this.colors,
  });
  final List<BookingSource> sources;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final validId = sources.any((s) => s.id == selectedId) ? selectedId : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: validId,
          isExpanded: true,
          hint: Text('Select source',
              style: TextStyle(color: colors.textHint, fontSize: 14)),
          dropdownColor: colors.surface,
          style: TextStyle(color: colors.textPrimary, fontSize: 14),
          iconEnabledColor: colors.textSecondary,
          items: sources
              .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
