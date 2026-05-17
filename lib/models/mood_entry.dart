import 'package:hive/hive.dart';

part 'mood_entry.g.dart';

@HiveType(typeId: 0)
class MoodEntry extends HiveObject {
  MoodEntry({
    required this.id,
    required this.timestamp,
    required this.mood,
    required this.energy,
    required this.focus,
    this.note,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime timestamp;

  @HiveField(2)
  double mood;

  @HiveField(3)
  double energy;

  @HiveField(4)
  double focus;

  @HiveField(5)
  String? note;

  double get averageScore => (mood + energy + focus) / 3.0;
}
