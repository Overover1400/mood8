// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'insight_type.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InsightTypeAdapter extends TypeAdapter<InsightType> {
  @override
  final int typeId = 13;

  @override
  InsightType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return InsightType.habitImpact;
      case 1:
        return InsightType.warning;
      case 2:
        return InsightType.timePattern;
      case 3:
        return InsightType.streakPattern;
      case 4:
        return InsightType.identityDriver;
      case 5:
        return InsightType.milestone;
      case 6:
        return InsightType.rhythm;
      case 7:
        return InsightType.discovery;
      default:
        return InsightType.habitImpact;
    }
  }

  @override
  void write(BinaryWriter writer, InsightType obj) {
    switch (obj) {
      case InsightType.habitImpact:
        writer.writeByte(0);
        break;
      case InsightType.warning:
        writer.writeByte(1);
        break;
      case InsightType.timePattern:
        writer.writeByte(2);
        break;
      case InsightType.streakPattern:
        writer.writeByte(3);
        break;
      case InsightType.identityDriver:
        writer.writeByte(4);
        break;
      case InsightType.milestone:
        writer.writeByte(5);
        break;
      case InsightType.rhythm:
        writer.writeByte(6);
        break;
      case InsightType.discovery:
        writer.writeByte(7);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InsightTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
