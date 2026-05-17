import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../theme/app_theme.dart';

part 'insight_type.g.dart';

@HiveType(typeId: 13)
enum InsightType {
  @HiveField(0)
  habitImpact,
  @HiveField(1)
  warning,
  @HiveField(2)
  timePattern,
  @HiveField(3)
  streakPattern,
  @HiveField(4)
  identityDriver,
  @HiveField(5)
  milestone,
  @HiveField(6)
  rhythm,
  @HiveField(7)
  discovery;

  String get badge {
    switch (this) {
      case InsightType.habitImpact:
        return 'Pattern';
      case InsightType.warning:
        return 'Warning';
      case InsightType.timePattern:
        return 'Time';
      case InsightType.streakPattern:
        return 'Streak';
      case InsightType.identityDriver:
        return 'Identity';
      case InsightType.milestone:
        return 'Milestone';
      case InsightType.rhythm:
        return 'Rhythm';
      case InsightType.discovery:
        return 'Discovery';
    }
  }

  String get emoji {
    switch (this) {
      case InsightType.habitImpact:
        return '💡';
      case InsightType.warning:
        return '⚠️';
      case InsightType.timePattern:
        return '🌅';
      case InsightType.streakPattern:
        return '🔥';
      case InsightType.identityDriver:
        return '🪞';
      case InsightType.milestone:
        return '🏆';
      case InsightType.rhythm:
        return '🎵';
      case InsightType.discovery:
        return '✨';
    }
  }

  IconData get icon {
    switch (this) {
      case InsightType.habitImpact:
        return Icons.lightbulb_outline_rounded;
      case InsightType.warning:
        return Icons.error_outline_rounded;
      case InsightType.timePattern:
        return Icons.wb_twilight_rounded;
      case InsightType.streakPattern:
        return Icons.local_fire_department_rounded;
      case InsightType.identityDriver:
        return Icons.psychology_alt_rounded;
      case InsightType.milestone:
        return Icons.emoji_events_rounded;
      case InsightType.rhythm:
        return Icons.graphic_eq_rounded;
      case InsightType.discovery:
        return Icons.auto_awesome_rounded;
    }
  }

  Color get color {
    switch (this) {
      case InsightType.habitImpact:
        return AppColors.purpleLight;
      case InsightType.warning:
        return const Color(0xFFFF6B81);
      case InsightType.timePattern:
        return AppColors.blueAccent;
      case InsightType.streakPattern:
        return AppColors.pinkLight;
      case InsightType.identityDriver:
        return AppColors.purple;
      case InsightType.milestone:
        return AppColors.pink;
      case InsightType.rhythm:
        return AppColors.blueAccent;
      case InsightType.discovery:
        return AppColors.purpleLight;
    }
  }
}
