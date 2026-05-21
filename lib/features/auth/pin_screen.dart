import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'auth_cubit.dart';

// PIN screen is always dark regardless of OS theme — intentional exception to
// the "use theme tokens" rule. The spec requires a fixed dark background.
const _kPinBackground = Color(0xFF0D0F1A);
const _kAccentColor = Color(0xFF534AB7);
const _kDotFilled = Color(0xFF7F77DD);
const _kDotBorder = Color(0xFF3C3489);
const _kSubtitleColor = Color(0xFF5A5C70);
const _kKeyBackground = Color(0xFF1C1F2E);
const _kErrorColor = Color(0xFFE24B4A);
const _kRoleHintColor = Color(0xFF3C3066);

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> with TickerProviderStateMixin {
  String _pin = '';
  bool _isError = false;
  String _appVersion = '';
  Timer? _clearTimer;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _appVersion = 'v${info.version} (${info.buildNumber})');
    });
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _clearTimer?.cancel();
    super.dispose();
  }

  void _onDigit(String digit) {
    if (_isError || _pin.length >= 4) return;
    setState(() => _pin += digit);
    if (_pin.length == 4) {
      context.read<AuthCubit>().verifyPin(_pin);
    }
  }

  void _onBackspace() {
    if (_isError || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go('/home');
        } else if (state is AuthError) {
          setState(() {
            _isError = true;
            _pin = '';
          });
          _shakeController.forward(from: 0);
          _clearTimer?.cancel();
          _clearTimer = Timer(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() => _isError = false);
              context.read<AuthCubit>().resetError();
            }
          });
        }
      },
      child: Scaffold(
        backgroundColor: _kPinBackground,
        body: SafeArea(
          child: Column(
            children: [
              // Vertically centered header: logo, name, subtitle, PIN dots
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LogoMark(),
                      const SizedBox(height: 12),
                      const Text(
                        'StayOps',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Hospitality income tracker',
                        style: TextStyle(fontSize: 12, color: _kSubtitleColor),
                      ),
                      const SizedBox(height: 40),
                      const Text(
                        'Enter your 4-digit PIN',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                      const SizedBox(height: 20),
                      AnimatedBuilder(
                        animation: _shakeAnimation,
                        builder: (context, child) => Transform.translate(
                          offset: Offset(_shakeAnimation.value, 0),
                          child: child,
                        ),
                        child: _PinDots(pinLength: _pin.length),
                      ),
                    ],
                  ),
                ),
              ),
              // Numpad capped at 260dp so keys stay compact on all screen sizes
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _Numpad(onDigit: _onDigit, onBackspace: _onBackspace),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 20,
                child: Text(
                  _isError ? 'Incorrect PIN. Try again.' : '',
                  style: const TextStyle(fontSize: 12, color: _kErrorColor),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _appVersion,
                style: const TextStyle(fontSize: 11, color: _kRoleHintColor),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: _kAccentColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.home_work, color: Colors.white, size: 26),
    );
  }
}

class _PinDots extends StatelessWidget {
  const _PinDots({required this.pinLength});

  final int pinLength;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (index) {
        final filled = index < pinLength;
        return Padding(
          padding: EdgeInsets.only(right: index < 3 ? 14 : 0),
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? _kDotFilled : Colors.transparent,
              border: Border.all(
                color: filled ? _kDotFilled : _kDotBorder,
                width: 1.5,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _Numpad extends StatelessWidget {
  const _Numpad({required this.onDigit, required this.onBackspace});

  final void Function(String) onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder lets keys scale to the available width.
    // key_width = (total_width - 2 gaps) / 3
    return LayoutBuilder(
      builder: (context, constraints) {
        final keyWidth = (constraints.maxWidth - 2 * 10) / 3;
        final keyHeight = keyWidth * 0.72;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRow(['1', '2', '3'], keyWidth, keyHeight),
            const SizedBox(height: 10),
            _buildRow(['4', '5', '6'], keyWidth, keyHeight),
            const SizedBox(height: 10),
            _buildRow(['7', '8', '9'], keyWidth, keyHeight),
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(width: keyWidth, height: keyHeight), // empty
                const SizedBox(width: 10),
                _DigitKey(digit: '0', width: keyWidth, height: keyHeight, onTap: onDigit),
                const SizedBox(width: 10),
                _BackspaceKey(width: keyWidth, height: keyHeight, onTap: onBackspace),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildRow(List<String> digits, double keyWidth, double keyHeight) {
    return Row(
      children: digits.asMap().entries.map((e) {
        return Padding(
          padding: EdgeInsets.only(right: e.key < 2 ? 10 : 0),
          child: _DigitKey(
            digit: e.value,
            width: keyWidth,
            height: keyHeight,
            onTap: onDigit,
          ),
        );
      }).toList(),
    );
  }
}

class _DigitKey extends StatelessWidget {
  const _DigitKey({
    required this.digit,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final String digit;
  final double width;
  final double height;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(digit),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _kKeyBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.07),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(
              fontSize: 22,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _BackspaceKey extends StatelessWidget {
  const _BackspaceKey({
    required this.width,
    required this.height,
    required this.onTap,
  });

  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _kKeyBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.07),
            width: 1,
          ),
        ),
        child: const Icon(
          Icons.backspace_outlined,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}
