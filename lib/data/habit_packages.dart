import 'package:flutter/material.dart';

import '../models/frequency.dart';
import '../models/habit_polarity.dart';
import '../models/habit_type.dart';
import '../models/routine_category.dart';
import '../theme/app_theme.dart';

/// One habit inside a [HabitPackage]. Mirrors the user-facing fields a
/// regular `Habit` exposes, plus the polarity/avoid extras for the
/// quit/reduce packages. Materialised into real `Habit` rows when the
/// user starts the package — at which point each gets a packageId
/// stamp so the Habits screen can filter by program.
class HabitPackageItem {
  const HabitPackageItem({
    required this.title,
    required this.icon,
    required this.habitType,
    required this.frequency,
    required this.identity,
    required this.category,
    this.targetValue,
    this.targetUnit,
    this.polarity = HabitPolarity.build,
    this.avoidMode,
    this.avoidDurationDays,
  });

  final String title;
  final String icon;
  final HabitType habitType;
  final Frequency frequency;
  final String identity;
  final RoutineCategory category;
  final int? targetValue;
  final String? targetUnit;
  final HabitPolarity polarity;
  final AvoidMode? avoidMode;
  final int? avoidDurationDays;
}

/// One curated habit package — a guided 7-to-60-day program shipped
/// as Premium Plus content. Definitions live here in code (not on the
/// server) so a package is the same on every device, every install.
/// When a user starts a package, [items] is materialised into real
/// Habit rows tagged with this package's [id].
class HabitPackage {
  const HabitPackage({
    required this.id,
    required this.name,
    required this.emoji,
    required this.tagline,
    required this.goal,
    required this.durationDays,
    required this.accent,
    required this.items,
  });

  final String id;
  final String name;
  final String emoji;
  /// One-line pitch shown on the browse grid.
  final String tagline;
  /// Longer description on the detail screen.
  final String goal;
  final int durationDays;
  /// Brand accent used to tint the fancy package tab + detail screen.
  final Color accent;
  final List<HabitPackageItem> items;

  int get habitCount => items.length;
}

