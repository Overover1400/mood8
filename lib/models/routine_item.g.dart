// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routine_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RoutineItemAdapter extends TypeAdapter<RoutineItem> {
  @override
  final int typeId = 1;

  @override
  RoutineItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RoutineItem(
      id: fields[0] as String,
      title: fields[1] as String,
      time: fields[2] as DateTime,
      durationMinutes: fields[3] as int,
      category: fields[4] as RoutineCategory,
      meta: fields[5] as String,
      isCompleted: fields[6] as bool,
      completedAt: fields[7] as DateTime?,
      sortOrder: fields[8] as int,
    );
  }

  @override
  void write(BinaryWriter writer, RoutineItem obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.time)
      ..writeByte(3)
      ..write(obj.durationMinutes)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.meta)
      ..writeByte(6)
      ..write(obj.isCompleted)
      ..writeByte(7)
      ..write(obj.completedAt)
      ..writeByte(8)
      ..write(obj.sortOrder);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutineItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
