import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/sfx_type.dart';
import '../services/badge_service.dart';
import '../services/effects_service.dart';
import '../services/habit_repository.dart';
import '../services/haptic_service.dart';
import '../services/milestone_service.dart';
import '../services/sfx_service.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/add_habit_sheet.dart';
import '../widgets/badge_unlock_modal.dart';
import '../widgets/empty_state.dart';
import '../widgets/freeze_badge.dart';
import '../widgets/freeze_modal.dart';
import '../widgets/habit_card.dart';
import '../widgets/responsive_container.dart';
import 'habit_detail_screen.dart';

import '../models/user_profile.dart';
import '../services/freeze_service.dart';

const String _kAllFilter = '__all__';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final HabitRepository _repo = HabitRepository();
  final UserRepository _userRepo = UserRepository();
  late final ValueListenable<Box<Habit>> _habitListenable =
      _repo.watchHabits();
  late final ValueListenable<Box<HabitLog>> _logListenable =
      _repo.watchLogs();

  String _filter = _kAllFilter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        children: [
          const _BackgroundGlow(),
          SafeArea(
            child: ResponsiveContainer(
              maxWidth: 560,
              child: ValueListenableBuilder<Box<Habit>>(
                  valueListenable: _habitListenable,
                  builder: (context, habitBox, _) =>
                      ValueListenableBuilder<Box<HabitLog>>(
                    valueListenable: _logListenable,
                    builder: (context, logBox, _) {
                      final today = DateTime.now();
                      final all = _repo.getActiveHabits();
                      final user = _userRepo.getCurrentUser();
                      final identities = <String>{
                        for (final h in all) h.identity,
                        ...?user?.identities,
                      }.toList();

                      final scheduled =
                          all.where((h) => h.isScheduledFor(today)).toList();
                      final visible = _filter == _kAllFilter
                          ? all
                          : all
                              .where((h) => h.identity == _filter)
                              .toList();

                      final completedToday = scheduled.where((h) {
                        final l = _repo.getLogForDate(h.id, today);
                        return l != null && l.isCompleted;
                      }).length;

                      final grouped = _groupByIdentity(visible);
                      final best = _bestStreak(all);

                      debugPrint(
                          '==> HabitsScreen build (habits=${all.length}, scheduled=${scheduled.length}, completed=$completedToday, filter=$_filter)');

                      // Detect a missed scheduled habit from yesterday and
                      // offer a freeze (once per session per habit per date).
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _maybePromptFreeze(all, user);
                      });

                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding:
                            const EdgeInsets.fromLTRB(20, 16, 20, 180),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Header(profile: user),
                            const SizedBox(height: 16),
                            _IdentityFilter(
                              identities: identities,
                              value: _filter,
                              onChanged: (v) =>
                                  setState(() => _filter = v),
                            ),
                            const SizedBox(height: 16),
                            _ProgressCard(
                              completed: completedToday,
                              total: scheduled.length,
                              bestStreak: best,
                            ),
                            const SizedBox(height: 22),
                            if (all.isEmpty)
                              EmptyState(
                                icon: Icons.check_circle_outline_rounded,
                                title: 'No habits yet',
                                subtitle:
                                    'Each habit is a vote for who you are becoming.',
                                ctaLabel: 'Build the first one',
                                onCta: () => _openSheet(),
                              )
                            else if (visible.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Text(
                                    'No habits for this identity yet.',
                                    style: TextStyle(
                                      color: AppColors.inkDim,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              )
                            else
                              for (final entry in grouped.entries) ...[
                                _GroupHeader(label: entry.key),
                                const SizedBox(height: 8),
                                for (var i = 0; i < entry.value.length; i++) ...[
                                  HabitCard(
                                    habit: entry.value[i],
                                    todayValue: _todayValue(entry.value[i]),
                                    last7: _last7(entry.value[i]),
                                    onTap: () => _openDetail(entry.value[i]),
                                    onIncrement: () =>
                                        _increment(entry.value[i]),
                                    onDecrement: () =>
                                        _decrement(entry.value[i]),
                                    onToggle: () =>
                                        _toggle(entry.value[i]),
                                  )
                                      .animate(delay: (40 * i).ms)
                                      .fadeIn(duration: 320.ms)
                                      .slideY(
                                          begin: 0.04,
                                          end: 0,
                                          curve: Curves.easeOut),
                                  if (i < entry.value.length - 1)
                                    const SizedBox(height: 10),
                                ],
                                const SizedBox(height: 18),
                              ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          Positioned(
            right: 24,
            bottom: 110,
            child: _Fab(onTap: _openSheet)
                .animate()
                .fadeIn(delay: 200.ms, duration: 350.ms)
                .scaleXY(begin: 0.7, end: 1.0, curve: Curves.easeOutBack),
          ),
        ],
      ),
    );
  }

  int _todayValue(Habit h) =>
      _repo.getLogForDate(h.id, DateTime.now())?.value ?? 0;

  List<HabitLog> _last7(Habit h) {
    final today = DateTime.now();
    return _repo.getLogsForHabit(
      h.id,
      from: today.subtract(const Duration(days: 6)),
      to: today,
    );
  }

  int _bestStreak(List<Habit> all) {
    var best = 0;
    for (final h in all) {
      final s = _repo.getStreakForHabit(h.id);
      if (s > best) best = s;
    }
    return best;
  }

  Map<String, List<Habit>> _groupByIdentity(List<Habit> habits) {
    final map = <String, List<Habit>>{};
    for (final h in habits) {
      map.putIfAbsent(h.identity, () => []).add(h);
    }
    return map;
  }

  Future<void> _openSheet({Habit? editing}) async {
    HapticService().light();
    await showAddHabitSheet(context, editing: editing);
  }

  Future<void> _openDetail(Habit habit) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HabitDetailScreen(habitId: habit.id),
      ),
    );
  }

  Future<void> _toggle(Habit h) async {
    final currentValue =
        _repo.getLogForDate(h.id, DateTime.now())?.value ?? 0;
    final willComplete = currentValue == 0;
    HapticService().medium();
    if (willComplete) {
      SfxService().fire(SfxType.habitComplete);
    }
    await _repo.toggleYesNoLog(habitId: h.id);
    if (willComplete) {
      _celebrateHabit(h);
    }
  }

  Future<void> _increment(Habit h) async {
    HapticService().light();
    final step = h.targetUnit?.toLowerCase().contains('minute') == true ? 5 : 1;
    await _repo.incrementLog(habitId: h.id, by: step);
    final after = _repo.getLogForDate(h.id, DateTime.now());
    if (after != null && after.isCompleted && after.value - step < after.targetValue) {
      SfxService().fire(SfxType.habitComplete);
      _celebrateHabit(h);
    }
  }

  void _celebrateHabit(Habit h) {
    if (!mounted) return;
    EffectsService().celebrateHabitComplete(context: context);
    // Streak milestone follow-up — Phoenix Rise for thresholds.
    final streak = _repo.getStreakForHabit(h.id);
    MilestoneService().checkStreak(streak).then((milestone) {
      if (milestone == null || !mounted) return;
      EffectsService().celebrateStreakMilestone(
        context: context,
        days: streak,
      );
    });
    // Badge check after the cinematic effects so the unlock celebration
    // doesn't clash with PremiumBloom / PhoenixRise.
    Future<void>.delayed(const Duration(milliseconds: 1200), () async {
      final awarded = await BadgeService().checkAndAwardBadges();
      if (awarded.isNotEmpty && mounted) {
        await showBadgeUnlockQueue(context, awarded);
      }
    });
  }

  Future<void> _decrement(Habit h) async {
    HapticService().light();
    final step = h.targetUnit?.toLowerCase().contains('minute') == true ? 5 : 1;
    await _repo.incrementLog(habitId: h.id, by: -step);
  }

  bool _freezePromptInFlight = false;

  Future<void> _maybePromptFreeze(
    List<Habit> habits,
    UserProfile? profile,
  ) async {
    if (_freezePromptInFlight || !mounted) return;
    if (profile == null || profile.freezesAvailable <= 0) return;

    final yesterday =
        DateTime.now().subtract(const Duration(days: 1));
    final y = DateTime(yesterday.year, yesterday.month, yesterday.day);

    // First habit that was scheduled yesterday, has an existing streak
    // worth protecting, wasn't completed, isn't already frozen, and that
    // we haven't already prompted about this session.
    final freezeSvc = FreezeService();
    Habit? target;
    for (final h in habits) {
      if (!h.isScheduledFor(y)) continue;
      if (h.isFrozenOn(y)) continue;
      final log = _repo.getLogForDate(h.id, y);
      if (log != null && log.isCompleted) continue;
      // Only suggest a freeze when there was a streak to lose (>= 2 days).
      final streak = _repo.getStreakForHabit(h.id);
      if (streak < 2) continue;
      if (freezeSvc.wasPrompted(kind: 'habit', id: h.id, date: y)) continue;
      target = h;
      break;
    }
    if (target == null) return;

    _freezePromptInFlight = true;
    freezeSvc.markPrompted(kind: 'habit', id: target.id, date: y);
    final habit = target;
    try {
      await showFreezeModal(
        context,
        itemType: 'habit',
        itemName: habit.title,
        date: y,
        profile: profile,
        onConfirm: () async {
          await freezeSvc.freezeHabit(habit, profile, y);
        },
      );
    } finally {
      if (mounted) _freezePromptInFlight = false;
    }
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
              top: -80,
              left: -80,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.purple.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              right: -100,
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
  const _Header({this.profile});
  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Habits',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontSize: 32,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                "Who you're becoming",
                style: TextStyle(
                  color: AppColors.inkDim,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
        if (profile != null)
          FreezeBadge(
            count: profile!.freezesAvailable,
            profile: profile,
          ),
      ],
    );
  }
}

