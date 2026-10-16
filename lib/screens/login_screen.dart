import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/constants.dart';
import '../core/services/auth_service.dart';
import 'register_screen.dart';
import '../shared/models/xame_user.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final Future<void> Function(XameUser user) onAuthenticated;

  const LoginScreen({
    super.key,
    required this.onAuthenticated,
  });

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _busy = false;
  bool _obscurePassword = true;
  bool _otpRequired = false;
  bool _passwordSetupRequired = false;

  String? _pendingSetupXameId;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _message = null;
    });
  }

  Future<void> _login() async {
    if (_busy || !_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });

    try {
      final result = await ref.read(authServiceProvider).login(
            _identifierController.text.trim(),
            _passwordController.text,
            otp: _otpRequired ? _otpController.text.trim() : null,
          );

      if (!mounted) return;

      switch (result.type) {
        case LoginResultType.success:
          setState(() {
            _otpRequired = false;
            _passwordSetupRequired = false;
          });
          await widget.onAuthenticated(result.user!);
          break;

        case LoginResultType.needsOTP:
          setState(() {
            _otpRequired = true;
            _message = result.message ??
                'Enter the verification code sent to your registered contact.';
          });
          break;

        case LoginResultType.needsPasswordSetup:
          setState(() {
            _passwordSetupRequired = true;
            _pendingSetupXameId = result.user!.xameId;
            _message =
                'Your account needs a password before you can continue.';
          });
          break;
      }
    } catch (error) {
      _showError(_cleanError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }

  Future<void> _setPassword() async {
    if (_busy || !_formKey.currentState!.validate()) return;

    final password = _newPasswordController.text;
    final validation =
        ref.read(authServiceProvider).validatePassword(password);

    if (!validation.isValid) {
      _showError(
        'Password requirements:\n${validation.errors.map((e) => '• $e').join('\n')}',
      );
      return;
    }

    if (password != _confirmPasswordController.text) {
      _showError('The passwords do not match.');
      return;
    }

    final xameId = _pendingSetupXameId;
    if (xameId == null || xameId.isEmpty) {
      _showError('Account information is missing. Please try logging in again.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });

    try {
      final response = await Dio(
        BaseOptions(
          baseUrl: AppConstants.serverUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: const {'Content-Type': 'application/json'},
        ),
      ).post(
        '/api/set-password',
        data: {
          'xameId': xameId,
          'newPassword': password,
        },
      );

      final data = response.data;
      if (data is! Map || data['success'] != true) {
        throw Exception(
          data is Map
              ? data['message']?.toString() ?? 'Could not set your password.'
              : 'Unexpected server response.',
        );
      }

      if (!mounted) return;

      _passwordController.clear();
      _otpController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      setState(() {
        _identifierController.text = xameId;
        _passwordSetupRequired = false;
        _otpRequired = false;
        _pendingSetupXameId = null;
        _message = 'Password created. Sign in with your new password.';
      });
    } on DioException catch (error) {
      final data = error.response?.data;
      _showError(
        data is Map && data['message'] is String
            ? data['message'] as String
            : error.type == DioExceptionType.connectionError
                ? 'Could not connect. Check your internet connection.'
                : 'Could not set your password. Please try again.',
      );
    } catch (error) {
      _showError(_cleanError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _backToLogin() {
    setState(() {
      _passwordSetupRequired = false;
      _otpRequired = false;
      _pendingSetupXameId = null;
      _message = null;
      _error = null;
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _otpController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(
                      'assets/images/xamepay_logo.png',
                      width: 96,
                      height: 96,
                      filterQuality: FilterQuality.high,
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'XamePay',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: Color(0xFF064E3B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Your money. Your world.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF68766D),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _passwordSetupRequired
                          ? 'Create your password'
                          : 'Sign in to your wallet',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF202824),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (!_passwordSetupRequired) ...[
                      TextFormField(
                        controller: _identifierController,
                        enabled: !_busy && !_otpRequired,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Xame-ID',
                          hintText: 'Enter your Xame-ID',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter your Xame-ID.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        enabled: !_busy,
                        obscureText: _obscurePassword,
                        textInputAction:
                            _otpRequired ? TextInputAction.next : TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!_otpRequired) _login();
                        },
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter your password.';
                          }
                          return null;
                        },
                      ),
                      if (_otpRequired) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _otpController,
                          enabled: !_busy,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _login(),
                          decoration: const InputDecoration(
                            labelText: 'Verification code',
                            prefixIcon: Icon(Icons.verified_user_outlined),
                          ),
                          validator: (value) {
                            if (_otpRequired &&
                                (value == null || value.trim().isEmpty)) {
                              return 'Enter the verification code.';
                            }
                            return null;
                          },
                        ),
                      ],
                    ] else ...[
                      TextFormField(
                        controller: _newPasswordController,
                        enabled: !_busy,
                        obscureText: _obscurePassword,
                        decoration: const InputDecoration(
                          labelText: 'New password',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter a new password.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirmPasswordController,
                        enabled: !_busy,
                        obscureText: _obscurePassword,
                        decoration: const InputDecoration(
                          labelText: 'Confirm new password',
                          prefixIcon: Icon(Icons.lock_reset_rounded),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Confirm your password.';
                          }
                          return null;
                        },
                      ),
                    ],
                    if (_message != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _message!,
                        style: const TextStyle(
                          color: Color(0xFF087F5B),
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFB42318),
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    ElevatedButton(
                      onPressed: _busy
                          ? null
                          : _passwordSetupRequired
                              ? _setPassword
                              : _login,
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _passwordSetupRequired
                                  ? 'Create password'
                                  : _otpRequired
                                      ? 'Verify and sign in'
                                      : 'Sign in securely',
                            ),
                    ),
                    if (_otpRequired || _passwordSetupRequired) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _busy ? null : _backToLogin,
                        child: const Text('Back to sign in'),
                      ),
                    ],
                    if (!_otpRequired && !_passwordSetupRequired) ...[
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const RegisterScreen(),
                                  ),
                                ),
                        child: const Text('Create your XamePay account'),
                      ),
                    ],
                    const SizedBox(height: 26),
                    const Text(
                      'Secure access to your XamePay wallet',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF7A857E),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
