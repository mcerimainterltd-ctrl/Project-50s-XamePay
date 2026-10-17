import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/services/app_lock_service.dart';

class AppLockScreen extends StatefulWidget {
  final bool setup;
  final Future<void> Function() onDone;
  final Future<void> Function() onReset;

  const AppLockScreen({
    super.key,
    required this.setup,
    required this.onDone,
    required this.onReset,
  });

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  static const _bg = Color(0xFF062B20);
  static const _gold = Color(0xFFE6C978);

  String _pin = '';
  String? _first;
  String _msg = '';
  bool _busy = false;

  String get _title => widget.setup
      ? (_first == null ? 'Create a 6-digit code' : 'Confirm your code')
      : 'Enter your code';

  Future<void> _tap(String d) async {
    if (_busy || _pin.length >= 6) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _msg = '';
    });
    if (_pin.length == 6) await _submit();
  }

  void _back() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    _busy = true;
    final pin = _pin;
    try {
      if (widget.setup) {
        if (_first == null) {
          setState(() {
            _first = pin;
            _pin = '';
          });
        } else if (_first == pin) {
          await AppLockService.setCode(pin);
          await widget.onDone();
        } else {
          setState(() {
            _first = null;
            _pin = '';
            _msg = "Codes didn't match. Start again.";
          });
        }
      } else {
        if (await AppLockService.verify(pin)) {
          await widget.onDone();
        } else {
          final left = await AppLockService.failsLeft();
          if (left <= 0) {
            await widget.onReset();
            return;
          }
          if (!mounted) return;
          setState(() {
            _pin = '';
            _msg = 'Wrong code. $left ${left == 1 ? 'attempt' : 'attempts'} left.';
          });
        }
      }
    } finally {
      _busy = false;
    }
  }

  Widget _key(Widget child, VoidCallback? onTap) => Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(40),
          child: SizedBox(height: 68, child: Center(child: child)),
        ),
      );

  Widget _digit(String d) => _key(
        Text(d,
            style: const TextStyle(
                color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600)),
        () => _tap(d),
      );

  Widget _pad() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(children: [
          Row(children: [_digit('1'), _digit('2'), _digit('3')]),
          Row(children: [_digit('4'), _digit('5'), _digit('6')]),
          Row(children: [_digit('7'), _digit('8'), _digit('9')]),
          Row(children: [
            _key(const SizedBox.shrink(), null),
            _digit('0'),
            _key(const Icon(Icons.backspace_outlined, color: Colors.white70),
                _back),
          ]),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(children: [
            const Spacer(flex: 2),
            const Icon(Icons.lock_outline, color: _gold, size: 40),
            const SizedBox(height: 16),
            Text(_title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                6,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length ? _gold : Colors.transparent,
                    border: Border.all(color: _gold, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 20,
              child: Text(_msg,
                  style: const TextStyle(
                      color: Color(0xFFFF8A80), fontSize: 13)),
            ),
            const Spacer(),
            _pad(),
            if (!widget.setup)
              TextButton(
                onPressed: _busy ? null : () => widget.onReset(),
                child: const Text('Forgot code? Sign in again',
                    style: TextStyle(color: Colors.white70)),
              ),
            const SizedBox(height: 12),
          ]),
        ),
      ),
    );
  }
}
