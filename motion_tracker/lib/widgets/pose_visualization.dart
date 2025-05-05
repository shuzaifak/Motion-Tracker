import 'package:flutter/material.dart';
import '../models/user_model.dart';

class PoseVisualization extends StatelessWidget {
  final PoseKeypoint keypoint;
  final String activityType;

  const PoseVisualization({
    Key? key,
    required this.keypoint,
    required this.activityType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CustomPaint(
            painter: PosePainter(
              keypoint: keypoint,
              activityType: activityType,
            ),
          ),
        ),
      ),
    );
  }
}

class PosePainter extends CustomPainter {
  final PoseKeypoint keypoint;
  final String activityType;

  PosePainter({
    required this.keypoint,
    required this.activityType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Define skeleton connections
    final List<List<String>> connections = [
      // Face
      ['Nose', 'Left Eye'],
      ['Nose', 'Right Eye'],
      ['Left Eye', 'Left Ear'],
      ['Right Eye', 'Right Ear'],
      // Torso
      ['Left Shoulder', 'Right Shoulder'],
      ['Left Shoulder', 'Left Hip'],
      ['Right Shoulder', 'Right Hip'],
      ['Left Hip', 'Right Hip'],
      // Arms
      ['Left Shoulder', 'Left Elbow'],
      ['Left Elbow', 'Left Wrist'],
      ['Right Shoulder', 'Right Elbow'],
      ['Right Elbow', 'Right Wrist'],
      // Legs
      ['Left Hip', 'Left Knee'],
      ['Left Knee', 'Left Ankle'],
      ['Right Hip', 'Right Knee'],
      ['Right Knee', 'Right Ankle'],
    ];

    // Map keypoint names to their positions
    final Map<String, Offset> pointPositions = {};
    for (final position in keypoint.positions) {
      pointPositions[position.name] = Offset(
        position.x * size.width,
        position.y * size.height,
      );
    }

    // Draw connections
    final Paint linePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (final connection in connections) {
      final String start = connection[0];
      final String end = connection[1];

      if (pointPositions.containsKey(start) &&
          pointPositions.containsKey(end)) {
        // Use different colors for left and right
        if (start.contains('Left') || end.contains('Left')) {
          linePaint.color = Colors.blue;
        } else if (start.contains('Right') || end.contains('Right')) {
          linePaint.color = Colors.red;
        } else {
          linePaint.color = Colors.purple;
        }

        canvas.drawLine(
          pointPositions[start]!,
          pointPositions[end]!,
          linePaint,
        );
      }
    }

    // Draw keypoints
    final Paint pointPaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 1
      ..style = PaintingStyle.fill;

    pointPositions.forEach((name, position) {
      // Different colors for different body parts
      if (name.contains('Shoulder') || name.contains('Hip')) {
        pointPaint.color = Colors.purple;
      } else if (name.contains('Eye') ||
          name.contains('Ear') ||
          name.contains('Nose')) {
        pointPaint.color = Colors.yellow;
      } else if (name.contains('Elbow') || name.contains('Wrist')) {
        pointPaint.color = name.contains('Left') ? Colors.blue : Colors.red;
      } else if (name.contains('Knee') || name.contains('Ankle')) {
        pointPaint.color = name.contains('Left') ? Colors.blue : Colors.red;
      } else {
        pointPaint.color = Colors.green;
      }

      // Draw keypoint
      canvas.drawCircle(position, 6, pointPaint);
    });

    // Draw center of gravity if we have enough points
    if (pointPositions.containsKey('Left Hip') &&
        pointPositions.containsKey('Right Hip') &&
        pointPositions.containsKey('Left Shoulder') &&
        pointPositions.containsKey('Right Shoulder')) {
      final Offset centerOfGravity = Offset(
        (pointPositions['Left Hip']!.dx +
                pointPositions['Right Hip']!.dx +
                pointPositions['Left Shoulder']!.dx +
                pointPositions['Right Shoulder']!.dx) /
            4,
        (pointPositions['Left Hip']!.dy +
                pointPositions['Right Hip']!.dy +
                pointPositions['Left Shoulder']!.dy +
                pointPositions['Right Shoulder']!.dy) /
            4,
      );

      final Paint cogPaint = Paint()
        ..color = Colors.orange
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      // Draw crosshair for center of gravity
      canvas.drawCircle(centerOfGravity, 10, cogPaint);
      canvas.drawLine(
        Offset(centerOfGravity.dx - 15, centerOfGravity.dy),
        Offset(centerOfGravity.dx + 15, centerOfGravity.dy),
        cogPaint,
      );
      canvas.drawLine(
        Offset(centerOfGravity.dx, centerOfGravity.dy - 15),
        Offset(centerOfGravity.dx, centerOfGravity.dy + 15),
        cogPaint,
      );
    }

    // Draw coordinate origin
    final Paint originPaint = Paint()
      ..color = Colors.black45
      ..strokeWidth = 1;

    // Horizontal midline
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      originPaint,
    );

    // Vertical midline
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      originPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
