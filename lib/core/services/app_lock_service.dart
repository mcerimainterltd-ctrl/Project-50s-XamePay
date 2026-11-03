import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import '../config/constants.dart';

/// Local six-digit app lock. Only a salted, iterated hash is stored.
class AppLockService {
  static const _s = FlutterSecureStorage();
  static const _kHash = 'xamepay:lock_hash';
  static const _kSalt = 'xamepay:lock_salt';
  static const _kFails = 'xamepay:lock_fails';
  static const maxFails = 5;
  static const _kReset = 'xamepay:lock_reset';

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
    final hashed = _hash(pin, salt);
    await _s.write(key: _kHash, value: hashed);
    final replace = (await _s.read(key: _kReset)) == '1';
    await _s.delete(key: _kReset);
    final accepted = await _push(salt, hashed, replace: replace);
    if (!accepted) await restoreFromServer();
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

  static Future<Dio?> _api() async {
    try {
      final token = await _s.read(key: AppConstants.keySessionToken);
      if (token == null || token.trim().isEmpty) return null;
      return Dio(BaseOptions(
        baseUrl: AppConstants.serverUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token.trim()}',
        },
      ));
    } catch (_) {
      return null;
    }
  }

  /// Returns false only when the server refused to overwrite an existing code.
  static Future<bool> _push(String salt, String hash,
      {bool replace = false}) async {
    try {
      final api = await _api();
      if (api == null) return true;
      await api.post('/api/app-lock/set', data: {
        'salt': salt,
        'hash': hash,
        if (replace) 'replace': true,
      });
      return true;
    } on DioException catch (e) {
      return e.response?.statusCode != 409;
    } catch (_) {
      return true;
    }
  }

  /// 1 = restored from server, 0 = server has no code, -1 = server unreachable.
  static Future<int> restoreFromServer() async {
    try {
      final api = await _api();
      if (api == null) return -1;
      final r = await api.get('/api/app-lock/get');
      final d = r.data;
      if (d is! Map || d['success'] != true) return -1;
      if (d['hasLock'] != true) return 0;
      final salt = d['salt'];
      final hash = d['hash'];
      if (salt is! String || hash is! String || salt.isEmpty || hash.isEmpty) {
        return 0;
      }
      await _s.write(key: _kSalt, value: salt);
      await _s.write(key: _kHash, value: hash);
      await _s.write(key: _kFails, value: '0');
      return 1;
    } catch (_) {
      return -1;
    }
  }

  /// Existing installs: upload a code that only exists on this phone.
  static Future<void> syncLocalToServer() async {
    try {
      final salt = await _s.read(key: _kSalt);
      final hash = await _s.read(key: _kHash);
      if (salt == null || hash == null || salt.isEmpty || hash.isEmpty) return;
      await _push(salt, hash);
    } catch (_) {}
  }

  static Future<void> requestReset() => _s.write(key: _kReset, value: '1');
  static Future<bool> resetRequested() async =>
      (await _s.read(key: _kReset)) == '1';

  static Future<void> clear() async {
    await _s.delete(key: _kHash);
    await _s.delete(key: _kSalt);
    await _s.delete(key: _kFails);
  }
}
