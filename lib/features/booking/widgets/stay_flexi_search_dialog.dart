import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_theme.dart';
import '../booking_repository.dart';

Future<Map<String, dynamic>?> showStayFlexiSearchDialog(
    BuildContext context) async {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => const _StayFlexiSearchDialog(),
  );
}

class _StayFlexiSearchDialog extends StatefulWidget {
  const _StayFlexiSearchDialog();

  @override
  State<_StayFlexiSearchDialog> createState() =>
      _StayFlexiSearchDialogState();
}

class _StayFlexiSearchDialogState extends State<_StayFlexiSearchDialog> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final sfBookingId = _controller.text.trim();
    if (sfBookingId.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final exists =
          await BookingRepository().stayFlexiBookingExists(sfBookingId);
      if (!mounted) return;
      if (exists) {
        setState(() {
          _loading = false;
          _error = 'This booking is already added.';
        });
        return;
      }

      final response =
          await Supabase.instance.client.functions.invoke(
        'get-booking-info-from-sf',
        body: {
          'sfBookingId': sfBookingId,
          'hotelId': AppConstants.sfHotelId,
        },
      );

      if (!mounted) return;

      final data = response.data;
      if (data == null) {
        setState(() {
          _loading = false;
          _error = 'No booking found for this ID.';
        });
        return;
      }

      Navigator.of(context).pop(data as Map<String, dynamic>);
    } on FunctionException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.details?.toString() ?? 'Failed to fetch booking details.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(
        'Stay Flexi Booking',
        style: TextStyle(color: colors.textPrimary, fontSize: 17),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _loading ? null : _search(),
            style: TextStyle(color: colors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Stay Flexi Booking ID',
              labelStyle: TextStyle(color: colors.textSecondary),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colors.accent, width: 2),
              ),
              filled: true,
              fillColor: colors.background,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: colors.danger, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : FilledButton(
                onPressed: _controller.text.trim().isEmpty ? null : _search,
                child: const Text('Search'),
              ),
      ],
    );
  }
}
