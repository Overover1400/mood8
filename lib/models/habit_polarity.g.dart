// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_polarity.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HabitPolarityAdapter extends TypeAdapter<HabitPolarity> {
  @override
  final int typeId = 24;

  @override
  HabitPolarity read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return HabitPolarity.build;
      case 1:
        return HabitPolarity.avoid;
      default:
        return HabitPolarity.build;
    }
  }

  @override
  void write(BinaryWriter writer, HabitPolarity obj) {
    switch (obj) {
      case HabitPolarity.build:
        writer.writeByte(0);
        break;
      case HabitPolarity.avoid:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitPolarityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AvoidModeAdapter extends TypeAdapter<AvoidMode> {
  @override
  final int typeId = 25;

  @override
  AvoidMode read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AvoidMode.quit;
      case 1:
        return AvoidMode.reduce;
      default:
        return AvoidMode.quit;
    }
  }

  @override
  void write(BinaryWriter writer, AvoidMode obj) {
    switch (obj) {
      case AvoidMode.quit:
        writer.writeByte(0);
        break;
      case AvoidMode.reduce:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AvoidModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
