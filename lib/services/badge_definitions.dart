import 'package:flutter/material.dart';

import '../models/badge_category.dart';

/// Static catalog of every milestone badge Mood8 can award. Ordered by
/// category, then by unlock threshold ascending — the order here drives
/// the gallery layout.
class BadgeDefinition {
  const BadgeDefinition({
    required this.key,
    required this.title,
    required this.description,
    required this.threshold,
    required this.category,
    required this.icon,
    required this.gradientStart,
    required this.gradientEnd,
  });

  /// Stable key persisted in the EarnedBadge record. Never rename without
  /// a migration plan — old records pin against this exact string.
  final String key;
  final String title;
  final String description;

  /// Numeric unlock requirement (days for streak/routine, count for habit/
  /// reflection/gratitude). Sourced from [BadgeService] counters.
  final int threshold;
  final BadgeCategory category;
  final IconData icon;
  final Color gradientStart;
  final Color gradientEnd;

  Color get accent => gradientEnd;
}

class BadgeCatalog {
  BadgeCatalog._();

  // ─── Category color palettes (spec) ───────────────────────────────────
  static const Color _streakStart = Color(0xFFFB923C);
  static const Color _streakEnd = Color(0xFFEF4444);
  static const Color _habitStart = Color(0xFFA855F7); // purple
  static const Color _habitEnd = Color(0xFFEC4899); // pink
  static const Color _routineStart = Color(0xFF818CF8);
  static const Color _routineEnd = Color(0xFF6366F1);
  static const Color _identityStart = Color(0xFFF59E0B);
  static const Color _identityEnd = Color(0xFFD97706);
  static const Color _gratitudeStart = Color(0xFFF472B6);
  static const Color _gratitudeEnd = Color(0xFFEC4899);

