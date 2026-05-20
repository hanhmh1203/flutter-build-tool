// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'build_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BuildLogAdapter extends TypeAdapter<BuildLog> {
  @override
  final int typeId = 2;

  @override
  BuildLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BuildLog(
      id: fields[0] as String,
      projectId: fields[1] as String,
      commandLabel: fields[2] as String,
      fullCommand: fields[3] as String,
      startedAt: fields[4] as DateTime,
      logFilePath: fields[7] as String,
      exitCode: fields[6] as int?,
    )..durationMs = fields[5] as int?;
  }

  @override
  void write(BinaryWriter writer, BuildLog obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.projectId)
      ..writeByte(2)
      ..write(obj.commandLabel)
      ..writeByte(3)
      ..write(obj.fullCommand)
      ..writeByte(4)
      ..write(obj.startedAt)
      ..writeByte(5)
      ..write(obj.durationMs)
      ..writeByte(6)
      ..write(obj.exitCode)
      ..writeByte(7)
      ..write(obj.logFilePath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BuildLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
