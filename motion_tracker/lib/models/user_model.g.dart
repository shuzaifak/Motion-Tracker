// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserAdapter extends TypeAdapter<User> {
  @override
  final int typeId = 0;

  @override
  User read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return User(
      username: fields[0] as String,
      email: fields[1] as String,
      password: fields[2] as String,
      createdAt: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, User obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.username)
      ..writeByte(1)
      ..write(obj.email)
      ..writeByte(2)
      ..write(obj.password)
      ..writeByte(3)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MotionDataAdapter extends TypeAdapter<MotionData> {
  @override
  final int typeId = 1;

  @override
  MotionData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MotionData(
      id: fields[0] as String,
      title: fields[1] as String,
      recordedAt: fields[2] as DateTime,
      videoPath: fields[3] as String,
      keypoints: (fields[4] as List).cast<PoseKeypoint>(),
      activityType: fields[5] as String,
      analysisResults: (fields[6] as Map).cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, MotionData obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.recordedAt)
      ..writeByte(3)
      ..write(obj.videoPath)
      ..writeByte(4)
      ..write(obj.keypoints)
      ..writeByte(5)
      ..write(obj.activityType)
      ..writeByte(6)
      ..write(obj.analysisResults);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MotionDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PoseKeypointAdapter extends TypeAdapter<PoseKeypoint> {
  @override
  final int typeId = 2;

  @override
  PoseKeypoint read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PoseKeypoint(
      frameIndex: fields[0] as int,
      positions: (fields[1] as List).cast<KeypointPosition>(),
    );
  }

  @override
  void write(BinaryWriter writer, PoseKeypoint obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.frameIndex)
      ..writeByte(1)
      ..write(obj.positions);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PoseKeypointAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class KeypointPositionAdapter extends TypeAdapter<KeypointPosition> {
  @override
  final int typeId = 3;

  @override
  KeypointPosition read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return KeypointPosition(
      id: fields[0] as int,
      name: fields[1] as String,
      x: fields[2] as double,
      y: fields[3] as double,
      confidence: fields[4] as double,
    );
  }

  @override
  void write(BinaryWriter writer, KeypointPosition obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.x)
      ..writeByte(3)
      ..write(obj.y)
      ..writeByte(4)
      ..write(obj.confidence);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeypointPositionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
