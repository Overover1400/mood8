import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../theme/app_theme.dart';

part 'focus_area.g.dart';

@HiveType(typeId: 4)
enum FocusArea {
  @HiveField(0)
  work,
  @HiveField(1)
  health,
  @HiveField(2)
  creativity,
  @HiveField(3)
  mindfulness,
  @HiveField(4)
  relationships,
  @HiveField(5)
  learning;

  String get label {
    switch (this) {
      case FocusArea.work:
        return 'Work';
      case FocusArea.health:
        return 'Health';
      case FocusArea.creativity:
        return 'Creativity';
      case FocusArea.mindfulness:
        return 'Mindfulness';
      case FocusArea.relationships:
        return 'Relationships';
      case FocusArea.learning:
        return 'Learning';
    }
  }

  String get emoji {
    switch (this) {
      case FocusArea.work:
        return '💼';
      case FocusArea.health:
        return '💪';
      case FocusArea.creativity:
        return '🎨';
      case FocusArea.mindfulness:
        return '🧘';
      case FocusArea.relationships:
        return '❤️';
      case FocusArea.learning:
        return '📚';
    }
  }

  IconData get icon {
    switch (this) {
      case FocusArea.work:
        return Icons.work_outline_rounded;
      case FocusArea.health:
        return Icons.favorite_outline_rounded;
      case FocusArea.creativity:
        return Icons.brush_outlined;
      case FocusArea.mindfulness:
        return Icons.self_improvement_rounded;
      case FocusArea.relationships:
        return Icons.people_alt_outlined;
      case FocusArea.learning:
        return Icons.menu_book_rounded;
    }
  }

  Color get color {
    switch (this) {
      case FocusArea.work:
        return AppColors.purple;
      case FocusArea.health:
        return AppColors.pink;
      case FocusArea.creativity:
        return AppColors.purpleLight;
      case FocusArea.mindfulness:
        return AppColors.blueAccent;
      case FocusArea.relationships:
        return AppColors.pinkLight;
      case FocusArea.learning:
        return const Color(0xFFD946EF);
    }
  }

  String get description {
    switch (this) {
      case FocusArea.work:
        return 'Build, ship, do meaningful work';
      case FocusArea.health:
        return 'Move, sleep, eat well';
      case FocusArea.creativity:
        return 'Make things, explore ideas';
      case FocusArea.mindfulness:
        return 'Stay present, slow down';
      case FocusArea.relationships:
        return 'Connect deeply with people';
      case FocusArea.learning:
        return 'Read, study, get curious';
    }
  }

  List<String> get suggestedRoutines {
    switch (this) {
      case FocusArea.work:
        return const ['Deep work block', 'Inbox triage', 'Plan tomorrow'];
      case FocusArea.health:
        return const ['Workout', 'Walk & sunlight', 'Hydrate check'];
      case FocusArea.creativity:
        return const ['Creative session', 'Sketch / notes'];
      case FocusArea.mindfulness:
        return const ['Meditation', 'Breath reset'];
      case FocusArea.relationships:
        return const ['Reach out', 'Connect call'];
      case FocusArea.learning:
        return const ['Reading block', 'Study sprint'];
    }
  }
}
