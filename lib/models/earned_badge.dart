import 'package:hive/hive.dart';

import 'badge_category.dart';

part 'earned_badge.g.dart';

/// A user's earned milestone badge. The catalog (titles, icons, criteria)
/// lives in `badge_definitions.dart` — this record is a permanent snapshot
/// of *what was earned and when*, so removed catalog entries don't erase
/// past unlocks.
@HiveType(typeId: 17)
class EarnedBadge extends HiveObject {
  EarnedBadge({
    required this.id,
    required this.badgeKey,
    required this.title,
    required this.description,
    required this.iconCode,
    required this.colorHex,
    required this.unlockedAt,
    required this.category,
  });

  @HiveField(0)
  String id;

  /// Stable catalog key, e.g. `streak_7`, `habit_100`, `gratitude_30`.
  @HiveField(1)
  String badgeKey;

  @HiveField(2)
  String title;

  @HiveField(3)
  String description;

  /// IconData.codePoint snapshot. Reconstruct with `IconData(iconCode,
  /// fontFamily: 'MaterialIcons')`.
  @HiveField(4)
  int iconCode;

  /// `0xAARRGGBB` int form of the badge's accent color.
  @HiveField(5)
  int colorHex;

  @HiveField(6)
  DateTime unlockedAt;

  @HiveField(7)
  BadgeCategory category;
}
