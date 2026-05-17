import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../theme/app_theme.dart';

part 'routine_category.g.dart';

@HiveType(typeId: 2)
enum RoutineCategory {
  @HiveField(0)
  work,
  @HiveField(1)
  health,
  @HiveField(2)
  mindful,
  @HiveField(3)
  creative,
  @HiveField(4)
  rest;

  String get label {
    switch (this) {
      case RoutineCategory.work:
        return 'Work';
      case RoutineCategory.health:
        return 'Health';
      case RoutineCategory.mindful:
        return 'Mindful';
      case RoutineCategory.creative:
        return 'Creative';
      case RoutineCategory.rest:
        return 'Rest';
    }
  }

  Color get color {
    switch (this) {
      case RoutineCategory.work:
        return AppColors.purple;
      case RoutineCategory.health:
        return AppColors.pink;
      case RoutineCategory.mindful:
        return AppColors.blueAccent;
      case RoutineCategory.creative:
        return AppColors.purpleLight;
      case RoutineCategory.rest:
        return AppColors.pinkLight;
    }
  }

  IconData get icon {
    switch (this) {
      case RoutineCategory.work:
        return Icons.psychology_alt_rounded;
      case RoutineCategory.health:
        return Icons.directions_walk_rounded;
      case RoutineCategory.mindful:
        return Icons.self_improvement_rounded;
      case RoutineCategory.creative:
        return Icons.brush_rounded;
      case RoutineCategory.rest:
        return Icons.nightlight_round;
    }
  }
}
