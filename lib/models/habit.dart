import 'package:hive/hive.dart';

import 'frequency.dart';
import 'habit_polarity.dart';
import 'habit_type.dart';
import 'routine_category.dart';

part 'habit.g.dart';

@HiveType(typeId: 8)
class Habit extends HiveObject {
  Habit({
    required this.id,
    required this.title,
    required this.icon,
    required this.habitType,
    required this.identity,
    required this.category,
    required this.frequency,
    required this.color,
    required this.createdAt,
    this.description,
    this.targetValue,
    this.targetUnit,
    this.frequencyDays,
    this.sortOrder = 0,
    this.isArchived = false,
    List<DateTime>? frozenDates,
    this.updatedAt,
    this.polarity = HabitPolarity.build,
    this.avoidMode,
    this.avoidDurationDays,
    this.packageId,
  }) : frozenDates = frozenDates ?? <DateTime>[];

  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? description;

  @HiveField(3)
  String icon;

  @HiveField(4)
  HabitType habitType;

  @HiveField(5)
  int? targetValue;

  @HiveField(6)
  String? targetUnit;

  @HiveField(7)
  String identity;

  @HiveField(8)
  RoutineCategory category;

  @HiveField(9)
  Frequency frequency;

  @HiveField(10)
  List<int>? frequencyDays;

  @HiveField(11)
  int color;

  @HiveField(12)
  DateTime createdAt;

  @HiveField(13)
  int sortOrder;

  @HiveField(14)
  bool isArchived;

  @HiveField(15)
  List<DateTime> frozenDates;

  @HiveField(16)
  DateTime? updatedAt;

  /// Whether this is a habit to build (do more) or avoid (do less).
  /// Defaults to `build` so legacy habits read from Hive without the
  /// field set still work.
  @HiveField(17)
  HabitPolarity polarity;

  /// Only meaningful when [polarity] is [HabitPolarity.avoid]:
  /// - [AvoidMode.quit] — daily yes/no "stayed clean"
  /// - [AvoidMode.reduce] — daily count, trend downward
  @HiveField(18)
  AvoidMode? avoidMode;

  /// Reduce-mode horizon: 7, 30, or 90 days. The detail screen draws
  /// a trend chart spanning this window.
  @HiveField(19)
  int? avoidDurationDays;

  /// Set when this habit was materialised by starting an AI Habit
  /// Package (Premium Plus). Stable id from `lib/data/habit_packages.dart`,
  /// e.g. "pkg.morning_calm". Null for regular user-created habits.
  /// Drives the per-package filter tab on the Habits screen.
  @HiveField(20)
  String? packageId;

  bool get isAvoid => polarity == HabitPolarity.avoid;
  bool get isFromPackage => packageId != null;
  bool get isQuit => isAvoid && avoidMode == AvoidMode.quit;
  bool get isReduce => isAvoid && avoidMode == AvoidMode.reduce;

  bool isFrozenOn(DateTime date) {
    for (final d in frozenDates) {
      if (d.year == date.year &&
          d.month == date.month &&
          d.day == date.day) {
        return true;
      }
    }
    return false;
  }

  bool isScheduledFor(DateTime date) {
    final wd = weekdayIndexFor(date);
    switch (frequency) {
      case Frequency.daily:
        return true;
      case Frequency.weekdays:
        return wd >= 1 && wd <= 5;
      case Frequency.weekends:
        return wd == 0 || wd == 6;
      case Frequency.custom:
        return frequencyDays?.contains(wd) ?? false;
      case Frequency.xPerWeek:
        return true;
    }
  }

  int get effectiveTarget {
    if (habitType == HabitType.yesNo) return 1;
    // Reduce-mode habits track a count with no upper bound — every
    // slip logged is data, never "completion". Return a very high cap
    // so the +/- stepper UI doesn't gate at 1.
    if (isReduce) return 1 << 20;
    return targetValue ?? 1;
  }
}
