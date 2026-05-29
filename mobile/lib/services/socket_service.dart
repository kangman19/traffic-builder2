import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/traffic_update.dart';

const String kSocketUrl = 'http://10.0.2.2:3001';

class SocketService {
  io.Socket? _socket;
  final _updateController = StreamController<TrafficUpdate>.broadcast();

  Stream<TrafficUpdate> get updates => _updateController.stream;
  bool get isConnected => _socket?.connected ?? false;

  void connect() {
    if (_socket != null) return;

    _socket = io.io(
      kSocketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.on('connect', (_) {
      // ignore: avoid_print
      print('[Socket] Connected');
    });

    _socket!.on('traffic_update', (data) {
      try {
        final update = TrafficUpdate.fromJson(Map<String, dynamic>.from(data as Map));
        _updateController.add(update);
      } catch (e) {
        // ignore: avoid_print
        print('[Socket] Parse error: $e');
      }
    });

    _socket!.on('disconnect', (_) {
      // ignore: avoid_print
      print('[Socket] Disconnected');
    });

    _socket!.connect();
  }

  void checkTraffic(String userId) {
    _socket?.emit('check_traffic', {'userId': userId});
  }

  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _updateController.close();
  }
}
