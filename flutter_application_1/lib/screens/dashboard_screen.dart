import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const DashboardScreen({super.key, required this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _api = ApiService();
  bool _isChecking = false;
  bool? _isOnline;
  String _statusMsg = 'Not tested yet';

  @override
  void initState() {
    super.initState();
    _checkServer();
  }

  Future<void> _checkServer() async {
    setState(() {
      _isChecking = true;
      _statusMsg = 'Testing connection...';
    });

    final online = await _api.checkHealth();
    if (mounted) {
      setState(() {
        _isOnline = online;
        _isChecking = false;
        _statusMsg = online
            ? 'Connected: ${_api.baseUrl}'
            : 'Offline / Unreachable: ${_api.baseUrl}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.car_crash_rounded,
                  color: Color(0xFF38BDF8), size: 24),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vehicle Smoke & Plate AI',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'FYP Real-Time Detection Test Suite',
                  style: TextStyle(fontSize: 11, color: Colors.white60),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Re-check Server',
            onPressed: _isChecking ? null : _checkServer,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Server Connection Status Card
            _buildConnectionBanner(),

            const SizedBox(height: 24),
            const Text(
              'Testing Modules',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),

            // Navigation Cards Grid
            _buildActionCard(
              title: 'Image Detection & OCR',
              subtitle:
                  'Upload or select vehicle photos to detect exhaust smoke and read license plate text with EasyOCR.',
              icon: Icons.image_search_rounded,
              accentColor: const Color(0xFF38BDF8),
              badge: 'FastAPI /predict-image',
              onTap: () => widget.onNavigate(1),
            ),

            const SizedBox(height: 14),
            _buildActionCard(
              title: 'Video Stream Processing',
              subtitle:
                  'Upload .mp4 vehicle videos to analyze frame-by-frame emission rates and timestamped plate detections.',
              icon: Icons.video_collection_rounded,
              accentColor: const Color(0xFFA855F7),
              badge: 'FastAPI /predict-video',
              onTap: () => widget.onNavigate(2),
            ),

            const SizedBox(height: 14),
            _buildActionCard(
              title: 'Real-Time WebSocket Stream',
              subtitle:
                  'Live binary frame streaming with sub-second bounding box response and audio/visual smoke alerts.',
              icon: Icons.stream_rounded,
              accentColor: const Color(0xFF10B981),
              badge: 'WebSocket /ws-video-stream',
              onTap: () => widget.onNavigate(3),
            ),

            const SizedBox(height: 24),
            const Text(
              'System Specifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            _buildSystemSpecs(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionBanner() {
    final bool online = _isOnline == true;
    final Color statusColor = _isChecking
        ? Colors.amber
        : (online ? const Color(0xFF10B981) : const Color(0xFFEF4444));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isChecking
                  ? Icons.hourglass_top_rounded
                  : (online ? Icons.wifi_rounded : Icons.wifi_off_rounded),
              color: statusColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _isChecking
                          ? 'Checking Status...'
                          : (online ? 'Backend Online' : 'Backend Offline'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _statusMsg,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: _isChecking ? null : _checkServer,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: statusColor.withOpacity(0.6)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Test Ping',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required String badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white60,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white30, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemSpecs() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: const Column(
        children: [
          _SpecRow(
            label: 'Smoke Detection Model',
            val: 'YOLOv11n (smoke.pt)',
            icon: Icons.cloud_outlined,
          ),
          Divider(color: Colors.white12, height: 18),
          _SpecRow(
            label: 'License Plate Model',
            val: 'YOLOv8 (number_plate.pt)',
            icon: Icons.confirmation_number_outlined,
          ),
          Divider(color: Colors.white12, height: 18),
          _SpecRow(
            label: 'OCR Engine',
            val: 'EasyOCR English Engine',
            icon: Icons.document_scanner_outlined,
          ),
          Divider(color: Colors.white12, height: 18),
          _SpecRow(
            label: 'Backend Framework',
            val: 'FastAPI + Uvicorn Async Server',
            icon: Icons.flash_on_outlined,
          ),
        ],
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  final String label;
  final String val;
  final IconData icon;

  const _SpecRow({
    required this.label,
    required this.val,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF38BDF8)),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.white70),
        ),
        const Spacer(),
        Text(
          val,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
