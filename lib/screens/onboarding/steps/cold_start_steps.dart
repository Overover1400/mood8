import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../theme/app_theme.dart';

/// Onboarding questions 4 and 5 (spec 3.7).
///
/// These two exist for one reason: they are the cold-start engine's
/// only input. Before a user has any history, "when is your energy
/// highest" and "what stopped you last time" are what let the app say
/// something useful on day one instead of waiting three weeks for
/// personal data. Both are single-tap and skippable.
///
/// Question 6 ("how many habits to start with") is deliberately not
/// asked — spec 10.7 says to cut questions rather than extend
/// onboarding, and its default of 2 is the answer most people give.

class _TapChoiceStep extends StatelessWidget {
  const _TapChoiceStep({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selected,
    required this.onPick,
  });

  final String title;
  final String subtitle;
  final List<({String code, String label, IconData icon})> options;
  final String? selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineLarge,
            )
                .animate()
                .fadeIn(duration: 500.ms)
                .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                  color: BrandColors.inkDim(context), fontSize: 14),
            ).animate().fadeIn(delay: 120.ms, duration: 500.ms),
            const SizedBox(height: 20),
            for (var i = 0; i < options.length; i++) ...[
              _ChoiceCard(
                label: options[i].label,
                icon: options[i].icon,
                selected: selected == options[i].code,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onPick(options[i].code);
                },
              )
                  .animate(delay: (70 * i).ms)
                  .fadeIn(duration: 360.ms)
                  .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(colors: [
                    AppColors.purple.withValues(alpha: 0.28),
                    AppColors.pink.withValues(alpha: 0.18),
                  ])
                : null,
            color: selected
                ? null
                : BrandColors.bgCard(context).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? AppColors.pinkLight.withValues(alpha: 0.65)
                  : AppColors.purple.withValues(alpha: 0.22),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 20,
                  color: selected
                      ? AppColors.pinkLight
                      : BrandColors.inkDim(context)),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: BrandColors.ink(context),
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded,
                    size: 19, color: AppColors.pinkLight),
            ],
          ),
        ),
      ),
    );
  }
}

/// Q4 — "When do you usually feel most energetic?"
/// Seeds the adaptation engine's starting assumption, which real
/// check-in data replaces within one to two weeks.
class EnergyPeakStep extends StatelessWidget {
  const EnergyPeakStep({
    super.key,
    required this.selected,
    required this.onSubmit,
  });

  final String? selected;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) => _TapChoiceStep(
        title: 'When do you have\nthe most energy?',
        subtitle: "We'll put the demanding habits there first.",
        selected: selected,
        onPick: onSubmit,
        options: const [
          (code: 'morning', label: 'Morning', icon: Icons.wb_twilight_rounded),
          (
            code: 'afternoon',
            label: 'Afternoon',
            icon: Icons.wb_sunny_rounded
          ),
          (code: 'evening', label: 'Evening', icon: Icons.nights_stay_rounded),
          (code: 'varies', label: 'It varies', icon: Icons.shuffle_rounded),
        ],
      );
}

/// Q5 — "What stopped you last time you tried?"
/// Pre-configures the failure response and the tone of reminders, so
/// the first adaptation proposal is already pointed the right way.
class FailureReasonStep extends StatelessWidget {
  const FailureReasonStep({
    super.key,
    required this.selected,
    required this.onSubmit,
  });

