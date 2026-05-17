import 'package:hive/hive.dart';

part 'habit_type.g.dart';

@HiveType(typeId: 9)
enum HabitType {
  @HiveField(0)
  yesNo,
  @HiveField(1)
  counter,
  @HiveField(2)
  duration;

  String get label {
    switch (this) {
      case HabitType.yesNo:
        return 'Yes / No';
      case HabitType.counter:
        return 'Counter';
      case HabitType.duration:
        return 'Duration';
    }
  }

  String get defaultUnit {
    switch (this) {
      case HabitType.yesNo:
        return '';
      case HabitType.counter:
        return 'times';
      case HabitType.duration:
        return 'minutes';
    }
  }
}
