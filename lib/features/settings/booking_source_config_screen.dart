import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/booking_source.dart';
import '../../shared/models/booking_type.dart';
import 'settings_cubit.dart';
import 'settings_widgets.dart';

class BookingSourceConfigScreen extends StatefulWidget {
  const BookingSourceConfigScreen({super.key});

  @override
  State<BookingSourceConfigScreen> createState() =>
      _BookingSourceConfigScreenState();
}

class _BookingSourceConfigScreenState
    extends State<BookingSourceConfigScreen> {
  String? _editingId;
  String? _selectedTypeId;
  String? _addTypeId;
  final _editController = TextEditingController();
  final _addController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    context.read<SettingsCubit>().loadAll();
  }

  @override
  void dispose() {
    _editController.dispose();
    _addController.dispose();
    super.dispose();
  }

  void _startEdit(BookingSource source) {
    setState(() {
      _editingId = source.id;
      _editController.text = source.name;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingId = null;
      _editController.clear();
    });
  }

  Future<void> _saveEdit(BookingSource source) async {
    final name = _editController.text.trim();
    if (name.isEmpty || name == source.name) {
      _cancelEdit();
      return;
    }
    setState(() => _saving = true);
    await context.read<SettingsCubit>().updateBookingSource(source.id, name);
    if (mounted) setState(() { _saving = false; _editingId = null; });
  }

  Future<void> _toggleActive(BookingSource source) async {
    setState(() => _saving = true);
    await context
        .read<SettingsCubit>()
        .setBookingSourceActive(source.id, isActive: !source.isActive);
    if (mounted) setState(() { _saving = false; _editingId = null; });
  }

  Future<void> _addSource() async {
    final name = _addController.text.trim();
    final typeId = _addTypeId ?? _selectedTypeId;
    if (name.isEmpty || typeId == null) return;
    setState(() => _saving = true);
    await context.read<SettingsCubit>().addBookingSource(name, typeId);
    if (mounted) {
      _addController.clear();
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.nav,
        elevation: 0,
        leading: BackButton(color: colors.textPrimary),
        title: Text(
          'Booking Sources',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: colors.textPrimary,
          ),
        ),
      ),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          if (state is SettingsLoading || state is SettingsInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is SettingsError) {
            return SettingsErrorView(
              message: state.message,
              colors: colors,
              onRetry: () => context.read<SettingsCubit>().loadAll(),
            );
          }
          if (state is SettingsLoaded) {
            // Default the type filter and add-type to first type
            if (_selectedTypeId == null && state.bookingTypes.isNotEmpty) {
              _selectedTypeId = state.bookingTypes.first.id;
              _addTypeId = state.bookingTypes.first.id;
            }
            return _buildContent(
              context,
              state.bookingTypes,
              state.bookingSources,
              colors,
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<BookingType> types,
    List<BookingSource> allSources,
    AppColors colors,
  ) {
    final filteredSources = _selectedTypeId == null
        ? allSources
        : allSources.where((s) => s.bookingTypeId == _selectedTypeId).toList();

    final typeMap = {for (final t in types) t.id: t.name};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type filter pills
          _TypeFilterPills(
            types: types,
            selectedId: _selectedTypeId,
            colors: colors,
            onSelect: (id) => setState(() {
              _selectedTypeId = id;
              _addTypeId = id;
              _editingId = null;
            }),
          ),
          const SizedBox(height: 16),
          if (filteredSources.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No sources for this type.',
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < filteredSources.length; i++) ...[
                    _SourceRow(
                      source: filteredSources[i],
                      typeName: typeMap[filteredSources[i].bookingTypeId] ?? '',
                      isEditing: _editingId == filteredSources[i].id,
                      isSaving: _saving,
                      editController: _editController,
                      colors: colors,
                      onEditTap: () => _startEdit(filteredSources[i]),
                      onSave: () => _saveEdit(filteredSources[i]),
                      onCancel: _cancelEdit,
                      onToggleActive: () => _toggleActive(filteredSources[i]),
                    ),
                    if (i < filteredSources.length - 1)
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: colors.border,
                      ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 12),
          if (_selectedTypeId != null)
            SettingsAddRow(
              controller: _addController,
              isSaving: _saving,
              colors: colors,
              hint: 'Add new source…',
              onAdd: _addSource,
            ),
        ],
      ),
    );
  }
}

class _TypeFilterPills extends StatelessWidget {
  const _TypeFilterPills({
    required this.types,
    required this.selectedId,
    required this.colors,
    required this.onSelect,
  });

  final List<BookingType> types;
  final String? selectedId;
  final AppColors colors;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final type in types)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onSelect(type.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: selectedId == type.id
                        ? colors.accent
                        : colors.accentSubtle,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    type.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: selectedId == type.id
                          ? Colors.white
                          : colors.accent,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.source,
    required this.typeName,
    required this.isEditing,
    required this.isSaving,
    required this.editController,
    required this.colors,
    required this.onEditTap,
    required this.onSave,
    required this.onCancel,
    required this.onToggleActive,
  });

  final BookingSource source;
  final String typeName;
  final bool isEditing;
  final bool isSaving;
  final TextEditingController editController;
  final AppColors colors;
  final VoidCallback onEditTap;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: source.isActive ? 1.0 : 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        source.isActive ? colors.success : colors.textHint,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.name,
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.textPrimary,
                        ),
                      ),
                      if (typeName.isNotEmpty)
                        Text(
                          typeName,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                  onPressed: isSaving ? null : onEditTap,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
            if (isEditing) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.accentSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: editController,
                      autofocus: true,
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        filled: true,
                        fillColor: colors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: isSaving ? null : onCancel,
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: colors.textSecondary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: isSaving ? null : onSave,
                          child: const Text('Save'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: isSaving ? null : onToggleActive,
                          child: Text(
                            source.isActive ? 'Deactivate' : 'Restore',
                            style: TextStyle(
                              color: source.isActive
                                  ? colors.danger
                                  : colors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ] else
              const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
