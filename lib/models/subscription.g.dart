// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SubscriptionTierAdapter extends TypeAdapter<SubscriptionTier> {
  @override
  final int typeId = 14;

  @override
  SubscriptionTier read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SubscriptionTier.free;
      case 1:
        return SubscriptionTier.premium;
      case 2:
        return SubscriptionTier.premiumLifetime;
      // Legacy Plus values from before the tier collapse: read
      // recurring Plus (3) back as plain Premium and lifetime Plus
      // (4) back as Premium · Lifetime so any Hive-cached row
      // written by an older build still deserialises cleanly.
      case 3:
        return SubscriptionTier.premium;
      case 4:
        return SubscriptionTier.premiumLifetime;
      default:
        return SubscriptionTier.free;
    }
  }

  @override
  void write(BinaryWriter writer, SubscriptionTier obj) {
    switch (obj) {
      case SubscriptionTier.free:
        writer.writeByte(0);
        break;
      case SubscriptionTier.premium:
        writer.writeByte(1);
        break;
      case SubscriptionTier.premiumLifetime:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubscriptionTierAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
