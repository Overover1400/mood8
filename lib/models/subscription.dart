import 'package:hive/hive.dart';

part 'subscription.g.dart';

/// Subscription tier. One paid family called "Premium" with a
/// recurring + a lifetime variant. The backend stores the billing
/// cadence in `premium_type` ("monthly" / "annual" / "lifetime"); we
/// collapse that into the two paid enum values below plus `free`.
///
/// The former `premiumPlus` + `premiumPlusLifetime` values were
/// retired when the two-tier system was collapsed into one. The
/// HiveField ids stay stable so any cached enum value from an older
/// build still deserializes cleanly (a Plus row simply reads back as
/// its lifetime/recurring Premium equivalent via the adapter).
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

  bool get isLifetime => this == SubscriptionTier.premiumLifetime;

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
