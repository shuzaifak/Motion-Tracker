import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:math' as Math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import 'package:video_player/video_player.dart';

class MotionTrackerScreen extends StatefulWidget {
  const MotionTrackerScreen({super.key});

  @override
  State<MotionTrackerScreen> createState() => _MotionTrackerScreenState();
}

class _MotionTrackerScreenState extends State<MotionTrackerScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isTrackerStarted = false;
  int _statusFailureCount = 0;
  bool _isCameraOn = false;
  bool _isRecording = false;
  List<String> _exercises = [];
  VideoPlayerController? _videoController;
  String? _selectedExercise;
  int _repGoal = 10;
  int _painLevel = 0;
  Map<String, dynamic> _status = {};
  Timer? _statusTimer;
  Timer? _frameTimer;
  late String _backendUrl = 'http://192.168.50.84:5000';
  bool _isSendingFrames = false;
  List<String> _debugLogs = [];
  List<Map<String, dynamic>> _exerciseData = [];
  List<PoseKeypoint> _keypoints = [];
  late Box<MotionData> _motionDataBox;
  bool _showDebugPanel = true;

  @override
  void initState() {
    super.initState();
    _motionDataBox = Hive.box<MotionData>('motionData');
    _addDebugLog('Initializing MotionTrackerScreen');

    // Initialize in proper sequence
    _initializeApp();
  }

  Future<bool> _isUrlAccessible(String url, {Duration timeout = const Duration(seconds: 3)}) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(timeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      _addDebugLog('URL accessibility check failed for $url: $e');
      return false;
    }
  }

  Future<void> _ensureBackendConnection({bool showUI = true}) async {
    const possiblePorts = [5000, 8000, 8080, 3000];
    const possibleAddresses = [
      "192.168.50.84", // Your current WiFi IP (primary)
      "10.158.78.84",  // Your previous IP
      "172.31.16.1",   // Your virtual Ethernet IP (alternative)
      "localhost",     // For emulator testing only
      "127.0.0.1"      // For emulator testing only
    ];

    if (await _isUrlAccessible('$_backendUrl/health')) {
      _addDebugLog('Current backend URL is accessible: $_backendUrl');
      return;
    }

    _addDebugLog('Current backend URL is not accessible, trying alternatives...');

    if (showUI) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('Connecting...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SpinKitRing(color: Theme.of(context).primaryColor),
              SizedBox(height: 20),
              Text('Trying to connect to the server...'),
            ],
          ),
        ),
      );
    }

    for (final address in possibleAddresses) {
      for (final port in possiblePorts) {
        final testUrl = 'http://$address:$port';
        _addDebugLog('Testing connection to $testUrl');

        if (await _isUrlAccessible('$testUrl/health')) {
          _addDebugLog('Found accessible backend at $testUrl');

          if (showUI) {
            Navigator.of(context).pop(); // Close the dialog
          }

          if (testUrl != _backendUrl) {
            setState(() {
              _backendUrl = testUrl;
            });

            _showSuccess('Connected to server at $testUrl');
            _addDebugLog('Updated backend URL to $testUrl');

            await _startTracker();
            await _fetchExercises();
            return;
          }
          return;
        }
      }
    }

    if (showUI) {
      Navigator.of(context).pop();
      _showError('Could not connect to any server. Please check your network and server status.');
    }

    _addDebugLog('Failed to find any accessible backend server');
  }

  Future<void> _initializeApp() async {
    await _ensureBackendConnection();
    await _startTracker();
    await _fetchExercises();
    _startStatusPolling();
    await _checkPermissions();
    if (_isCameraOn) {
      await _initVideoController();
    }
  }

  void _addDebugLog(String message) {
    final log = '${DateTime.now().toIso8601String()}: $message';
    print(log);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _debugLogs.add(log);
          if (_debugLogs.length > 50) _debugLogs.removeAt(0);
        });
      }
    });
  }

  Future<void> _checkPermissions() async {
    _addDebugLog('Checking camera permissions');
    try {
      var status = await Permission.camera.status;
      _addDebugLog('Camera permission status: $status');
      if (await Permission.camera.request().isGranted) {
        _addDebugLog('Camera permission granted');
        await _initializeCamera();
      } else {
        _showError('Camera permission denied');
        _addDebugLog('Camera permission denied');
      }
    } catch (e) {
      _showError('Permission check failed: $e');
      _addDebugLog('Permission check failed: $e');
    }
  }

  Future<void> _initializeCamera() async {
    _addDebugLog('Initializing camera');

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showError('No cameras available');
        return;
      }

      _cameraController = CameraController(
        cameras[0],
        ResolutionPreset.low,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      _addDebugLog('Camera initialized');
      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      _showError('Camera initialization failed: $e');
      _addDebugLog('Camera error: $e');
    }
  }

  Future<void> _fetchExercises() async {
    _addDebugLog('Fetching exercises from $_backendUrl/get_exercises');
    try {
      final response = await http.get(
        Uri.parse('$_backendUrl/get_exercises'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _exercises = List<String>.from(data['exercises']);
            _selectedExercise = _exercises.isNotEmpty ? _exercises[0] : null;
          });
          _addDebugLog('Exercises fetched: ${_exercises.length}');
        } else {
          _showError(data['message'] ?? 'Failed to fetch exercises');
        }
      } else {
        _showError('Failed to fetch exercises: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Error fetching exercises: $e');
      _addDebugLog('Error fetching exercises: $e');
      await Future.delayed(Duration(seconds: 3));
      if (mounted) {
        _fetchExercises();
      }
    }
  }

  Future<void> _startTracker() async {
    _addDebugLog('Starting tracker via $_backendUrl/start_tracker');

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final request = http.Request('POST', Uri.parse('$_backendUrl/start_tracker'));
        _addDebugLog('Request headers: ${request.headers}');

        final response = await request.send().timeout(const Duration(seconds: 10));
        final responseBody = await response.stream.bytesToString();
        _addDebugLog('Response status: ${response.statusCode}, body: $responseBody');

        if (response.statusCode == 200) {
          final data = json.decode(responseBody);
          if (data['status'] == 'success') {
            setState(() {
              _isTrackerStarted = true;
            });
            _addDebugLog('Tracker started');
            return;
          } else {
            if (data['message']?.contains('already running') ?? false) {
              setState(() {
                _isTrackerStarted = true;
              });
              _addDebugLog('Tracker was already running');
              return;
            }

            _addDebugLog('Start tracker failed: ${data['message']}');
            if (attempt == 3) {
              _showError(data['message']);
            }
          }
        } else {
          _addDebugLog('Start tracker failed: ${response.statusCode}');
          if (attempt == 3) {
            _showError('Failed to start tracker: ${response.statusCode}');
          }
        }
      } catch (e) {
        _addDebugLog('Error starting tracker (attempt $attempt): $e');
        if (attempt == 3) {
          _showError('Error starting tracker: $e');
        }
      }

      if (attempt < 3) {
        _addDebugLog('Retrying start tracker in ${attempt * 2} seconds...');
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
  }

  Future<void> _toggleCamera() async {
    _addDebugLog('Toggling camera via $_backendUrl/toggle_camera');
    try {
      final request = http.Request('POST', Uri.parse('$_backendUrl/toggle_camera'));
      _addDebugLog('Request headers: ${request.headers}');
      final response = await request.send().timeout(const Duration(seconds: 10));
      final responseBody = await response.stream.bytesToString();
      _addDebugLog('Response status: ${response.statusCode}, body: $responseBody');
      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        if (data['status'] == 'success') {
          setState(() {
            _isCameraOn = data['is_camera_on'];
            _isSendingFrames = _isCameraOn;
          });

          if (_isCameraOn) {
            await _initVideoController();

            if (!_isTrackerStarted) {
              await _startTracker();
            }
            _startFrameSending();
          } else {
            _stopFrameSending();
            if (_videoController != null) {
              await _videoController!.dispose();
              _videoController = null;
            }
          }
          _addDebugLog('Camera toggled: ${_isCameraOn ? 'On' : 'Off'}');
        } else {
          _showError(data['message']);
          _addDebugLog('Toggle camera failed: ${data['message']}');
        }
      } else {
        _showError('Failed to toggle camera: ${response.statusCode}');
        _addDebugLog('Toggle camera failed: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Error toggling camera: $e');
      _addDebugLog('Error toggling camera: $e');
    }
  }

  void _startFrameSending() {
    if (_frameTimer != null) {
      _addDebugLog('Frame timer already running');
      return;
    }

    _frameTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (!_isSendingFrames || _cameraController == null || !_cameraController!.value.isInitialized) {
        return;
      }

      try {
        final image = await _cameraController!.takePicture();
        final bytes = await image.readAsBytes();

        var request = http.MultipartRequest('POST', Uri.parse('$_backendUrl/upload_frame'));
        request.files.add(http.MultipartFile.fromBytes('frame', bytes, filename: 'frame.jpg'));

        final response = await request.send().timeout(const Duration(seconds: 10));
        final responseBody = await response.stream.bytesToString();

        if (response.statusCode == 200) {
          final data = json.decode(responseBody);
          if (data['status'] == 'success' && data['landmarks'] != null && _isRecording) {
            _keypoints.add(_parseKeypoints(data['landmarks'], _keypoints.length));
          }
        }
      } catch (e) {
        _addDebugLog('Error sending frame: $e');
      }
    });
  }

  PoseKeypoint _parseKeypoints(dynamic landmarks, int frameIndex) {
    _addDebugLog('Parsing keypoints for frame $frameIndex');
    List<KeypointPosition> positions = [];
    const landmarkNames = [
      'Nose', 'Left Eye Inner', 'Left Eye', 'Left Eye Outer', 'Right Eye Inner',
      'Right Eye', 'Right Eye Outer', 'Left Ear', 'Right Ear', 'Mouth Left',
      'Mouth Right', 'Left Shoulder', 'Right Shoulder', 'Left Elbow', 'Right Elbow',
      'Left Wrist', 'Right Wrist', 'Left Pinky', 'Right Pinky', 'Left Index',
      'Right Index', 'Left Thumb', 'Right Thumb', 'Left Hip', 'Right Hip',
      'Left Knee', 'Right Knee', 'Left Ankle', 'Right Ankle', 'Left Heel',
      'Right Heel', 'Left Foot Index', 'Right Foot Index'
    ];
    for (int i = 0; i < landmarks.length; i++) {
      final landmark = landmarks[i];
      positions.add(KeypointPosition(
        id: i,
        name: landmarkNames[i],
        x: landmark['x'].toDouble(),
        y: landmark['y'].toDouble(),
        confidence: landmark['visibility'].toDouble(),
      ));
    }
    _addDebugLog('Keypoints parsed: ${positions.length}');
    return PoseKeypoint(frameIndex: frameIndex, positions: positions);
  }

  void _stopFrameSending() {
    _addDebugLog('Stopping frame sending');
    _frameTimer?.cancel();
    _frameTimer = null;
    setState(() {
      _isSendingFrames = false;
    });
    _addDebugLog('Frame sending stopped');
  }

  Future<void> _toggleRecording() async {
    _addDebugLog('Toggling recording via $_backendUrl/toggle_recording');
    try {
      final request = http.Request('POST', Uri.parse('$_backendUrl/toggle_recording'));
      _addDebugLog('Request headers: ${request.headers}');
      final response = await request.send().timeout(const Duration(seconds: 10));
      final responseBody = await response.stream.bytesToString();
      _addDebugLog('Response status: ${response.statusCode}, body: $responseBody');
      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        if (data['status'] == 'success') {
          setState(() {
            _isRecording = data['is_recording'];
          });
          if (_isRecording) {
            _exerciseData.clear();
            _keypoints.clear();
            _addDebugLog('Recording started');
          } else {
            await _saveMotionData();
            _addDebugLog('Recording stopped and data saved');
          }
        } else {
          _showError(data['message']);
          _addDebugLog('Toggle recording failed: ${data['message']}');
        }
      } else {
        _showError('Failed to toggle recording: ${response.statusCode}');
        _addDebugLog('Toggle recording failed: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Error toggling recording: $e');
      _addDebugLog('Error toggling recording: $e');
    }
  }

  Future<void> _saveMotionData() async {
    _addDebugLog('Saving motion data');
    try {
      final statusResponse = await http.get(Uri.parse('$_backendUrl/get_status')).timeout(const Duration(seconds: 10));
      _addDebugLog('Get status response: ${statusResponse.statusCode}, body: ${statusResponse.body}');

      if (statusResponse.statusCode == 200) {
        final statusData = json.decode(statusResponse.body);
        if (statusData['status'] == 'success') {
          final status = statusData['data'];

          List<Map<String, dynamic>> exerciseData = [];
          try {
            final exerciseResponse = await http.get(Uri.parse('$_backendUrl/get_exercise_data')).timeout(const Duration(seconds: 10));
            if (exerciseResponse.statusCode == 200) {
              final exerciseJson = json.decode(exerciseResponse.body);
              if (exerciseJson['status'] == 'success') {
                exerciseData = List<Map<String, dynamic>>.from(exerciseJson['data']);
                _addDebugLog('Exercise data fetched: ${exerciseData.length} entries');
              }
            }
          } catch (e) {
            _addDebugLog('Error fetching exercise data: $e');
          }

          final analysisResults = {
            'repCount': status['rep_count'] ?? 0,
            'maxROM': status['max_rom']?.toDouble() ?? 0.0,
            'painLevel': status['pain_level'] ?? 0,
            'repSpeed': status['rep_speed'] ?? 'Normal',
            'duration': exerciseData.isNotEmpty
                ? (exerciseData.last['time'] as num?)?.toInt() ?? 0
                : 0,
            'exerciseData': exerciseData,
            'jointRanges': _calculateJointRanges(),
          };

          final motionData = MotionData(
            id: const Uuid().v4(),
            title: '${_selectedExercise ?? "Exercise"} ${DateTime.now().toIso8601String().substring(0, 10)}',
            recordedAt: DateTime.now(),
            videoPath: '',
            keypoints: _keypoints,
            activityType: _selectedExercise ?? 'Exercise',
            analysisResults: analysisResults,
          );

          await _motionDataBox.add(motionData);
          _showSuccess('Motion data saved successfully');
          _addDebugLog('Motion data saved to Hive');
        }
      }
    } catch (e, stackTrace) {
      _addDebugLog('Error saving motion data: $e\n$stackTrace');
      _showError('Error saving motion data: ${e.toString()}');
    }
  }

  Map<String, dynamic> _calculateJointRanges() {
    _addDebugLog('Calculating joint ranges');
    Map<String, dynamic> jointRanges = {};
    final trackedJoints = [
      'Left Shoulder', 'Right Shoulder', 'Left Elbow', 'Right Elbow',
      'Left Wrist', 'Right Wrist', 'Left Hip', 'Right Hip',
      'Left Knee', 'Right Knee', 'Left Ankle', 'Right Ankle'
    ];
    for (final joint in trackedJoints) {
      double minX = double.infinity, maxX = -double.infinity;
      double minY = double.infinity, maxY = -double.infinity;
      for (final keypoint in _keypoints) {
        final position = keypoint.positions.firstWhere(
              (p) => p.name == joint,
          orElse: () => KeypointPosition(id: 0, name: joint, x: 0, y: 0, confidence: 0),
        );
        if (position.confidence > 0.5) {
          minX = min(minX, position.x);
          maxX = max(maxX, position.x);
          minY = min(minY, position.y);
          maxY = max(maxY, position.y);
        }
      }
      if (minX != double.infinity) {
        jointRanges[joint] = {
          'x_range': maxX - minX,
          'y_range': maxY - minY,
        };
      }
    }
    _addDebugLog('Joint ranges calculated: ${jointRanges.keys.length} joints');
    return jointRanges;
  }

  Future<void> _resetCounter() async {
    _addDebugLog('Resetting counter via $_backendUrl/reset_counter');
    try {
      final request = http.Request('POST', Uri.parse('$_backendUrl/reset_counter'));
      _addDebugLog('Request headers: ${request.headers}');
      final response = await request.send().timeout(const Duration(seconds: 10));
      final responseBody = await response.stream.bytesToString();
      _addDebugLog('Response status: ${response.statusCode}, body: $responseBody');
      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        if (data['status'] == 'success') {
          _addDebugLog('Counter reset');
          _showSuccess('Counter reset successfully');
        } else {
          _showError(data['message']);
          _addDebugLog('Reset counter failed: ${data['message']}');
        }
      } else {
        _showError('Failed to reset counter: ${response.statusCode}');
        _addDebugLog('Reset counter failed: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Error resetting counter: $e');
      _addDebugLog('Error resetting counter: $e');
    }
  }

  Future<void> _changeExercise(String exercise) async {
    _addDebugLog('Changing exercise to $exercise via $_backendUrl/change_exercise');
    try {
      final request = http.Request(
        'POST',
        Uri.parse('$_backendUrl/change_exercise'),
      );
      request.headers['Content-Type'] = 'application/json';
      request.body = json.encode({'exercise': exercise});
      _addDebugLog('Request headers: ${request.headers}, body: ${request.body}');
      final response = await request.send().timeout(const Duration(seconds: 10));
      final responseBody = await response.stream.bytesToString();
      _addDebugLog('Response status: ${response.statusCode}, body: $responseBody');
      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        if (data['status'] == 'success') {
          setState(() {
            _selectedExercise = exercise;
          });
          _addDebugLog('Exercise changed to: $exercise');
          _showSuccess('Exercise changed to: $exercise');
        } else {
          _showError(data['message']);
          _addDebugLog('Change exercise failed: ${data['message']}');
        }
      } else {
        _showError('Failed to change exercise: ${response.statusCode}');
        _addDebugLog('Change exercise failed: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Error changing exercise: $e');
      _addDebugLog('Error changing exercise: $e');
    }
  }

  Future<void> _setPainLevel(int level) async {
    _addDebugLog('Setting pain level to $level via $_backendUrl/set_pain_level');
    try {
      final request = http.Request(
        'POST',
        Uri.parse('$_backendUrl/set_pain_level'),
      );
      request.headers['Content-Type'] = 'application/json';
      request.body = json.encode({'pain_level': level});
      _addDebugLog('Request headers: ${request.headers}, body: ${request.body}');
      final response = await request.send().timeout(const Duration(seconds: 10));
      final responseBody = await response.stream.bytesToString();
      _addDebugLog('Response status: ${response.statusCode}, body: $responseBody');
      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        if (data['status'] == 'success') {
          setState(() {
            _painLevel = level;
          });
          _addDebugLog('Pain level set to: $level');
        } else {
          _showError(data['message']);
          _addDebugLog('Set pain level failed: ${data['message']}');
        }
      } else {
        _showError('Failed to set pain level: ${response.statusCode}');
        _addDebugLog('Set pain level failed: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Error setting pain level: $e');
      _addDebugLog('Error setting pain level: $e');
    }
  }

  Future<void> _setRepGoal(int goal) async {
    _addDebugLog('Setting rep goal to $goal via $_backendUrl/set_rep_goal');
    try {
      final request = http.Request(
        'POST',
        Uri.parse('$_backendUrl/set_rep_goal'),
      );
      request.headers['Content-Type'] = 'application/json';
      request.body = json.encode({'rep_goal': goal});
      _addDebugLog('Request headers: ${request.headers}, body: ${request.body}');
      final response = await request.send().timeout(const Duration(seconds: 10));
      final responseBody = await response.stream.bytesToString();
      _addDebugLog('Response status: ${response.statusCode}, body: $responseBody');
      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        if (data['status'] == 'success') {
          setState(() {
            _repGoal = goal;
          });
          _addDebugLog('Rep goal set to: $goal');
          _showSuccess('Rep goal set to: $goal');
        } else {
          _showError(data['message']);
          _addDebugLog('Set rep goal failed: ${data['message']}');
        }
      } else {
        _showError('Failed to set rep goal: ${response.statusCode}');
        _addDebugLog('Set rep goal failed: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Error setting rep goal: $e');
      _addDebugLog('Error setting rep goal: $e');
    }
  }

  void _startStatusPolling() {
    _statusTimer?.cancel();

    _statusTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final response = await http.get(
          Uri.parse('$_backendUrl/get_status'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'success' && mounted) {
            setState(() {
              _status = data['data'];
            });
            return;
          }
        }

        _statusFailureCount++;

        if (_statusFailureCount >= 3) {
          _addDebugLog('Multiple status update failures, attempting to reconnect');
          _statusTimer?.cancel();
          await _ensureBackendConnection(showUI: false);
          _startStatusPolling();
          _statusFailureCount = 0;
        } else {
          _addDebugLog('Status update failed. Attempt: $_statusFailureCount');
        }
      } catch (e) {
        _statusFailureCount++;
        _addDebugLog('Status poll error: $e');

        if (_statusFailureCount >= 3) {
          _addDebugLog('Multiple status poll errors, attempting to reconnect');
          _statusTimer?.cancel();
          await _ensureBackendConnection(showUI: false);
          _startStatusPolling();
          _statusFailureCount = 0;
        }
      }
    });
  }

  void _showError(String message) {
    _addDebugLog('Showing error: $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    _addDebugLog('Showing success: $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _addDebugLog('Disposing MotionTrackerScreen');
    _cameraController?.dispose();
    _statusTimer?.cancel();
    _stopFrameSending();
    _videoController?.dispose();
    _videoController = null;
    try {
      http.post(Uri.parse('$_backendUrl/stop_tracker'))
          .timeout(Duration(seconds: 3))
          .then((response) {
        _addDebugLog('Stop tracker response: ${response.statusCode}');
      });
    } catch (e) {
      _addDebugLog('Error stopping tracker: $e');
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rehabilitation Motion Tracker'),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showDebugPanel ? Icons.bug_report : Icons.bug_report_outlined),
            onPressed: () {
              setState(() {
                _showDebugPanel = !_showDebugPanel;
                _addDebugLog('Debug panel toggled: $_showDebugPanel');
              });
            },
            tooltip: 'Toggle Debug Panel',
          ),
        ],
      ),
      body: _isCameraInitialized
          ? LayoutBuilder(
        builder: (context, constraints) {
          final isWideScreen = constraints.maxWidth > 800;
          return isWideScreen ? _buildWideLayout() : _buildNarrowLayout();
        },
      )
          : Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Theme.of(context).primaryColor.withOpacity(0.8), Colors.blue.shade900],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpinKitWave(color: Colors.white, size: 50.0),
              SizedBox(height: 20),
              Text(
                'Initializing Camera...',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Card(
            margin: const EdgeInsets.all(8),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: _buildCameraPreviewWithFeed(),
                  ),
                ),
                _buildCameraControls(),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: _buildStatusPanel(),
        ),
      ],
    );
  }

  Widget _buildCameraPreviewWithFeed() {
    if (!_isCameraInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Stack(
      children: [
        _isCameraOn
            ? _buildNetworkVideoFeed()
            : _buildLocalCameraPreview(),
        if (_isRecording) _buildRecordingIndicator(),
      ],
    );
  }

  Widget _buildNetworkVideoFeed() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: _videoController!.value.size.width,
          height: _videoController!.value.size.height,
          child: VideoPlayer(_videoController!),
        ),
      );
    }

    return Container(
      color: Colors.black,
      height: MediaQuery.of(context).size.width * 9 / 16,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off, size: 48, color: Colors.white),
            const SizedBox(height: 16),
            const Text('Connecting to video feed...',
                style: TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            const SpinKitPulse(
              color: Colors.white,
              size: 40.0,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _retryVideoConnection,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry Connection'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _initVideoController() async {
    _addDebugLog('Initializing video controller');
    try {
      if (_videoController != null) {
        await _videoController!.dispose();
      }

      _videoController = VideoPlayerController.network(
        '$_backendUrl/video_feed',
        formatHint: VideoFormat.other,
        httpHeaders: {
          'Accept': 'multipart/x-mixed-replace',
          'Connection': 'keep-alive',
        },
      );

      await _videoController!.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Video init timed out'),
      );

      if (mounted) {
        setState(() {
          _videoController!.play();
          _videoController!.setLooping(true);
        });
      }
    } catch (e) {
      _addDebugLog('Video init failed: $e');
      if (mounted) {
        setState(() {
          _videoController = null;
        });
      }
      _retryVideoConnection();
    }
  }

  void _videoListener() {
    if (_videoController?.value.hasError ?? false) {
      _addDebugLog('Video error: ${_videoController?.value.errorDescription}');
    }

    if (_videoController?.value.isPlaying ?? false) {
      _addDebugLog('Video playback started');
    }
  }

  void _retryVideoConnection() async {
    _addDebugLog('Retrying video connection');

    try {
      final response = await http.get(
        Uri.parse('$_backendUrl/health'),
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _videoController?.dispose();
            _videoController = null;
          });
        }
        await _initVideoController();
      } else {
        _addDebugLog('Backend not ready: ${response.statusCode}');
        _showError('Cannot connect to video server (status: ${response.statusCode})');

        if (mounted) {
          Future.delayed(const Duration(seconds: 5), _retryVideoConnection);
        }
      }
    } catch (e) {
      _addDebugLog('Connection test failed: $e');
      _showError('Network error: ${e.toString().substring(0, Math.min(50, e.toString().length))}...');

      if (mounted) {
        Future.delayed(const Duration(seconds: 5), _retryVideoConnection);
      }
    }
  }

  Widget _buildLocalCameraPreview() {
    return Container(
      color: Colors.black,
      child: _cameraController != null && _cameraController!.value.isInitialized
          ? CameraPreview(_cameraController!)
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildRecordingIndicator() {
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, color: Colors.white, size: 12),
            SizedBox(width: 8),
            Text(
              'RECORDING',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Card(
            margin: const EdgeInsets.all(8),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: _isCameraOn
                        ? Stack(
                      children: [
                        Image.network(
                          '$_backendUrl/video_feed',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              return child;
                            }
                            return const Center(child: CircularProgressIndicator());
                          },
                          errorBuilder: (context, error, stackTrace) {
                            _addDebugLog('Video feed error: $error');
                            return const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.videocam_off, size: 48, color: Colors.red),
                                  SizedBox(height: 16),
                                  Text('Failed to load video feed',
                                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            );
                          },
                        ),
                        if (_isRecording)
                          Positioned(
                            top: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.circle, color: Colors.white, size: 12),
                                  const SizedBox(width: 8),
                                  Text(
                                    'RECORDING',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    )
                        : Container(
                      color: Colors.black,
                      child: CameraPreview(_cameraController!),
                    ),
                  ),
                ),
                _buildCameraControls(),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            child: _buildStatusPanel(),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraControls() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: _buildActionButton(
                    onPressed: _toggleCamera,
                    label: _isCameraOn ? 'Stop Camera' : 'Start Camera',
                    icon: _isCameraOn ? Icons.videocam_off : Icons.videocam,
                    color: _isCameraOn ? Colors.red : Colors.blue,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildActionButton(
                    onPressed: _isCameraOn ? _toggleRecording : null,
                    label: _isRecording ? 'Stop Recording' : 'Start Recording',
                    icon: _isRecording ? Icons.stop : Icons.fiber_manual_record,
                    color: _isRecording ? Colors.red : Colors.green,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildActionButton(
                    onPressed: _isCameraOn ? _resetCounter : null,
                    label: 'Reset Counter',
                    icon: Icons.restart_alt,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedExercise,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down),
                      hint: const Text('Select Exercise'),
                      items: _exercises
                          .map((exercise) => DropdownMenuItem(
                        value: exercise,
                        child: Text(
                          exercise,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          _changeExercise(value);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Rep Goal',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    ),
                    controller: TextEditingController(text: _repGoal.toString()),
                    onSubmitted: (value) {
                      final goal = int.tryParse(value);
                      if (goal != null && goal > 0) {
                        _setRepGoal(goal);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pain Level:', style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    const Icon(Icons.sentiment_very_dissatisfied, color: Colors.red),
                    Expanded(
                      child: Slider(
                        value: _painLevel.toDouble(),
                        min: 0,
                        max: 10,
                        divisions: 10,
                        label: _painLevel.toString(),
                        onChanged: (value) {
                          final level = value.round();
                          setState(() {
                            _painLevel = level;
                          });
                          _setPainLevel(level);
                        },
                        activeColor: _getPainLevelColor(_painLevel),
                      ),
                    ),
                    const Icon(Icons.sentiment_very_satisfied, color: Colors.green),
                  ],
                ),
                Center(
                  child: Text(
                    _getPainLevelDescription(_painLevel),
                    style: TextStyle(
                      color: _getPainLevelColor(_painLevel),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.9),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
    );
  }

  Widget _buildStatusPanel() {
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircularPercentIndicator(
                radius: 60.0,
                lineWidth: 10.0,
                percent: (_status['rep_count'] ?? 0) / (_status['rep_goal'] ?? 1).toDouble(),
                center: Text(
                  '${_status['rep_count'] ?? 0}/${_status['rep_goal'] ?? 1}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                progressColor: Colors.blue,
                circularStrokeCap: CircularStrokeCap.round,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatusCard(
              title: 'Exercise Metrics',
              children: [
                _buildStatusItem('Current Angle', '${_status['current_angle']?.toStringAsFixed(1) ?? '0'}°'),
                _buildStatusItem('Max ROM', '${_status['max_rom']?.toStringAsFixed(1) ?? '0'}°'),
                _buildStatusItem('Previous Best', '${_status['historical_max_rom']?.toStringAsFixed(1) ?? '0'}°'),
                _buildStatusItem('Exercise Speed', _status['rep_speed'] ?? 'Normal'),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatusCard(
              title: 'Feedback',
              children: [
                Text(
                  _status['feedback'] ?? 'No feedback available',
                  style: TextStyle(
                    color: _status['feedback']?.contains('WARNING') ?? false
                        ? Colors.red
                        : _status['feedback']?.contains('Caution') ?? false
                        ? Colors.orange
                        : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (_showDebugPanel) ...[
              const SizedBox(height: 16),
              _buildStatusCard(
                title: 'Debug Logs',
                children: [
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      itemCount: _debugLogs.length,
                      itemBuilder: (context, index) {
                        return Text(
                          _debugLogs[index],
                          style: const TextStyle(fontSize: 12),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Color _getPainLevelColor(int level) {
    if (level < 3) return Colors.green;
    if (level < 6) return Colors.orange;
    return Colors.red;
  }

  String _getPainLevelDescription(int level) {
    if (level == 0) return 'No pain';
    if (level < 3) return 'Mild';
    if (level < 6) return 'Moderate';
    if (level < 9) return 'Severe';
    return 'Extreme';
  }
}