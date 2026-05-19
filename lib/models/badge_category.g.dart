// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'badge_category.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BadgeCategoryAdapter extends TypeAdapter<BadgeCategory> {
  @override
  final int typeId = 18;

  @override
  BadgeCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return BadgeCategory.streak;
      case 1:
        return BadgeCategory.habit;
      case 2:
        return BadgeCategory.routine;
      case 3:
        return BadgeCategory.identity;
      case 4:
        return BadgeCategory.gratitude;
      default:
        return BadgeCategory.streak;
    }
  }

  @override
  void write(BinaryWriter writer, BadgeCategory obj) {
    switch (obj) {
      case BadgeCategory.streak:
        writer.writeByte(0);
        break;
      case BadgeCategory.habit:
        writer.writeByte(1);
        break;
      case BadgeCategory.routine:
        writer.writeByte(2);
        break;
      case BadgeCategory.identity:
        writer.writeByte(3);
        break;
      case BadgeCategory.gratitude:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BadgeCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
