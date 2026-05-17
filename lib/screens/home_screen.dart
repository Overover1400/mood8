import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/adaptive_suggestion.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/mood_entry.dart';
import '../models/reflection.dart';
import '../models/routine_item.dart';
import '../models/sfx_type.dart';
import '../models/user_profile.dart';
import '../services/adaptive_routine_service.dart';
import '../services/habit_repository.dart';
import '../services/haptic_service.dart';
import '../services/mood_repository.dart';
import '../services/onboarding_service.dart';
import '../services/reflection_repository.dart';
import '../services/routine_repository.dart';
import '../services/score_service.dart';
import '../services/sfx_service.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/cards.dart';
import '../widgets/glow_slider.dart';
import '../widgets/habit_log_button.dart';
import '../widgets/mood_orb.dart';
import '../widgets/adaptive_suggestion_card.dart';
import '../widgets/reflection_card.dart';
import '../widgets/responsive_container.dart';
import '../widgets/settings/color_avatar.dart';
import 'habit_detail_screen.dart';
import 'main_navigation.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MoodRepository _moods = MoodRepository();
  final RoutineRepository _routines = RoutineRepository();
  final UserRepository _users = UserRepository();
  final ReflectionRepository _reflections = ReflectionRepository();
  final HabitRepository _habits = HabitRepository();
  final ScoreService _score = ScoreService();
  final AdaptiveRoutineService _adaptive = AdaptiveRoutineService();

  AdaptiveSuggestion? _suggestion;
  bool _applyingSuggestion = false;
  bool _suggestionLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSuggestion();
  }

  Future<void> _loadSuggestion() async {
    try {
      final s = await _adaptive.topSuggestion();
      if (!mounted) return;
      setState(() {
        _suggestion = s;
        _suggestionLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _suggestionLoaded = true);
    }
  }

  Future<void> _applySuggestion() async {
    final s = _suggestion;
    if (s == null || _applyingSuggestion) return;
    setState(() => _applyingSuggestion = true);
    try {
      final msg = await _adaptive.apply(s);
      await _adaptive.dismiss(s);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg ?? 'Got it — taking a look.'),
          backgroundColor: AppColors.bgCard,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
      setState(() {
        _suggestion = null;
        _applyingSuggestion = false;
      });
    } catch (_) {
      if (mounted) setState(() => _applyingSuggestion = false);
    }
  }

  Future<void> _dismissSuggestion() async {
    final s = _suggestion;
    if (s == null) return;
    await _adaptive.dismiss(s);
    if (!mounted) return;
    setState(() => _suggestion = null);
  }

  double _mood = 0.72;
  double _energy = 0.58;
  double _focus = 0.65;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        children: [
          const _BackgroundGlow(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: ResponsiveContainer(
                maxWidth: 480,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ValueListenableBuilder<Box<MoodEntry>>(
                        valueListenable: _moods.watchEntries(),
                        builder: (context, _, _) =>
                            ValueListenableBuilder<Box<UserProfile>>(
                          valueListenable: _users.watchUser(),
                          builder: (context, userBox, _) {
                            final user =
                                userBox.get(UserRepository.userKey);
                            return _Header(
                              name: user?.name ?? 'friend',
                              streak: _moods.calculateStreak(),
                              onLongPressName: () =>
                                  _confirmReset(context),
                              onOpenSettings: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              ),
                            );
                          },
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 500.ms)
                          .slideY(
                              begin: -0.15,
                              end: 0,
                              curve: Curves.easeOutCubic),
                      ValueListenableBuilder<Box<Reflection>>(
                        valueListenable: _reflections.watchReflections(),
                        builder: (context, _, _) {
                          final today = _reflections.getTodayReflection();
                          final hour = DateTime.now().hour;
                          if (today != null) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: ReflectionCard(
                                reflection: today,
                                compact: true,
                                onTap: () => MainNavigation.goToTab(
                                    context, kCoachTabIndex),
                              )
                                  .animate()
                                  .fadeIn(delay: 60.ms, duration: 500.ms)
                                  .slideY(
                                      begin: 0.06,
                                      end: 0,
                                      curve: Curves.easeOutCubic),
                            );
                          }
                          if (hour >= 18) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: _ReflectionNudge(
                                onTap: () => MainNavigation.goToTab(
                                    context, kCoachTabIndex),
                              )
                                  .animate()
                                  .fadeIn(delay: 60.ms, duration: 500.ms)
                                  .slideY(
                                      begin: 0.06,
                                      end: 0,
                                      curve: Curves.easeOutCubic),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      const SizedBox(height: 24),
                      _MoodHeroCard(
                        mood: _mood,
                        energy: _energy,
                        focus: _focus,
                        onMood: (v) => setState(() => _mood = v),
                        onEnergy: (v) => setState(() => _energy = v),
                        onFocus: (v) => setState(() => _focus = v),
                      )
                          .animate()
                          .fadeIn(delay: 100.ms, duration: 600.ms)
                          .slideY(
                              begin: 0.1, end: 0, curve: Curves.easeOutCubic),
                      const SizedBox(height: 18),
                      _SaveButton(
                        saving: _saving,
                        onTap: _handleSave,
                      )
                          .animate()
                          .fadeIn(delay: 250.ms, duration: 500.ms)
                          .slideY(
                              begin: 0.1, end: 0, curve: Curves.easeOutCubic),
                      const SizedBox(height: 28),
                      ValueListenableBuilder<Box<MoodEntry>>(
                        valueListenable: _moods.watchEntries(),
                        builder: (context, _, _) {
                          return ValueListenableBuilder<Box<RoutineItem>>(
                            valueListenable: _routines.watchRoutines(),
                            builder: (context, _, _) =>
                                ValueListenableBuilder<Box<HabitLog>>(
                              valueListenable: _habits.watchLogs(),
                              builder: (context, _, _) => _StatsRow(
                                streak: _moods.calculateStreak(),
                                completedToday: _routines
                                    .getTodayRoutines()
                                    .where((r) => r.isCompleted)
                                    .length,
                                totalToday:
                                    _routines.getTodayRoutines().length,
                                disciplineScore: _score.getDisciplineScore(),
                                onTapDiscipline: () =>
                                    MainNavigation.goToTab(
                                        context, kProgressTabIndex),
                              ),
                            ),
                          );
                        },
                      )
                          .animate()
                          .fadeIn(delay: 350.ms, duration: 500.ms)
                          .slideY(
                              begin: 0.1, end: 0, curve: Curves.easeOutCubic),
                      if (_suggestionLoaded && _suggestion != null) ...[
                        const SizedBox(height: 18),
                        AdaptiveSuggestionCard(
                          suggestion: _suggestion!,
                          applying: _applyingSuggestion,
                          onApply: _applySuggestion,
                          onDismiss: _dismissSuggestion,
                        )
                            .animate()
                            .fadeIn(delay: 380.ms, duration: 500.ms)
                            .slideY(
                                begin: 0.05,
                                end: 0,
                                curve: Curves.easeOut),
                      ],
                      const SizedBox(height: 28),
                      ValueListenableBuilder<Box<Habit>>(
                        valueListenable: _habits.watchHabits(),
                        builder: (context, _, _) =>
                            ValueListenableBuilder<Box<HabitLog>>(
                          valueListenable: _habits.watchLogs(),
                          builder: (context, _, _) => _TodayHabits(
                            habits: _habits
                                .getHabitsForDate(DateTime.now())
                                .take(3)
                                .toList(),
                            repo: _habits,
                            onSeeAll: () => MainNavigation.goToTab(
                                context, kHabitsTabIndex),
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 400.ms, duration: 500.ms)
                          .slideY(
                              begin: 0.1, end: 0, curve: Curves.easeOutCubic),
                      const SizedBox(height: 28),
                      ValueListenableBuilder<Box<RoutineItem>>(
                        valueListenable: _routines.watchRoutines(),
                        builder: (context, _, _) => _UpNextSection(
                          routines: _routines.getTodayRoutines(),
                          currentId: _routines.getCurrentRoutine()?.id,
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 450.ms, duration: 500.ms)
                          .slideY(
                              begin: 0.1, end: 0, curve: Curves.easeOutCubic),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }


  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Reset onboarding?',
            style: TextStyle(color: AppColors.ink)),
        content: const Text(
          'This clears your profile and routines so you can run onboarding again.',
          style: TextStyle(color: AppColors.inkSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset',
                style: TextStyle(color: Color(0xFFFF6B81))),
          ),
        ],
      ),
    );
    if (ok == true) {
      await OnboardingService().reset();
    }
  }

  static const Set<int> _kStreakMilestones = {3, 7, 30, 100, 365};

  Future<void> _handleSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _moods.addEntry(
        mood: _mood * 10,
        energy: _energy * 10,
        focus: _focus * 10,
      );
      final streak = _moods.calculateStreak();
      final hitMilestone = _kStreakMilestones.contains(streak);
      if (hitMilestone) {
        SfxService().fire(SfxType.streakMilestone);
        HapticService().heavy();
      } else {
        SfxService().fire(SfxType.checkInSuccess);
        HapticService().heavy();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hitMilestone
              ? '🔥 $streak-day streak — keep going.'
              : 'Check-in saved'),
          backgroundColor: AppColors.bgCard,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          duration: Duration(seconds: hitMilestone ? 3 : 2),
        ),
      );
    } catch (e) {
      SfxService().fire(SfxType.errorGentle);
      HapticService().heavy();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save check-in: $e'),
          backgroundColor: AppColors.bgCard,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
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
              top: -120,
              right: -80,
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.purple.withValues(alpha: 0.30),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -120,
              left: -100,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.pink.withValues(alpha: 0.25),
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
  const _Header({
    required this.name,
    required this.streak,
    required this.onLongPressName,
    required this.onOpenSettings,
  });

  final String name;
  final int streak;
  final VoidCallback onLongPressName;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final date = DateFormat('EEEE, MMM d').format(now).toUpperCase();
    final greeting = _greeting(now.hour);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date,
                style: TextStyle(
                  color: AppColors.inkDim,
                  fontSize: 11,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onLongPress: onLongPressName,
                behavior: HitTestBehavior.opaque,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$greeting,\n',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      TextSpan(
                        text: name,
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge
                            ?.copyWith(
                              foreground: Paint()
                                ..shader = AppColors.primaryGradient
                                    .createShader(const Rect.fromLTWH(
                                        0, 0, 220, 50)),
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: AppColors.softGradient,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: AppColors.purple.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                '$streak day streak',
                style: TextStyle(
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        ColorAvatar(
          name: name,
          size: 38,
          onTap: onOpenSettings,
        ),
      ],
    );
  }

  String _greeting(int hour) {
    if (hour < 5) return 'Late night';
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Good night';
  }
}

