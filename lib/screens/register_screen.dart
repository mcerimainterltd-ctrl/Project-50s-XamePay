import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/auth_service.dart';
import '../shared/models/xame_user.dart';

const _emerald = Color(0xFF064E3B);
const _green = Color(0xFF087F5B);
const _gold = Color(0xFFE6C978);
const _ivory = Color(0xFFFAFAF7);
const _charcoal = Color(0xFF202824);

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _day = TextEditingController();
  final _month = TextEditingController();
  final _year = TextEditingController();
  final _phone = TextEditingController();
  final _referral = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _otp = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _busy = false;
  bool _otpSent = false;
  XameUser? _createdUser;
  String? _error;
  // XAMEPAY_HOME_COUNTRY_V1
  String? _homeCountry;
  List<Map<String, dynamic>> _regions = [];
  bool _regionsFailed = false;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _day.dispose();
    _month.dispose();
    _year.dispose();
    _phone.dispose();
    _referral.dispose();
    _password.dispose();
    _confirm.dispose();
    _otp.dispose();
    super.dispose();
  }

  AuthService get _auth => ref.read(authServiceProvider);

  Future<void> _loadRegions() async {
    if (mounted) setState(() => _regionsFailed = false);
    try {
      final list = await _auth.fetchOpenRegions();
      if (!mounted) return;
      setState(() {
        _regions = list;
        _regionsFailed = list.isEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _regionsFailed = true);
    }
  }

  Widget _countryPicker() {
    if (_regions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _regionsFailed
            ? TextButton.icon(
                onPressed: _loadRegions,
                icon: const Icon(Icons.refresh),
                label: const Text('Could not load countries. Tap to retry.'),
              )
            : const Text('Loading countries…'),
      );
    }
    return DropdownButtonFormField<String>(
      value: _homeCountry,
      isExpanded: true,
      decoration: _decoration('Country of your wallet'),
      items: _regions
          .map((r) => DropdownMenuItem<String>(
                value: r['code'].toString(),
                child: Text('${r['name']} (${r['currency']})'),
              ))
          .toList(),
      onChanged: _busy ? null : (v) => setState(() => _homeCountry = v),
      validator: (v) => v == null ? 'Choose your wallet country' : null,
    );
  }

  InputDecoration _decoration(String label, {String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDDE5DF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDDE5DF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _green, width: 1.6),
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool obscure = false,
    Widget? suffix,
    int maxLength = 0,
  }) {
    return TextFormField(
      controller: controller,
      decoration: _decoration(label, hint: hint).copyWith(
        suffixIcon: suffix,
        counterText: maxLength > 0 ? null : '',
      ),
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      obscureText: obscure,
      maxLength: maxLength > 0 ? maxLength : null,
      enabled: !_busy,
      autocorrect: false,
    );
  }

  String _dateString() {
    final d = int.tryParse(_day.text.trim());
    final m = int.tryParse(_month.text.trim());
    final y = int.tryParse(_year.text.trim());
    if (d == null || m == null || y == null) return '';
    return '${y.toString().padLeft(4, '0')}-'
        '${m.toString().padLeft(2, '0')}-'
        '${d.toString().padLeft(2, '0')}';
  }

  void _showError(Object error) {
    if (!mounted) return;
    setState(() {
      _error = error.toString().replaceFirst('Exception: ', '');
    });
  }

  Future<void> _submit() async {
    if (_busy || _createdUser != null) return;
    FocusScope.of(context).unfocus();
    setState(() => _error = null);

    if (!_formKey.currentState!.validate()) return;

    final day = int.tryParse(_day.text.trim());
    final month = int.tryParse(_month.text.trim());
    final year = int.tryParse(_year.text.trim());

    if (day == null || month == null || year == null) {
      setState(() => _error = 'Enter your complete date of birth.');
      return;
    }

    final dobError = _auth.validateRegistrationDob(day, month, year);
    if (dobError != null) {
      setState(() => _error = dobError);
      return;
    }

    final phone = _phone.text.trim();
    final password = _password.text;
    if (password != _confirm.text) {
      setState(() => _error = 'Your passwords do not match.');
      return;
    }

    if (_homeCountry == null) {
      setState(() => _error = 'Choose the country for your wallet.');
      return;
    }
    setState(() => _busy = true);
    try {
      if (phone.isNotEmpty && !_otpSent) {
        await _auth.sendRegistrationOtp(phone);
        if (!mounted) return;
        setState(() {
          _otpSent = true;
          _error = null;
        });
        return;
      }

      if (phone.isNotEmpty) {
        final code = _otp.text.trim();
        if (!RegExp(r'^\d{6}$').hasMatch(code)) {
          setState(() => _error = 'Enter the six-digit verification code.');
          return;
        }
        await _auth.verifyRegistrationOtp(phone: phone, otp: code);
      }

      final user = await _auth.register(
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        dob: _dateString(),
        password: password,
        phone: phone.isEmpty ? null : phone,
        homeCountry: _homeCountry,
      );

      final referral = _referral.text.trim();
      if (referral.isNotEmpty) {
        try {
          await _auth.registerReferral(
            newUserId: user.xameId,
            referralCode: referral,
          );
        } catch (_) {
          // Referral processing must not invalidate a successful registration.
        }
      }

      if (!mounted) return;
      setState(() => _createdUser = user);
    } catch (error) {
      if (phone.isNotEmpty && _otpSent && mounted) {
        setState(() {
          _otpSent = false;
          _otp.clear();
        });
      }
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _heading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _charcoal,
            fontSize: 25,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF66736B),
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 20),
      child: Text(
        text,
        style: const TextStyle(
          color: _emerald,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    final user = _createdUser!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: Color(0xFFE4F2E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: _green,
                size: 46,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Account created',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                color: _charcoal,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your XamePay account has been created. Keep your Xame-ID safe.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF66736B), height: 1.5),
            ),
            const SizedBox(height: 28),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _emerald,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Text(
                    'YOUR XAME-ID',
                    style: TextStyle(
                      color: _gold,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    user.xameId,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: user.xameId),
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Xame-ID copied.')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy Xame-ID'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: _gold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Sign in now'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading(
            'Create your account',
            'Join XamePay with a secure account of your own.',
          ),
          _sectionLabel('PERSONAL DETAILS'),
          Row(
            children: [
              Expanded(
                child: _field(
                  controller: _first,
                  label: 'First name',
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter your first name.'
                      : null,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s{2,}')),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  controller: _last,
                  label: 'Last name',
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter your last name.'
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Date of birth',
            style: TextStyle(
              color: _charcoal,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _field(
                  controller: _day,
                  label: 'Day',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  validator: (v) => int.tryParse(v ?? '') == null
                      ? 'Required'
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _field(
                  controller: _month,
                  label: 'Month',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  validator: (v) => int.tryParse(v ?? '') == null
                      ? 'Required'
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _field(
                  controller: _year,
                  label: 'Year',
                  hint: 'YYYY',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  validator: (v) => v == null || v.trim().length != 4
                      ? 'Enter year'
                      : null,
                ),
              ),
            ],
          ),
          _sectionLabel('WALLET COUNTRY'),
          _countryPicker(),
          _sectionLabel('ACCOUNT SECURITY'),
          _field(
            controller: _phone,
            label: 'Phone number (optional)',
            hint: 'e.g. +263771234567',
            keyboardType: TextInputType.phone,
            validator: (v) {
              final value = (v ?? '').trim();
              if (value.isNotEmpty &&
                  !RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(value)) {
                return 'Use international format, e.g. +263771234567.';
              }
              return null;
            },
          ),
          if (_otpSent) ...[
            const SizedBox(height: 16),
            _field(
              controller: _otp,
              label: 'Six-digit verification code',
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? '')
                  ? null
                  : 'Enter the six-digit code.',
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        setState(() {
                          _otpSent = false;
                          _otp.clear();
                          _error = null;
                        });
                      },
                child: const Text('Change phone number'),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _field(
            controller: _password,
            label: 'Password',
            obscure: _obscurePassword,
            suffix: IconButton(
              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
              onPressed: () => setState(
                () => _obscurePassword = !_obscurePassword,
              ),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Enter a password.';
              }
              final result = _auth.validatePassword(v);
              return result.isValid
                  ? null
                  : 'Password needs: ${result.errors.join(', ')}.';
            },
          ),
          const SizedBox(height: 16),
          _field(
            controller: _confirm,
            label: 'Confirm password',
            obscure: _obscureConfirm,
            suffix: IconButton(
              tooltip: _obscureConfirm ? 'Show password' : 'Hide password',
              onPressed: () => setState(
                () => _obscureConfirm = !_obscureConfirm,
              ),
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
            validator: (v) => v != _password.text
                ? 'Passwords do not match.'
                : null,
          ),
          _sectionLabel('OPTIONAL'),
          _field(
            controller: _referral,
            label: 'Referral code',
            hint: 'Enter a referral code if you have one',
          ),
          if (_error != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEEE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFF9B2525),
                  fontSize: 13,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _busy ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                disabledBackgroundColor: const Color(0xFF9CB8AA),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _otpSent ? 'Verify and create account' : 'Create account',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Your information is used to create and secure your account.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF7A857E),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ivory,
      appBar: AppBar(
        backgroundColor: _ivory,
        foregroundColor: _emerald,
        elevation: 0,
        title: const Text(
          'XamePay',
          style: TextStyle(
            color: _emerald,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: _createdUser != null
            ? _buildSuccess()
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/xamepay_logo.png',
                      width: 76,
                      height: 76,
                      filterQuality: FilterQuality.high,
                    ),
                    const SizedBox(height: 22),
                    _buildForm(),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: _busy ? null : () => Navigator.of(context).pop(),
                      child: const Text(
                        'Already have an account? Sign in',
                        style: TextStyle(
                          color: _emerald,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
