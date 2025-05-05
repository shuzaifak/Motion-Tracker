import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import 'recording_screen.dart';
import 'motion_analysis_screen.dart';

class MotionDataScreen extends StatefulWidget {
  const MotionDataScreen({super.key});

  @override
  State<MotionDataScreen> createState() => _MotionDataScreenState();
}

class _MotionDataScreenState extends State<MotionDataScreen> {
  final Box<MotionData> _motionDataBox = Hive.box<MotionData>('motionData');
  String _filterActivityType = 'All';
  String _sortBy = 'Date (Newest)';

  List<String> get _activityTypes {
    final Set<String> types = {'All'};
    for (int i = 0; i < _motionDataBox.length; i++) {
      final MotionData data = _motionDataBox.getAt(i) as MotionData;
      types.add(data.activityType);
    }
    return types.toList()..sort();
  }

  List<MotionData> _getFilteredAndSortedData() {
    List<MotionData> filteredData = [];
    for (int i = 0; i < _motionDataBox.length; i++) {
      final MotionData data = _motionDataBox.getAt(i) as MotionData;
      if (_filterActivityType == 'All' || data.activityType == _filterActivityType) {
        filteredData.add(data);
      }
    }
    switch (_sortBy) {
      case 'Date (Newest)':
        filteredData.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
        break;
      case 'Date (Oldest)':
        filteredData.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
        break;
      case 'Title (A-Z)':
        filteredData.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'Activity Type':
        filteredData.sort((a, b) => a.activityType.compareTo(b.activityType));
        break;
      case 'Rep Count':
        filteredData.sort((a, b) => (b.analysisResults['repCount'] as int? ?? 0)
            .compareTo(a.analysisResults['repCount'] as int? ?? 0));
        break;
      case 'Max ROM':
        filteredData.sort((a, b) => (b.analysisResults['maxROM'] as double? ?? 0)
            .compareTo(a.analysisResults['maxROM'] as double? ?? 0));
        break;
    }
    return filteredData;
  }

  void _deleteRecording(BuildContext context, MotionData data, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recording'),
        content: Text(
            'Are you sure you want to delete "${data.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              await _motionDataBox.deleteAt(index);
              if (!mounted) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Recording deleted')),
              );
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Motion Data'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterOptions(context),
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: _motionDataBox.listenable(),
        builder: (context, box, _) {
          if (box.isEmpty) {
            return _buildEmptyState();
          }
          final filteredData = _getFilteredAndSortedData();
          if (filteredData.isEmpty) {
            return Center(
              child: Text(
                'No recordings match the selected filter: "$_filterActivityType"',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.fitness_center,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Total Recordings',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${box.length}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.category,
                                    color: Theme.of(context).colorScheme.secondary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Current Filter',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _filterActivityType,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredData.length,
                  itemBuilder: (context, index) {
                    final data = filteredData[index];
                    final boxIndex = _motionDataBox.values.toList().indexOf(data);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MotionAnalysisScreen(motionData: data),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data.title,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          data.activityType,
                                          style: TextStyle(color: Colors.grey[700]),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    color: Colors.red[400],
                                    onPressed: () => _deleteRecording(context, data, boxIndex),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDetailRow(
                                    context,
                                    Icons.calendar_today,
                                    'Date',
                                    DateFormat('MMM d, yyyy • h:mm a').format(data.recordedAt),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    context,
                                    Icons.repeat,
                                    'Rep Count',
                                    data.analysisResults['repCount']?.toString() ?? 'N/A',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    context,
                                    Icons.straighten,
                                    'Max ROM',
                                    (data.analysisResults['maxROM'] as double?)?.toStringAsFixed(1) != null
                                        ? '${(data.analysisResults['maxROM'] as double).toStringAsFixed(1)}°'
                                        : 'N/A',
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Tap to view detailed analysis',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MotionTrackerScreen()),
          );
        },
        child: const Icon(Icons.add),
        tooltip: 'Record New Motion',
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value) {
    // Log potential data issues for debugging
    if (value == 'N/A') {
      debugPrint('MotionDataScreen: Missing data for $label in MotionData');
    }
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
        ),
        Text(value),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fitness_center, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No Motion Data Available',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Start by recording your first exercise',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MotionTrackerScreen()),
              );
            },
            icon: const Icon(Icons.fitness_center),
            label: const Text('Record Now'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Filter & Sort',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Activity Type',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _activityTypes.map((type) {
                      return FilterChip(
                        label: Text(type),
                        selected: _filterActivityType == type,
                        onSelected: (selected) {
                          setState(() {
                            _filterActivityType = type;
                          });
                          if (mounted) {
                            this.setState(() {});
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sort By',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      'Date (Newest)',
                      'Date (Oldest)',
                      'Title (A-Z)',
                      'Activity Type',
                      'Rep Count',
                      'Max ROM',
                    ].map((sort) {
                      return ChoiceChip(
                        label: Text(sort),
                        selected: _sortBy == sort,
                        onSelected: (selected) {
                          setState(() {
                            _sortBy = sort;
                          });
                          if (mounted) {
                            this.setState(() {});
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}