import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/constants.dart';
import '../../shared/models/xame_user.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final currentUserProvider = StateProvider<XameUser?>((ref) => null);

class AuthService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.serverUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {'Content-Type': 'application/json'},
    ),
  );

  Future<Map<String, String>> authenticatedHeaders({
    Map<String, String>? additional,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (additional != null) ...additional,
    };

    final token = await _storage.read(
      key: AppConstants.keySessionToken,
    );

    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }

    return headers;
  }

  Future<XameUser?> init() async {
    final token = await _storage.read(
      key: AppConstants.keySessionToken,
    );

    if (token == null || token.trim().isEmpty) return null;

    return getSavedUser();
  }

  Future<XameUser?> getSavedUser() async {
    try {
      final raw = await _storage.read(key: AppConstants.keyUser);
      if (raw == null) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      final user = XameUser.fromMap(decoded);
      if (user.xameId.trim().isEmpty) return null;

      return user;
    } catch (_) {
      return null;
    }
  }

  Future<LoginResult> login(
    String xameId,
    String password, {
    String? otp,
    bool isPhone = false,
  }) async {
    final identifier = xameId.trim();

    if (identifier.isEmpty || password.isEmpty) {
      throw Exception('Enter your Xame-ID and password.');
    }

    final body = <String, dynamic>{
      if (isPhone) 'phone': identifier else 'xameId': identifier,
      'password': password,
      if (otp != null && otp.trim().isNotEmpty) 'otp': otp.trim(),
    };

    Response<dynamic> response;

    try {
      response = await _dio.post(
        '/api/login',
        data: body,
        options: Options(
          headers: const {'User-Agent': 'XamePay/1.0'},
        ),
      );
    } on DioException catch (error) {
      final data = error.response?.data;

      // HTTP 403 can indicate that the account needs its initial password.
      if (data is Map && data['requiresPasswordSetup'] == true) {
        final userData = data['user'];
        if (userData is Map) {
          return LoginResult.needsPasswordSetup(
            XameUser.fromMap(Map<String, dynamic>.from(userData)),
          );
        }
        throw Exception(
          'The server returned incomplete account information.',
        );
      }

      if (data is Map && data['message'] is String) {
        throw Exception(data['message']);
      }

      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        throw Exception(
          'Could not connect. Check your internet connection and try again.',
        );
      }

      throw Exception('Login failed. Please try again.');
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('The server returned an unexpected login response.');
    }

    if (data['requiresOTP'] == true) {
      return LoginResult.needsOTP(
        data['message']?.toString() ?? 'Enter the verification code.',
      );
    }

    if (data['requiresPasswordSetup'] == true) {
      final userData = data['user'];
      if (userData is! Map<String, dynamic>) {
        throw Exception('The server returned incomplete account information.');
      }

      return LoginResult.needsPasswordSetup(XameUser.fromMap(userData));
    }

    if (data['success'] != true) {
      throw Exception(data['message']?.toString() ?? 'Login failed.');
    }

    final userData = data['user'];
    final token = data['sessionToken']?.toString();

    if (userData is! Map<String, dynamic> ||
        userData['xameId'] == null ||
        token == null ||
        token.trim().isEmpty) {
      throw Exception(
        'Login response is missing the user or session token.',
      );
    }

    final user = XameUser.fromMap(userData);

    // Persist the session only after a successful, complete response.
    await _storage.write(
      key: AppConstants.keyUser,
      value: jsonEncode(userData),
    );
    await _storage.write(
      key: AppConstants.keySessionToken,
      value: token.trim(),
    );

    return LoginResult.success(user);
  }

  Future<void> logout(String xameId) async {
    final token = await _storage.read(
      key: AppConstants.keySessionToken,
    );

    try {
      if (token != null && token.trim().isNotEmpty) {
        await _dio.post(
          '/api/logout',
          data: {'userId': xameId},
          options: Options(
            headers: {'Authorization': 'Bearer ${token.trim()}'},
          ),
        );
      }
    } catch (_) {
      // Local logout must still work if the server cannot be reached.
    } finally {
      await _storage.delete(key: AppConstants.keySessionToken);
      await _storage.delete(key: AppConstants.keyUser);
    }
  }

  Future<void> forceLogout() async {
    // Never erase unrelated credentials or all secure-storage entries.
    await _storage.delete(key: AppConstants.keySessionToken);
    await _storage.delete(key: AppConstants.keyUser);
  }

  PasswordValidation validatePassword(String password) {
    final errors = <String>[];

    if (password.length < 8) errors.add('At least 8 characters');
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      errors.add('One uppercase letter');
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      errors.add('One lowercase letter');
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) errors.add('One number');
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) {
      errors.add('One special character');
    }

    return PasswordValidation(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
}

class LoginResult {
  final LoginResultType type;
  final XameUser? user;
  final String? message;

  const LoginResult._({
    required this.type,
    this.user,
    this.message,
  });

  factory LoginResult.success(XameUser user) => LoginResult._(
        type: LoginResultType.success,
        user: user,
      );

  factory LoginResult.needsPasswordSetup(XameUser user) => LoginResult._(
        type: LoginResultType.needsPasswordSetup,
        user: user,
      );

  factory LoginResult.needsOTP(String message) => LoginResult._(
        type: LoginResultType.needsOTP,
        message: message,
      );
}

enum LoginResultType {
  success,
  needsPasswordSetup,
  needsOTP,
}

class PasswordValidation {
  final bool isValid;
  final List<String> errors;

  const PasswordValidation({
    required this.isValid,
    required this.errors,
  });
}
