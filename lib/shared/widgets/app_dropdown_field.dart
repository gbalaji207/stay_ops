import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'app_text_field.dart';

class AppDropdownItem<T> {
  final T value;
  final String label;

  const AppDropdownItem({required this.value, required this.label});
}

/// Dropdown that matches [AppTextField] styling with a floating label.
///
/// Set [searchable] to true for large lists — opens a search dialog instead
/// of the native dropdown sheet.
class AppDropdownField<T> extends StatefulWidget {
  const AppDropdownField({
    super.key,
    required this.label,
    required this.items,
    this.hintText,
    this.value,
    this.onChanged,
    this.enabled = true,
    this.searchable = false,
    this.validator,
  });

  final String label;
  final String? hintText;
  final List<AppDropdownItem<T>> items;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final bool enabled;
  final bool searchable;
  final String? Function(T?)? validator;

  @override
  State<AppDropdownField<T>> createState() => _AppDropdownFieldState<T>();
}

class _AppDropdownFieldState<T> extends State<AppDropdownField<T>> {
  final TextEditingController _searchController = TextEditingController();
  late final TextEditingController _displayController;

  @override
  void initState() {
    super.initState();
    _displayController = TextEditingController(text: _labelForValue(widget.value));
  }

  @override
  void didUpdateWidget(AppDropdownField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value || widget.items != oldWidget.items) {
      _displayController.text = _labelForValue(widget.value);
      if (widget.items != oldWidget.items) {
        _searchController.clear();
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _displayController.dispose();
    super.dispose();
  }

  String _labelForValue(T? value) {
    if (value == null) return '';
    try {
      return widget.items.firstWhere((i) => i.value == value).label;
    } catch (_) {
      return '';
    }
  }

  Future<void> _showSearchDialog() async {
    var filtered = widget.items;

    final selected = await showDialog<T>(
      context: context,
      builder: (dialogContext) {
        final colors = Theme.of(dialogContext).extension<AppColors>()!;
        return StatefulBuilder(
          builder: (_, setDialogState) {
            return AlertDialog(
              title: Text(widget.label),
              contentPadding: EdgeInsets.zero,
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: AppTextField(
                        controller: _searchController,
                        label: 'Search',
                        prefixIcon: Icons.search,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        onChanged: (query) {
                          setDialogState(() {
                            filtered = query.isEmpty
                                ? widget.items
                                : widget.items
                                    .where((i) => i.label
                                        .toLowerCase()
                                        .contains(query.toLowerCase()))
                                    .toList();
                          });
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: filtered.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('No results found'),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              itemBuilder: (_, index) {
                                final item = filtered[index];
                                final isSelected = item.value == widget.value;
                                return ListTile(
                                  title: Text(item.label),
                                  selected: isSelected,
                                  selectedTileColor:
                                      colors.accentSubtle,
                                  trailing: isSelected
                                      ? Icon(Icons.check,
                                          color: colors.accent)
                                      : null,
                                  onTap: () =>
                                      Navigator.pop(dialogContext, item.value),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );

    _searchController.clear();
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) FocusScope.of(context).unfocus();

    if (selected != null) {
      widget.onChanged?.call(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: width),
        );

    final inputDecoration = InputDecoration(
      labelText: widget.label,
      labelStyle: TextStyle(
        color: colors.textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      floatingLabelStyle: TextStyle(
        color: colors.accent,
        fontWeight: FontWeight.w500,
      ),
      hintText: widget.hintText,
      hintStyle: TextStyle(color: colors.textHint),
      filled: true,
      fillColor: colors.background,
      border: border(colors.border, 1.0),
      enabledBorder: border(colors.border, 1.0),
      focusedBorder: border(colors.accent, 1.5),
      disabledBorder: border(colors.border, 1.0),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );

    if (widget.searchable) {
      return GestureDetector(
        onTap: widget.enabled ? _showSearchDialog : null,
        child: AbsorbPointer(
          child: AppTextField(
            controller: _displayController,
            label: widget.label,
            hintText: widget.hintText,
            enabled: widget.enabled,
            suffixIcon: Icon(Icons.arrow_drop_down, color: colors.textSecondary),
          ),
        ),
      );
    }

    return DropdownButtonFormField<T>(
      value: widget.value,
      items: widget.items
          .map((i) => DropdownMenuItem<T>(
                value: i.value,
                child: Text(i.label),
              ))
          .toList(),
      onChanged: widget.enabled ? widget.onChanged : null,
      validator: widget.validator,
      decoration: inputDecoration,
      style: TextStyle(color: colors.textPrimary, fontSize: 14),
      dropdownColor: colors.surface,
      icon: Icon(Icons.arrow_drop_down, color: colors.textSecondary),
    );
  }
}
