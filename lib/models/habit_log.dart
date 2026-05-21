import 'package:hive/hive.dart';

part 'habit_log.g.dart';

@HiveType(typeId: 11)
class HabitLog extends HiveObject {
  HabitLog({
    required this.id,
    required this.habitId,
    required this.date,
    required this.value,
    required this.targetValue,
    required this.timestamp,
    this.note,
    this.updatedAt,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String habitId;

  @HiveField(2)
  DateTime date;

  @HiveField(3)
  int value;

  @HiveField(4)
  int targetValue;

  @HiveField(5)
  String? note;

  @HiveField(6)
  DateTime timestamp;

  @HiveField(7)
  DateTime? updatedAt;

  bool get isCompleted => value >= targetValue;

  double get completionPercentage {
    if (targetValue <= 0) return value > 0 ? 1.0 : 0.0;
    return (value / targetValue).clamp(0.0, 1.0);
  }
}
