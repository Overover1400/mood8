import 'package:hive/hive.dart';

part 'subscription.g.dart';

/// Subscription tier. Two paid families (Premium and Premium Plus),
/// each with a recurring + a lifetime variant. The backend stores the
/// family in `premium_plan` ("premium" / "premium_plus") and the
/// billing cadence in `premium_type` ("monthly" / "annual" /
/// "lifetime"); we collapse them into the four paid enum values below
/// plus `free`.
@HiveType(typeId: 14)
enum SubscriptionTier {
  @HiveField(0)
  free,
  @HiveField(1)
  premium,
  @HiveField(2)
  premiumLifetime,
  @HiveField(3)
  premiumPlus,
  @HiveField(4)
  premiumPlusLifetime;

  bool get isPaid =>
      this == SubscriptionTier.premium ||
      this == SubscriptionTier.premiumLifetime ||
      this == SubscriptionTier.premiumPlus ||
      this == SubscriptionTier.premiumPlusLifetime;

  /// True for any Premium Plus variant — gates the AI Habit Packages.
  bool get isPlus =>
      this == SubscriptionTier.premiumPlus ||
      this == SubscriptionTier.premiumPlusLifetime;

  bool get isLifetime =>
      this == SubscriptionTier.premiumLifetime ||
      this == SubscriptionTier.premiumPlusLifetime;

  String get label {
    switch (this) {
      case SubscriptionTier.free:
        return 'Free';
      case SubscriptionTier.premium:
        return 'Premium';
      case SubscriptionTier.premiumLifetime:
        return 'Premium · Lifetime';
      case SubscriptionTier.premiumPlus:
        return 'Premium Plus';
      case SubscriptionTier.premiumPlusLifetime:
        return 'Premium Plus · Lifetime';
    }
  }
}
