// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HabitAdapter extends TypeAdapter<Habit> {
  @override
  final int typeId = 8;

  @override
  Habit read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Habit(
      id: fields[0] as String,
      title: fields[1] as String,
      icon: fields[3] as String,
      habitType: fields[4] as HabitType,
      identity: fields[7] as String,
      category: fields[8] as RoutineCategory,
      frequency: fields[9] as Frequency,
      color: fields[11] as int,
      createdAt: fields[12] as DateTime,
      description: fields[2] as String?,
      targetValue: fields[5] as int?,
      targetUnit: fields[6] as String?,
      frequencyDays: (fields[10] as List?)?.cast<int>(),
      sortOrder: fields[13] as int,
      isArchived: fields[14] as bool,
      frozenDates: (fields[15] as List?)?.cast<DateTime>(),
      updatedAt: fields[16] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Habit obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.icon)
      ..writeByte(4)
      ..write(obj.habitType)
      ..writeByte(5)
      ..write(obj.targetValue)
      ..writeByte(6)
      ..write(obj.targetUnit)
      ..writeByte(7)
      ..write(obj.identity)
      ..writeByte(8)
      ..write(obj.category)
      ..writeByte(9)
      ..write(obj.frequency)
      ..writeByte(10)
      ..write(obj.frequencyDays)
      ..writeByte(11)
      ..write(obj.color)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(13)
      ..write(obj.sortOrder)
      ..writeByte(14)
      ..write(obj.isArchived)
      ..writeByte(15)
      ..write(obj.frozenDates)
      ..writeByte(16)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
