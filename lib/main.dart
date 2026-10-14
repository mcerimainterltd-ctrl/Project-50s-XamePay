import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/constants.dart';
import 'core/services/auth_service.dart';
import 'core/services/socket_service.dart';
import 'screens/login_screen.dart';
import 'screens/xame_pay_screen.dart';
import 'shared/models/xame_user.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: XamePayApp()));
}

class XamePayApp extends StatelessWidget {
  const XamePayApp({super.key});

  static const emerald = Color(0xFF064E3B);
  static const green = Color(0xFF087F5B);
  static const gold = Color(0xFFE6C978);
  static const warmWhite = Color(0xFFFAFAF7);
  static const charcoal = Color(0xFF202824);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: warmWhite,
        colorScheme: ColorScheme.fromSeed(
          seedColor: emerald,
          primary: emerald,
          secondary: gold,
          surface: warmWhite,
          onSurface: charcoal,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: emerald,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD9E3DC)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: green, width: 1.6),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: emerald,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      home: const _XamePayHome(),
    );
  }
}

class _XamePayHome extends ConsumerStatefulWidget {
  const _XamePayHome();

  @override
  ConsumerState<_XamePayHome> createState() => _XamePayHomeState();
}

class _XamePayHomeState extends ConsumerState<_XamePayHome> {
  bool _restoring = true;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    XameUser? user;

    try {
      user = await ref.read(authServiceProvider).init();
    } catch (_) {
      user = null;
    }

    if (!mounted) return;

    ref.read(currentUserProvider.notifier).state = user;

    if (user != null) {
      await ref.read(socketServiceProvider).connect(user.xameId);
    }

    if (mounted) {
      setState(() => _restoring = false);
    }
  }

  Future<void> _onAuthenticated(XameUser user) async {
    if (!mounted) return;

    ref.read(currentUserProvider.notifier).state = user;
    await ref.read(socketServiceProvider).connect(user.xameId);
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);

    final user = ref.read(currentUserProvider);
    try {
      await ref.read(socketServiceProvider).disconnect();

      if (user != null) {
        await ref.read(authServiceProvider).logout(user.xameId);
      } else {
        await ref.read(authServiceProvider).forceLogout();
      }
    } finally {
      if (mounted) {
        ref.read(currentUserProvider.notifier).state = null;
        setState(() => _loggingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    if (_restoring || _loggingOut) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: XamePayApp.emerald,
          ),
        ),
      );
    }

    if (user == null) {
      return LoginScreen(onAuthenticated: _onAuthenticated);
    }

    return XamePayScreen(
      userId: user.xameId,
      serverUrl: AppConstants.serverUrl,
      onBack: _logout,
    );
  }
}