class _MoodHeroCard extends StatelessWidget {
  const _MoodHeroCard({
    required this.mood,
    required this.energy,
    required this.focus,
    required this.onMood,
    required this.onEnergy,
    required this.onFocus,
  });

  final double mood;
  final double energy;
  final double focus;
  final ValueChanged<double> onMood;
  final ValueChanged<double> onEnergy;
  final ValueChanged<double> onFocus;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Center(child: const MoodOrb(size: 160)),
          const SizedBox(height: 28),
          Center(
            child: Text(
              'How are you,',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          Center(
            child: Text(
              'right now?',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    foreground: Paint()
                      ..shader = AppColors.primaryGradient
                          .createShader(const Rect.fromLTWH(0, 0, 220, 40)),
                  ),
            ),
          ),
          const SizedBox(height: 22),
          GlowSlider(
            label: 'Mood',
            icon: Icons.favorite_rounded,
            value: mood,
            onChanged: onMood,
          ),
          const SizedBox(height: 16),
          GlowSlider(
            label: 'Energy',
            icon: Icons.bolt_rounded,
            value: energy,
            onChanged: onEnergy,
          ),
          const SizedBox(height: 16),
          GlowSlider(
            label: 'Focus',
            icon: Icons.center_focus_strong_rounded,
            value: focus,
            onChanged: onFocus,
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.saving, required this.onTap});

  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: saving ? null : onTap,
      child: Opacity(
        opacity: saving ? 0.7 : 1.0,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: AppColors.buttonGradient,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.pink.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: AppColors.purple.withValues(alpha: 0.40),
                blurRadius: 30,
                spreadRadius: -4,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                saving
                    ? Icons.hourglass_top_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                saving ? 'Saving…' : 'Save check-in',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.streak,
    required this.completedToday,
    required this.totalToday,
    required this.disciplineScore,
    required this.onTapDiscipline,
  });

  final int streak;
  final int completedToday;
  final int totalToday;
  final int disciplineScore;
  final VoidCallback onTapDiscipline;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            label: 'Streak',
            value: '$streak',
            emoji: '🔥',
            accent: AppColors.pinkLight,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            label: 'Today',
            value: '$completedToday / $totalToday',
            emoji: '⚡',
            accent: AppColors.blueAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: onTapDiscipline,
            child: StatCard(
              label: 'Discipline',
              value: disciplineScore == 0 ? '—' : '$disciplineScore',
              emoji: '🏆',
              accent: AppColors.purpleLight,
            ),
          ),
        ),
      ],
    );
  }
}

