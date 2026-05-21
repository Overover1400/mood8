// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gratitude_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GratitudeEntryAdapter extends TypeAdapter<GratitudeEntry> {
  @override
  final int typeId = 16;

  @override
  GratitudeEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GratitudeEntry(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      items: (fields[2] as List).cast<String>(),
      createdAt: fields[3] as DateTime,
      updatedAt: fields[4] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, GratitudeEntry obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.items)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GratitudeEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
