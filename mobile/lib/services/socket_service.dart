import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../core/config/app_config.dart';
import '../models/traffic_update.dart';

/// Manages the persistent Socket.io connection to the backend.
///
/// Exposes a broadcast [Stream<TrafficUpdate>] so any widget or service
/// can subscribe without holding a direct reference to this class.
/// [onReconnected] fires whenever the socket reconnects after a drop —
/// callers should use this to trigger an immediate traffic check.
class SocketService {
  io.Socket? _socket;
  final _updateController     = StreamController<TrafficUpdate>.broadcast();
  final _reconnectedController = StreamController<void>.broadcast();

  // Tracks whether we have connected at least once so we can distinguish
  // a reconnect from the very first connect.
  bool _hasConnectedBefore = false;

  Stream<TrafficUpdate> get updates      => _updateController.stream;
  /// Emits whenever the socket reconnects after a disconnect.
  Stream<void>          get onReconnected => _reconnectedController.stream;
  bool get isConnected => _socket?.connected ?? false;

  void connect() {
    if (_socket != null) return;

    final socketUrl = AppConfig.backendSocketUrl;
    debugPrint('[SocketService] Connecting to $socketUrl');

    _socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(20)
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(30000)
          .build(),
    );

    _socket!.on('connect', (_) {
      if (_hasConnectedBefore) {
        debugPrint('[SocketService] Reconnected');
        _reconnectedController.add(null);
      } else {
        debugPrint('[SocketService] Connected');
        _hasConnectedBefore = true;
      }
    });

    _socket!.on('traffic_update', (rawData) {
      try {
        // socket_io_client may wrap the payload in a List
        final data = rawData is List ? rawData[0] : rawData;
        final update =
            TrafficUpdate.fromJson(Map<String, dynamic>.from(data as Map));
        _updateController.add(update);
      } catch (e) {
        debugPrint('[SocketService] Failed to parse traffic_update: $e');
      }
    });

    _socket!.on('connect_error', (err) {
      debugPrint('[SocketService] Connection error: $err');
    });

    _socket!.on('disconnect', (reason) {
      debugPrint('[SocketService] Disconnected — reason: $reason');
    });

    _socket!.connect();
  }

  /// Reconnects the socket if it is currently disconnected.
  /// Safe to call at any time; no-ops if already connected.
  void reconnectIfNeeded() {
    if (_socket == null) return;
    if (!isConnected) {
      debugPrint('[SocketService] Reconnect triggered');
      _socket!.connect();
    }
  }

  void checkTraffic(String userId) {
    if (!isConnected) {
      debugPrint('[SocketService] checkTraffic called but socket not connected');
      return;
    }
    _socket!.emit('check_traffic', {'userId': userId});
  }

  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _updateController.close();
    _reconnectedController.close();
  }
}
