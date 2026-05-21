// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminder_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReminderSettingsAdapter extends TypeAdapter<ReminderSettings> {
  @override
  final int typeId = 19;

  @override
  ReminderSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReminderSettings(
      enabled: fields[0] as bool?,
      reminderTimes: (fields[1] as List?)?.cast<int>(),
      smartSkip: fields[2] as bool?,
      quietHoursEnabled: fields[3] as bool?,
      quietStart: fields[4] as int?,
      quietEnd: fields[5] as int?,
      updatedAt: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, ReminderSettings obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.enabled)
      ..writeByte(1)
      ..write(obj.reminderTimes)
      ..writeByte(2)
      ..write(obj.smartSkip)
      ..writeByte(3)
      ..write(obj.quietHoursEnabled)
      ..writeByte(4)
      ..write(obj.quietStart)
      ..writeByte(5)
      ..write(obj.quietEnd)
      ..writeByte(6)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
