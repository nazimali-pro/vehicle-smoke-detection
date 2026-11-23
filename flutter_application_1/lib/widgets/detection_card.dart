import 'package:flutter/material.dart';
import '../models/detection_result.dart';

class DetectionCard extends StatelessWidget {
  final DetectionItem detection;
  final int index;

  const DetectionCard({
    super.key,
    required this.detection,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPlate = detection.isPlate;
    final Color mainColor = isPlate
        ? const Color(0xFF00E676)
        : const Color(0xFFFF5252);
    final IconData icon = isPlate ? Icons.pin : Icons.warning_amber_rounded;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2638),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: mainColor.withOpacity(0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: mainColor.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: mainColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: mainColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isPlate ? 'License Plate' : 'Smoke Emission',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: mainColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: mainColor.withOpacity(0.5)),
                      ),
                      child: Text(
                        '${(detection.confidence * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: mainColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (isPlate) ...[
                  Row(
                    children: [
                      const Text(
                        'Plate Text: ',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      Text(
                        (detection.plateText != null &&
                                detection.plateText!.trim().isNotEmpty)
                            ? detection.plateText!
                            : 'N/A',
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    'Class: ${detection.className}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Box: [${detection.bbox.map((b) => b.toStringAsFixed(0)).join(', ')}]',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 11,
                    fontFamily: 'monospace',
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
