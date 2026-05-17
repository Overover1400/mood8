// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'insight.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InsightAdapter extends TypeAdapter<Insight> {
  @override
  final int typeId = 12;

  @override
  Insight read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Insight(
      id: fields[0] as String,
      type: fields[1] as InsightType,
      title: fields[2] as String,
      confidence: fields[4] as double,
      effectSize: fields[5] as double,
      sampleSize: fields[6] as int,
      discoveredAt: fields[12] as DateTime,
      description: fields[3] as String?,
      relatedHabitId: fields[7] as String?,
      relatedIdentity: fields[8] as String?,
      actionable: fields[9] as bool,
      actionText: fields[10] as String?,
      aiExplanation: fields[11] as String?,
      dismissed: fields[13] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Insight obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.confidence)
      ..writeByte(5)
      ..write(obj.effectSize)
      ..writeByte(6)
      ..write(obj.sampleSize)
      ..writeByte(7)
      ..write(obj.relatedHabitId)
      ..writeByte(8)
      ..write(obj.relatedIdentity)
      ..writeByte(9)
      ..write(obj.actionable)
      ..writeByte(10)
      ..write(obj.actionText)
      ..writeByte(11)
      ..write(obj.aiExplanation)
      ..writeByte(12)
      ..write(obj.discoveredAt)
      ..writeByte(13)
      ..write(obj.dismissed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InsightAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
