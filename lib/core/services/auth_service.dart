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


  Exception _registrationRequestError(
    DioException error, {
    required String fallback,
  }) {
    final data = error.response?.data;

    if (data is Map) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return Exception(message.trim());
      }

      final errors = data['errors'];
      if (errors is List) {
        final messages = errors
            .map((item) {
              if (item is Map) {
                return item['msg']?.toString() ??
                    item['message']?.toString();
              }
              return item?.toString();
            })
            .whereType<String>()
            .map((message) => message.trim())
            .where((message) => message.isNotEmpty)
            .toList();

        if (messages.isNotEmpty) {
          return Exception(messages.join('\n'));
        }
      }
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return Exception(
        'Could not connect. Check your internet connection and try again.',
      );
    }

    return Exception(fallback);
  }

  String? validateRegistrationDob(int day, int month, int year) {
    final currentYear = DateTime.now().year;

    if (year < 1900 || year > currentYear) {
      return 'Enter a valid year.';
    }
    if (month < 1 || month > 12) {
      return 'Enter a valid month.';
    }
    if (day < 1 || day > 31) {
      return 'Enter a valid day.';
    }

    final date = DateTime(year, month, day);
    if (date.year != year ||
        date.month != month ||
        date.day != day) {
      return 'Enter a valid date of birth.';
    }

    return null;
  }

  // XAMEPAY_HOME_COUNTRY_V1: countries currently open for XamePay wallets.
  Future<List<Map<String, dynamic>>> fetchOpenRegions() async {
    final response = await _dio.get('/api/xamepay/regions');
    final data = response.data;
    if (data is Map && data['success'] == true && data['regions'] is List) {
      return (data['regions'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  Future<void> sendRegistrationOtp(String phone) async {
    late final Response<dynamic> response;
    try {
      response = await _dio.post(
        '/api/auth/send-otp',
        data: {'phone': phone.trim()},
      );
    } on DioException catch (error) {
      throw _registrationRequestError(
        error,
        fallback: 'Could not send verification code. Please try again.',
      );
    }

    final data = response.data;
    if (data is! Map || data['success'] != true) {
      final message = data is Map
          ? data['message']?.toString()
          : null;
      throw Exception(message ?? 'Could not send verification code.');
    }
  }

  Future<void> verifyRegistrationOtp({
    required String phone,
    required String otp,
  }) async {
    late final Response<dynamic> response;
    try {
      response = await _dio.post(
        '/api/auth/verify-otp',
        data: {'phone': phone.trim(), 'otp': otp.trim()},
      );
    } on DioException catch (error) {
      throw _registrationRequestError(
        error,
        fallback: 'Phone verification failed. Please try again.',
      );
    }

    final data = response.data;
    if (data is! Map || data['success'] != true) {
      final message = data is Map
          ? data['message']?.toString()
          : null;
      throw Exception(message ?? 'Phone verification failed.');
    }
  }

  Future<XameUser> register({
    required String firstName,
    required String lastName,
    required String dob,
    required String password,
    String? phone,
    String? homeCountry,
  }) async {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dob)) {
      throw Exception('Invalid date of birth format.');
    }

    final parts = dob.split('-').map(int.parse).toList();
    final dobError =
        validateRegistrationDob(parts[2], parts[1], parts[0]);
    if (dobError != null) throw Exception(dobError);

    final passwordResult = validatePassword(password);
    if (!passwordResult.isValid) {
      throw Exception(passwordResult.errors.join('\n'));
    }

    final normalizedPhone = phone?.trim();
    if (normalizedPhone != null &&
        normalizedPhone.isNotEmpty &&
        !RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(normalizedPhone)) {
      throw Exception(
        'Phone number must be in international format starting with +.',
      );
    }

    late final Response<dynamic> response;
    try {
      response = await _dio.post(
        '/api/register',
        data: {
          'firstName': firstName.trim(),
          'lastName': lastName.trim(),
          'dob': dob,
          'password': password,
          if (normalizedPhone != null && normalizedPhone.isNotEmpty)
            'phone': normalizedPhone,
          if (homeCountry != null && homeCountry.isNotEmpty)
            'homeCountry': homeCountry,
        },
      );
    } on DioException catch (error) {
      throw _registrationRequestError(
        error,
        fallback: 'Registration failed. Please try again.',
      );
    }

    final data = response.data;
    if (data is! Map || data['success'] != true) {
      final message = data is Map
          ? data['message']?.toString() ??
              data['errors']?.toString()
          : null;
      throw Exception(message ?? 'Registration failed.');
    }

    final rawUser = data['user'];
    if (rawUser is! Map) {
      throw Exception('Registration response did not contain a user.');
    }

    final user = XameUser.fromMap(
      Map<String, dynamic>.from(rawUser),
    );

    if (user.xameId.trim().isEmpty) {
      throw Exception('Registration response did not contain a Xame-ID.');
    }

    return user;
  }

  Future<void> registerReferral({
    required String newUserId,
    required String referralCode,
  }) async {
    try {
      await _dio.post(
        '/api/rewards/register-referral',
        data: {
          'newUserId': newUserId,
          'referralCode': referralCode.trim(),
        },
      );
    } catch (_) {
      // Referral processing is optional and must not block registration.
    }
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
