// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weekly_recap.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WeeklyRecapAdapter extends TypeAdapter<WeeklyRecap> {
  @override
  final int typeId = 20;

  @override
  WeeklyRecap read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WeeklyRecap(
      id: fields[0] as String,
      weekStart: fields[1] as DateTime,
      weekEnd: fields[2] as DateTime,
      narrative: fields[3] as String,
      patterns: (fields[4] as List?)?.cast<String>(),
      lookingAhead: fields[5] as String,
      moodSummary: fields[6] as String,
      gratitudeThemes: (fields[7] as List?)?.cast<String>(),
      stats: (fields[8] as Map?)?.cast<String, dynamic>(),
      generatedAt: fields[9] as DateTime,
      emailSent: fields[10] as bool,
      updatedAt: fields[11] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, WeeklyRecap obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.weekStart)
      ..writeByte(2)
      ..write(obj.weekEnd)
      ..writeByte(3)
      ..write(obj.narrative)
      ..writeByte(4)
      ..write(obj.patterns)
      ..writeByte(5)
      ..write(obj.lookingAhead)
      ..writeByte(6)
      ..write(obj.moodSummary)
      ..writeByte(7)
      ..write(obj.gratitudeThemes)
      ..writeByte(8)
      ..write(obj.stats)
      ..writeByte(9)
      ..write(obj.generatedAt)
      ..writeByte(10)
      ..write(obj.emailSent)
      ..writeByte(11)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeeklyRecapAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
