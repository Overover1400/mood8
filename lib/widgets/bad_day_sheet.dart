import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../services/bad_day_service.dart';
import '../services/habit_repository.dart';
import '../services/haptic_service.dart';
import '../theme/app_theme.dart';

/// The bad-day offer (spec 9.1).
///
/// Appears only after a check-in that reported low energy or low mood,
/// at most once a day, and only when the user still has habits left to
/// do. One tap accepts smaller versions for today; declining changes
/// nothing. It never blocks, and it never mentions failure.
class BadDaySheet extends StatelessWidget {
  const BadDaySheet({super.key, required this.habits});

  final List<Habit> habits;

  static Future<void> maybeShow(
    BuildContext context, {
    required double energy,
    required double mood,
    required List<Habit> remainingToday,
  }) async {
    final svc = BadDayService();
    if (!svc.isBadDay(energy: energy, mood: mood)) return;
    if (remainingToday.isEmpty) return;
    if (!await svc.shouldOfferToday()) return;
    await svc.markOffered();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BadDaySheet(habits: remainingToday.take(3).toList()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = BadDayService();
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        decoration: BoxDecoration(
          color: BrandColors.bgCard(context),
          borderRadius: BorderRadius.circular(24),
          border:
              Border.all(color: AppColors.purple.withValues(alpha: 0.30)),
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
              'Running low today.',
              style: TextStyle(
                color: BrandColors.ink(context),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Want the smaller version? It still counts, and your '
              'streak stays alive.',
              style: TextStyle(
                color: BrandColors.inkDim(context),
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            for (final h in habits)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: BrandColors.bgDeep(context).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.purple.withValues(alpha: 0.20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(h.icon, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              h.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: BrandColors.ink(context),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              svc.floorLabel(h),
                              style: TextStyle(
                                color: AppColors.pinkLight,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      HapticService().light();
                      for (final h in habits) {
                        await BadDayService().acceptFloor(h.id);
                      }
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.purple,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: const Text(
                      'Yes, smaller today',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BrandColors.inkSoft(context),
                      side: BorderSide(
                        color: AppColors.purple.withValues(alpha: 0.35),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: const Text('Full version'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Convenience for the Home screen: today's habits that still have no
/// log, so the offer is only about work that remains.
List<Habit> remainingHabitsToday(HabitRepository repo) {
  final today = DateTime.now();
  final done = <String>{};
  for (final l in repo.allLogs) {
    if (l.date.year == today.year &&
        l.date.month == today.month &&
        l.date.day == today.day) {
      done.add(l.habitId);
    }
  }
  return repo
      .getHabitsForDate(today)
      .where((h) => !done.contains(h.id))
      .toList();
}
