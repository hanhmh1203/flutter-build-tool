// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProjectAdapter extends TypeAdapter<Project> {
  @override
  final int typeId = 0;

  @override
  Project read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Project(
      id: fields[0] as String,
      name: fields[1] as String,
      path: fields[2] as String,
      addedAt: fields[7] as DateTime,
      lastFlavor: fields[3] as String?,
      lastDeviceId: fields[4] as String?,
      cleanBeforeBuild: fields[5] as bool,
      customCommands: (fields[6] as List?)?.cast<CustomCommand>(),
      lastOpenedAt: fields[8] as DateTime?,
      lastEntryPoint: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Project obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.path)
      ..writeByte(3)
      ..write(obj.lastFlavor)
      ..writeByte(4)
      ..write(obj.lastDeviceId)
      ..writeByte(5)
      ..write(obj.cleanBeforeBuild)
      ..writeByte(6)
      ..write(obj.customCommands)
      ..writeByte(7)
      ..write(obj.addedAt)
      ..writeByte(8)
      ..write(obj.lastOpenedAt)
      ..writeByte(9)
      ..write(obj.lastEntryPoint);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
