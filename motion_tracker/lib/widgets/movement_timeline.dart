import 'package:flutter/material.dart';
import '../models/user_model.dart';

class MovementTimeline extends StatelessWidget {
  final List<PoseKeypoint> keypoints;
  final int currentFrame;
  final Function(int) onFrameSelected;

  const MovementTimeline({
    Key? key,
    required this.keypoints,
    required this.currentFrame,
    required this.onFrameSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Timeline indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Text('Frame 1'),
              Expanded(
                child: Container(
                  height: 2,
                  color: Colors.grey[300],
                ),
              ),
              Text('Frame ${keypoints.length}'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Frame thumbnails
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: keypoints.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => onFrameSelected(index),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 80,
                  decoration: BoxDecoration(
                    border: index == currentFrame
                        ? Border.all(color: Colors.blue, width: 3)
                        : Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            color: Colors.grey[200],
                            child: CustomPaint(
                              painter: TimelinePosePainter(
                                keypoint: keypoints[index],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(
                          'Frame ${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: index == currentFrame
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // Frame selection slider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous),
                onPressed: currentFrame > 0
                    ? () => onFrameSelected(currentFrame - 1)
                    : null,
              ),
              Expanded(
                child: Slider(
                  value: currentFrame.toDouble(),
                  min: 0,
                  max: (keypoints.length - 1).toDouble(),
                  divisions: keypoints.length - 1,
                  label: 'Frame ${currentFrame + 1}',
                  onChanged: (value) => onFrameSelected(value.toInt()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next),
                onPressed: currentFrame < keypoints.length - 1
                    ? () => onFrameSelected(currentFrame + 1)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TimelinePosePainter extends CustomPainter {
  final PoseKeypoint keypoint;

  TimelinePosePainter({
    required this.keypoint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Define skeleton connections (simplified for thumbnails)
    final List<List<String>> connections = [
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
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final connection in connections) {
      final String start = connection[0];
      final String end = connection[1];

      if (pointPositions.containsKey(start) &&
          pointPositions.containsKey(end)) {
        // Use different colors for left and right
        if (start.contains('Left') || end.contains('Left')) {
          linePaint.color = Colors.blue.withOpacity(0.7);
        } else if (start.contains('Right') || end.contains('Right')) {
          linePaint.color = Colors.red.withOpacity(0.7);
        } else {
          linePaint.color = Colors.purple.withOpacity(0.7);
        }

        canvas.drawLine(
          pointPositions[start]!,
          pointPositions[end]!,
          linePaint,
        );
      }
    }

    // Draw keypoints (smaller for thumbnails)
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

      // Draw keypoint (smaller for timeline)
      canvas.drawCircle(position, 3, pointPaint);
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
