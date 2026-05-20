// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom_command.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CustomCommandAdapter extends TypeAdapter<CustomCommand> {
  @override
  final int typeId = 1;

  @override
  CustomCommand read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CustomCommand(
      id: fields[0] as String,
      label: fields[1] as String,
      command: fields[2] as String,
      icon: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CustomCommand obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.label)
      ..writeByte(2)
      ..write(obj.command)
      ..writeByte(3)
      ..write(obj.icon);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomCommandAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
