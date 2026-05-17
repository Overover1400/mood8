import 'package:hive/hive.dart';

part 'frequency.g.dart';

@HiveType(typeId: 10)
enum Frequency {
  @HiveField(0)
  daily,
  @HiveField(1)
  weekdays,
  @HiveField(2)
  weekends,
  @HiveField(3)
  custom,
  @HiveField(4)
  xPerWeek;

  String get label {
    switch (this) {
      case Frequency.daily:
        return 'Daily';
      case Frequency.weekdays:
        return 'Weekdays';
      case Frequency.weekends:
        return 'Weekends';
      case Frequency.custom:
        return 'Custom days';
      case Frequency.xPerWeek:
        return 'X per week';
    }
  }
}

int weekdayIndexFor(DateTime date) =>
    date.weekday == DateTime.sunday ? 0 : date.weekday;

const List<String> kWeekdayShort = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
