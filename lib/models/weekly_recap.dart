import 'package:hive/hive.dart';

part 'weekly_recap.g.dart';

/// AI-generated weekly recap. Authored by the backend, mirrored locally so
/// the in-app view doesn't require a network round trip after the first
/// generation. `weekly_recaps` box, keyed by `id`.
@HiveType(typeId: 20)
class WeeklyRecap extends HiveObject {
  WeeklyRecap({
    required this.id,
    required this.weekStart,
    required this.weekEnd,
    required this.narrative,
    required List<String>? patterns,
    required this.lookingAhead,
    required this.moodSummary,
    required List<String>? gratitudeThemes,
    required Map<String, dynamic>? stats,
    required this.generatedAt,
    this.emailSent = false,
  })  : patterns = List<String>.from(patterns ?? const <String>[]),
        gratitudeThemes =
            List<String>.from(gratitudeThemes ?? const <String>[]),
        stats = Map<String, dynamic>.from(stats ?? const <String, dynamic>{});

  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime weekStart;

  @HiveField(2)
  DateTime weekEnd;

  @HiveField(3)
  String narrative;

  @HiveField(4)
  List<String> patterns;

  @HiveField(5)
  String lookingAhead;

  /// One-line headline for the mood stat block, e.g. "Avg mood 7.2 / 10".
  @HiveField(6)
  String moodSummary;

  @HiveField(7)
  List<String> gratitudeThemes;

  /// `mood_entries`, `habits`, `routines`, `discipline`, `streak`, ...
  /// Loose shape on purpose so we can evolve without a migration.
  @HiveField(8)
  Map<String, dynamic> stats;

  @HiveField(9)
  DateTime generatedAt;

  @HiveField(10)
  bool emailSent;

  int statInt(String key) => (stats[key] as num?)?.toInt() ?? 0;
}
