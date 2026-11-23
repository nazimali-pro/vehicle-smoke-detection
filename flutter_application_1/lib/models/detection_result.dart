class DetectionItem {
  final int classId;
  final String className;
  final double confidence;
  final List<double> bbox; // [x1, y1, x2, y2]
  final String? savedPath;
  final int? imageId;
  final int? detectionNum;
  final String? plateText;
  final String modelType;
  final double? timestamp;

  DetectionItem({
    required this.classId,
    required this.className,
    required this.confidence,
    required this.bbox,
    this.savedPath,
    this.imageId,
    this.detectionNum,
    this.plateText,
    required this.modelType,
    this.timestamp,
  });

  bool get isSmoke =>
      modelType == 'object_detection' ||
      className.toLowerCase().contains('smoke');

  bool get isPlate =>
      modelType == 'plate_detection' ||
      className.toLowerCase().contains('plate');

  factory DetectionItem.fromJson(Map<String, dynamic> json) {
    List<double> parsedBbox = [];
    if (json['bbox'] != null) {
      parsedBbox = (json['bbox'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
    }

    return DetectionItem(
      classId: json['class_Id'] ?? json['class_id'] ?? 0,
      className: json['class_name'] ?? 'Unknown',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      bbox: parsedBbox,
      savedPath: json['saved_path'],
      imageId: json['image_id'],
      detectionNum: json['detection_num'],
      plateText: json['plate_text'],
      modelType: json['model_type'] ?? 'object_detection',
      timestamp: (json['timestamp'] as num?)?.toDouble(),
    );
  }
}

class ImageDetectionResponse {
  final List<DetectionItem> predictions;
  final int imageId;
  final String imageFolder;
  final int plateDetections;

  ImageDetectionResponse({
    required this.predictions,
    required this.imageId,
    required this.imageFolder,
    required this.plateDetections,
  });

  factory ImageDetectionResponse.fromJson(Map<String, dynamic> json) {
    var rawList = json['predictions'] as List? ?? [];
    List<DetectionItem> preds =
        rawList.map((item) => DetectionItem.fromJson(item)).toList();

    return ImageDetectionResponse(
      predictions: preds,
      imageId: json['image_id'] ?? 0,
      imageFolder: json['image_folder'] ?? '',
      plateDetections: json['plate_detections'] ?? 0,
    );
  }

  bool get hasSmoke => predictions.any((p) => p.isSmoke);
  bool get hasPlate => predictions.any((p) => p.isPlate);
  List<DetectionItem> get smokeDetections =>
      predictions.where((p) => p.isSmoke).toList();
  List<DetectionItem> get plateDetectionsList =>
      predictions.where((p) => p.isPlate).toList();
}

class FramePrediction {
  final int frame;
  final double timestamp;
  final List<DetectionItem> detections;

  FramePrediction({
    required this.frame,
    required this.timestamp,
    required this.detections,
  });

  factory FramePrediction.fromJson(Map<String, dynamic> json) {
    var rawList = json['detections'] as List? ?? [];
    List<DetectionItem> preds =
        rawList.map((item) => DetectionItem.fromJson(item)).toList();
    return FramePrediction(
      frame: json['frame'] ?? 0,
      timestamp: (json['timestamp'] as num?)?.toDouble() ?? 0.0,
      detections: preds,
    );
  }
}

class VideoDetectionResponse {
  final List<FramePrediction> videoPredictions;
  final double fps;
  final int totalFrames;
  final double duration;
  final int videoId;
  final String videoFolder;
  final int plateDetections;

  VideoDetectionResponse({
    required this.videoPredictions,
    required this.fps,
    required this.totalFrames,
    required this.duration,
    required this.videoId,
    required this.videoFolder,
    required this.plateDetections,
  });

  factory VideoDetectionResponse.fromJson(Map<String, dynamic> json) {
    var rawList = json['video_predictions'] as List? ?? [];
    List<FramePrediction> frameList =
        rawList.map((item) => FramePrediction.fromJson(item)).toList();

    return VideoDetectionResponse(
      videoPredictions: frameList,
      fps: (json['fps'] as num?)?.toDouble() ?? 0.0,
      totalFrames: json['total_frames'] ?? 0,
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      videoId: json['video_id'] ?? 0,
      videoFolder: json['video_folder'] ?? '',
      plateDetections: json['plate_detections'] ?? 0,
    );
  }

  int get totalSmokeEvents {
    int count = 0;
    for (var f in videoPredictions) {
      count += f.detections.where((d) => d.isSmoke).length;
    }
    return count;
  }
}

class StreamDetectionResponse {
  final List<DetectionItem> detections;
  final double timestamp;
  final int streamId;
  final int plateDetections;

  StreamDetectionResponse({
    required this.detections,
    required this.timestamp,
    required this.streamId,
    required this.plateDetections,
  });

  factory StreamDetectionResponse.fromJson(Map<String, dynamic> json) {
    var rawList = json['detections'] as List? ?? [];
    List<DetectionItem> preds =
        rawList.map((item) => DetectionItem.fromJson(item)).toList();
    return StreamDetectionResponse(
      detections: preds,
      timestamp: (json['timestamp'] as num?)?.toDouble() ?? 0.0,
      streamId: json['stream_id'] ?? 0,
      plateDetections: json['plate_detections'] ?? 0,
    );
  }
}
