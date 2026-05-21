/// Aggregated stats for one calendar year, used by the Year in Review
/// story experience. All numbers are computed on-demand by
/// [YearInReviewService.generateForYear] from the Hive repositories —
/// nothing is persisted. The service does cache the latest result in
/// memory so reopening the screen during a session is instant.
class YearInReviewData {
  const YearInReviewData({
    required this.year,
    required this.userName,
    required this.windowStart,
    required this.windowEnd,
    required this.daysActive,
    required this.totalCheckIns,
    required this.totalReflections,
    required this.totalGratitudes,
    required this.totalHabitsCompleted,
    required this.totalRoutinesCompleted,
    required this.perfectRoutineDays,
    required this.longestStreakDays,
    required this.longestStreakHabit,
    required this.avgMood,
    required this.highestMoodDay,
    required this.moodByMonth,
    required this.bestMonth,
    required this.bestMonthScore,
    required this.badgesEarned,
    required this.identities,
    required this.theme,
    required this.themeDescription,
  });

  /// Calendar year being recapped (e.g. 2026).
  final int year;
  final String userName;
  /// Inclusive — first day of the user's recap window. Equals
  /// `DateTime(year, 1, 1)` unless the user joined mid-year, in which
  /// case it's their `UserProfile.createdAt`.
  final DateTime windowStart;
  final DateTime windowEnd;

  final int daysActive;
  final int totalCheckIns;
  final int totalReflections;
  final int totalGratitudes;
  final int totalHabitsCompleted;
  final int totalRoutinesCompleted;
  final int perfectRoutineDays;
  final int longestStreakDays;
  final String? longestStreakHabit;
  final double? avgMood;
  final DateTime? highestMoodDay;
  /// Map of month (1–12) → average mood for that month. Months with no
  /// mood entries are omitted.
  final Map<int, double> moodByMonth;
  /// Month (1–12) of the user's most productive period — the month with
  /// the highest average discipline score in the recap window.
  final int? bestMonth;
  final int bestMonthScore;
  final int badgesEarned;
  final List<String> identities;
  /// Personality label ("The Consistent Builder", etc.) derived from
  /// the user's dominant signals across the year. See
  /// [YearInReviewService._pickTheme] for the picking logic.
  final String theme;
  final String themeDescription;

  /// True when the user has too little data for a meaningful recap.
  /// The story screen shows a graceful "come back soon" state instead.
  bool get hasMinimumData =>
      daysActive >= 7 || totalCheckIns >= 5;

  String get monthName {
    if (bestMonth == null) return '—';
    return const [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ][bestMonth! - 1];
  }
}
