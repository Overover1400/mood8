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
    this.aiManaged = false,
    this.goalDescription,
    this.programDurationDays,
    this.remindersEnabled = false,
    List<int>? reminderMinutes,
  })  : frozenDates = frozenDates ?? <DateTime>[],
        reminderMinutes = reminderMinutes ?? <int>[];

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

  /// True when this habit was designed by the Mood8 AI Coach via the
  /// `/api/coach/chat` flow (Premium Plus). Drives the "Mood8 AI
  /// Habits" filter tab on the Habits screen and, in future builds,
  /// failure-recovery conversations + program-progress display.
  @HiveField(21)
  bool aiManaged;

  /// The user's stated goal in their own words, captured at proposal
  /// time ("I want to be a book reader", "wake up earlier"). Stored
  /// so future builds can show the why on each habit + reference it
  /// in coach follow-ups. Null when [aiManaged] is false.
  @HiveField(22)
  String? goalDescription;

  /// The coach's suggested program window in days (7/14/21/30/60/90).
  /// Drives future build-2/3 progress display ("day 12 of 30"). Null
  /// when [aiManaged] is false.
  @HiveField(23)
  int? programDurationDays;

  /// True when the user enabled per-habit reminders. Pairs with
  /// [reminderMinutes] — the list of minute-of-day slots (0–1439)
  /// the OS should fire a local notification at.
  ///
  /// We store the toggle separately from the list so a user can
  /// silence reminders temporarily without losing their carefully
  /// picked times.
  @HiveField(24)
  bool remindersEnabled;

  /// Minute-of-day slots for reminders (e.g. 540 = 09:00). Empty when
  /// no reminders are set. Counter habits (drink water 8x/day, etc.)
  /// can have many entries; yes/no habits typically have one.
  @HiveField(25)
  List<int> reminderMinutes;

  bool get isAvoid => polarity == HabitPolarity.avoid;
  bool get isFromPackage => packageId != null;
  bool get isAiManaged => aiManaged;
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
