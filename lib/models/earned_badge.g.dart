// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'earned_badge.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EarnedBadgeAdapter extends TypeAdapter<EarnedBadge> {
  @override
  final int typeId = 17;

  @override
  EarnedBadge read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EarnedBadge(
      id: fields[0] as String,
      badgeKey: fields[1] as String,
      title: fields[2] as String,
      description: fields[3] as String,
      iconCode: fields[4] as int,
      colorHex: fields[5] as int,
      unlockedAt: fields[6] as DateTime,
      category: fields[7] as BadgeCategory,
      updatedAt: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, EarnedBadge obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.badgeKey)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.iconCode)
      ..writeByte(5)
      ..write(obj.colorHex)
      ..writeByte(6)
      ..write(obj.unlockedAt)
      ..writeByte(7)
      ..write(obj.category)
      ..writeByte(8)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EarnedBadgeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
