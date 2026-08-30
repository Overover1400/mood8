import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../services/haptic_service.dart';
import '../services/miss_reason_service.dart';
import '../theme/app_theme.dart';

/// The second-miss question (spec 2.2 step 2).
///
/// Fixed options only — no free-text field. One tap answers it, the
/// sheet is dismissible, and skipping is a first-class outcome rather
/// than a low score. The whole interaction exists to give the
/// adaptation engine one fact it cannot infer from behaviour: *why*.
class MissReasonSheet extends StatelessWidget {
  const MissReasonSheet({super.key, required this.habit});

  final Habit habit;

  static const _options = <({String code, String label, IconData icon})>[
    (code: 'no_time', label: 'No time', icon: Icons.schedule_rounded),
    (code: 'too_tired', label: 'Too tired', icon: Icons.bedtime_rounded),
    (code: 'forgot', label: 'Forgot', icon: Icons.notifications_off_rounded),
    (code: 'too_hard', label: 'Too hard', icon: Icons.fitness_center_rounded),
    (
      code: 'not_important',
      label: 'Not important right now',
      icon: Icons.low_priority_rounded
    ),
  ];

  /// Shows the sheet if the engine has something to ask about. Safe to
  /// call on every Home build — it self-limits to once a day.
  static Future<void> maybeShow(BuildContext context) async {
    final habit = await MissReasonService().habitToAskAbout();
    if (habit == null || !context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MissReasonSheet(habit: habit),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        decoration: BoxDecoration(
          color: BrandColors.bgCard(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.purple.withValues(alpha: 0.30),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: BrandColors.inkFaint(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '“${habit.title}” slipped twice this week.',
              style: TextStyle(
                color: BrandColors.ink(context),
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'What got in the way? One tap — it helps mood8 fix the '
              'plan instead of just marking it missed.',
              style: TextStyle(
                color: BrandColors.inkDim(context),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            ..._options.map((o) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ReasonRow(
                    label: o.label,
                    icon: o.icon,
                    onTap: () async {
                      HapticService().light();
                      await MissReasonService().recordAnswer(
                        habitId: habit.id,
                        reason: o.code,
                      );
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                )),
            const SizedBox(height: 2),
            Center(
              child: TextButton(
                onPressed: () async {
                  // A skip is recorded as skipped — never as a bad
                  // score, and never re-asked tomorrow.
                  await MissReasonService()
                      .recordAnswer(habitId: habit.id, reason: null);
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color: BrandColors.inkDim(context),
                    fontWeight: FontWeight.w700,
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

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: BrandColors.bgDeep(context).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.purple.withValues(alpha: 0.24),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.pinkLight),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: BrandColors.ink(context),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