class _UpNextSection extends StatelessWidget {
  const _UpNextSection({
    required this.routines,
    required this.currentId,
  });

  final List<RoutineItem> routines;
  final String? currentId;

  @override
  Widget build(BuildContext context) {
    final visible = routines.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4, bottom: 14),
          child: Row(
            children: [
              Text(
                'Up next',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Spacer(),
              Text(
                'See all',
                style: TextStyle(
                  color: AppColors.purpleLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No routines yet.',
              style: TextStyle(color: AppColors.inkDim, fontSize: 13),
            ),
          )
        else
          for (var i = 0; i < visible.length; i++) ...[
            RoutineCard(
              time: DateFormat('HH:mm').format(visible[i].time),
              title: visible[i].title,
              subtitle: visible[i].meta,
              icon: visible[i].category.icon,
              isNow: visible[i].id == currentId,
            ),
            if (i < visible.length - 1) const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _TodayHabits extends StatelessWidget {
  const _TodayHabits({
    required this.habits,
    required this.repo,
    required this.onSeeAll,
  });

  final List<Habit> habits;
  final HabitRepository repo;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (habits.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4, bottom: 12),
          child: Row(
            children: [
              Text(
                "Today's habits",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Spacer(),
              GestureDetector(
                onTap: onSeeAll,
                child: Text(
                  'See all',
                  style: TextStyle(
                    color: AppColors.purpleLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < habits.length; i++) ...[
          _MiniHabitRow(habit: habits[i], repo: repo),
          if (i < habits.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _MiniHabitRow extends StatelessWidget {
  const _MiniHabitRow({required this.habit, required this.repo});
  final Habit habit;
  final HabitRepository repo;

  @override
  Widget build(BuildContext context) {
    final color = Color(habit.color);
    final todayValue = repo.getLogForDate(habit.id, DateTime.now())?.value ?? 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => HabitDetailScreen(habitId: habit.id),
          ),
        ),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            color: AppColors.bgCard.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: color.withValues(alpha: 0.20),
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
                      color.withValues(alpha: 0.55),
                      color.withValues(alpha: 0.12),
                    ],
                  ),
                ),
                child: Text(habit.icon,
                    style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  habit.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              HabitLogButton(
                habit: habit,
                value: todayValue,
                compact: true,
                onIncrement: () {
                  final step = habit.targetUnit
                              ?.toLowerCase()
                              .contains('minute') ==
                          true
                      ? 5
                      : 1;
                  repo.incrementLog(habitId: habit.id, by: step);
                },
                onDecrement: () {
                  final step = habit.targetUnit
                              ?.toLowerCase()
                              .contains('minute') ==
                          true
                      ? 5
                      : 1;
                  repo.incrementLog(habitId: habit.id, by: -step);
                },
                onToggle: () => repo.toggleYesNoLog(habitId: habit.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReflectionNudge extends StatelessWidget {
  const _ReflectionNudge({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.purple.withValues(alpha: 0.18),
                AppColors.pink.withValues(alpha: 0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.pinkLight.withValues(alpha: 0.30),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.orbGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.pink.withValues(alpha: 0.40),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Tonight's reflection is ready",
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mood8 will read your day and write you a note.',
                      style: TextStyle(
                        color: AppColors.inkDim,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded,
                  color: AppColors.pinkLight, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
