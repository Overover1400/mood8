import 'package:hive/hive.dart';

part 'subscription.g.dart';

@HiveType(typeId: 14)
enum SubscriptionTier {
  @HiveField(0)
  free,
  @HiveField(1)
  premium,
  @HiveField(2)
  premiumLifetime;

  bool get isPaid =>
      this == SubscriptionTier.premium ||
      this == SubscriptionTier.premiumLifetime;

  String get label {
    switch (this) {
      case SubscriptionTier.free:
        return 'Free';
      case SubscriptionTier.premium:
        return 'Premium';
      case SubscriptionTier.premiumLifetime:
        return 'Premium · Lifetime';
    }
  }
}
