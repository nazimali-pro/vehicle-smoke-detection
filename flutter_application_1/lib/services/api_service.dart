import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/detection_result.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String _baseUrl = 'http://127.0.0.1:8000';

  String get baseUrl => _baseUrl;
  set baseUrl(String url) {
    _baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
  }

  String get wsUrl {
    String cleanUrl = _baseUrl.replaceFirst(RegExp(r'^http'), 'ws');
    return '$cleanUrl/ws-video-stream';
  }

  /// Check if the backend is reachable
  Future<bool> checkHealth() async {
    try {
      final uri = Uri.parse('$_baseUrl/health');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      try {
        final uri = Uri.parse(_baseUrl);
        final res = await http.get(uri).timeout(const Duration(seconds: 4));
        return res.statusCode < 500;
      } catch (_) {
        return false;
      }
    }
  }

  /// Upload an image to /predict-image
  Future<ImageDetectionResponse> predictImage(
    Uint8List bytes,
    String filename,
  ) async {
    final uri = Uri.parse('$_baseUrl/predict-image');
    var request = http.MultipartRequest('POST', uri);

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename.isEmpty ? 'upload.jpg' : filename,
      ),
    );

    final streamedResponse =
        await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return ImageDetectionResponse.fromJson(decoded);
    } else {
      throw Exception(
        'Server returned ${response.statusCode}: ${response.body}',
      );
    }
  }

  /// Upload a video to /predict-video
  Future<VideoDetectionResponse> predictVideo(
    Uint8List bytes,
    String filename,
  ) async {
    final uri = Uri.parse('$_baseUrl/predict-video');
    var request = http.MultipartRequest('POST', uri);

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename.isEmpty ? 'upload.mp4' : filename,
      ),
    );

    final streamedResponse =
        await request.send().timeout(const Duration(seconds: 180));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return VideoDetectionResponse.fromJson(decoded);
    } else {
      throw Exception(
        'Server returned ${response.statusCode}: ${response.body}',
      );
    }
  }
}