  final String? selected;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) => _TapChoiceStep(
        title: 'What stopped you\nlast time?',
        subtitle: 'No wrong answer — it just tells us what to watch for.',
        selected: selected,
        onPick: onSubmit,
        options: const [
          (code: 'no_time', label: 'No time', icon: Icons.schedule_rounded),
          (
            code: 'lost_motivation',
            label: 'Lost motivation',
            icon: Icons.trending_down_rounded
          ),
          (
            code: 'forgot',
            label: 'Kept forgetting',
            icon: Icons.notifications_off_rounded
          ),
          (
            code: 'too_hard',
            label: 'Too hard',
            icon: Icons.fitness_center_rounded
          ),
          (
            code: 'never_tried',
            label: 'Never really tried',
            icon: Icons.explore_rounded
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────
// Goal-setting questions.
//
// These four run before the energy/failure pair above. Together they
// answer: what are you actually trying to change, what is getting in
// the way, what is the ONE thing for the next 30 days, and where are
// you starting from.
//
// Every one is single-tap and skippable. They feed the same cold-start
// payload as Q4/Q5, so the first suggested plan is shaped by the user's
// stated goal instead of a generic default.
//
// Note on length: spec 10.7 caps onboarding at six questions. With these
// four the flow is longer than that cap, which is a deliberate trade —
// they were specified as required for the product's positioning. If
// first-session drop-off rises, these are the screens to move behind a
// dismissible "help mood8 know you" card on Home rather than cutting.
// ─────────────────────────────────────────────────────────────────────

/// Q1 — the headline goal. Sets which packages and habits get suggested.
class MainGoalStep extends StatelessWidget {
  const MainGoalStep({
    super.key,
    required this.selected,
    required this.onSubmit,
  });

  final String? selected;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) => _TapChoiceStep(
        title: 'What do you most\nwant to change?',
        subtitle: 'This shapes everything mood8 suggests next.',
        selected: selected,
        onPick: onSubmit,
        options: const [
          (
            code: 'build_habit',
            label: 'Build a new habit',
            icon: Icons.add_task_rounded
          ),
          (
            code: 'quit_habit',
            label: 'Quit a bad habit',
            icon: Icons.block_rounded
          ),
          (
            code: 'productivity',
            label: 'Get more organised and productive',
            icon: Icons.checklist_rounded
          ),
          (
            code: 'physical_health',
            label: 'Improve my physical health',
            icon: Icons.favorite_rounded
          ),
          (
            code: 'mental_health',
            label: 'Improve my mental health',
            icon: Icons.self_improvement_rounded
          ),
          (
            code: 'less_stress',
            label: 'Feel less stressed',
            icon: Icons.spa_rounded
          ),
          (
            code: 'specific_goal',
            label: 'Reach a specific goal',
            icon: Icons.flag_rounded
          ),
        ],
      );
}

/// Q2 — the pain point. The habit the user believes is holding them back
/// is usually the one worth attacking first, and naming it out loud is
/// itself part of why this question works.
class BlockingHabitStep extends StatelessWidget {
  const BlockingHabitStep({
    super.key,
    required this.selected,
    required this.onSubmit,
  });

  final String? selected;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) => _TapChoiceStep(
        title: 'What holds you\nback the most?',
        subtitle: 'The honest answer is the useful one.',
        selected: selected,
        onPick: onSubmit,
        options: const [
          (
            code: 'late_sleep',
            label: 'Going to bed too late',
            icon: Icons.bedtime_rounded
          ),
          (
            code: 'phone',
            label: 'Too much time on my phone',
            icon: Icons.smartphone_rounded
          ),
          (
            code: 'procrastination',
            label: 'Putting things off',
            icon: Icons.hourglass_empty_rounded
          ),
          (
            code: 'no_exercise',
            label: 'Not exercising',
            icon: Icons.directions_run_rounded
          ),
          (
            code: 'poor_diet',
            label: 'Eating badly',
            icon: Icons.restaurant_rounded
          ),
          (
            code: 'social_media',
            label: 'Social media',
            icon: Icons.thumb_up_off_alt_rounded
          ),
          (
            code: 'disorganised',
            label: 'Being disorganised',
            icon: Icons.inbox_rounded
          ),
          (
            code: 'stress',
            label: 'Stress and worry',
            icon: Icons.bolt_rounded
          ),
        ],
      );
}

/// Q3 — forces a single focus.
///
/// The most common way people fail is starting five habits at once. Asking
/// for exactly one, framed over a fixed 30 days, is the cheapest guard
/// against that in the whole flow.
class ThirtyDayFocusStep extends StatelessWidget {
  const ThirtyDayFocusStep({
    super.key,
    required this.selected,
    required this.onSubmit,
  });

  final String? selected;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) => _TapChoiceStep(
        title: 'If you changed just\none thing for 30 days?',
        subtitle: 'One. Starting five at once is why last time failed.',
        selected: selected,
        onPick: onSubmit,
        options: const [
          (
            code: 'exercise_20',
            label: '20 minutes of exercise a day',
            icon: Icons.fitness_center_rounded
          ),
          (
            code: 'read_daily',
            label: 'Read every day',
            icon: Icons.menu_book_rounded
          ),
          (
            code: 'sleep_before_12',
            label: 'Sleep before midnight',
            icon: Icons.nightlight_round
          ),
          (
            code: 'meditate',
            label: 'Meditate',
            icon: Icons.self_improvement_rounded
          ),
          (
            code: 'drink_water',
            label: 'Drink enough water',
            icon: Icons.water_drop_rounded
          ),
          (
            code: 'learn_skill',
            label: 'Learn a new skill',
            icon: Icons.school_rounded
          ),
        ],
      );
}

/// Q4 — the starting line.
///
/// Sets the difficulty of the first plan. Someone already doing something
/// 3–4 days a week needs a different first week from someone at zero, and
/// prescribing the same plan to both is how one of them gets discouraged.
class BaselineStep extends StatelessWidget {
  const BaselineStep({
    super.key,
    required this.selected,
    required this.onSubmit,
  });

  final String? selected;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) => _TapChoiceStep(
        title: 'Where are you\nstarting from?',
        subtitle: 'So the first week is a stretch, not a wall.',
        selected: selected,
        onPick: onSubmit,
        options: const [
          (
            code: 'never',
            label: "I don't do it at all right now",
            icon: Icons.radio_button_unchecked_rounded
          ),
          (
            code: 'rarely',
            label: '1–2 days a week',
            icon: Icons.looks_one_rounded
          ),
          (
            code: 'sometimes',
            label: '3–4 days a week',
            icon: Icons.looks_3_rounded
          ),
          (
            code: 'often',
            label: 'Almost every day',
            icon: Icons.check_circle_rounded
          ),
        ],
      );
}
