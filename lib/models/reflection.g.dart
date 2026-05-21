// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reflection.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReflectionAdapter extends TypeAdapter<Reflection> {
  @override
  final int typeId = 6;

  @override
  Reflection read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Reflection(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      reflection: fields[2] as String,
      generatedAt: fields[4] as DateTime,
      suggestion: fields[3] as String?,
      identityScores: (fields[5] as Map?)?.cast<String, double>(),
      updatedAt: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Reflection obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.reflection)
      ..writeByte(3)
      ..write(obj.suggestion)
      ..writeByte(4)
      ..write(obj.generatedAt)
      ..writeByte(5)
      ..write(obj.identityScores)
      ..writeByte(6)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReflectionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
