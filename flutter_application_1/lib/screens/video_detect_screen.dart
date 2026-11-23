import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/detection_result.dart';
import '../services/api_service.dart';
import '../widgets/detection_card.dart';

class VideoDetectScreen extends StatefulWidget {
  const VideoDetectScreen({super.key});

  @override
  State<VideoDetectScreen> createState() => _VideoDetectScreenState();
}

class _VideoDetectScreenState extends State<VideoDetectScreen> {
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _videoBytes;
  String _videoFileName = '';
  bool _isLoading = false;
  String? _errorMessage;
  VideoDetectionResponse? _result;

  Future<void> _pickVideo() async {
    try {
      final XFile? picked =
          await _picker.pickVideo(source: ImageSource.gallery);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _videoBytes = bytes;
          _videoFileName = picked.name;
          _result = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to select video: $e';
      });
    }
  }

  Future<void> _runVideoDetection() async {
    if (_videoBytes == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final resp = await _api.predictVideo(_videoBytes!, _videoFileName);
      setState(() {
        _result = resp;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Video analysis failed: $e';
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
          'Video Analysis & Timeline',
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
            // Pick Video Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickVideo,
              icon: const Icon(Icons.video_library_rounded),
              label: Text(_videoBytes == null
                  ? 'Select Vehicle Video (.mp4)'
                  : 'Change Video: $_videoFileName'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: const Color(0xFFA855F7),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                      color: const Color(0xFFA855F7).withOpacity(0.4)),
                ),
              ),
            ),

            if (_videoBytes != null) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _runVideoDetection,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.analytics_rounded),
                label: Text(
                  _isLoading
                      ? 'Processing Video Frames...'
                      : 'Process & Analyze Video',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA855F7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade400),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],

            if (_result != null) ...[
              const SizedBox(height: 20),
              _buildStatsGrid(),
              const SizedBox(height: 20),
              _buildTimelineSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Container(
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
            'Analysis Overview',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildStatPill('Total Frames', '${_result!.totalFrames}',
                  const Color(0xFF38BDF8)),
              const SizedBox(width: 8),
              _buildStatPill('Duration',
                  '${_result!.duration.toStringAsFixed(1)}s', Colors.amber),
              const SizedBox(width: 8),
              _buildStatPill(
                  'FPS', '${_result!.fps.toStringAsFixed(0)}', Colors.teal),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildStatPill(
                'Smoke Incidents',
                '${_result!.totalSmokeEvents}',
                const Color(0xFFEF4444),
              ),
              const SizedBox(width: 8),
              _buildStatPill(
                'Plate Reads',
                '${_result!.plateDetections}',
                const Color(0xFF10B981),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String title, String val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: Colors.white60),
              maxLines: 1,
            ),
            const SizedBox(height: 4),
            Text(
              val,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineSection() {
    final framesWithDetections = _result!.videoPredictions
        .where((f) => f.detections.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Frames with Detections',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              '${framesWithDetections.length} keyframes',
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (framesWithDetections.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text(
                'No events detected across the video.',
                style: TextStyle(color: Colors.white60),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: framesWithDetections.length,
            itemBuilder: (context, idx) {
              final frame = framesWithDetections[idx];
              final hasSmoke = frame.detections.any((d) => d.isSmoke);
              final hasPlate = frame.detections.any((d) => d.isPlate);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasSmoke
                        ? const Color(0xFFEF4444).withOpacity(0.4)
                        : Colors.white10,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Frame #${frame.frame} (@ ${frame.timestamp.toStringAsFixed(2)}s)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        if (hasSmoke)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('SMOKE',
                                style: TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                        if (hasPlate) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('PLATE',
                                style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...frame.detections.map(
                      (d) => DetectionCard(detection: d, index: 0),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
