import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/analytics_models.dart';
import '../models/earned_badge.dart';
import '../models/gratitude_entry.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/mood_entry.dart';
import '../services/analytics_service.dart';
import '../services/badge_definitions.dart';
import '../services/badge_service.dart';
import '../services/effects_service.dart';
import '../services/gratitude_repository.dart';
import '../services/habit_repository.dart';
import '../services/milestone_service.dart';
import '../services/mood_repository.dart';
import 'badges_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_number.dart';
import '../widgets/charts/habit_ring.dart';
import '../widgets/charts/identity_progress_bar.dart';
import '../widgets/charts/line_chart_card.dart';
import '../widgets/charts/streak_heatmap.dart';
import '../widgets/charts/time_of_day_chart.dart';
import '../widgets/highlight_card.dart';
import '../widgets/period_comparison.dart';
import '../widgets/responsive_container.dart';
import 'habit_detail_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final AnalyticsService _analytics = AnalyticsService();
  final MoodRepository _moods = MoodRepository();
  final HabitRepository _habits = HabitRepository();
  final GratitudeRepository _gratitude = GratitudeRepository();

  late final ValueListenable<Box<MoodEntry>> _moodListenable =
      _moods.watchEntries();
  late final ValueListenable<Box<Habit>> _habitListenable =
      _habits.watchHabits();
  late final ValueListenable<Box<HabitLog>> _logListenable =
      _habits.watchLogs();
  late final ValueListenable<Box<GratitudeEntry>> _gratitudeListenable =
      _gratitude.watchEntries();

  int _range = 30;
  // Tracks the last-seen progress per identity so we can detect crossings
  // (25/50/75/100%) between rebuilds and fire the constellation once.
  final Map<String, double> _identityHistory = {};

  void _onRangeChanged(int days) {
    HapticFeedback.selectionClick();
    setState(() => _range = days);
    _analytics.invalidate();
    // Range change is a snapshot swap, not a real progress event — reset the
    // history baseline so we don't fire from a stale comparison.
    _identityHistory.clear();
  }

  void _maybeCelebrateIdentity(Map<String, double> latest) {
    if (_identityHistory.isEmpty) {
      _identityHistory.addAll(latest);
      return;
    }
    for (final entry in latest.entries) {
      final prev = _identityHistory[entry.key];
      _identityHistory[entry.key] = entry.value;
      if (prev == null) continue;
      for (final threshold in const [0.25, 0.50, 0.75, 1.0]) {
        if (prev < threshold && entry.value >= threshold) {
          // Fire once per cross, asynchronously so we don't interleave the
          // build cycle. MilestoneService also persists the shown flag so a
          // user revisiting the Progress tab doesn't re-celebrate.
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final m = await MilestoneService().checkIdentityProgress(
              identity: entry.key,
              progress: entry.value,
            );
            if (m == null || !mounted) return;
            EffectsService().celebrateIdentityLevelUp(
              context: context,
              identity: entry.key,
              progress: entry.value,
            );
          });
          break; // only fire the highest threshold crossed in this tick
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        children: [
          const _BackgroundGlow(),
          SafeArea(
            child: ResponsiveContainer(
              maxWidth: 580,
              child: _Multilistener(
                  moods: _moodListenable,
                  habits: _habitListenable,
                  logs: _logListenable,
                  onChange: _analytics.invalidate,
                  builder: (context) => _buildContent(context),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final streak = _analytics.getCurrentStreak();
    final avgMood = _analytics.getAverageMood(_range);
    final habitRate = _analytics.getHabitsCompletionRate(_range);
    final series = _analytics.getMoodEnergyFocusOverTime(_range);
    final heatmap = _analytics.getStreakHeatmapData(_range);
    final identity = _analytics.getIdentityProgress(days: _range);
    _maybeCelebrateIdentity(identity);
    final topHabits = _analytics.getTopHabits(5, days: _range);
    final highlights = _analytics.getHighlights(_range);
    final tod = _analytics.getTimeOfDayPatterns(days: _range);
    final comparisons =
        _range >= 30 ? _analytics.getPeriodComparison(_range) : null;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 180),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Header(),
          const SizedBox(height: 16),
          _RangeSelector(value: _range, onChanged: _onRangeChanged),
          const SizedBox(height: 22),
          _HeroStats(
            streak: streak,
            avgMood: avgMood,
            habitRate: habitRate,
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
          const SizedBox(height: 12),
          ValueListenableBuilder<Box<EarnedBadge>>(
            valueListenable: BadgeService().watch(),
            builder: (context, box, _) => _BadgesPill(
              earned: box.values.map((b) => b.badgeKey).toSet().length,
              total: BadgeCatalog.count,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BadgesScreen()),
              ),
            )
                .animate()
                .fadeIn(delay: 150.ms, duration: 350.ms)
                .slideY(
                    begin: 0.04, end: 0, curve: Curves.easeOut),
          ),
          const SizedBox(height: 28),
          _Section(
            title: 'How you’ve been',
            child: LineChartCard(series: series),
          ),
          const SizedBox(height: 28),
          _Section(
            title: 'Your streak',
            trailing: streak == 0
                ? null
                : Text(
                    '$streak day${streak == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: AppColors.pinkLight,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.3,
                    ),
                  ),
            child: StreakHeatmap(days: heatmap),
          ),
          const SizedBox(height: 22),
          ValueListenableBuilder<Box<GratitudeEntry>>(
            valueListenable: _gratitudeListenable,
            builder: (context, _, _) {
              final streak = _gratitude.currentStreakSync();
              final monthCount = _gratitude.countThisMonth();
              if (streak == 0 && monthCount == 0) {
                return const SizedBox.shrink();
              }
              return _GratitudeStat(
                streak: streak,
                monthCount: monthCount,
              )
                  .animate()
                  .fadeIn(duration: 350.ms)
                  .slideY(begin: 0.05, end: 0, curve: Curves.easeOut);
            },
          ),
          const SizedBox(height: 28),
          _Section(
            title: 'Who you’re becoming',
            child: identity.isEmpty
                ? _EmptyHint(
                    text:
                        'Add a habit tied to an identity to see this grow.')
                : Column(
                    children: [
                      for (final e in identity.entries)
                        IdentityProgressBar(
                          identity: e.key,
                          value: e.value,
                          subtitle: _identityActionsLabel(e.key),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 28),
          _Section(
            title: 'Top habits',
            child: topHabits.isEmpty
                ? _EmptyHint(text: 'Log habits to surface your top streaks.')
                : SizedBox(
                    height: 168,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: topHabits.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, i) =>
                          _HabitRingCard(stats: topHabits[i]),
                    ),
                  ),
          ),
          const SizedBox(height: 28),
          _Section(
            title: 'Highlights',
            child: highlights.nonNull.isEmpty
                ? _EmptyHint(
                    text: 'Keep tracking — patterns appear after a few days.')
                : GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.5,
                    children: [
                      for (final h in highlights.nonNull)
                        HighlightCard(item: h),
                    ],
                  ),
          ),
          const SizedBox(height: 28),
          _Section(
            title: 'When you’re at your best',
            child: TimeOfDayChart(values: tod),
          ),
          if (comparisons != null) ...[
            const SizedBox(height: 28),
            _Section(
              title: 'This period vs last period',
              child: Column(
                children: [
                  for (var i = 0; i < comparisons.length; i++) ...[
                    PeriodComparisonRow(comparison: comparisons[i]),
                    if (i < comparisons.length - 1)
                      const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _identityActionsLabel(String identity) {
    final habits = _habits
        .getActiveHabits()
        .where((h) => h.identity == identity)
        .toList();
    var actions = 0;
    final today = DateTime.now();
    for (final h in habits) {
      final logs = _habits.getLogsForHabit(
        h.id,
        from: today.subtract(Duration(days: _range)),
        to: today,
      );
      actions += logs.where((l) => l.isCompleted).length;
    }
    return '$actions action${actions == 1 ? '' : 's'} this period';
  }
}

class _Multilistener extends StatelessWidget {
  const _Multilistener({
    required this.moods,
    required this.habits,
    required this.logs,
    required this.onChange,
    required this.builder,
  });

  final ValueListenable<Box<MoodEntry>> moods;
  final ValueListenable<Box<Habit>> habits;
  final ValueListenable<Box<HabitLog>> logs;
  final VoidCallback onChange;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<MoodEntry>>(
      valueListenable: moods,
      builder: (context, _, _) {
        return ValueListenableBuilder<Box<Habit>>(
          valueListenable: habits,
          builder: (context, _, _) {
            return ValueListenableBuilder<Box<HabitLog>>(
              valueListenable: logs,
              builder: (context, _, _) {
                onChange();
                return builder(context);
              },
            );
          },
        );
      },
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -100,
              right: -90,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.purple.withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 30,
              left: -100,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.pink.withValues(alpha: 0.20),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Progress',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontSize: 32,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          'Your journey so far',
          style: TextStyle(
            color: AppColors.inkDim,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static const _options = [7, 30, 90];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          for (final d in _options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: d == value ? AppColors.buttonGradient : null,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: d == value
                        ? [
                            BoxShadow(
                              color: AppColors.pink.withValues(alpha: 0.35),
                              blurRadius: 14,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    '$d days',
                    style: TextStyle(
                      color: d == value ? Colors.white : AppColors.inkDim,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroStats extends StatelessWidget {
  const _HeroStats({
    required this.streak,
    required this.avgMood,
    required this.habitRate,
  });

  final int streak;
  final double avgMood;
  final double habitRate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _HeroCard(
            emoji: '🔥',
            label: 'Streak',
            value: streak.toDouble(),
            fractionDigits: 0,
            suffix: ' d',
            accent: AppColors.pinkLight,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _HeroCard(
            emoji: '🌅',
            label: 'Avg mood',
            value: avgMood,
            fractionDigits: 1,
            suffix: '/10',
            accent: AppColors.purpleLight,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _HeroCard(
            emoji: '✨',
            label: 'Habits',
            value: habitRate * 100,
            fractionDigits: 0,
            suffix: '%',
            accent: AppColors.blueAccent,
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.emoji,
    required this.label,
    required this.value,
    required this.fractionDigits,
    required this.suffix,
    required this.accent,
  });

  final String emoji;
  final String label;
  final double value;
  final int fractionDigits;
  final String suffix;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.18),
            accent.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withValues(alpha: 0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accent.withValues(alpha: 0.45),
                  accent.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 12),
          AnimatedNumber(
            value: value,
            fractionDigits: fractionDigits,
            builder: (context, text) => Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: text,
                    style: GoogleFonts.instrumentSerif(
                      color: AppColors.ink,
                      fontStyle: FontStyle.italic,
                      fontSize: 26,
                      height: 1.0,
                    ),
                  ),
                  TextSpan(
                    text: suffix,
                    style: TextStyle(
                      color: AppColors.inkDim,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: AppColors.inkDim,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, right: 2, bottom: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              if (trailing != null) trailing as Widget,
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.bgCard.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.purple.withValues(alpha: 0.18),
            ),
          ),
          child: child,
        ),
      ],
    )
        .animate()
        .fadeIn(duration: 450.ms)
        .slideY(begin: 0.04, end: 0, curve: Curves.easeOut);
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: TextStyle(color: AppColors.inkDim, fontSize: 13),
      ),
    );
  }
}

class _HabitRingCard extends StatelessWidget {
  const _HabitRingCard({required this.stats});
  final HabitStats stats;

  @override
  Widget build(BuildContext context) {
    final color = Color(stats.habit.color);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => HabitDetailScreen(habitId: stats.habit.id),
        ),
      ),
      child: Container(
        width: 140,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.bg.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withValues(alpha: 0.22),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stats.habit.icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 8),
            Text(
              stats.habit.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: HabitRing(
                value: stats.completionRate,
                size: 72,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '🔥 ${stats.streak}d streak',
              style: TextStyle(
                color: AppColors.inkDim,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgesPill extends StatelessWidget {
  const _BadgesPill({
    required this.earned,
    required this.total,
    required this.onTap,
  });
  final int earned;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          decoration: BoxDecoration(
            color: AppColors.bgCard.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.purple.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.pinkLight.withValues(alpha: 0.85),
                      AppColors.purple.withValues(alpha: 0.20),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Achievements',
                  style: TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Text(
                '$earned / $total',
                style: TextStyle(
                  color: AppColors.pinkLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.purpleLight,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GratitudeStat extends StatelessWidget {
  const _GratitudeStat({required this.streak, required this.monthCount});
  final int streak;
  final int monthCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.pink.withValues(alpha: 0.20),
            AppColors.pinkLight.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.pinkLight.withValues(alpha: 0.40),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.pinkLight.withValues(alpha: 0.85),
                  AppColors.pink.withValues(alpha: 0.30),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.pink.withValues(alpha: 0.45),
                  blurRadius: 14,
                ),
              ],
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GRATITUDE',
                  style: TextStyle(
                    color: AppColors.inkDim,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$streak',
                      style: GoogleFonts.instrumentSerif(
                        color: AppColors.ink,
                        fontStyle: FontStyle.italic,
                        fontSize: 24,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      ' day streak',
                      style: TextStyle(
                        color: AppColors.inkSoft,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'THIS MONTH',
                style: TextStyle(
                  color: AppColors.inkFaint,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$monthCount',
                style: GoogleFonts.instrumentSerif(
                  color: AppColors.pinkLight,
                  fontStyle: FontStyle.italic,
                  fontSize: 22,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
