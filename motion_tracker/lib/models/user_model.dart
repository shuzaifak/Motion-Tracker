import 'package:hive/hive.dart';

part 'user_model.g.dart';

@HiveType(typeId: 0)
class User extends HiveObject {
  @HiveField(0)
  String username;

  @HiveField(1)
  String email;

  @HiveField(2)
  String password;

  @HiveField(3)
  DateTime createdAt;

  User({
    required this.username,
    required this.email,
    required this.password,
    required this.createdAt,
  });
}

// Run the following command to generate the adapter code:
// flutter packages pub run build_runner build

@HiveType(typeId: 1)
class MotionData extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  DateTime recordedAt;

  @HiveField(3)
  String videoPath;

  @HiveField(4)
  List<PoseKeypoint> keypoints;

  @HiveField(5)
  String activityType;

  @HiveField(6)
  Map<String, dynamic> analysisResults;

  MotionData({
    required this.id,
    required this.title,
    required this.recordedAt,
    required this.videoPath,
    required this.keypoints,
    required this.activityType,
    required this.analysisResults,
  });
}

@HiveType(typeId: 2)
class PoseKeypoint extends HiveObject {
  @HiveField(0)
  int frameIndex;

  @HiveField(1)
  List<KeypointPosition> positions;

  PoseKeypoint({
    required this.frameIndex,
    required this.positions,
  });
}

@HiveType(typeId: 3)
class KeypointPosition extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  String name;

  @HiveField(2)
  double x;

  @HiveField(3)
  double y;

  @HiveField(4)
  double confidence;

  KeypointPosition({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.confidence,
  });

  get positions => null;
}
