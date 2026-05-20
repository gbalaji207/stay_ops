import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.label,
    this.controller,
    this.hintText,
    this.prefixText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction = TextInputAction.next,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.maxLines = 1,
    this.maxLength,
    this.fontSize = 14,
  });

  final String? label;
  final TextEditingController? controller;
  final String? hintText;
  final String? prefixText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool autofocus;
  final int maxLines;
  final int? maxLength;
  final double fontSize;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: width),
        );

    final enabledBorder = border(colors.border, 1.0);
    final focusedBorder = border(colors.accent, 1.5);

    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      keyboardType: widget.keyboardType,
      textCapitalization: widget.textCapitalization,
      textInputAction: widget.textInputAction,
      inputFormatters: widget.inputFormatters,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      style: TextStyle(color: colors.textPrimary, fontSize: widget.fontSize),
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: TextStyle(
          color: colors.textSecondary,
          fontSize: widget.fontSize,
          fontWeight: FontWeight.w400,
        ),
        floatingLabelStyle: TextStyle(
          color: _isFocused ? colors.accent : colors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        prefixText: widget.prefixText,
        prefixStyle:
            TextStyle(color: colors.textSecondary, fontSize: widget.fontSize),
        prefixIcon: widget.prefixIcon != null
            ? Icon(widget.prefixIcon, color: colors.textSecondary, size: 18)
            : null,
        suffixIcon: widget.suffixIcon,
        hintText: widget.hintText,
        hintStyle: TextStyle(color: colors.textHint),
        filled: true,
        fillColor: colors.background,
        border: enabledBorder,
        enabledBorder: enabledBorder,
        focusedBorder: focusedBorder,
        disabledBorder: enabledBorder,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        counterText: '',
      ),
    );
  }
}
