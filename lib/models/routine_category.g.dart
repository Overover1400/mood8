// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routine_category.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RoutineCategoryAdapter extends TypeAdapter<RoutineCategory> {
  @override
  final int typeId = 2;

  @override
  RoutineCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return RoutineCategory.work;
      case 1:
        return RoutineCategory.health;
      case 2:
        return RoutineCategory.mindful;
      case 3:
        return RoutineCategory.creative;
      case 4:
        return RoutineCategory.rest;
      default:
        return RoutineCategory.work;
    }
  }

  @override
  void write(BinaryWriter writer, RoutineCategory obj) {
    switch (obj) {
      case RoutineCategory.work:
        writer.writeByte(0);
        break;
      case RoutineCategory.health:
        writer.writeByte(1);
        break;
      case RoutineCategory.mindful:
        writer.writeByte(2);
        break;
      case RoutineCategory.creative:
        writer.writeByte(3);
        break;
      case RoutineCategory.rest:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutineCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
