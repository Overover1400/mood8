import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../services/habit_reminder_service.dart';
import '../services/haptic_service.dart';
import '../services/stepping_stone_service.dart';
import '../theme/app_theme.dart';

/// Third-miss offer: park the habit and build a smaller one first.
///
/// Never says the user failed, and never removes anything permanently —
/// the hard habit is archived with a visible route back.
class SteppingStoneSheet extends StatelessWidget {
  const SteppingStoneSheet({super.key, required this.habit});

  final Habit habit;

  static Future<bool> show(BuildContext context, {required Habit habit}) async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SteppingStoneSheet(habit: habit),
    );
    return r ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final svc = SteppingStoneService();
    final smaller = svc.steppingStoneTitle(habit);
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        decoration: BoxDecoration(
          color: BrandColors.bgCard(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.purple.withValues(alpha: 0.30)),
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
              '“${habit.title}” isn’t landing yet.',
              style: TextStyle(
                color: BrandColors.ink(context),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'That usually means it’s too big for right now, not that you '
              'can’t do it. Build a smaller version first — when that’s '
              'steady, mood8 brings this one back automatically.',
              style: TextStyle(
                color: BrandColors.inkSoft(context),
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: BrandColors.bgDeep(context).withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppColors.purple.withValues(alpha: 0.22)),
              ),
              child: Row(
                children: [
                  Icon(Icons.trending_down_rounded,
                      size: 17, color: AppColors.purpleLight),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Start instead with: $smaller',
                      style: TextStyle(
                        color: BrandColors.ink(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () async {
                HapticService().selection();
                final created = await svc.park(habit);
                if (created != null) {
                  await HabitReminderService().rescheduleFor(created);
                  await HabitReminderService().cancelFor(habit);
                }
                if (context.mounted) Navigator.of(context).pop(created != null);
              },
              child: Container(
                width: double.infinity,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.purple, AppColors.pink],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Do the smaller one',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Keep it as it is',
                  style: TextStyle(
                    color: BrandColors.inkDim(context),
                    fontSize: 13,
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
