import 'package:hive/hive.dart';

part 'pattern_alert.g.dart';

@HiveType(typeId: 22)
enum PatternCategory {
  @HiveField(0)
  streak,
  @HiveField(1)
  moodCorrelation,
  @HiveField(2)
  dayOfWeek,
  @HiveField(3)
  growth,
  @HiveField(4)
  checkIn;

  String get label {
    switch (this) {
      case PatternCategory.streak:
        return 'Streaks';
      case PatternCategory.moodCorrelation:
        return 'Mood';
      case PatternCategory.dayOfWeek:
        return 'Day of week';
      case PatternCategory.growth:
        return 'Growth';
      case PatternCategory.checkIn:
        return 'Check-ins';
    }
  }
}

@HiveType(typeId: 23)
enum PatternSeverity {
  @HiveField(0)
  positive,
  @HiveField(1)
  neutral,
  @HiveField(2)
  gentleConcern;
}

/// A detected behavioral pattern surfaced to the user. Stored locally so the
/// home carousel + history screen can rebuild without a network call.
@HiveType(typeId: 21)
class PatternAlert extends HiveObject {
  PatternAlert({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.severity,
    required this.detectedAt,
    required this.relevanceScore,
    this.actionLabel,
    this.actionRoute,
    this.dismissedAt,
    this.viewedAt,
    String? dedupeKey,
  }) : dedupeKey = dedupeKey ?? '${category.name}.$id';

  @HiveField(0)
  String id;

  @HiveField(1)
  PatternCategory category;

  @HiveField(2)
  String title;

  @HiveField(3)
  String body;

  @HiveField(4)
  String? actionLabel;

  /// Logical route key the home card / history detail consumes — e.g.
  /// `coach`, `habits`, `progress`, or `habit:<id>`. Resolved by the
  /// caller, not by the model.
  @HiveField(5)
  String? actionRoute;

  @HiveField(6)
  PatternSeverity severity;

  @HiveField(7)
  DateTime detectedAt;

  @HiveField(8)
  DateTime? dismissedAt;

  @HiveField(9)
  DateTime? viewedAt;

  @HiveField(10)
  double relevanceScore;

  /// Stable key used to suppress duplicate detections (e.g. same habit +
  /// same streak milestone shouldn't fire twice). Default derives from
  /// category + id but detectors can override.
  @HiveField(11)
  String dedupeKey;

  bool get isDismissed => dismissedAt != null;
  bool get isViewed => viewedAt != null;
  bool get isUnread => !isDismissed && !isViewed;
}
