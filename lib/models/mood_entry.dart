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
    this.updatedAt,
    this.partOfDay,
    this.dayRating,
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

  /// Last-write-wins timestamp for cloud sync. Nullable for backward
  /// compat — coalesces to [timestamp] when missing.
  @HiveField(6)
  DateTime? updatedAt;

  /// Spec 2.1 — `'morning'` or `'evening'`. A plain string rather than a
  /// Hive enum so it round-trips to the backend's `part_of_day` column
  /// without a codec, and so old entries (null) stay readable.
  ///
  /// This is the field the adaptation engine needs: one entry per day
  /// gives it nothing to compare, and comparison is the whole product.
  @HiveField(7)
  String? partOfDay;

  /// Spec 2.1 — evening check-in only: "how did the day go", 1–5.
  /// Null on morning entries.
  @HiveField(8)
  double? dayRating;

  bool get isEvening => partOfDay == 'evening';

  double get averageScore => (mood + energy + focus) / 3.0;
}
