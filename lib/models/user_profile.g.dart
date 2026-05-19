// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserProfileAdapter extends TypeAdapter<UserProfile> {
  @override
  final int typeId = 3;

  @override
  UserProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProfile(
      name: fields[0] as String,
      identities: (fields[1] as List).cast<String>(),
      focusAreas: (fields[2] as List).cast<FocusArea>(),
      hasCompletedOnboarding: fields[3] as bool,
      createdAt: fields[4] as DateTime,
      chronotype: fields[5] as Chronotype,
      freezesAvailable: fields[6] as int?,
      lastFreezeReplenish: fields[7] as DateTime?,
      totalFreezesUsed: fields[8] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.identities)
      ..writeByte(2)
      ..write(obj.focusAreas)
      ..writeByte(3)
      ..write(obj.hasCompletedOnboarding)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.chronotype)
      ..writeByte(6)
      ..write(obj.freezesAvailable)
      ..writeByte(7)
      ..write(obj.lastFreezeReplenish)
      ..writeByte(8)
      ..write(obj.totalFreezesUsed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChronotypeAdapter extends TypeAdapter<Chronotype> {
  @override
  final int typeId = 5;

  @override
  Chronotype read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return Chronotype.morningPerson;
      case 1:
        return Chronotype.balanced;
      case 2:
        return Chronotype.nightOwl;
      default:
        return Chronotype.morningPerson;
    }
  }

  @override
  void write(BinaryWriter writer, Chronotype obj) {
    switch (obj) {
      case Chronotype.morningPerson:
        writer.writeByte(0);
        break;
      case Chronotype.balanced:
        writer.writeByte(1);
        break;
      case Chronotype.nightOwl:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChronotypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
