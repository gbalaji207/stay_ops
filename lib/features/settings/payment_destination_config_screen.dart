import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/payment_destination.dart';
import 'settings_cubit.dart';
import 'settings_widgets.dart';

class PaymentDestinationConfigScreen extends StatefulWidget {
  const PaymentDestinationConfigScreen({super.key});

  @override
  State<PaymentDestinationConfigScreen> createState() =>
      _PaymentDestinationConfigScreenState();
}

class _PaymentDestinationConfigScreenState
    extends State<PaymentDestinationConfigScreen> {
  String? _editingId;
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

  void _startEdit(PaymentDestination dest) {
    setState(() {
      _editingId = dest.id;
      _editController.text = dest.name;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingId = null;
      _editController.clear();
    });
  }

  Future<void> _saveEdit(PaymentDestination dest) async {
    final name = _editController.text.trim();
    if (name.isEmpty || name == dest.name) {
      _cancelEdit();
      return;
    }
    setState(() => _saving = true);
    await context
        .read<SettingsCubit>()
        .updatePaymentDestination(dest.id, name);
    if (mounted) setState(() { _saving = false; _editingId = null; });
  }

  Future<void> _toggleActive(PaymentDestination dest) async {
    setState(() => _saving = true);
    await context
        .read<SettingsCubit>()
        .setPaymentDestinationActive(dest.id, isActive: !dest.isActive);
    if (mounted) setState(() { _saving = false; _editingId = null; });
  }

  Future<void> _addDestination() async {
    final name = _addController.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    await context.read<SettingsCubit>().addPaymentDestination(name);
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
          'Payment Destinations',
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
            return _buildList(context, state.paymentDestinations, colors);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<PaymentDestination> destinations,
    AppColors colors,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                for (int i = 0; i < destinations.length; i++) ...[
                  _DestinationRow(
                    destination: destinations[i],
                    isEditing: _editingId == destinations[i].id,
                    isSaving: _saving,
                    editController: _editController,
                    colors: colors,
                    onEditTap: () => _startEdit(destinations[i]),
                    onSave: () => _saveEdit(destinations[i]),
                    onCancel: _cancelEdit,
                    onToggleActive: () => _toggleActive(destinations[i]),
                  ),
                  if (i < destinations.length - 1)
                    Divider(height: 1, thickness: 1, color: colors.border),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SettingsAddRow(
            controller: _addController,
            isSaving: _saving,
            colors: colors,
            hint: 'Add new destination…',
            onAdd: _addDestination,
          ),
        ],
      ),
    );
  }
}

class _DestinationRow extends StatelessWidget {
  const _DestinationRow({
    required this.destination,
    required this.isEditing,
    required this.isSaving,
    required this.editController,
    required this.colors,
    required this.onEditTap,
    required this.onSave,
    required this.onCancel,
    required this.onToggleActive,
  });

  final PaymentDestination destination;
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
      opacity: destination.isActive ? 1.0 : 0.5,
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
                    color: destination.isActive
                        ? colors.success
                        : colors.textHint,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    destination.name,
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.textPrimary,
                    ),
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
                      style:
                          TextStyle(fontSize: 14, color: colors.textPrimary),
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
                            destination.isActive ? 'Deactivate' : 'Restore',
                            style: TextStyle(
                              color: destination.isActive
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
