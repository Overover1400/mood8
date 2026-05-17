import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/mood_entry.dart';
import '../models/routine_item.dart';
import '../services/mood_repository.dart';
import '../services/routine_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/cards.dart';
import '../widgets/glow_slider.dart';
import '../widgets/mood_orb.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MoodRepository _moods = MoodRepository();
  final RoutineRepository _routines = RoutineRepository();

  double _mood = 0.72;
  double _energy = 0.58;
  double _focus = 0.65;
  int _navIndex = 0;
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
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ValueListenableBuilder<Box<MoodEntry>>(
                        valueListenable: _moods.watchEntries(),
                        builder: (context, _, _) => _Header(
                          streak: _moods.calculateStreak(),
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 500.ms)
                          .slideY(
                              begin: -0.15,
                              end: 0,
                              curve: Curves.easeOutCubic),
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
                            builder: (context, _, _) => _StatsRow(
                              streak: _moods.calculateStreak(),
                              todayCheckIns:
                                  _moods.getEntriesForDate(DateTime.now()).length,
                              completedToday: _routines
                                  .getTodayRoutines()
                                  .where((r) => r.isCompleted)
                                  .length,
                              totalToday:
                                  _routines.getTodayRoutines().length,
                              score: _todayScore(),
                            ),
                          );
                        },
                      )
                          .animate()
                          .fadeIn(delay: 350.ms, duration: 500.ms)
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
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: MoodBottomNav(
              currentIndex: _navIndex,
              onTap: (i) => setState(() => _navIndex = i),
            )
                .animate()
                .fadeIn(delay: 550.ms, duration: 500.ms)
                .slideY(begin: 0.4, end: 0, curve: Curves.easeOutCubic),
          ),
        ],
      ),
    );
  }

  int _todayScore() {
    final today = _moods.getEntriesForDate(DateTime.now());
    if (today.isEmpty) return 0;
    final avg = today
            .map((e) => e.averageScore)
            .fold<double>(0, (a, b) => a + b) /
        today.length;
    return (avg * 100).round();
  }

  Future<void> _handleSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _moods.addEntry(
        mood: _mood * 10,
        energy: _energy * 10,
        focus: _focus * 10,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Check-in saved'),
          backgroundColor: AppColors.bgCard,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
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
  const _Header({required this.streak});

  final int streak;

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
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$greeting,\n',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    TextSpan(
                      text: 'Hamed',
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge
                          ?.copyWith(
                            foreground: Paint()
                              ..shader = AppColors.primaryGradient
                                  .createShader(
                                      const Rect.fromLTWH(0, 0, 220, 50)),
                          ),
                    ),
                  ],
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
    required this.todayCheckIns,
    required this.completedToday,
    required this.totalToday,
    required this.score,
  });

  final int streak;
  final int todayCheckIns;
  final int completedToday;
  final int totalToday;
  final int score;

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
          child: StatCard(
            label: 'Score',
            value: score == 0 && todayCheckIns == 0 ? '—' : '$score',
            emoji: '✨',
            accent: AppColors.purpleLight,
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
