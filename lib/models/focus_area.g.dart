// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'focus_area.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FocusAreaAdapter extends TypeAdapter<FocusArea> {
  @override
  final int typeId = 4;

  @override
  FocusArea read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return FocusArea.work;
      case 1:
        return FocusArea.health;
      case 2:
        return FocusArea.creativity;
      case 3:
        return FocusArea.mindfulness;
      case 4:
        return FocusArea.relationships;
      case 5:
        return FocusArea.learning;
      default:
        return FocusArea.work;
    }
  }

  @override
  void write(BinaryWriter writer, FocusArea obj) {
    switch (obj) {
      case FocusArea.work:
        writer.writeByte(0);
        break;
      case FocusArea.health:
        writer.writeByte(1);
        break;
      case FocusArea.creativity:
        writer.writeByte(2);
        break;
      case FocusArea.mindfulness:
        writer.writeByte(3);
        break;
      case FocusArea.relationships:
        writer.writeByte(4);
        break;
      case FocusArea.learning:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FocusAreaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
