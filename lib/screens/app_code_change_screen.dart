import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/services/app_lock_service.dart';

/// Change the 6-digit app-opening code: current code, new code, confirm.
class AppCodeChangeScreen extends StatefulWidget {
  const AppCodeChangeScreen({super.key});

  @override
  State<AppCodeChangeScreen> createState() => _AppCodeChangeScreenState();
}

class _AppCodeChangeScreenState extends State<AppCodeChangeScreen> {
  static const _bg = Color(0xFF062B20);
  static const _gold = Color(0xFFE6C978);

  int _stage = 0; // 0 = current, 1 = new, 2 = confirm
  String _pin = '';
  String _current = '';
  String _first = '';
  String _msg = '';
  bool _busy = false;

  String get _title => _stage == 0
      ? 'Enter your current code'
      : _stage == 1
          ? 'Enter a new 6-digit code'
          : 'Confirm your new code';

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
      if (_stage == 0) {
        if (await AppLockService.failsLeft() <= 0) {
          if (!mounted) return;
          setState(() {
            _pin = '';
            _msg = 'Too many wrong attempts. Sign out and use Forgot code.';
          });
          return;
        }
        if (await AppLockService.verify(pin)) {
          if (!mounted) return;
          setState(() {
            _current = pin;
            _pin = '';
            _stage = 1;
          });
        } else {
          final left = await AppLockService.failsLeft();
          if (!mounted) return;
          setState(() {
            _pin = '';
            _msg = left > 0
                ? 'Wrong code. $left ${left == 1 ? 'attempt' : 'attempts'} left.'
                : 'Too many wrong attempts. Sign out and use Forgot code.';
          });
        }
      } else if (_stage == 1) {
        if (pin == _current) {
          setState(() {
            _pin = '';
            _msg = 'The new code must be different from the current one.';
          });
        } else {
          setState(() {
            _first = pin;
            _pin = '';
            _stage = 2;
          });
        }
      } else {
        if (pin != _first) {
          setState(() {
            _pin = '';
            _first = '';
            _stage = 1;
            _msg = 'Codes did not match. Enter the new code again.';
          });
          return;
        }
        final err = await AppLockService.changeCode(_current, pin);
        if (!mounted) return;
        if (err != null) {
          setState(() {
            _pin = '';
            _first = '';
            _stage = 1;
            _msg = err;
          });
          return;
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('App code changed')));
        Navigator.of(context).pop(true);
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
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('App opening code'),
      ),
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
            height: 36,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(_msg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFFFF8A80), fontSize: 13)),
            ),
          ),
          const Spacer(),
          _pad(),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}
