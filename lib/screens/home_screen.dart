import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

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
  double _mood = 0.72;
  double _energy = 0.58;
  double _focus = 0.65;
  int _navIndex = 0;

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
                      const _Header()
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
                      const _SaveButton()
                          .animate()
                          .fadeIn(delay: 250.ms, duration: 500.ms)
                          .slideY(
                              begin: 0.1, end: 0, curve: Curves.easeOutCubic),
                      const SizedBox(height: 28),
                      const _StatsRow()
                          .animate()
                          .fadeIn(delay: 350.ms, duration: 500.ms)
                          .slideY(
                              begin: 0.1, end: 0, curve: Curves.easeOutCubic),
                      const SizedBox(height: 28),
                      const _UpNextSection()
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
  const _Header();

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
                '12 day streak',
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
  const _SaveButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
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
      },
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
          children: const [
            Icon(Icons.check_circle_outline_rounded,
                color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text(
              'Save check-in',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
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

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            label: 'Streak',
            value: '12',
            emoji: '🔥',
            accent: AppColors.pinkLight,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            label: 'Today',
            value: '4 / 6',
            emoji: '⚡',
            accent: AppColors.blueAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            label: 'Score',
            value: '82',
            emoji: '✨',
            accent: AppColors.purpleLight,
          ),
        ),
      ],
    );
  }
}

class _UpNextSection extends StatelessWidget {
  const _UpNextSection();

  @override
  Widget build(BuildContext context) {
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
        const RoutineCard(
          time: '14:30',
          title: 'Deep work block',
          subtitle: 'Mood8 — design system',
          icon: Icons.psychology_alt_rounded,
          isNow: true,
        ),
        const SizedBox(height: 12),
        const RoutineCard(
          time: '16:00',
          title: 'Walk & sunlight',
          subtitle: '20 min · zone 2',
          icon: Icons.directions_walk_rounded,
        ),
        const SizedBox(height: 12),
        const RoutineCard(
          time: '19:00',
          title: 'Evening reset',
          subtitle: 'Journal · stretch · plan',
          icon: Icons.nightlight_round,
        ),
      ],
    );
  }
}