/// The 10 curated Mood8 packages. Order here is the order they appear
/// on the browse grid. Adding / reordering items here is the entire
/// authoring workflow — no migration, no backend round-trip.
const List<HabitPackage> kHabitPackages = [
  // 1 — Morning Calm
  HabitPackage(
    id: 'pkg.morning_calm',
    name: 'Morning Calm',
    emoji: '🌅',
    tagline: 'Start every morning grounded.',
    goal: 'A 14-day reset that anchors your morning around five small,'
        ' quiet rituals — hydration, breath, movement, intention, and'
        ' a phone-free start.',
    durationDays: 14,
    accent: AppColors.pinkLight,
    items: [
      HabitPackageItem(
        title: 'Morning hydration',
        icon: '💧',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Morning Calm',
        category: RoutineCategory.health,
      ),
      HabitPackageItem(
        title: '2-minute breath',
        icon: '🌬️',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Morning Calm',
        category: RoutineCategory.mindful,
      ),
      HabitPackageItem(
        title: 'Stretch for 5 min',
        icon: '🧘',
        habitType: HabitType.duration,
        frequency: Frequency.daily,
        identity: 'Morning Calm',
        category: RoutineCategory.health,
        targetValue: 5,
        targetUnit: 'minutes',
      ),
      HabitPackageItem(
        title: 'Set today’s intention',
        icon: '✨',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Morning Calm',
        category: RoutineCategory.mindful,
      ),
      HabitPackageItem(
        title: 'Phone-free first 30 min',
        icon: '📵',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Morning Calm',
        category: RoutineCategory.mindful,
      ),
    ],
  ),
  // 2 — Athlete Start
  HabitPackage(
    id: 'pkg.athlete_start',
    name: 'Athlete Start',
    emoji: '💪',
    tagline: 'Build a daily-movement identity.',
    goal: 'Thirty days of foundational training — daily movement, hydration,'
        ' mobility, three weekly strength sessions, and protected sleep.',
    durationDays: 30,
    accent: AppColors.purple,
    items: [
      HabitPackageItem(
        title: 'Move for 30 minutes',
        icon: '🏃',
        habitType: HabitType.duration,
        frequency: Frequency.daily,
        identity: 'Athlete',
        category: RoutineCategory.health,
        targetValue: 30,
        targetUnit: 'minutes',
      ),
      HabitPackageItem(
        title: 'Drink 8 cups of water',
        icon: '💧',
        habitType: HabitType.counter,
        frequency: Frequency.daily,
        identity: 'Athlete',
        category: RoutineCategory.health,
        targetValue: 8,
        targetUnit: 'cups',
      ),
      HabitPackageItem(
        title: 'Stretch / mobility',
        icon: '🤸',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Athlete',
        category: RoutineCategory.health,
      ),
      HabitPackageItem(
        title: 'Strength session',
        icon: '🏋️',
        habitType: HabitType.counter,
        frequency: Frequency.xPerWeek,
        identity: 'Athlete',
        category: RoutineCategory.health,
        targetValue: 3,
        targetUnit: 'sessions',
      ),
      HabitPackageItem(
        title: 'Lights out by 11pm',
        icon: '🌙',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Athlete',
        category: RoutineCategory.rest,
      ),
    ],
  ),
  // 3 — Deep Learning
  HabitPackage(
    id: 'pkg.deep_learning',
    name: 'Deep Learning',
    emoji: '📚',
    tagline: 'A daily reading + focus practice.',
    goal: 'Thirty days of becoming someone who reads, focuses deeply, and'
        ' reflects on what they’ve learned — anchored by one big focus'
        ' block and a weekly review.',
    durationDays: 30,
    accent: AppColors.blueAccent,
    items: [
      HabitPackageItem(
        title: 'Read for 30 minutes',
        icon: '📖',
        habitType: HabitType.duration,
        frequency: Frequency.daily,
        identity: 'Learner',
        category: RoutineCategory.creative,
        targetValue: 30,
        targetUnit: 'minutes',
      ),
      HabitPackageItem(
        title: 'Deep focus block',
        icon: '🎯',
        habitType: HabitType.duration,
        frequency: Frequency.daily,
        identity: 'Learner',
        category: RoutineCategory.work,
        targetValue: 60,
        targetUnit: 'minutes',
      ),
      HabitPackageItem(
        title: 'Capture one lesson',
        icon: '✍️',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Learner',
        category: RoutineCategory.creative,
      ),
      HabitPackageItem(
        title: 'Review the week’s notes',
        icon: '🗂️',
        habitType: HabitType.yesNo,
        frequency: Frequency.xPerWeek,
        identity: 'Learner',
        category: RoutineCategory.creative,
        targetValue: 1,
      ),
    ],
  ),
  // 4 — Sleep Reset
  HabitPackage(
    id: 'pkg.sleep_reset',
    name: 'Sleep Reset',
    emoji: '🌙',
    tagline: 'Rebuild your sleep window.',
    goal: 'Twenty-one days to walk your bedtime back to 11pm with a'
        ' protected wind-down: no screens an hour before bed, no'
        ' caffeine after 2pm, and a steady wake time.',
    durationDays: 21,
    accent: AppColors.purpleLight,
    items: [
      HabitPackageItem(
        title: 'No screens 60 min before bed',
        icon: '📵',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Sleeper',
        category: RoutineCategory.rest,
      ),
      HabitPackageItem(
        title: 'In bed by 11pm',
        icon: '🛏️',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Sleeper',
        category: RoutineCategory.rest,
      ),
      HabitPackageItem(
        title: 'Wake at 7am',
        icon: '☀️',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Sleeper',
        category: RoutineCategory.rest,
      ),
      HabitPackageItem(
        title: 'No caffeine after 2pm',
        icon: '☕',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Sleeper',
        category: RoutineCategory.rest,
      ),
      HabitPackageItem(
        title: 'Wind-down ritual',
        icon: '🕯️',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Sleeper',
        category: RoutineCategory.rest,
      ),
    ],
  ),
  // 5 — Caffeine Cut (reduce)
  HabitPackage(
    id: 'pkg.caffeine_cut',
    name: 'Caffeine Cut',
    emoji: '☕',
    tagline: 'Gently reduce daily caffeine.',
    goal: 'Thirty days of tracking your caffeine intake daily and watching'
        ' it drift down. No shame — just data, plus hydration and a soft'
        ' afternoon cutoff to make the drop feel easy.',
    durationDays: 30,
    accent: AppColors.pinkLight,
    items: [
      HabitPackageItem(
        title: 'Caffeine count',
        icon: '☕',
        habitType: HabitType.counter,
        frequency: Frequency.daily,
        identity: 'Caffeine Cut',
        category: RoutineCategory.health,
        polarity: HabitPolarity.avoid,
        avoidMode: AvoidMode.reduce,
        avoidDurationDays: 30,
      ),
      HabitPackageItem(
        title: 'Drink 8 cups of water',
        icon: '💧',
        habitType: HabitType.counter,
        frequency: Frequency.daily,
        identity: 'Caffeine Cut',
        category: RoutineCategory.health,
        targetValue: 8,
        targetUnit: 'cups',
      ),
      HabitPackageItem(
        title: 'No caffeine after 12pm',
        icon: '🚫',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Caffeine Cut',
        category: RoutineCategory.health,
      ),
    ],
  ),
  // 6 — Quit Smoking (quit)
  HabitPackage(
    id: 'pkg.quit_smoking',
    name: 'Quit Smoking',
    emoji: '🚭',
    tagline: 'One clean day at a time.',
    goal: 'Sixty days of staying smoke-free, with a daily reset breathwork'
        ' practice for cravings, hydration to flush, and gentle movement.'
        ' Slips reset the streak but never the program — kindness first.',
    durationDays: 60,
    accent: AppColors.pink,
    items: [
      HabitPackageItem(
        title: 'Stayed smoke-free today',
        icon: '🚭',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Quit Smoking',
        category: RoutineCategory.health,
        polarity: HabitPolarity.avoid,
        avoidMode: AvoidMode.quit,
      ),
      HabitPackageItem(
        title: '5-min breathwork on craving',
        icon: '🌬️',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Quit Smoking',
        category: RoutineCategory.mindful,
      ),
      HabitPackageItem(
        title: 'Drink 8 cups of water',
        icon: '💧',
        habitType: HabitType.counter,
        frequency: Frequency.daily,
        identity: 'Quit Smoking',
        category: RoutineCategory.health,
        targetValue: 8,
        targetUnit: 'cups',
      ),
      HabitPackageItem(
        title: 'Walk 20 minutes',
        icon: '🚶',
        habitType: HabitType.duration,
        frequency: Frequency.daily,
        identity: 'Quit Smoking',
        category: RoutineCategory.health,
        targetValue: 20,
        targetUnit: 'minutes',
      ),
    ],
  ),
  // 7 — Digital Detox
  HabitPackage(
    id: 'pkg.digital_detox',
    name: 'Digital Detox',
    emoji: '📱',
    tagline: 'Reclaim attention from your phone.',
    goal: 'Two weeks of pulling your attention back — under three hours of'
        ' screen time, no phone in bed, and a phone-free first thirty'
        ' minutes of the day.',
    durationDays: 14,
    accent: AppColors.blueAccent,
    items: [
      HabitPackageItem(
        title: 'Screen time under 3h',
        icon: '⏳',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Digital Detox',
        category: RoutineCategory.mindful,
      ),
      HabitPackageItem(
        title: 'No phone in bed',
        icon: '🛏️',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Digital Detox',
        category: RoutineCategory.rest,
      ),
      HabitPackageItem(
        title: 'Phone-free first 30 min',
        icon: '🌅',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Digital Detox',
        category: RoutineCategory.mindful,
      ),
      HabitPackageItem(
        title: 'Scroll count',
        icon: '📲',
        habitType: HabitType.counter,
        frequency: Frequency.daily,
        identity: 'Digital Detox',
        category: RoutineCategory.mindful,
        polarity: HabitPolarity.avoid,
        avoidMode: AvoidMode.reduce,
        avoidDurationDays: 14,
      ),
    ],
  ),
  // 8 — Self-Compassion
  HabitPackage(
    id: 'pkg.self_compassion',
    name: 'Self-Compassion',
    emoji: '❤️',
    tagline: 'Soften how you speak to yourself.',
    goal: 'Twenty-one days of practising a kinder inner voice — one'
        ' gratitude, one affirmation, one walk outside, one noticing of'
        ' negative self-talk.',
    durationDays: 21,
    accent: AppColors.pinkLight,
    items: [
      HabitPackageItem(
        title: 'Three gratitudes',
        icon: '🙏',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Self-Compassion',
        category: RoutineCategory.mindful,
      ),
      HabitPackageItem(
        title: 'One kind affirmation',
        icon: '💗',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Self-Compassion',
        category: RoutineCategory.mindful,
      ),
      HabitPackageItem(
        title: 'Notice negative self-talk',
        icon: '👀',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Self-Compassion',
        category: RoutineCategory.mindful,
      ),
      HabitPackageItem(
        title: 'Walk outside 15 min',
        icon: '🚶',
        habitType: HabitType.duration,
        frequency: Frequency.daily,
        identity: 'Self-Compassion',
        category: RoutineCategory.health,
        targetValue: 15,
        targetUnit: 'minutes',
      ),
    ],
  ),
  // 9 — Creative Spark
  HabitPackage(
    id: 'pkg.creative_spark',
    name: 'Creative Spark',
    emoji: '✨',
    tagline: 'Show up to your craft every day.',
    goal: 'Thirty days of practising your craft daily, capturing ideas'
        ' as they appear, and shipping one piece a week — even if rough.',
    durationDays: 30,
    accent: AppColors.purple,
    items: [
      HabitPackageItem(
        title: 'Create for 30 minutes',
        icon: '🎨',
        habitType: HabitType.duration,
        frequency: Frequency.daily,
        identity: 'Creator',
        category: RoutineCategory.creative,
        targetValue: 30,
        targetUnit: 'minutes',
      ),
      HabitPackageItem(
        title: 'Capture one idea',
        icon: '💡',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Creator',
        category: RoutineCategory.creative,
      ),
      HabitPackageItem(
        title: 'Sketch or brainstorm',
        icon: '✏️',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Creator',
        category: RoutineCategory.creative,
      ),
      HabitPackageItem(
        title: 'Ship one piece',
        icon: '🚀',
        habitType: HabitType.yesNo,
        frequency: Frequency.xPerWeek,
        identity: 'Creator',
        category: RoutineCategory.creative,
        targetValue: 1,
      ),
    ],
  ),
  // 10 — Reset Week
  HabitPackage(
    id: 'pkg.reset_week',
    name: 'Reset Week',
    emoji: '🌿',
    tagline: 'A short, full-body, full-mind reset.',
    goal: 'Seven days, six gentle anchors — hydration, movement, sleep,'
        ' gratitude, no alcohol, a phone-free evening. Perfect after'
        ' a heavy stretch, before a new chapter, or just because.',
    durationDays: 7,
    accent: AppColors.blueAccent,
    items: [
      HabitPackageItem(
        title: 'Morning hydration',
        icon: '💧',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Reset Week',
        category: RoutineCategory.health,
      ),
      HabitPackageItem(
        title: 'Move 20 minutes',
        icon: '🚶',
        habitType: HabitType.duration,
        frequency: Frequency.daily,
        identity: 'Reset Week',
        category: RoutineCategory.health,
        targetValue: 20,
        targetUnit: 'minutes',
      ),
      HabitPackageItem(
        title: 'No alcohol',
        icon: '🚫',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Reset Week',
        category: RoutineCategory.health,
        polarity: HabitPolarity.avoid,
        avoidMode: AvoidMode.quit,
      ),
      HabitPackageItem(
        title: '8h sleep window',
        icon: '🌙',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Reset Week',
        category: RoutineCategory.rest,
      ),
      HabitPackageItem(
        title: 'Three gratitudes',
        icon: '🙏',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Reset Week',
        category: RoutineCategory.mindful,
      ),
      HabitPackageItem(
        title: 'Phone-free evening',
        icon: '📵',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Reset Week',
        category: RoutineCategory.mindful,
      ),
    ],
  ),
];

HabitPackage? habitPackageById(String? id) {
  if (id == null) return null;
  for (final p in kHabitPackages) {
    if (p.id == id) return p;
  }
  return null;
}
