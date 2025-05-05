import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class JointRangeChart extends StatelessWidget {
  final String title;
  final Map<String, dynamic> jointRanges;
  final List<String> filterJoints;

  const JointRangeChart({
    Key? key,
    required this.title,
    required this.jointRanges,
    required this.filterJoints,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Filter joints based on the provided list
    final Map<String, dynamic> filteredJoints = {};
    jointRanges.forEach((key, value) {
      if (filterJoints.contains(key)) {
        filteredJoints[key] = value;
      }
    });

    // Check if we have data to display
    if (filteredJoints.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'No data available for $title',
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Range of motion for key joints',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 240,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final int index = value.toInt();
                          if (index < 0 ||
                              index >= filteredJoints.keys.length) {
                            return const SizedBox();
                          }
                          final joint = filteredJoints.keys.elementAt(index);

                          // Simplify joint names for better display
                          String displayName = joint;
                          if (joint.contains('Left')) {
                            displayName = 'L ${joint.replaceAll('Left ', '')}';
                          } else if (joint.contains('Right')) {
                            displayName = 'R ${joint.replaceAll('Right ', '')}';
                          }

                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey[300],
                        strokeWidth: 1,
                      );
                    },
                  ),
                  barGroups: _createBarGroups(filteredJoints),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendItem(
                  color: Colors.blue,
                  label: 'X-axis range',
                ),
                SizedBox(width: 16),
                _LegendItem(
                  color: Colors.green,
                  label: 'Y-axis range',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<BarChartGroupData> _createBarGroups(Map<String, dynamic> joints) {
    final List<BarChartGroupData> barGroups = [];

    int index = 0;
    joints.forEach((joint, data) {
      // Extract x and y range values
      double xRange = 0.0;
      double yRange = 0.0;

      if (data is Map) {
        if (data.containsKey('x_range')) {
          xRange = (data['x_range'] as num).toDouble();
        }
        if (data.containsKey('y_range')) {
          yRange = (data['y_range'] as num).toDouble();
        }
      }

      // Scale values for better visualization (assuming range is between 0-1)
      xRange = xRange * 100;
      yRange = yRange * 100;

      // Create bar group
      barGroups.add(
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: xRange,
              color: Colors.blue,
              width: 16,
              borderRadius: BorderRadius.circular(4),
            ),
            BarChartRodData(
              toY: yRange,
              color: Colors.green,
              width: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );

      index++;
    });

    return barGroups;
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
