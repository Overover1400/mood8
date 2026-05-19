import 'package:hive/hive.dart';

import 'frequency.dart';
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
    return targetValue ?? 1;
  }
}
