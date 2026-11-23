import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../models/detection_result.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../widgets/bounding_box_painter.dart';
import '../widgets/detection_card.dart';

class LiveStreamScreen extends StatefulWidget {
  const LiveStreamScreen({super.key});

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  final ApiService _api = ApiService();
  final WebSocketStreamService _ws = WebSocketStreamService();
  final ImagePicker _picker = ImagePicker();

  bool _isWsConnected = false;
  bool _isStreaming = false;
  Timer? _streamingTimer;

  Uint8List? _feedImageBytes;
  Size _feedNaturalSize = Size.zero;
  StreamDetectionResponse? _latestDetection;

  int _frameCount = 0;
  double _fps = 0.0;
  DateTime? _lastFpsCalcTime;
  int _fpsFrameCounter = 0;

  StreamSubscription? _detectionSub;
  StreamSubscription? _statusSub;

  @override
  void initState() {
    super.initState();
    _statusSub = _ws.statusStream.listen((connected) {
      if (mounted) {
        setState(() {
          _isWsConnected = connected;
          if (!connected) _isStreaming = false;
        });
      }
    });

    _detectionSub = _ws.detectionsStream.listen((resp) {
      if (mounted) {
        setState(() {
          _latestDetection = resp;
          _frameCount++;
          _fpsFrameCounter++;

          final now = DateTime.now();
          if (_lastFpsCalcTime == null) {
            _lastFpsCalcTime = now;
          } else {
            final diff = now.difference(_lastFpsCalcTime!).inMilliseconds;
            if (diff >= 1000) {
              _fps = (_fpsFrameCounter * 1000.0) / diff;
              _fpsFrameCounter = 0;
              _lastFpsCalcTime = now;
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _stopStreaming();
    _ws.dispose();
    _detectionSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  Future<void> _toggleConnection() async {
    if (_isWsConnected) {
      _stopStreaming();
      _ws.disconnect();
    } else {
      try {
        await _ws.connect(_api.wsUrl);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('WebSocket Connection Failed: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Future<void> _pickFeedSource() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final ui.Codec codec = await ui.instantiateImageCodec(bytes);
        final ui.FrameInfo fi = await codec.getNextFrame();

        setState(() {
          _feedImageBytes = bytes;
          _feedNaturalSize =
              Size(fi.image.width.toDouble(), fi.image.height.toDouble());
        });
      }
    } catch (_) {}
  }

  Future<void> _loadSampleForStream() async {
    try {
      final res = await http.get(Uri.parse('${_api.baseUrl}/sample-image'));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        final bytes = res.bodyBytes;
        final ui.Codec codec = await ui.instantiateImageCodec(bytes);
        final ui.FrameInfo fi = await codec.getNextFrame();
        setState(() {
          _feedImageBytes = bytes;
          _feedNaturalSize =
              Size(fi.image.width.toDouble(), fi.image.height.toDouble());
        });
      }
    } catch (_) {}
  }

  void _toggleStreaming() {
    if (_isStreaming) {
      _stopStreaming();
    } else {
      _startStreaming();
    }
  }

  void _startStreaming() {
    if (!_isWsConnected || _feedImageBytes == null) return;

    setState(() {
      _isStreaming = true;
      _frameCount = 0;
      _fps = 0.0;
      _fpsFrameCounter = 0;
      _lastFpsCalcTime = DateTime.now();
    });

    // Stream frames at ~10 FPS (100ms interval)
    _streamingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_feedImageBytes != null && _isWsConnected) {
        _ws.sendFrame(_feedImageBytes!);
      }
    });
  }

  void _stopStreaming() {
    _streamingTimer?.cancel();
    _streamingTimer = null;
    if (mounted) {
      setState(() {
        _isStreaming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasSmoke =
        _latestDetection?.detections.any((d) => d.isSmoke) ?? false;
    final bool hasPlate =
        _latestDetection?.detections.any((d) => d.isPlate) ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text(
          'Live WebSocket Stream Tester',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isWsConnected ? Icons.link_off_rounded : Icons.link_rounded,
              color: _isWsConnected
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
            ),
            tooltip: _isWsConnected ? 'Disconnect WS' : 'Connect WS',
            onPressed: _toggleConnection,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isWsConnected
                      ? const Color(0xFF10B981).withOpacity(0.4)
                      : Colors.white12,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _isWsConnected
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isWsConnected
                          ? 'WebSocket Connected: ${_api.wsUrl}'
                          : 'WebSocket Disconnected',
                      style: TextStyle(
                        color: _isWsConnected ? Colors.white : Colors.white60,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _toggleConnection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isWsConnected
                          ? const Color(0xFFEF4444).withOpacity(0.2)
                          : const Color(0xFF10B981).withOpacity(0.2),
                      foregroundColor: _isWsConnected
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                    ),
                    child: Text(_isWsConnected ? 'Disconnect' : 'Connect'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Live HUD & Video area
            _buildStreamDisplayArea(),

            const SizedBox(height: 14),

            // Controls
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isStreaming ? null : _pickFeedSource,
                    icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                    label: const Text('Pick Feed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: const Color(0xFF38BDF8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                            color: const Color(0xFF38BDF8).withOpacity(0.4)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isStreaming ? null : _loadSampleForStream,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text('Sample Car'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: const Color(0xFFA855F7),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                            color: const Color(0xFFA855F7).withOpacity(0.4)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        (!_isWsConnected || _feedImageBytes == null)
                            ? null
                            : _toggleStreaming,
                    icon: Icon(
                        _isStreaming
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                        size: 20),
                    label: Text(_isStreaming ? 'Stop Feed' : 'Start Feed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isStreaming
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (hasSmoke) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF4444)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFEF4444), size: 26),
                    SizedBox(width: 10),
                    Text(
                      'REAL-TIME ALERT: VEHICLE SMOKE DETECTED!',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (hasPlate) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00E676)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pin, color: Color(0xFF00E676), size: 24),
                    const SizedBox(width: 10),
                    const Text('Detected Plate: ',
                        style: TextStyle(color: Colors.white70)),
                    Text(
                      _latestDetection!.detections
                          .where((d) => d.isPlate)
                          .map((d) => d.plateText ?? 'Scanning...')
                          .join(', '),
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_latestDetection != null &&
                _latestDetection!.detections.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Live Frame Detections',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              ..._latestDetection!.detections.map(
                (d) => DetectionCard(detection: d, index: 0),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStreamDisplayArea() {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_feedImageBytes != null)
            Image.memory(_feedImageBytes!, fit: BoxFit.contain)
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.videocam_outlined,
                      size: 50, color: Colors.white.withOpacity(0.2)),
                  const SizedBox(height: 10),
                  const Text('Select or load a feed frame to begin streaming',
                      style: TextStyle(color: Colors.white54, fontSize: 13)),
                ],
              ),
            ),

          if (_feedImageBytes != null &&
              _latestDetection != null &&
              _latestDetection!.detections.isNotEmpty)
            CustomPaint(
              painter: BoundingBoxPainter(
                detections: _latestDetection!.detections,
                imageSize: _feedNaturalSize,
              ),
            ),

          // HUD Overlay Header
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isStreaming
                              ? const Color(0xFF10B981)
                              : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isStreaming
                            ? 'LIVE: ${_fps.toStringAsFixed(1)} FPS'
                            : 'STANDBY',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Frames Sent: $_frameCount',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
