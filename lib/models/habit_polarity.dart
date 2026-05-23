import 'package:hive/hive.dart';

part 'habit_polarity.g.dart';

/// Whether the user wants to BUILD this habit (do it more) or AVOID
/// it (do it less / quit entirely). Drives the card tint and the
/// "good" direction shown in stats.
@HiveType(typeId: 24)
enum HabitPolarity {
  @HiveField(0)
  build,
  @HiveField(1)
  avoid;

  String get label => this == HabitPolarity.build ? 'Build' : 'Avoid';
}

/// For avoid habits, how the user wants to handle it:
/// - [quit] — eliminate completely. Daily "stayed clean" check, streak.
/// - [reduce] — cut down. Daily count + downward-trend display.
@HiveType(typeId: 25)
enum AvoidMode {
  @HiveField(0)
  quit,
  @HiveField(1)
  reduce;

  String get label => this == AvoidMode.quit ? 'Quit' : 'Reduce';
}