  static const List<BadgeDefinition> all = [
    // ── Streak ──────────────────────────────────────────────────────────
    BadgeDefinition(
      key: 'streak_1',
      title: 'First Step',
      description: 'You showed up. The streak begins.',
      threshold: 1,
      category: BadgeCategory.streak,
      icon: Icons.local_fire_department_rounded,
      gradientStart: _streakStart,
      gradientEnd: _streakEnd,
    ),
    BadgeDefinition(
      key: 'streak_7',
      title: 'Building Momentum',
      description: 'A full week of consistency.',
      threshold: 7,
      category: BadgeCategory.streak,
      icon: Icons.local_fire_department_rounded,
      gradientStart: _streakStart,
      gradientEnd: _streakEnd,
    ),
    BadgeDefinition(
      key: 'streak_14',
      title: 'Two Weeks Strong',
      description: 'The habit is starting to feel like yours.',
      threshold: 14,
      category: BadgeCategory.streak,
      icon: Icons.local_fire_department_rounded,
      gradientStart: _streakStart,
      gradientEnd: _streakEnd,
    ),
    BadgeDefinition(
      key: 'streak_30',
      title: 'Monthly Master',
      description: 'Thirty days. This is who you are now.',
      threshold: 30,
      category: BadgeCategory.streak,
      icon: Icons.emoji_events_rounded,
      gradientStart: _streakStart,
      gradientEnd: _streakEnd,
    ),
    BadgeDefinition(
      key: 'streak_90',
      title: 'Quarter Champion',
      description: 'A season of showing up.',
      threshold: 90,
      category: BadgeCategory.streak,
      icon: Icons.emoji_events_rounded,
      gradientStart: _streakStart,
      gradientEnd: _streakEnd,
    ),
    BadgeDefinition(
      key: 'streak_365',
      title: 'Year-Long Legend',
      description: 'Three hundred and sixty-five days of becoming.',
      threshold: 365,
      category: BadgeCategory.streak,
      icon: Icons.workspace_premium_rounded,
      gradientStart: _streakStart,
      gradientEnd: _streakEnd,
    ),

    // ── Habit volume ────────────────────────────────────────────────────
    BadgeDefinition(
      key: 'habit_10',
      title: 'Getting Started',
      description: 'Ten habits logged. The compound starts now.',
      threshold: 10,
      category: BadgeCategory.habit,
      icon: Icons.check_circle_outline_rounded,
      gradientStart: _habitStart,
      gradientEnd: _habitEnd,
    ),
    BadgeDefinition(
      key: 'habit_100',
      title: 'Centurion',
      description: 'One hundred completions. Identity in motion.',
      threshold: 100,
      category: BadgeCategory.habit,
      icon: Icons.check_circle_rounded,
      gradientStart: _habitStart,
      gradientEnd: _habitEnd,
    ),
    BadgeDefinition(
      key: 'habit_500',
      title: 'Five Hundred Club',
      description: 'Five hundred small votes for who you are.',
      threshold: 500,
      category: BadgeCategory.habit,
      icon: Icons.workspace_premium_rounded,
      gradientStart: _habitStart,
      gradientEnd: _habitEnd,
    ),
    BadgeDefinition(
      key: 'habit_1000',
      title: 'Thousand Strong',
      description: 'A thousand reps. Mastery shape.',
      threshold: 1000,
      category: BadgeCategory.habit,
      icon: Icons.emoji_events_rounded,
      gradientStart: _habitStart,
      gradientEnd: _habitEnd,
    ),

    // ── Routine ─────────────────────────────────────────────────────────
    BadgeDefinition(
      key: 'routine_1',
      title: 'Routine Rookie',
      description: 'First perfect day. Every routine, complete.',
      threshold: 1,
      category: BadgeCategory.routine,
      icon: Icons.event_available_rounded,
      gradientStart: _routineStart,
      gradientEnd: _routineEnd,
    ),
    BadgeDefinition(
      key: 'routine_7',
      title: 'Consistent',
      description: 'Seven perfect routine days.',
      threshold: 7,
      category: BadgeCategory.routine,
      icon: Icons.event_available_rounded,
      gradientStart: _routineStart,
      gradientEnd: _routineEnd,
    ),
    BadgeDefinition(
      key: 'routine_30',
      title: 'Disciplined',
      description: 'Thirty perfect routine days. Discipline is a craft.',
      threshold: 30,
      category: BadgeCategory.routine,
      icon: Icons.workspace_premium_rounded,
      gradientStart: _routineStart,
      gradientEnd: _routineEnd,
    ),

    // ── Identity / Reflection ───────────────────────────────────────────
    BadgeDefinition(
      key: 'reflection_1',
      title: 'Self-Aware',
      description: 'You paused. You looked in. That counts.',
      threshold: 1,
      category: BadgeCategory.identity,
      icon: Icons.psychology_rounded,
      gradientStart: _identityStart,
      gradientEnd: _identityEnd,
    ),
    BadgeDefinition(
      key: 'reflection_7',
      title: 'Reflective',
      description: 'Seven reflections — patterns are starting to show.',
      threshold: 7,
      category: BadgeCategory.identity,
      icon: Icons.psychology_rounded,
      gradientStart: _identityStart,
      gradientEnd: _identityEnd,
    ),
    BadgeDefinition(
      key: 'reflection_30',
      title: 'Mindful',
      description: 'Thirty reflections. A practice, not a moment.',
      threshold: 30,
      category: BadgeCategory.identity,
      icon: Icons.auto_awesome_rounded,
      gradientStart: _identityStart,
      gradientEnd: _identityEnd,
    ),

    // ── Gratitude ───────────────────────────────────────────────────────
    BadgeDefinition(
      key: 'gratitude_7',
      title: 'Grateful Heart',
      description: 'A week of noticing what mattered.',
      threshold: 7,
      category: BadgeCategory.gratitude,
      icon: Icons.favorite_rounded,
      gradientStart: _gratitudeStart,
      gradientEnd: _gratitudeEnd,
    ),
    BadgeDefinition(
      key: 'gratitude_30',
      title: 'Thankful Soul',
      description: 'Thirty days of small thanks. Rewiring.',
      threshold: 30,
      category: BadgeCategory.gratitude,
      icon: Icons.favorite_rounded,
      gradientStart: _gratitudeStart,
      gradientEnd: _gratitudeEnd,
    ),
  ];

  static int get count => all.length;

  static List<BadgeDefinition> forCategory(BadgeCategory c) =>
      all.where((b) => b.category == c).toList();

  static BadgeDefinition? byKey(String key) {
    for (final b in all) {
      if (b.key == key) return b;
    }
    return null;
  }
}
