import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../models/detection_result.dart';
import '../services/api_service.dart';
import '../widgets/bounding_box_painter.dart';
import '../widgets/detection_card.dart';

class ImageDetectScreen extends StatefulWidget {
  const ImageDetectScreen({super.key});

  @override
  State<ImageDetectScreen> createState() => _ImageDetectScreenState();
}

class _ImageDetectScreenState extends State<ImageDetectScreen> {
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _selectedImageBytes;
  String _imageFileName = '';
  Size _imageNaturalSize = Size.zero;
  bool _isLoading = false;
  String? _errorMessage;
  ImageDetectionResponse? _result;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        await _loadImageBytes(bytes, picked.name);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to select image: $e';
      });
    }
  }

  Future<void> _loadImageBytes(Uint8List bytes, String filename) async {
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo fi = await codec.getNextFrame();

    setState(() {
      _selectedImageBytes = bytes;
      _imageFileName = filename;
      _imageNaturalSize =
          Size(fi.image.width.toDouble(), fi.image.height.toDouble());
      _result = null;
      _errorMessage = null;
    });
  }

  Future<void> _loadSampleImage() async {
    try {
      final res = await http.get(Uri.parse('${_api.baseUrl}/sample-image'));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        await _loadImageBytes(res.bodyBytes, 'sample_vehicle.jpg');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loaded sample vehicle image from server'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        return;
      }
      setState(() {
        _errorMessage = 'Server did not return a sample image (code: ${res.statusCode}).';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not load sample image: $e';
      });
    }
  }

  Future<void> _runDetection() async {
    if (_selectedImageBytes == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final response =
          await _api.predictImage(_selectedImageBytes!, _imageFileName);
      setState(() {
        _result = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Detection failed: $e';
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
          'Image Smoke & Plate Detection',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_special_rounded, color: Color(0xFF38BDF8)),
            tooltip: 'Load Project Sample Vehicle',
            onPressed: _loadSampleImage,
          ),
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_rounded,
                color: Colors.white),
            tooltip: 'Pick from Gallery / Files',
            onPressed: () => _pickImage(ImageSource.gallery),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Action Bar: Pick buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded, size: 20),
                    label: const Text('Pick Image'),
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
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loadSampleImage,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                    label: const Text('Sample Vehicle'),
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
              ],
            ),

            const SizedBox(height: 16),

            // Image Preview Card with Bounding Box Overlay
            _buildImageDisplayArea(),

            if (_selectedImageBytes != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _runDetection,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search_rounded),
                label: Text(
                  _isLoading ? 'Analyzing Models...' : 'Run Smoke & Plate AI',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: const Color(0xFF0F172A),
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
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Colors.redAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Results Section
            if (_result != null) ...[
              const SizedBox(height: 20),
              _buildResultsSummary(),
              const SizedBox(height: 14),
              const Text(
                'Detection Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              if (_result!.predictions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'No smoke or license plates detected in this image.',
                      style: TextStyle(color: Colors.white60, fontSize: 14),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _result!.predictions.length,
                  itemBuilder: (context, index) {
                    return DetectionCard(
                      detection: _result!.predictions[index],
                      index: index,
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageDisplayArea() {
    if (_selectedImageBytes == null) {
      return Container(
        height: 260,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car_filled_rounded,
                size: 56, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 12),
            const Text(
              'No vehicle image selected',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pick a photo or load a project sample above',
              style: TextStyle(color: Colors.white30, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image Header Info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: Colors.black26,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _imageFileName,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${_imageNaturalSize.width.toInt()}x${_imageNaturalSize.height.toInt()} px',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          // Interactive Image with bounding boxes
          AspectRatio(
            aspectRatio: _imageNaturalSize.width > 0 &&
                    _imageNaturalSize.height > 0
                ? (_imageNaturalSize.width / _imageNaturalSize.height)
                : (16 / 9),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(
                      _selectedImageBytes!,
                      fit: BoxFit.contain,
                    ),
                    if (_result != null && _result!.predictions.isNotEmpty)
                      CustomPaint(
                        painter: BoundingBoxPainter(
                          detections: _result!.predictions,
                          imageSize: _imageNaturalSize,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSummary() {
    final bool hasSmoke = _result!.hasSmoke;
    final bool hasPlate = _result!.hasPlate;

    return Column(
      children: [
        // Alert banner if smoke is detected
        if (hasSmoke)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFFEF4444).withOpacity(0.6), width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EXCESSIVE SMOKE DETECTED!',
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${_result!.smokeDetections.length} smoke emission plume(s) identified.',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.5), width: 1.5),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: Color(0xFF10B981), size: 26),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No Vehicle Smoke Emission Detected (Clean Vehicle)',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // License Plate Read Card
        if (hasPlate) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF00E676).withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.confirmation_number_rounded,
                    color: Color(0xFF00E676), size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'License Plate Recognition (EasyOCR):',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _result!.plateDetectionsList
                            .map((p) => p.plateText ?? 'Unknown')
                            .join(', '),
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
