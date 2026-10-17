import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../config/constants.dart';

final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();
  ref.onDispose(service.dispose);
  return service;
});

enum SocketState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

class WalletReceiveData {
  final String? senderId;
  final String? senderName;
  final double amount;
  final String currency;

  const WalletReceiveData({
    this.senderId,
    this.senderName,
    required this.amount,
    required this.currency,
  });
}

class SocketService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  final StreamController<Map<String, dynamic>> _walletDebitController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<WalletReceiveData> _walletReceiveController =
      StreamController<WalletReceiveData>.broadcast();

  final StreamController<SocketState> _connectionController =
      StreamController<SocketState>.broadcast();

  IO.Socket? _socket;
  String? currentUserId;
  bool _disposed = false;

  Stream<Map<String, dynamic>> get walletDebit =>
      _walletDebitController.stream;

  Stream<WalletReceiveData> get walletReceive =>
      _walletReceiveController.stream;

  Stream<SocketState> get connectionState =>
      _connectionController.stream;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect(String xameId, {bool stealth = false}) async {
    if (_disposed || xameId.trim().isEmpty) return;

    if (_socket?.connected == true && currentUserId == xameId) return;

    await disconnect();

    currentUserId = xameId;

    final token = await _storage.read(
      key: AppConstants.keySessionToken,
    );

    if (_disposed) return;

    if (token == null || token.trim().isEmpty) {
      _connectionController.add(SocketState.failed);
      return;
    }

    _connectionController.add(SocketState.connecting);

    try {
      final socket = IO.io(
        AppConstants.serverUrl,
        IO.OptionBuilder()
            .setPath('/socket.io/')
            .setTransports(['websocket'])
            .setQuery({'userId': xameId, 'app': 'xamepay'})
            .setAuth({'token': token.trim()})
            .enableReconnection()
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .setReconnectionAttempts(999999)
            .setTimeout(30000)
            .enableForceNew()
            .build(),
      );

      _socket = socket;

      socket.onConnect((_) {
        if (!_disposed) {
          _connectionController.add(SocketState.connected);
        }
      });

      socket.onConnectError((error) {
        debugPrint('XamePay socket connection error: $error');
        if (!_disposed) {
          _connectionController.add(SocketState.failed);
        }
      });

      socket.onDisconnect((_) {
        if (!_disposed) {
          _connectionController.add(SocketState.disconnected);
        }
      });

      socket.on('wallet:debit', (dynamic data) {
        if (_disposed || data is! Map) return;

        _walletDebitController.add(
          Map<String, dynamic>.from(data),
        );
      });

      socket.on('wallet:receive', (dynamic data) {
        if (_disposed || data is! Map) return;

        final amount = data['amount'];
        _walletReceiveController.add(
          WalletReceiveData(
            senderId: data['senderId']?.toString(),
            senderName: data['senderName']?.toString(),
            amount: amount is num
                ? amount.toDouble()
                : double.tryParse(amount?.toString() ?? '') ?? 0,
            currency: data['currency']?.toString() ?? 'NGN',
          ),
        );
      });
    } catch (error, stack) {
      debugPrint('XamePay socket setup failed: $error\n$stack');
      if (!_disposed) {
        _connectionController.add(SocketState.failed);
      }
    }
  }

  Future<void> disconnect() async {
    final socket = _socket;
    _socket = null;

    if (socket != null) {
      socket.clearListeners();
      socket.disconnect();
      socket.dispose();
    }

    if (!_disposed) {
      _connectionController.add(SocketState.disconnected);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;

    final socket = _socket;
    _socket = null;

    socket?.clearListeners();
    socket?.disconnect();
    socket?.dispose();

    _walletDebitController.close();
    _walletReceiveController.close();
    _connectionController.close();
  }
}
