
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/user_model.dart';
import '../widgets/pose_visualization.dart';
import '../widgets/motion_metrics_card.dart';
import '../widgets/joint_range_chart.dart';
import '../widgets/movement_timeline.dart';

class MotionAnalysisScreen extends StatefulWidget {
  final MotionData motionData;

  const MotionAnalysisScreen({Key? key, required this.motionData}) : super(key: key);

  @override
  State<MotionAnalysisScreen> createState() => _MotionAnalysisScreenState();
}

class _MotionAnalysisScreenState extends State<MotionAnalysisScreen>
    with SingleTickerProviderStateMixin {
  int _currentFrameIndex = 0;
  late TabController _tabController;
  bool _isProcessing = false;
  String _feedbackText = '';
  Map<String, dynamic>? _analysisResults;
  Map<String, List<double>> _jointTrajectories = {};
  List<Map<String, dynamic>> _insightsList = [];

  double _overallPerformanceScore = 0.0;
  double _stabilityScore = 0.0;
  double _smoothnessScore = 0.0;
  double _rangeOfMotionScore = 0.0;
  double _symmetryScore = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _processMotionData();
    if (widget.motionData.keypoints.isEmpty) {
      debugPrint('Warning: No pose keypoints found in motion data');
    }
  }

  Future<void> _processMotionData() async {
    setState(() {
      _isProcessing = true;
    });
    try {
      if (widget.motionData.keypoints.isEmpty) {
        _analysisResults = {'errorMessage': 'No pose data available'};
        _feedbackText = 'No motion data was captured. Ensure the subject is fully visible and well-lit during recording.';
        _insightsList.add({
          'title': 'Recording Issue',
          'description': 'No motion data detected. Try recording again with better lighting and positioning.',
          'icon': Icons.warning_rounded,
          'color': Colors.red,
        });
        return;
      }

      // Fixed type casting issue by safely converting the map
      _analysisResults = Map<String, dynamic>.from(widget.motionData.analysisResults);
      _processJointTrajectories();
      _calculatePerformanceMetrics();
      _generateInsights();
      _generateFeedback();
    } catch (e) {
      debugPrint('Error processing motion data: $e');
      _analysisResults = {'errorMessage': 'Error processing data'};
      _feedbackText = 'An error occurred while analyzing the motion data.';
      _insightsList.add({
        'title': 'Analysis Error',
        'description': 'An error occurred. Please try recording again.',
        'icon': Icons.error_rounded,
        'color': Colors.red,
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _processJointTrajectories() {
    if (widget.motionData.keypoints.isEmpty) {
      _jointTrajectories = {
        for (var joint in [
          'Left Shoulder', 'Right Shoulder', 'Left Elbow', 'Right Elbow',
          'Left Wrist', 'Right Wrist', 'Left Hip', 'Right Hip',
          'Left Knee', 'Right Knee', 'Left Ankle', 'Right Ankle'
        ])
          joint: []
      };
      return;
    }
    final List<String> trackedJoints = [
      'Left Shoulder', 'Right Shoulder', 'Left Elbow', 'Right Elbow',
      'Left Wrist', 'Right Wrist', 'Left Hip', 'Right Hip',
      'Left Knee', 'Right Knee', 'Left Ankle', 'Right Ankle'
    ];
    Map<String, List<double>> trajectories = {};
    for (final joint in trackedJoints) {
      trajectories[joint] = [];
    }
    for (final keypoint in widget.motionData.keypoints) {
      for (final position in keypoint.positions) {
        if (trackedJoints.contains(position.name)) {
          double normX = position.x.clamp(0.0, 1.0);
          double normY = position.y.clamp(0.0, 1.0);
          trajectories[position.name]!.add(normX + normY);
        }
      }
    }
    setState(() => _jointTrajectories = trajectories);
  }

  void _calculatePerformanceMetrics() {
    if (_analysisResults == null || _analysisResults!.containsKey('errorMessage')) {
      _stabilityScore = 0.0;
      _smoothnessScore = 0.0;
      _rangeOfMotionScore = 0.0;
      _symmetryScore = 0.0;
      _overallPerformanceScore = 0.0;
      return;
    }
    double stabilityTotal = 0.0;
    int stabilityCount = 0;
    _jointTrajectories.forEach((joint, trajectory) {
      if (trajectory.isNotEmpty) {
        double mean = trajectory.reduce((a, b) => a + b) / trajectory.length;
        double variance =
            trajectory.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / trajectory.length;
        double jointStability = max(0, 1 - min(1, variance * 10));
        stabilityTotal += jointStability;
        stabilityCount++;
      }
    });
    _stabilityScore = stabilityCount > 0 ? stabilityTotal / stabilityCount : 0.0;
    double smoothnessTotal = 0.0;
    int smoothnessCount = 0;
    _jointTrajectories.forEach((joint, trajectory) {
      if (trajectory.length > 1) {
        double jumpSum = 0.0;
        for (int i = 1; i < trajectory.length; i++) {
          jumpSum += (trajectory[i] - trajectory[i - 1]).abs();
        }
        double avgJump = jumpSum / (trajectory.length - 1);
        double jointSmoothness = max(0, 1 - min(1, avgJump * 5));
        smoothnessTotal += jointSmoothness;
        smoothnessCount++;
      }
    });
    _smoothnessScore = smoothnessCount > 0 ? smoothnessTotal / smoothnessCount : 0.0;
    double rangeTotal = 0.0;
    int rangeCount = 0;

    // Safely handle jointRanges access with type checking
    if (_analysisResults!.containsKey('jointRanges')) {
      var jointRanges = _analysisResults!['jointRanges'];
      if (jointRanges is Map) {
        jointRanges.forEach((joint, range) {
          if (range is Map && range.containsKey('x_range') && range.containsKey('y_range')) {
            double xRange = (range['x_range'] as num).toDouble();
            double yRange = (range['y_range'] as num).toDouble();
            double jointRange = (xRange + yRange) / 2;
            double normalizedRange = min(1.0, jointRange * 2);
            rangeTotal += normalizedRange;
            rangeCount++;
          }
        });
      }
    }

    _rangeOfMotionScore = rangeCount > 0 ? rangeTotal / rangeCount : 0.0;
    double symmetryTotal = 0.0;
    int symmetryCount = 0;
    List<List<String>> symmetryPairs = [
      ['Left Shoulder', 'Right Shoulder'],
      ['Left Elbow', 'Right Elbow'],
      ['Left Wrist', 'Right Wrist'],
      ['Left Hip', 'Right Hip'],
      ['Left Knee', 'Right Knee'],
      ['Left Ankle', 'Right Ankle'],
    ];
    for (final pair in symmetryPairs) {
      final leftJoint = pair[0];
      final rightJoint = pair[1];
      if (_jointTrajectories.containsKey(leftJoint) &&
          _jointTrajectories.containsKey(rightJoint) &&
          _jointTrajectories[leftJoint]!.isNotEmpty &&
          _jointTrajectories[rightJoint]!.isNotEmpty) {
        double leftAvg =
            _jointTrajectories[leftJoint]!.reduce((a, b) => a + b) / _jointTrajectories[leftJoint]!.length;
        double rightAvg =
            _jointTrajectories[rightJoint]!.reduce((a, b) => a + b) / _jointTrajectories[rightJoint]!.length;
        double diff = (leftAvg - rightAvg).abs();
        double similarity = max(0, 1 - min(1, diff * 2));
        symmetryTotal += similarity;
        symmetryCount++;
      }
    }
    _symmetryScore = symmetryCount > 0 ? symmetryTotal / symmetryCount : 0.0;
    _overallPerformanceScore = (_stabilityScore * 0.25 +
        _smoothnessScore * 0.25 +
        _rangeOfMotionScore * 0.25 +
        _symmetryScore * 0.25);
  }

  void _generateInsights() {
    _insightsList = [];
    if (_stabilityScore < 0.4) {
      _insightsList.add({
        'title': 'Stability',
        'description': 'Consider improving stability in your exercises. Try focusing on core engagement.',
        'icon': Icons.warning_rounded,
        'color': Colors.orange,
      });
    } else if (_stabilityScore > 0.7) {
      _insightsList.add({
        'title': 'Good Stability',
        'description': 'You demonstrate good stability in your exercises.',
        'icon': Icons.check_circle_rounded,
        'color': Colors.green,
      });
    }
    if (_smoothnessScore < 0.4) {
      _insightsList.add({
        'title': 'Exercise Flow',
        'description': 'Your movements could be more fluid. Try to focus on smooth transitions.',
        'icon': Icons.warning_rounded,
        'color': Colors.orange,
      });
    } else if (_smoothnessScore > 0.7) {
      _insightsList.add({
        'title': 'Smooth Motion',
        'description': 'Your exercises show good fluidity and control.',
        'icon': Icons.check_circle_rounded,
        'color': Colors.green,
      });
    }
    if (_symmetryScore < 0.4) {
      _insightsList.add({
        'title': 'Asymmetry Detected',
        'description': 'There\'s notable asymmetry between your left and right sides. Consider balancing your training.',
        'icon': Icons.warning_rounded,
        'color': Colors.orange,
      });
    } else if (_symmetryScore > 0.7) {
      _insightsList.add({
        'title': 'Good Symmetry',
        'description': 'Your exercises show good balance between left and right sides.',
        'icon': Icons.check_circle_rounded,
        'color': Colors.green,
      });
    }

    // Safely access repCount and repGoal with null checks and type coercion
    if (_analysisResults != null && _analysisResults!['repCount'] != null) {
      final repCount = (_analysisResults!['repCount'] is int)
          ? _analysisResults!['repCount'] as int
          : (_analysisResults!['repCount'] as num).toInt();

      final repGoal = _analysisResults!.containsKey('repGoal') && _analysisResults!['repGoal'] != null
          ? (_analysisResults!['repGoal'] is int
          ? _analysisResults!['repGoal'] as int
          : (_analysisResults!['repGoal'] as num).toInt())
          : 10;

      if (repCount < repGoal * 0.5) {
        _insightsList.add({
          'title': 'Low Repetition Count',
          'description': 'You completed fewer reps than the goal. Consider increasing endurance.',
          'icon': Icons.warning_rounded,
          'color': Colors.orange,
        });
      } else if (repCount >= repGoal) {
        _insightsList.add({
          'title': 'Goal Achieved',
          'description': 'You met or exceeded your repetition goal!',
          'icon': Icons.check_circle_rounded,
          'color': Colors.green,
        });
      }
    }

    // Safely handle pain level with null checks and type coercion
    if (_analysisResults != null &&
        _analysisResults!.containsKey('painLevel') &&
        _analysisResults!['painLevel'] != null) {
      int painLevel = (_analysisResults!['painLevel'] is int)
          ? _analysisResults!['painLevel'] as int
          : (_analysisResults!['painLevel'] as num).toInt();

      if (painLevel > 5) {
        _insightsList.add({
          'title': 'High Pain Level',
          'description': 'You reported significant pain. Consult a professional if pain persists.',
          'icon': Icons.warning_rounded,
          'color': Colors.red,
        });
      }
    }

    if (_insightsList.isEmpty) {
      _insightsList.add({
        'title': 'Exercise Analysis',
        'description': 'Analysis complete. Review the metrics for detailed feedback.',
        'icon': Icons.analytics,
        'color': Colors.blue,
      });
    }
  }

  void _generateFeedback() {
    String feedback = '';
    if (_overallPerformanceScore > 0.7) {
      feedback += 'Great work! Your exercise shows strong control and execution. ';
    } else if (_overallPerformanceScore > 0.4) {
      feedback += 'Solid effort! Your exercise shows reasonable control with some areas to improve. ';
    } else {
      feedback += 'Thanks for recording your exercise. There are several areas where you could improve. ';
    }
    feedback += 'Your exercise demonstrates ${_rangeOfMotionScore > 0.6 ? 'good range of motion' : 'limited mobility'} with ${_smoothnessScore > 0.6 ? 'smooth transitions' : 'some jerkiness in movement.'}';
    feedback += '\n\nRecommendations: ';
    if (_stabilityScore < 0.5) {
      feedback += 'Focus on core engagement to improve stability. ';
    }
    if (_symmetryScore < 0.5) {
      feedback += 'Work on balancing effort between left and right sides. ';
    }
    if (_smoothnessScore < 0.5) {
      feedback += 'Practice slower, more controlled movements to improve smoothness. ';
    }
    if (_rangeOfMotionScore < 0.5) {
      feedback += 'Consider incorporating flexibility exercises to increase range of motion. ';
    }

    // Safely check pain level
    int painLevel = 0;
    if (_analysisResults != null &&
        _analysisResults!.containsKey('painLevel') &&
        _analysisResults!['painLevel'] != null) {
      painLevel = (_analysisResults!['painLevel'] is int)
          ? _analysisResults!['painLevel'] as int
          : (_analysisResults!['painLevel'] as num).toInt();
    }

    if (painLevel > 5) {
      feedback += 'You reported a high pain level. Consult a professional if pain persists. ';
    }
    _feedbackText = feedback;
  }

  void _shareAnalysis() async {
    try {
      setState(() {
        _isProcessing = true;
      });
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/motion_analysis.txt');
      String content = 'Exercise Analysis for ${widget.motionData.title}\n';
      content += 'Recorded on: ${widget.motionData.recordedAt.toString().substring(0, 16)}\n';
      content += 'Activity Type: ${widget.motionData.activityType}\n\n';
      content += 'Performance Metrics:\n';
      content += '- Overall Score: ${(_overallPerformanceScore * 100).toStringAsFixed(1)}%\n';
      content += '- Stability: ${(_stabilityScore * 100).toStringAsFixed(1)}%\n';
      content += '- Smoothness: ${(_smoothnessScore * 100).toStringAsFixed(1)}%\n';
      content += '- Range of Motion: ${(_rangeOfMotionScore * 100).toStringAsFixed(1)}%\n';
      content += '- Symmetry: ${(_symmetryScore * 100).toStringAsFixed(1)}%\n';

      // Safely access values with null checks and type handling
      final repCount = _analysisResults != null && _analysisResults!.containsKey('repCount') && _analysisResults!['repCount'] != null
          ? (_analysisResults!['repCount'] is int
          ? _analysisResults!['repCount'] as int
          : (_analysisResults!['repCount'] as num).toInt())
          : 0;

      final maxROM = _analysisResults != null && _analysisResults!.containsKey('maxROM') && _analysisResults!['maxROM'] != null
          ? (_analysisResults!['maxROM'] is double
          ? _analysisResults!['maxROM'] as double
          : (_analysisResults!['maxROM'] as num).toDouble())
          : 0.0;

      final painLevel = _analysisResults != null && _analysisResults!.containsKey('painLevel') && _analysisResults!['painLevel'] != null
          ? (_analysisResults!['painLevel'] is int
          ? _analysisResults!['painLevel'] as int
          : (_analysisResults!['painLevel'] as num).toInt())
          : 0;

      content += '- Rep Count: $repCount\n';
      content += '- Max ROM: ${maxROM.toStringAsFixed(1)}°\n';
      content += '- Pain Level: $painLevel\n';
      content += '- Rep Speed: ${_analysisResults?['repSpeed'] ?? 'Normal'}\n\n';
      content += 'Feedback:\n$_feedbackText\n\n';
      content += 'Generated by MotionTracker App';
      await file.writeAsString(content);
      await Share.shareXFiles([XFile(file.path)], text: 'Exercise Analysis Report');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing analysis: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showFrameSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Frame',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: widget.motionData.keypoints.isEmpty
                    ? const Center(child: Text('No frames available'))
                    : MovementTimeline(
                  keypoints: widget.motionData.keypoints,
                  currentFrame: _currentFrameIndex,
                  onFrameSelected: (index) {
                    setState(() {
                      _currentFrameIndex = index;
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.motionData.title),
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: _shareAnalysis),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Poses'),
            Tab(text: 'Analysis'),
            Tab(text: 'Report'),
          ],
        ),
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : widget.motionData.keypoints.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning, size: 48),
            const SizedBox(height: 16),
            const Text(
              'No Pose Data Available',
              style: TextStyle(fontSize: 18),
            ),
            Text(
              'The recording contains no pose analysis data. Ensure the subject is fully visible, well-lit, and facing the camera.',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Record Again'),
            ),
          ],
        ),
      )
          : TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildPosesTab(),
          _buildAnalysisTab(),
          _buildReportTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Performance Score',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildPerformanceScoreIndicator(),
                const SizedBox(height: 24),
                const Text(
                  'Key Insights',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._insightsList.map((insight) => _buildInsightCard(insight)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceScoreIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 120,
                width: 120,
                child: Stack(
                  children: [
                    Center(
                      child: SizedBox(
                        height: 120,
                        width: 120,
                        child: CircularProgressIndicator(
                          value: _overallPerformanceScore,
                          strokeWidth: 12,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(_getScoreColor(_overallPerformanceScore)),
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${(_overallPerformanceScore * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Overall',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildScoreItem('Stability', _stabilityScore),
              _buildScoreItem('Smoothness', _smoothnessScore),
              _buildScoreItem('Range', _rangeOfMotionScore),
              _buildScoreItem('Symmetry', _symmetryScore),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreItem(String label, double score) {
    return Column(
      children: [
        SizedBox(
          height: 50,
          width: 50,
          child: Stack(
            children: [
              Center(
                child: SizedBox(
                  height: 50,
                  width: 50,
                  child: CircularProgressIndicator(
                    value: score,
                    strokeWidth: 5,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(_getScoreColor(score)),
                  ),
                ),
              ),
              Center(
                child: Text(
                  '${(score * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 0.7) {
      return Colors.green;
    } else if (score >= 0.4) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  Widget _buildInsightCard(Map<String, dynamic> insight) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      child: ListTile(
        leading: Icon(insight['icon'] as IconData, color: insight['color'] as Color, size: 32),
        title: Text(insight['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(insight['description'] as String),
      ),
    );
  }

  Widget _buildPosesTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('Frame:'),
              Expanded(
                child: Slider(
                  value: _currentFrameIndex.toDouble(),
                  min: 0,
                  max: max(0, (widget.motionData.keypoints.length - 1).toDouble()),
                  divisions: max(1, widget.motionData.keypoints.length - 1),
                  onChanged: (value) {
                    setState(() {
                      _currentFrameIndex = value.toInt();
                    });
                  },
                ),
              ),
              Text('${_currentFrameIndex + 1}/${widget.motionData.keypoints.length}'),
              IconButton(
                icon: const Icon(Icons.fullscreen),
                onPressed: () => _showFrameSelection(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: widget.motionData.keypoints.isEmpty
              ? const Center(child: Text('No pose data available'))
              : Center(
            child: PoseVisualization(
              keypoint: widget.motionData.keypoints[_currentFrameIndex],
              activityType: widget.motionData.activityType,
            ),
          ),
        ),
        Expanded(
          child: widget.motionData.keypoints.isEmpty
              ? const SizedBox()
              : SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Joint Data',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildJointDataTable(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJointDataTable() {
    final keypoint = widget.motionData.keypoints[_currentFrameIndex];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const AlwaysScrollableScrollPhysics(),
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Joint Name')),
          DataColumn(label: Text('X Position')),
          DataColumn(label: Text('Y Position')),
          DataColumn(label: Text('Confidence')),
        ],
        rows: keypoint.positions.map((position) {
          return DataRow(
            cells: [
              DataCell(Text(position.name)),
              DataCell(Text(position.x.toStringAsFixed(3))),
              DataCell(Text(position.y.toStringAsFixed(3))),
              DataCell(Text(position.confidence.toStringAsFixed(2))),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAnalysisTab() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MotionMetricsCard(
              stabilityScore: _stabilityScore,
              smoothnessScore: _smoothnessScore,
              rangeOfMotionScore: _rangeOfMotionScore,
              symmetryScore: _symmetryScore,
            ),
            const SizedBox(height: 24),
            const Text(
              'Joint Movement Analysis',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildJointRangeCharts(),
            const SizedBox(height: 24),
            const Text(
              'Movement Trajectories',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildTrajectoryCharts(),
            const SizedBox(height: 24),
            _buildExerciseMetrics(),
          ],
        ),
      ),
    );
  }

  Widget _buildJointRangeCharts() {
    if (_analysisResults == null ||
        !_analysisResults!.containsKey('jointRanges') ||
        (_analysisResults!['jointRanges'] is! Map)) {
      return const Center(child: Text('No joint range data available.'));
    }

    // First, safely convert the dynamic map to Map<String, dynamic>
    Map<String, dynamic> safeJointRanges = {};

    // Cast safely by rebuilding the map with proper types
    (_analysisResults!['jointRanges'] as Map).forEach((key, value) {
      if (key is String && value is Map) {
        // Convert inner map values if needed
        Map<String, dynamic> innerMap = {};
        value.forEach((k, v) {
          if (k is String) {
            innerMap[k] = v;
          }
        });
        safeJointRanges[key] = innerMap;
      }
    });

    return Column(
      children: [
        JointRangeChart(
          title: 'Upper Body Range of Motion',
          jointRanges: safeJointRanges,
          filterJoints: [
            'Left Shoulder', 'Right Shoulder', 'Left Elbow', 'Right Elbow',
            'Left Wrist', 'Right Wrist'
          ],
        ),
        const SizedBox(height: 16),
        JointRangeChart(
          title: 'Lower Body Range of Motion',
          jointRanges: safeJointRanges,
          filterJoints: [
            'Left Hip', 'Right Hip', 'Left Knee', 'Right Knee',
            'Left Ankle', 'Right Ankle'
          ],
        ),
      ],
    );
  }

  Widget _buildTrajectoryCharts() {
    if (_jointTrajectories.isEmpty) {
      return const Center(child: Text('No trajectory data available.'));
    }
    final upperBodyJoints = ['Left Shoulder', 'Right Shoulder', 'Left Elbow', 'Right Elbow'];
    final lowerBodyJoints = ['Left Hip', 'Right Hip', 'Left Knee', 'Right Knee'];
    return Column(
      children: [
        SizedBox(
          height: 250,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: true),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: true),
              lineBarsData: [
                for (final joint in upperBodyJoints)
                  if (_jointTrajectories.containsKey(joint) && _jointTrajectories[joint]!.isNotEmpty)
                    LineChartBarData(
                      spots: List.generate(
                        _jointTrajectories[joint]!.length,
                            (index) => FlSpot(index.toDouble(), _jointTrajectories[joint]![index]),
                      ),
                      isCurved: true,
                      gradient: LinearGradient(
                        colors: [if (joint.contains('Left')) Colors.blue else Colors.red],
                      ),
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                    ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Upper Body Trajectory',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600]),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 250,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: true),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: true),
              lineBarsData: [
                for (final joint in lowerBodyJoints)
                  if (_jointTrajectories.containsKey(joint) && _jointTrajectories[joint]!.isNotEmpty)
                    LineChartBarData(
                      spots: List.generate(
                        _jointTrajectories[joint]!.length,
                            (index) => FlSpot(index.toDouble(), _jointTrajectories[joint]![index]),
                      ),
                      isCurved: true,
                      gradient: LinearGradient(
                        colors: [if (joint.contains('Left')) Colors.blue else Colors.red],
                      ),
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                    ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Lower Body Trajectory',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseMetrics() {
    if (_analysisResults == null) {
      return const SizedBox();
    }
    final repCount = _analysisResults!['repCount'] as int? ?? 0;
    final maxROM = _analysisResults!['maxROM'] as double? ?? 0.0;
    final painLevel = _analysisResults!['painLevel'] as int? ?? 0;
    final repSpeed = _analysisResults!['repSpeed'] as String? ?? 'Normal';
    final duration = _analysisResults!['duration'] as int? ?? 0;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Exercise Metrics',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildMetricRow('Repetition Count', repCount.toString()),
            _buildMetricRow('Max Range of Motion', '${maxROM.toStringAsFixed(1)}°'),
            _buildMetricRow('Pain Level', painLevel.toString()),
            _buildMetricRow('Repetition Speed', repSpeed),
            _buildMetricRow('Duration', '${duration ~/ 60}:${(duration % 60).toString().padLeft(2, '0')} min'),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildReportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.motionData.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Activity Type: ${widget.motionData.activityType}',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Recorded on: ${widget.motionData.recordedAt.toString().substring(0, 16)}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Performance Summary',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildMetricRow('Overall Score', '${(_overallPerformanceScore * 100).toStringAsFixed(1)}%'),
                  _buildMetricRow('Stability', '${(_stabilityScore * 100).toStringAsFixed(1)}%'),
                  _buildMetricRow('Smoothness', '${(_smoothnessScore * 100).toStringAsFixed(1)}%'),
                  _buildMetricRow('Range of Motion', '${(_rangeOfMotionScore * 100).toStringAsFixed(1)}%'),
                  _buildMetricRow('Symmetry', '${(_symmetryScore * 100).toStringAsFixed(1)}%'),
                  _buildMetricRow('Rep Count', '${_analysisResults?['repCount'] ?? 0}'),
                  _buildMetricRow('Max ROM', '${_analysisResults?['maxROM']?.toStringAsFixed(1) ?? 0}°'),
                  _buildMetricRow('Pain Level', '${_analysisResults?['painLevel'] ?? 0}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Detailed Feedback',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(_feedbackText, style: const TextStyle(fontSize: 14)),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Key Insights',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._insightsList.map((insight) => _buildInsightCard(insight)),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton.icon(
              onPressed: _shareAnalysis,
              icon: const Icon(Icons.share),
              label: const Text('Share Report'),
            ),
          ),
        ],
      ),
    );
  }
}