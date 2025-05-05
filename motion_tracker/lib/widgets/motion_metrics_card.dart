import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class MotionMetricsCard extends StatelessWidget {
  final double stabilityScore;
  final double smoothnessScore;
  final double rangeOfMotionScore;
  final double symmetryScore;

  const MotionMetricsCard({
    super.key,
    required this.stabilityScore,
    required this.smoothnessScore,
    required this.rangeOfMotionScore,
    required this.symmetryScore,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Motion Quality Metrics',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            AspectRatio(
              aspectRatio: 1.5,
              child: RadarChart(
                RadarChartData(
                  radarShape: RadarShape.polygon,
                  radarBorderData: BorderSide(color: Colors.grey[300]!),
                  gridBorderData:
                      BorderSide(color: Colors.grey[200]!, width: 1),
                  tickCount: 5,
                  dataSets: [
                    RadarDataSet(
                      fillColor: Colors.blue.withOpacity(0.2),
                      borderColor: Colors.blue,
                      entryRadius: 5,
                      dataEntries: [
                        RadarEntry(value: stabilityScore),
                        RadarEntry(value: smoothnessScore),
                        RadarEntry(value: rangeOfMotionScore),
                        RadarEntry(value: symmetryScore),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildMetricRow('Stability', stabilityScore, Icons.balance),
            _buildMetricRow('Smoothness', smoothnessScore, Icons.waves),
            _buildMetricRow('Range', rangeOfMotionScore, Icons.open_with),
            _buildMetricRow('Symmetry', symmetryScore, Icons.compare_arrows),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String title, double score, IconData icon) {
    final color = _getScoreColor(score);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${(score * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: color)),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: score,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.5) return Colors.orange;
    return Colors.red;
  }
}
