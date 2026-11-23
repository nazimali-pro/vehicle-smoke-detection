import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService _api = ApiService();
  late TextEditingController _urlController;
  bool _isTesting = false;
  String? _testResult;
  bool? _isSuccess;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: _api.baseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _saveUrl() {
    _api.baseUrl = _urlController.text;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Server URL updated to: ${_api.baseUrl}'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
      _isSuccess = null;
    });

    _api.baseUrl = _urlController.text;
    final success = await _api.checkHealth();

    if (mounted) {
      setState(() {
        _isTesting = false;
        _isSuccess = success;
        _testResult = success
            ? 'Success! Connected to ${_api.baseUrl}'
            : 'Connection failed. Ensure backend server is running.';
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
        title: const Text(
          'Backend Settings & Docs',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Server URL config card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Server Host Address',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Set the FastAPI backend URL (use local IP for testing across Wi-Fi or mobile):',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      hintText: 'http://127.0.0.1:8000',
                      hintStyle: const TextStyle(color: Colors.white30),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.dns_rounded,
                          color: Color(0xFF38BDF8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Presets
                  Row(
                    children: [
                      ActionChip(
                        label: const Text('localhost:8000'),
                        backgroundColor: const Color(0xFF0F172A),
                        labelStyle: const TextStyle(
                            color: Color(0xFF38BDF8), fontSize: 11),
                        onPressed: () {
                          _urlController.text = 'http://127.0.0.1:8000';
                          _saveUrl();
                        },
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        label: const Text('LAN IP'),
                        backgroundColor: const Color(0xFF0F172A),
                        labelStyle: const TextStyle(
                            color: Color(0xFFA855F7), fontSize: 11),
                        onPressed: () {
                          _urlController.text = 'http://192.168.100.108:8000';
                          _saveUrl();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saveUrl,
                          icon: const Icon(Icons.save_rounded, size: 18),
                          label: const Text('Save URL'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isTesting ? null : _testConnection,
                          icon: _isTesting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.bolt_rounded, size: 18),
                          label: const Text('Test Connection'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF38BDF8),
                            foregroundColor: const Color(0xFF0F172A),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_testResult != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isSuccess == true
                            ? const Color(0xFF10B981).withOpacity(0.15)
                            : const Color(0xFFEF4444).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isSuccess == true
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                        ),
                      ),
                      child: Text(
                        _testResult!,
                        style: TextStyle(
                          color: _isSuccess == true
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Endpoints Table
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active API Endpoints',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 12),
                  _EndpointRow(
                    method: 'POST',
                    methodColor: Color(0xFF38BDF8),
                    path: '/predict-image',
                    desc: 'Upload vehicle image; returns smoke & plate boxes + OCR',
                  ),
                  Divider(color: Colors.white12, height: 16),
                  _EndpointRow(
                    method: 'POST',
                    methodColor: Color(0xFFA855F7),
                    path: '/predict-video',
                    desc: 'Upload mp4 video; returns per-frame detections & timestamps',
                  ),
                  Divider(color: Colors.white12, height: 16),
                  _EndpointRow(
                    method: 'WS',
                    methodColor: Color(0xFF10B981),
                    path: '/ws-video-stream',
                    desc: 'Bidirectional streaming for live camera detection feed',
                  ),
                  Divider(color: Colors.white12, height: 16),
                  _EndpointRow(
                    method: 'GET',
                    methodColor: Colors.amber,
                    path: '/docs',
                    desc: 'Interactive OpenAPI / Swagger UI test console',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EndpointRow extends StatelessWidget {
  final String method;
  final Color methodColor;
  final String path;
  final String desc;

  const _EndpointRow({
    required this.method,
    required this.methodColor,
    required this.path,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: methodColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                method,
                style: TextStyle(
                  color: methodColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              path,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          desc,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
      ],
    );
  }
}
