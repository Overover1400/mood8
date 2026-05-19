import 'habit.dart';
import 'habit_log.dart';

class DataPoint {
  const DataPoint({
    required this.date,
    required this.mood,
    required this.energy,
    required this.focus,
  });

  final DateTime date;
  final double? mood;
  final double? energy;
  final double? focus;

  bool get hasData => mood != null || energy != null || focus != null;
}

class HeatmapDay {
  const HeatmapDay({
    required this.date,
    required this.completionScore,
    required this.hasData,
    this.isFrozen = false,
  });

  final DateTime date;
  final double completionScore;
  final bool hasData;
  final bool isFrozen;
}

class HabitStats {
  const HabitStats({
    required this.habit,
    required this.completionRate,
    required this.streak,
    required this.last30Days,
  });

  final Habit habit;
  final double completionRate;
  final int streak;
  final List<HabitLog> last30Days;
}

enum TimeOfDayBlock {
  morning,
  afternoon,
  evening,
  night;

  String get label {
    switch (this) {
      case TimeOfDayBlock.morning:
        return 'Morning';
      case TimeOfDayBlock.afternoon:
        return 'Afternoon';
      case TimeOfDayBlock.evening:
        return 'Evening';
      case TimeOfDayBlock.night:
        return 'Night';
    }
  }

  String get hourRange {
    switch (this) {
      case TimeOfDayBlock.morning:
        return '5–11';
      case TimeOfDayBlock.afternoon:
        return '12–17';
      case TimeOfDayBlock.evening:
        return '18–23';
      case TimeOfDayBlock.night:
        return '0–4';
    }
  }

  static TimeOfDayBlock forHour(int hour) {
    if (hour >= 5 && hour <= 11) return TimeOfDayBlock.morning;
    if (hour >= 12 && hour <= 17) return TimeOfDayBlock.afternoon;
    if (hour >= 18 && hour <= 23) return TimeOfDayBlock.evening;
    return TimeOfDayBlock.night;
  }
}

class Highlights {
  const Highlights({
    this.bestDay,
    this.bestWeek,
    this.topHabit,
    this.longestStreak,
    this.improvedMost,
    this.bestTime,
  });

  final HighlightItem? bestDay;
  final HighlightItem? bestWeek;
  final HighlightItem? topHabit;
  final HighlightItem? longestStreak;
  final HighlightItem? improvedMost;
  final HighlightItem? bestTime;

  List<HighlightItem> get nonNull => <HighlightItem>[
        if (bestDay != null) bestDay as HighlightItem,
        if (bestWeek != null) bestWeek as HighlightItem,
        if (topHabit != null) topHabit as HighlightItem,
        if (longestStreak != null) longestStreak as HighlightItem,
        if (improvedMost != null) improvedMost as HighlightItem,
        if (bestTime != null) bestTime as HighlightItem,
      ];
}

class HighlightItem {
  const HighlightItem({
    required this.emoji,
    required this.label,
    required this.value,
    this.subtitle,
  });

  final String emoji;
  final String label;
  final String value;
  final String? subtitle;
}

class Comparison {
  const Comparison({
    required this.metric,
    required this.current,
    required this.previous,
    required this.unit,
  });

  final String metric;
  final double current;
  final double previous;
  final String unit;

  double get change => current - previous;
  double get changePercent {
    if (previous == 0) return current == 0 ? 0 : 1.0;
    return (current - previous) / previous;
  }

  bool get isUp => change > 0;
  bool get isDown => change < 0;
}
