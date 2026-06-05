import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_text_field.dart';

class ChannelManagerTokenScreen extends StatefulWidget {
  const ChannelManagerTokenScreen({super.key});

  @override
  State<ChannelManagerTokenScreen> createState() =>
      _ChannelManagerTokenScreenState();
}

class _ChannelManagerTokenScreenState
    extends State<ChannelManagerTokenScreen> {
  final _tokenController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _decodeJwtPayload(String token) {
    final parts = token.trim().split('.');
    if (parts.length != 3) throw const FormatException('Invalid JWT structure');
    var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
    while (payload.length % 4 != 0) {
      payload += '=';
    }
    return jsonDecode(utf8.decode(base64Decode(payload)))
        as Map<String, dynamic>;
  }

  String _toIso(dynamic unix) {
    final ms = (unix as num).toInt() * 1000;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String();
  }

  Future<void> _save() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;

    setState(() => _saving = true);
    try {
      final payload = _decodeJwtPayload(token);
      final iat = payload['iat'];
      final exp = payload['exp'];
      if (iat == null || exp == null) {
        throw const FormatException('JWT missing iat or exp claims');
      }

      await Supabase.instance.client.functions.invoke(
        'channel-manager-tokens-upsert',
        body: {
          'channel_manager_token': token,
          'created_at': _toIso(iat),
          'expired_at': _toIso(exp),
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token saved successfully')),
      );
      context.pop();
    } on FormatException catch (e) {
      if (!mounted) return;
      _showError('Invalid JWT token: ${e.message}');
    } on FunctionException catch (e) {
      if (!mounted) return;
      _showError('Edge function error: ${e.details}');
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to save token');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).extension<AppColors>()!.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.nav,
        elevation: 0,
        title: Text(
          'Channel Manager Token',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: colors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.accentSubtle,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: colors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Paste the JWT token from your channel manager. '
                      'The expiry date will be read automatically from the token.',
                      style: TextStyle(fontSize: 12, color: colors.accent),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AppTextField(
              label: 'JWT Token',
              controller: _tokenController,
              maxLines: 6,
              hintText: 'Paste JWT token here',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accent,
                  disabledBackgroundColor: colors.border,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _saving
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.textPrimary,
                        ),
                      )
                    : const Text(
                        'Save Token',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
