import 'package:flutter/material.dart';
import '../models/detection_result.dart';

class BoundingBoxPainter extends CustomPainter {
  final List<DetectionItem> detections;
  final Size imageSize;

  BoundingBoxPainter({
    required this.detections,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.width == 0 || imageSize.height == 0) return;

    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;

    for (var detection in detections) {
      if (detection.bbox.length < 4) continue;

      final double x1 = detection.bbox[0] * scaleX;
      final double y1 = detection.bbox[1] * scaleY;
      final double x2 = detection.bbox[2] * scaleX;
      final double y2 = detection.bbox[3] * scaleY;

      final Rect rect = Rect.fromLTRB(x1, y1, x2, y2);
      final bool isPlate = detection.isPlate;

      // Color scheme: Smoke is Red/Amber, Plate is Emerald/Cyan
      final Color boxColor = isPlate
          ? const Color(0xFF00E676) // Bright Green
          : const Color(0xFFFF5252); // Bright Red / Smoke Alert

      // Draw semi-transparent box fill
      final Paint fillPaint = Paint()
        ..color = boxColor.withOpacity(0.18)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        fillPaint,
      );

      // Draw box border
      final Paint borderPaint = Paint()
        ..color = boxColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        borderPaint,
      );

      // Label text
      String label;
      if (isPlate) {
        String plateStr = (detection.plateText != null &&
                detection.plateText!.trim().isNotEmpty &&
                detection.plateText != 'No text detected')
            ? 'Plate: ${detection.plateText}'
            : 'Number Plate';
        label = '$plateStr ${(detection.confidence * 100).toStringAsFixed(0)}%';
      } else {
        label = 'Smoke ${(detection.confidence * 100).toStringAsFixed(0)}%';
      }

      // Draw label background pill and text
      final textSpan = TextSpan(
        text: ' $label ',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Position label above box or inside if too close to top
      double labelY = y1 - textPainter.height - 4;
      if (labelY < 0) {
        labelY = y1 + 4;
      }
      final double labelX = x1.clamp(0.0, size.width - textPainter.width - 4);

      final Rect bgRect = Rect.fromLTWH(
        labelX,
        labelY,
        textPainter.width + 6,
        textPainter.height + 4,
      );

      final Paint bgPaint = Paint()
        ..color = boxColor.withOpacity(0.9)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
        bgPaint,
      );

      textPainter.paint(canvas, Offset(labelX + 3, labelY + 2));
    }
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) {
    return oldDelegate.detections != detections ||
        oldDelegate.imageSize != imageSize;
  }
}
