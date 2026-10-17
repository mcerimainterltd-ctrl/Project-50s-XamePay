import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Local six-digit app lock. Only a salted, iterated hash is stored.
class AppLockService {
  static const _s = FlutterSecureStorage();
  static const _kHash = 'xamepay:lock_hash';
  static const _kSalt = 'xamepay:lock_salt';
  static const _kFails = 'xamepay:lock_fails';
  static const maxFails = 5;

  static String _hash(String pin, String salt) {
    List<int> d = utf8.encode('$salt:$pin');
    final s = utf8.encode(salt);
    for (var i = 0; i < 20000; i++) {
      d = sha256.convert([...d, ...s]).bytes;
    }
    return base64Encode(d);
  }

  static bool _eq(String a, String b) {
    if (a.length != b.length) return false;
    var r = 0;
    for (var i = 0; i < a.length; i++) {
      r |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return r == 0;
  }

  static Future<bool> hasLock() async {
    try {
      final h = await _s.read(key: _kHash);
      final s = await _s.read(key: _kSalt);
      return h != null && h.isNotEmpty && s != null && s.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setCode(String pin) async {
    final r = Random.secure();
    final salt = base64Encode(List<int>.generate(16, (_) => r.nextInt(256)));
    await _s.write(key: _kSalt, value: salt);
    await _s.write(key: _kHash, value: _hash(pin, salt));
    await _s.write(key: _kFails, value: '0');
  }

  static Future<bool> verify(String pin) async {
    final salt = await _s.read(key: _kSalt);
    final hash = await _s.read(key: _kHash);
    if (salt == null || hash == null) return false;
    if (_eq(_hash(pin, salt), hash)) {
      await _s.write(key: _kFails, value: '0');
      return true;
    }
    final n = (int.tryParse(await _s.read(key: _kFails) ?? '0') ?? 0) + 1;
    await _s.write(key: _kFails, value: '$n');
    return false;
  }

  static Future<int> failsLeft() async {
    final n = int.tryParse(await _s.read(key: _kFails) ?? '0') ?? 0;
    return max(0, maxFails - n);
  }

  static Future<void> clear() async {
    await _s.delete(key: _kHash);
    await _s.delete(key: _kSalt);
    await _s.delete(key: _kFails);
  }
}
