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
      };

  static Future<DailyData> gather() async {
    final user = UserRepository().getCurrentUser();
    final moods = MoodRepository();
    final routines = RoutineRepository();
    final intentions = IntentionRepository();

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
    );
  }
}
