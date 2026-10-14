import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService();
  service.initialize();
  return service;
});

class PushService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');

      await _notifications.initialize(
        const InitializationSettings(android: android),
      );

      _initialized = true;
    } catch (error) {
      debugPrint('XamePay notification initialization failed: $error');
    }
  }

  Future<void> showAlertNotification(String title, String body) async {
    await initialize();

    if (!_initialized) return;

    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'xamepay_wallet_alerts',
          'XamePay Wallet Alerts',
          channelDescription: 'Wallet debit and credit notifications',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
      );

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
      );
    } catch (error) {
      debugPrint('XamePay notification failed: $error');
    }
  }
}
