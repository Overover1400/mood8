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
    required this.why,
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

  /// Spec 1.3.3 — one or two sentences explaining what this habit is and
  /// why it earns its place in the package. Users were accepting a bundle
  /// of habits they didn't understand, and an unexplained habit is the
  /// first one dropped. Shown inline under the habit on the detail screen.
  final String why;

  final int? targetValue;
  final String? targetUnit;
  final HabitPolarity polarity;
  final AvoidMode? avoidMode;
  final int? avoidDurationDays;
}

/// One curated habit package — a guided 7-to-60-day program shipped
/// as Premium content. Definitions live here in code (not on the
/// server) so a package is the same on every device, every install.
/// When a user starts a package, [items] is materialised into real
/// Habit rows tagged with this package's [id].
class HabitPackage {
  const HabitPackage({
    required this.id,
    required this.name,
    required this.shortName,
    required this.emoji,
    required this.tagline,
    required this.goal,
    required this.durationDays,
    required this.accent,
    required this.items,
  });

  final String id;

  /// Spec 1.3.1 — the package name is written as a sentence the *user*
  /// says about themselves ("I'm becoming an athlete"), not as a product
  /// category label ("Athlete Start"). Identity framing is the whole
  /// point: people keep habits that match who they think they are.
  final String name;

  /// Short label for places a full sentence won't fit — the start button,
  /// the running pill, the habits-screen program filter.
  final String shortName;

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
    name: 'I’m becoming a morning person',
    shortName: 'Morning Calm',
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
        why: 'A glass of water before anything else. It’s the easiest win'
            ' of the day, and starting with one you can’t fail makes the'
            ' next four feel lighter.',
      ),
      HabitPackageItem(
        title: '2-minute breath',
        icon: '🌬️',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Morning Calm',
        category: RoutineCategory.mindful,
        why: 'Two minutes of slow breathing before the day starts pulling'
            ' at you. It sets the pace you want the morning to run at.',
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
        why: 'Five minutes of movement to wake your body up before your'
            ' inbox does. Calm mornings are physical, not only mental.',
      ),
      HabitPackageItem(
        title: 'Set today’s intention',
        icon: '✨',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Morning Calm',
        category: RoutineCategory.mindful,
        why: 'Naming one thing that matters today keeps the morning from'
            ' being decided by whoever messages you first.',
      ),
      HabitPackageItem(
        title: 'Phone-free first 30 min',
        icon: '📵',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Morning Calm',
        category: RoutineCategory.mindful,
        why: 'The single habit that protects the other four. Pick up the'
            ' phone first and the calm morning is already gone.',
      ),
    ],
  ),
  // 2 — Athlete Start
  HabitPackage(
    id: 'pkg.athlete_start',
    name: 'I’m becoming an athlete',
    shortName: 'Athlete Start',
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
        why: 'Any movement counts — walk, ride, swim, lift. Daily beats'
            ' intense: consistency is what turns exercise into identity.',
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
        why: 'Training loads dehydrate you, and dehydration shows up as'
            ' fatigue you’ll blame on the workout instead of the water.',
      ),
      HabitPackageItem(
        title: 'Stretch / mobility',
        icon: '🤸',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Athlete',
        category: RoutineCategory.health,
        why: 'The habit that keeps the other ones possible. Most people'
            ' stop training because of a niggle, not a lack of motivation.',
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
        why: 'Three a week, not daily — muscle is built in the recovery'
            ' between sessions, so more is genuinely worse here.',
      ),
      HabitPackageItem(
        title: 'Lights out by 11pm',
        icon: '🌙',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Athlete',
        category: RoutineCategory.rest,
        why: 'Sleep is where training turns into adaptation. Skip it and'
            ' you get the soreness without the gains.',
      ),
    ],
  ),
  // 3 — Deep Learning
  HabitPackage(
    id: 'pkg.deep_learning',
    name: 'I’m becoming a scholar',
    shortName: 'Deep Learning',
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
        why: 'Half an hour of real reading a day is roughly a book a'
            ' fortnight. The volume compounds far faster than people expect.',
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
        why: 'One uninterrupted hour on the hardest thing you have. Deep'
            ' work is a skill that fades without regular practice.',
      ),
      HabitPackageItem(
        title: 'Capture one lesson',
        icon: '✍️',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Learner',
        category: RoutineCategory.creative,
        why: 'Writing down one thing you learned is what separates reading'
            ' from remembering. One sentence is enough.',
      ),
      HabitPackageItem(
        title: 'Review the week’s notes',
        icon: '🗂️',
        habitType: HabitType.yesNo,
        frequency: Frequency.xPerWeek,
        identity: 'Learner',
        category: RoutineCategory.creative,
        targetValue: 1,
        why: 'Revisiting your notes once a week is spaced repetition in'
            ' its simplest form — it’s what moves knowledge into memory.',
      ),
    ],
  ),
  // 4 — Sleep Reset
  HabitPackage(
    id: 'pkg.sleep_reset',
    name: 'I’m becoming someone who sleeps well',
    shortName: 'Sleep Reset',
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
        why: 'Screens keep you alert through light and through content.'
            ' The hour before bed is the one that decides how fast you drop off.',
      ),
      HabitPackageItem(
        title: 'In bed by 11pm',
        icon: '🛏️',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Sleeper',
        category: RoutineCategory.rest,
        why: 'A consistent bedtime matters more than a perfect one. Your'
            ' body clock responds to regularity, not to the number on it.',
      ),
      HabitPackageItem(
        title: 'Wake at 7am',
        icon: '☀️',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Sleeper',
        category: RoutineCategory.rest,
        why: 'The fixed wake time is what actually resets the clock —'
            ' including weekends, which is the part most people skip.',
      ),
      HabitPackageItem(
        title: 'No caffeine after 2pm',
        icon: '☕',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Sleeper',
        category: RoutineCategory.rest,
        why: 'Caffeine has a long half-life — an afternoon coffee is still'
            ' in your system at midnight, even if you fall asleep fine.',
      ),
      HabitPackageItem(
        title: 'Wind-down ritual',
        icon: '🕯️',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Sleeper',
        category: RoutineCategory.rest,
        why: 'The same few calm minutes every night become a signal your'
            ' body learns to read as "sleep is next".',
      ),
    ],
  ),
  // 5 — Caffeine Cut (reduce)
  HabitPackage(
    id: 'pkg.caffeine_cut',
    name: 'I’m becoming free of the caffeine cycle',
    shortName: 'Caffeine Cut',
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
        why: 'Counting, not quitting. Most people have no idea what their'
            ' real daily number is, and the number alone starts lowering it.',
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
        why: 'Much of what feels like a caffeine craving is ordinary'
            ' thirst. Water first makes the cut markedly easier.',
      ),
      HabitPackageItem(
        title: 'No caffeine after 12pm',
        icon: '🚫',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Caffeine Cut',
        category: RoutineCategory.health,
        why: 'A cutoff time is easier to hold than a daily limit, and it'
            ' improves your sleep — which is what lowers tomorrow’s need.',
      ),
    ],
  ),
  // 6 — Quit Smoking (quit)
  HabitPackage(
    id: 'pkg.quit_smoking',
    name: 'I’m becoming smoke-free',
    shortName: 'Quit Smoking',
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
        why: 'One day at a time, marked once a day. Sixty days is not a'
            ' target you hit — it’s sixty individual decisions.',
      ),
      HabitPackageItem(
        title: '5-min breathwork on craving',
        icon: '🌬️',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Quit Smoking',
        category: RoutineCategory.mindful,
        why: 'Cravings peak and pass in a few minutes. Having something'
            ' specific to do during that window is what gets you through it.',
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
        why: 'Water gives your hands and mouth something to do, which is'
            ' half of what the habit actually was.',
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
        why: 'A walk reliably lowers craving intensity, and it replaces'
            ' the break that smoking used to give you.',
      ),
    ],
  ),
  // 7 — Digital Detox
  HabitPackage(
    id: 'pkg.digital_detox',
    name: 'I’m becoming present again',
    shortName: 'Digital Detox',
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
        why: 'A ceiling, not a ban. Three hours leaves room for the phone'
            ' to be useful without it eating the evening.',
      ),
      HabitPackageItem(
        title: 'No phone in bed',
        icon: '🛏️',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Digital Detox',
        category: RoutineCategory.rest,
        why: 'The bedroom rule does double duty: it cuts scrolling and it'
            ' protects your sleep at the same time.',
      ),
      HabitPackageItem(
        title: 'Phone-free first 30 min',
        icon: '🌅',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Digital Detox',
        category: RoutineCategory.mindful,
        why: 'How you start sets your attention for hours. Begin in'
            ' someone else’s feed and you spend the day catching up.',
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
        why: 'Counting pickups makes an invisible habit visible. Awareness'
            ' does most of the work before any rule does.',
      ),
    ],
  ),
  // 8 — Self-Compassion
  HabitPackage(
    id: 'pkg.self_compassion',
    name: 'I’m becoming kinder to myself',
    shortName: 'Self-Compassion',
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
        why: 'Three specific things, not three big ones. Specific is what'
            ' makes this land instead of feeling like a chore.',
      ),
      HabitPackageItem(
        title: 'One kind affirmation',
        icon: '💗',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Self-Compassion',
        category: RoutineCategory.mindful,
        why: 'One sentence you’d say to a friend in your situation. Said'
            ' to yourself, in your own words.',
      ),
      HabitPackageItem(
        title: 'Notice negative self-talk',
        icon: '👀',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Self-Compassion',
        category: RoutineCategory.mindful,
        why: 'Just noticing — no fixing required. You can’t soften a voice'
            ' you haven’t heard yourself use.',
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
        why: 'Getting outside shifts mood measurably, and it interrupts'
            ' the loop that indoor rumination feeds on.',
      ),
    ],
  ),
  // 9 — Creative Spark
  HabitPackage(
    id: 'pkg.creative_spark',
    name: 'I’m becoming a maker',
    shortName: 'Creative Spark',
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
        why: 'Showing up daily matters more than the quality of any one'
            ' session. Makers are people who make on the uninspired days too.',
      ),
      HabitPackageItem(
        title: 'Capture one idea',
        icon: '💡',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Creator',
        category: RoutineCategory.creative,
        why: 'Ideas arrive unannounced and leave the same way. A captured'
            ' one becomes raw material; an uncaptured one is gone.',
      ),
      HabitPackageItem(
        title: 'Sketch or brainstorm',
        icon: '✏️',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Creator',
        category: RoutineCategory.creative,
        why: 'Low-stakes play, separate from finished work. This is where'
            ' the ideas worth shipping usually come from.',
      ),
      HabitPackageItem(
        title: 'Ship one piece',
        icon: '🚀',
        habitType: HabitType.yesNo,
        frequency: Frequency.xPerWeek,
        identity: 'Creator',
        category: RoutineCategory.creative,
        targetValue: 1,
        why: 'Weekly, and rough is fine. Finishing is a separate skill'
            ' from making, and it only improves by being practised.',
      ),
    ],
  ),
  // 10 — Reset Week
  HabitPackage(
    id: 'pkg.reset_week',
    name: 'I’m resetting',
    shortName: 'Reset Week',
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
        why: 'The smallest possible starting point. A reset week works by'
            ' being genuinely easy to complete.',
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
        why: 'Twenty minutes, any intensity. Enough to change how the day'
            ' feels without needing to be scheduled around.',
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
        why: 'Seven days off is long enough to notice the difference in'
            ' your sleep and mood, and short enough to commit to.',
      ),
      HabitPackageItem(
        title: '8h sleep window',
        icon: '🌙',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Reset Week',
        category: RoutineCategory.rest,
        why: 'Protecting the window matters more than hitting eight hours'
            ' exactly. Give yourself the chance and the sleep follows.',
      ),
      HabitPackageItem(
        title: 'Three gratitudes',
        icon: '🙏',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Reset Week',
        category: RoutineCategory.mindful,
        why: 'A one-minute counterweight to a heavy stretch. It shifts'
            ' what you notice, which is most of what a reset is.',
      ),
      HabitPackageItem(
        title: 'Phone-free evening',
        icon: '📵',
        habitType: HabitType.yesNo,
        frequency: Frequency.daily,
        identity: 'Reset Week',
        category: RoutineCategory.mindful,
        why: 'The evening is where a reset week is won or lost. Off the'
            ' phone, the other five habits have room to happen.',
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
