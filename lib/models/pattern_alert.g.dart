// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pattern_alert.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PatternAlertAdapter extends TypeAdapter<PatternAlert> {
  @override
  final int typeId = 21;

  @override
  PatternAlert read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PatternAlert(
      id: fields[0] as String,
      category: fields[1] as PatternCategory,
      title: fields[2] as String,
      body: fields[3] as String,
      severity: fields[6] as PatternSeverity,
      detectedAt: fields[7] as DateTime,
      relevanceScore: fields[10] as double,
      actionLabel: fields[4] as String?,
      actionRoute: fields[5] as String?,
      dismissedAt: fields[8] as DateTime?,
      viewedAt: fields[9] as DateTime?,
      dedupeKey: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PatternAlert obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.category)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.body)
      ..writeByte(4)
      ..write(obj.actionLabel)
      ..writeByte(5)
      ..write(obj.actionRoute)
      ..writeByte(6)
      ..write(obj.severity)
      ..writeByte(7)
      ..write(obj.detectedAt)
      ..writeByte(8)
      ..write(obj.dismissedAt)
      ..writeByte(9)
      ..write(obj.viewedAt)
      ..writeByte(10)
      ..write(obj.relevanceScore)
      ..writeByte(11)
      ..write(obj.dedupeKey);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatternAlertAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PatternCategoryAdapter extends TypeAdapter<PatternCategory> {
  @override
  final int typeId = 22;

  @override
  PatternCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PatternCategory.streak;
      case 1:
        return PatternCategory.moodCorrelation;
      case 2:
        return PatternCategory.dayOfWeek;
      case 3:
        return PatternCategory.growth;
      case 4:
        return PatternCategory.checkIn;
      default:
        return PatternCategory.streak;
    }
  }

  @override
  void write(BinaryWriter writer, PatternCategory obj) {
    switch (obj) {
      case PatternCategory.streak:
        writer.writeByte(0);
        break;
      case PatternCategory.moodCorrelation:
        writer.writeByte(1);
        break;
      case PatternCategory.dayOfWeek:
        writer.writeByte(2);
        break;
      case PatternCategory.growth:
        writer.writeByte(3);
        break;
      case PatternCategory.checkIn:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatternCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PatternSeverityAdapter extends TypeAdapter<PatternSeverity> {
  @override
  final int typeId = 23;

  @override
  PatternSeverity read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PatternSeverity.positive;
      case 1:
        return PatternSeverity.neutral;
      case 2:
        return PatternSeverity.gentleConcern;
      default:
        return PatternSeverity.positive;
    }
  }

  @override
  void write(BinaryWriter writer, PatternSeverity obj) {
    switch (obj) {
      case PatternSeverity.positive:
        writer.writeByte(0);
        break;
      case PatternSeverity.neutral:
        writer.writeByte(1);
        break;
      case PatternSeverity.gentleConcern:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatternSeverityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
