// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'morning_intention.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MorningIntentionAdapter extends TypeAdapter<MorningIntention> {
  @override
  final int typeId = 15;

  @override
  MorningIntention read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MorningIntention(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      text: fields[2] as String,
      createdAt: fields[3] as DateTime,
      wasSkipped: fields[4] as bool,
      updatedAt: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, MorningIntention obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.text)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.wasSkipped)
      ..writeByte(5)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MorningIntentionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
