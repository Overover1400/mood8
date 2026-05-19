import '../services/gratitude_repository.dart';
import '../services/intention_repository.dart';
import '../services/mood_repository.dart';
import '../services/routine_repository.dart';
import '../services/user_repository.dart';

class DailyData {
  DailyData({
    required this.name,
    required this.identities,
    required this.mood,
    required this.energy,
    required this.focus,
    required this.routinesCompleted,
    required this.routinesTotal,
    required this.routineNames,
    required this.skippedRoutines,
    required this.streak,
    required this.hasCheckin,
    this.morningIntention,
    this.recentGratitude = const <String>[],
  });

  final String name;
  final List<String> identities;
  final double mood;
  final double energy;
  final double focus;
  final int routinesCompleted;
  final int routinesTotal;
  final List<String> routineNames;
  final List<String> skippedRoutines;
  final int streak;
  final bool hasCheckin;

  /// The user's typed morning intention for today (null if not set or
  /// explicitly skipped). The backend uses this to enrich nightly reflections
  /// with a "User's morning intention today was: …" line of context.
  final String? morningIntention;

  /// Flattened list of recent gratitude items (last few days, max ~9).
  /// Empty when the user hasn't logged any.
  final List<String> recentGratitude;

  Map<String, dynamic> toJson() => {
        'name': name,
        'identities': identities,
        'mood': mood,
        'energy': energy,
        'focus': focus,
        'routines_completed': routinesCompleted,
        'routines_total': routinesTotal,
        'routine_names': routineNames,
        'skipped_routines': skippedRoutines,
        'streak': streak,
        'has_checkin': hasCheckin,
        if (morningIntention != null && morningIntention!.isNotEmpty)
          'morning_intention': morningIntention,
        if (recentGratitude.isNotEmpty) 'recent_gratitude': recentGratitude,
      };

  static Future<DailyData> gather() async {
    final user = UserRepository().getCurrentUser();
    final moods = MoodRepository();
    final routines = RoutineRepository();
    final intentions = IntentionRepository();
    final gratitude = GratitudeRepository();

    final today = moods.getTodayEntry();
    final todayRoutines = routines.getRoutinesForDate(DateTime.now());
    final completed =
        todayRoutines.where((r) => r.isCompleted).toList(growable: false);
    final skipped =
        todayRoutines.where((r) => !r.isCompleted).toList(growable: false);
    final intention = intentions.getTodaysIntention();
    final intentionText =
        intention != null && !intention.wasSkipped && intention.text.trim().isNotEmpty
            ? intention.text.trim()
            : null;

    // Flatten gratitude items from the last 3 days, freshest first, deduped.
    final recentEntries = await gratitude.getRecent(3);
    final recentGratitude = <String>[];
    for (final e in recentEntries) {
      for (final item in e.nonEmptyItems) {
        if (recentGratitude.length >= 9) break;
        if (!recentGratitude.contains(item)) {
          recentGratitude.add(item);
        }
      }
    }

    return DailyData(
      name: user?.name ?? 'friend',
      identities: List<String>.from(user?.identities ?? const <String>[]),
      mood: today?.mood ?? 5.0,
      energy: today?.energy ?? 5.0,
      focus: today?.focus ?? 5.0,
      routinesCompleted: completed.length,
      routinesTotal: todayRoutines.length,
      routineNames: completed.map((r) => r.title).toList(),
      skippedRoutines: skipped.map((r) => r.title).toList(),
      streak: moods.calculateStreak(),
      hasCheckin: today != null,
      morningIntention: intentionText,
      recentGratitude: recentGratitude,
    );
  }
}
