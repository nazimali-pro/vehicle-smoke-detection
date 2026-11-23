import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/detection_result.dart';

class WebSocketStreamService {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  final StreamController<StreamDetectionResponse> _detectionController =
      StreamController<StreamDetectionResponse>.broadcast();
  final StreamController<bool> _statusController =
      StreamController<bool>.broadcast();

  Stream<StreamDetectionResponse> get detectionsStream =>
      _detectionController.stream;
  Stream<bool> get statusStream => _statusController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect(String wsUrl) async {
    disconnect();
    try {
      final uri = Uri.parse(wsUrl);
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;
      _statusController.add(true);

      _channel!.stream.listen(
        (data) {
          try {
            if (data is String) {
              final json = jsonDecode(data);
              final resp = StreamDetectionResponse.fromJson(json);
              _detectionController.add(resp);
            }
          } catch (e) {
            // ignore decode error on frame
          }
        },
        onError: (err) {
          _isConnected = false;
          _statusController.add(false);
        },
        onDone: () {
          _isConnected = false;
          _statusController.add(false);
        },
      );
    } catch (e) {
      _isConnected = false;
      _statusController.add(false);
      rethrow;
    }
  }

  void sendFrame(Uint8List frameBytes) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(frameBytes);
    }
  }

  void disconnect() {
    _isConnected = false;
    _statusController.add(false);
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _detectionController.close();
    _statusController.close();
  }
}