class _IdentityFilter extends StatelessWidget {
  const _IdentityFilter({
    required this.identities,
    required this.value,
    required this.onChanged,
  });

  final List<String> identities;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final all = [_kAllFilter, ...identities];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: all.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final id = all[i];
          final selected = id == value;
          final label = id == _kAllFilter ? 'All' : id;
          return GestureDetector(
            onTap: () {
              HapticService().selection();
              onChanged(id);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient:
                    selected ? AppColors.buttonGradient : null,
                color: selected
                    ? null
                    : AppColors.bgCard.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected
                      ? Colors.transparent
                      : AppColors.purple.withValues(alpha: 0.20),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.pink.withValues(alpha: 0.35),
                          blurRadius: 14,
                        ),
                      ]
                    : null,
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.inkSoft,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.completed,
    required this.total,
    required this.bestStreak,
  });

  final int completed;
  final int total;
  final int bestStreak;

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0.0 : completed / total;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  total == 0
                      ? 'No habits scheduled today'
                      : '$completed of $total habits done today',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                '${(percent * 100).round()}%',
                style: TextStyle(
                  color: AppColors.pinkLight,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Container(
                  height: 10,
                  color: AppColors.bg.withValues(alpha: 0.7),
                ),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  widthFactor: percent.clamp(0, 1),
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: AppColors.buttonGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.pink.withValues(alpha: 0.45),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                bestStreak == 0
                    ? 'No streaks yet — start today.'
                    : 'Top streak: $bestStreak day${bestStreak == 1 ? '' : 's'}',
                style: TextStyle(
                  color: AppColors.inkDim,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, top: 4),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.buttonGradient,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: AppColors.inkDim,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _Fab extends StatelessWidget {
  const _Fab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.buttonGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.pink.withValues(alpha: 0.55),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: AppColors.purple.withValues(alpha: 0.45),
              blurRadius: 30,
              spreadRadius: -4,
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}
