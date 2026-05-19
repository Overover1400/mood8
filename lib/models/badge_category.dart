import 'package:hive/hive.dart';

part 'badge_category.g.dart';

@HiveType(typeId: 18)
enum BadgeCategory {
  @HiveField(0)
  streak,
  @HiveField(1)
  habit,
  @HiveField(2)
  routine,
  @HiveField(3)
  identity,
  @HiveField(4)
  gratitude;

  String get label {
    switch (this) {
      case BadgeCategory.streak:
        return 'Streaks';
      case BadgeCategory.habit:
        return 'Habits';
      case BadgeCategory.routine:
        return 'Routines';
      case BadgeCategory.identity:
        return 'Identity';
      case BadgeCategory.gratitude:
        return 'Gratitude';
    }
  }
}
