import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AdaptiveActionType { addRoutine, addHabit, moveRoutine, simplify, challenge }

class AdaptiveSuggestion {
  const AdaptiveSuggestion({
    required this.id,
    required this.title,
    required this.reason,
    required this.actionType,
    required this.confidence,
    this.targetRoutineId,
    this.targetHabitId,
    this.newHour,
    this.newMinute,
  });

  final String id;
  final String title;
  final String reason;
  final AdaptiveActionType actionType;
  final double confidence;
  final String? targetRoutineId;
  final String? targetHabitId;
  final int? newHour;
  final int? newMinute;

  IconData get icon {
    switch (actionType) {
      case AdaptiveActionType.addRoutine:
      case AdaptiveActionType.addHabit:
        return Icons.add_circle_outline_rounded;
      case AdaptiveActionType.moveRoutine:
        return Icons.swap_vert_rounded;
      case AdaptiveActionType.simplify:
        return Icons.compress_rounded;
      case AdaptiveActionType.challenge:
        return Icons.local_fire_department_rounded;
    }
  }

  Color get tone {
    switch (actionType) {
      case AdaptiveActionType.addRoutine:
      case AdaptiveActionType.addHabit:
        return AppColors.purpleLight;
      case AdaptiveActionType.moveRoutine:
        return AppColors.blueAccent;
      case AdaptiveActionType.simplify:
        return AppColors.pinkLight;
      case AdaptiveActionType.challenge:
        return AppColors.pink;
    }
  }

  String get badge {
    // "Challenge" now refers to the dedicated Challenges feature, so
    // the AI recommendation card on Home uses the broader label
    // "Suggestion" to avoid confusion.
    switch (actionType) {
      case AdaptiveActionType.addRoutine:
      case AdaptiveActionType.addHabit:
        return 'Suggestion';
      case AdaptiveActionType.moveRoutine:
        return 'Suggestion';
      case AdaptiveActionType.simplify:
        return 'Suggestion';
      case AdaptiveActionType.challenge:
        return 'Suggestion';
    }
  }
}
